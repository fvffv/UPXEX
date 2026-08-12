/* compress_lz4.cpp -- raw LZ4 block support for executable images */

#include "../conf.h"
#include "compress.h"
#include "../util/membuffer.h"

#include <lz4/lib/lz4.h>
#include <lz4/lib/lz4hc.h>

int upx_lz4_compress(const upx_bytep src, unsigned src_len, upx_bytep dst, unsigned *dst_len,
                     upx_callback_t *cb, int method, int level,
                     const upx_compress_config_t *cconf, upx_compress_result_t *cresult) {
    assert(method == M_LZ4);
    UNUSED(cb);
    UNUSED(cconf);
    UNUSED(cresult);
    if (src_len > (unsigned) LZ4_MAX_INPUT_SIZE || *dst_len > (unsigned) INT_MAX)
        return UPX_E_ERROR;

    int result;
    if (level >= 4) {
        const int hc_level = UPX_MIN(level, LZ4HC_CLEVEL_MAX);
        result = LZ4_compress_HC((const char *) src, (char *) dst, (int) src_len,
                                 (int) *dst_len, hc_level);
    } else {
        // A larger acceleration trades a little ratio for fewer match-search
        // decisions and is the startup-first profile used by --lz4.
        result = LZ4_compress_fast((const char *) src, (char *) dst, (int) src_len,
                                   (int) *dst_len, opt->nextgen.lz4_acceleration);
    }
    if (result <= 0) {
        *dst_len = 0;
        return UPX_E_ERROR;
    }
    *dst_len = (unsigned) result;
    return UPX_E_OK;
}

int upx_lz4_decompress(const upx_bytep src, unsigned src_len, upx_bytep dst, unsigned *dst_len,
                       int method, const upx_compress_result_t *cresult) {
    assert(method == M_LZ4);
    UNUSED(cresult);
    if (src_len > (unsigned) INT_MAX || *dst_len > (unsigned) INT_MAX)
        return UPX_E_ERROR;
    const int result = LZ4_decompress_safe((const char *) src, (char *) dst, (int) src_len,
                                           (int) *dst_len);
    if (result < 0) {
        *dst_len = 0;
        return UPX_E_ERROR;
    }
    *dst_len = (unsigned) result;
    return UPX_E_OK;
}

int upx_lz4_test_overlap(const upx_bytep buf, const upx_bytep tbuf, unsigned src_off,
                         unsigned src_len, unsigned *dst_len, int method,
                         const upx_compress_result_t *cresult) {
    assert(method == M_LZ4);
    MemBuffer b(src_off + src_len);
    memcpy(b + src_off, buf + src_off, src_len);
    const unsigned expected = *dst_len;
    const int r = upx_lz4_decompress(raw_index_bytes(b, src_off, src_len), src_len,
                                     raw_bytes(b, expected), dst_len, method, cresult);
    if (r != UPX_E_OK || *dst_len != expected)
        return UPX_E_ERROR;
    if (tbuf != nullptr && memcmp(tbuf, b, expected) != 0)
        return UPX_E_ERROR;
    return UPX_E_OK;
}

int upx_lz4_init(void) { return LZ4_VERSION_NUMBER == LZ4_versionNumber() ? 0 : -1; }

const char *upx_lz4_version_string(void) { return LZ4_versionString(); }
