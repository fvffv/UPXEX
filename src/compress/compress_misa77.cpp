/* compress_misa77.cpp -- misa77 block support for Win64 executable images */

#include "../conf.h"
#include "compress.h"
#include "../util/membuffer.h"

#include <misa77/misa77.h>

#include <cstdint>

static int misa77_stream_level(int upx_level) noexcept
{
    // User-facing misa77 levels -1..4 are represented as UPX levels 1..6.
    // Some generic packer paths use level 10 for compressed headers/loaders;
    // treat that as misa77's highest level instead of rejecting the block.
    const int bounded_level = upx_level < 1 ? 1 : (upx_level > 6 ? 6 : upx_level);
    return bounded_level - 2;
}

int upx_misa77_compress(const upx_bytep src, unsigned src_len, upx_bytep dst,
                        unsigned *dst_len, upx_callback_t *cb, int method, int level,
                        const upx_compress_config_t *cconf,
                        upx_compress_result_t *cresult)
{
    assert(method == M_MISA77);
    UNUSED(cb);
    UNUSED(cconf);
    UNUSED(cresult);

    const int misa_level = misa77_stream_level(level);
    if (misa_level < misa77::config::min_level || misa_level > misa77::config::max_level)
        return UPX_E_INVALID_ARGUMENT;

    const misa77::config cfg(static_cast<int8_t>(misa_level));
    const upx_uint64_t bound = misa77::compress_bound(src_len, cfg);
    if (bound > *dst_len)
        return UPX_E_OUTPUT_OVERRUN;

    const upx_uint64_t result = misa77::compress(src, src_len, dst, *dst_len, cfg);
    if (result == 0 || result > UINT_MAX) {
        *dst_len = 0;
        return UPX_E_ERROR;
    }
    *dst_len = static_cast<unsigned>(result);
    return UPX_E_OK;
}

int upx_misa77_decompress(const upx_bytep src, unsigned src_len, upx_bytep dst,
                          unsigned *dst_len, int method,
                          const upx_compress_result_t *cresult)
{
    assert(method == M_MISA77);
    UNUSED(cresult);
    if (src_len < 8)
        return UPX_E_INPUT_OVERRUN;

    // Generic Unix unpacking places compressed input above the output in one
    // allocation. misa77 consumes a forward control stream and a backwards
    // literal stream, so that layout can overwrite input which is still live.
    // Runtime overlap is tested separately below; host-side decompression can
    // cheaply snapshot the compressed block when the ranges overlap.
    const upx_byte *input = src;
    MemBuffer input_copy;
    const uintptr_t src_begin = reinterpret_cast<uintptr_t>(src);
    const uintptr_t src_end = src_begin + src_len;
    const uintptr_t dst_begin = reinterpret_cast<uintptr_t>(dst);
    const uintptr_t dst_end = dst_begin + *dst_len;
    if (src_begin < dst_end && dst_begin < src_end) {
        input_copy.alloc(src_len);
        memcpy(input_copy, src, src_len);
        input = input_copy;
    }

    const upx_uint64_t expected = misa77::decompressed_size(input);
    if (expected != *dst_len)
        return UPX_E_ERROR;

    // Heavy streams currently have no upstream safe decoder. UPX validates
    // the compressed payload checksum before reaching this host-side path.
    const bool heavy = (input[7] & 1u) != 0;
    const upx_uint64_t result =
        misa77::decompress(input, src_len, dst, *dst_len, misa77::dconfig(!heavy));
    if (result != expected) {
        *dst_len = 0;
        return UPX_E_ERROR;
    }
    *dst_len = static_cast<unsigned>(result);
    return UPX_E_OK;
}

int upx_misa77_test_overlap(const upx_bytep buf, const upx_bytep tbuf,
                            unsigned src_off, unsigned src_len, unsigned *dst_len,
                            int method, const upx_compress_result_t *cresult)
{
    assert(method == M_MISA77);
    MemBuffer b(src_off + src_len);
    memcpy(b + src_off, buf + src_off, src_len);
    const unsigned expected = *dst_len;
    const upx_byte *const input = raw_index_bytes(b, src_off, src_len);
    const bool heavy = (input[7] & 1u) != 0;

    if (heavy) {
        // The upstream heavy decoder has no bounds-checked mode, so model the
        // byte-at-a-time runtime stubs here.  Reading and writing the same
        // MemBuffer is intentional: findOverlapOverhead() uses this to prove
        // that the selected in-place layout cannot overwrite unread controls
        // or literals.
        const unsigned input_end = src_off + src_len;
        if (src_len < 8 || expected > b.getSize())
            return UPX_E_ERROR;

        upx_uint64_t stream_size = 0;
        for (unsigned i = 0; i < 7; ++i)
            stream_size |= static_cast<upx_uint64_t>(b[src_off + i]) << (8 * i);
        if (stream_size != expected)
            return UPX_E_ERROR;

        unsigned out = 0;
        if (expected <= 64) {
            if (8u + expected > src_len)
                return UPX_E_ERROR;
            for (; out < expected; ++out)
                b[out] = b[src_off + 8 + out];
        } else {
            if (src_len < 16)
                return UPX_E_ERROR;
            upx_uint64_t suffix64 = 0;
            for (unsigned i = 0; i < 8; ++i)
                suffix64 |= static_cast<upx_uint64_t>(b[src_off + 8 + i]) << (8 * i);
            if (suffix64 > src_len - 16)
                return UPX_E_ERROR;
            const unsigned suffix = static_cast<unsigned>(suffix64);
            const unsigned suffix_start = input_end - suffix;
            unsigned literals = suffix_start;
            unsigned control = src_off + 16;

            while (control < literals) {
                if (literals - control < 4)
                    return UPX_E_ERROR;
                const upx_uint32_t token = static_cast<upx_uint32_t>(b[control]) |
                    (static_cast<upx_uint32_t>(b[control + 1]) << 8) |
                    (static_cast<upx_uint32_t>(b[control + 2]) << 16) |
                    (static_cast<upx_uint32_t>(b[control + 3]) << 24);
                control += 4;

                unsigned literal_len = token >> 26;
                unsigned match_len_code = (token >> 20) & 63u;
                const unsigned distance = (token & 0xfffffu) + 33u;
                if (literal_len == 63) {
                    unsigned extension;
                    do {
                        if (control >= literals)
                            return UPX_E_ERROR;
                        extension = b[control++];
                        if (literal_len > UINT_MAX - extension)
                            return UPX_E_ERROR;
                        literal_len += extension;
                    } while (extension == 255);
                }
                if (literal_len > literals - control || literal_len > expected - out)
                    return UPX_E_ERROR;
                literals -= literal_len;
                for (unsigned i = 0; i < literal_len; ++i)
                    b[out++] = b[literals + i];

                unsigned match_len;
                if (match_len_code == 0)
                    match_len = 0;
                else if (match_len_code <= 29)
                    match_len = match_len_code + 3;
                else if (match_len_code <= 45)
                    match_len = 2 * match_len_code - 26;
                else if (match_len_code <= 61)
                    match_len = 4 * match_len_code - 116;
                else
                    match_len = match_len_code == 62 ? 160 : 192;
                if (match_len > expected - out || distance > out)
                    return UPX_E_ERROR;
                for (unsigned i = 0; i < match_len; ++i) {
                    b[out] = b[out - distance];
                    ++out;
                }
            }
            if (suffix > expected - out)
                return UPX_E_ERROR;
            for (unsigned i = 0; i < suffix; ++i)
                b[out++] = b[suffix_start + i];
        }
        *dst_len = out;
        if (out != expected || (tbuf != nullptr && memcmp(tbuf, b, expected) != 0))
            return UPX_E_ERROR;
        return UPX_E_OK;
    }

    const upx_uint64_t result = misa77::decompress(input, src_len, raw_bytes(b, expected),
                                                   expected, misa77::dconfig(!heavy));
    *dst_len = result > UINT_MAX ? 0 : static_cast<unsigned>(result);
    if (result != expected)
        return UPX_E_ERROR;
    if (tbuf != nullptr && memcmp(tbuf, b, expected) != 0)
        return UPX_E_ERROR;
    return UPX_E_OK;
}

int upx_misa77_init(void) { return 0; }

const char *upx_misa77_version_string(void) { return MISA77_VERSION_STR; }
