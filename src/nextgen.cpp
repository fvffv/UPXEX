/* nextgen.cpp -- UPX Next Generation compression providers */

#include "conf.h"
#include "nextgen.h"
#include "compress/compress.h"
#include "util/membuffer.h"
#include <lz4/lib/lz4.h>
#include <lz4/lib/lz4hc.h>
#include <misa77/misa77.h>

namespace upx::nextgen {

static bool isKnownCompressionKind(CompressionKind kind) noexcept {
    switch (kind) {
    case CompressionKind::Nrv2b:
    case CompressionKind::Nrv2d:
    case CompressionKind::Nrv2e:
    case CompressionKind::Lzma:
    case CompressionKind::Lz4:
    case CompressionKind::Lz4Hc:
    case CompressionKind::Misa77:
        return true;
    }
    return false;
}

bool CompressedSegment::isValid(upx_uint64_t payload_size) const noexcept {
    if (!isKnownCompressionKind(compression) || original_size == 0 || compressed_size == 0)
        return false;
    if ((permissions & ~(PermissionRead | PermissionWrite | PermissionExecute)) != 0)
        return false;
    if (compressed_offset > payload_size || compressed_size > payload_size - compressed_offset)
        return false;
    if (virtual_address + original_size < virtual_address)
        return false;
    return true;
}

bool CompressedSegmentTableHeader::isValid(upx_uint64_t table_size) const noexcept {
    if (magic != Magic || version != Version || entry_size != sizeof(CompressedSegment))
        return false;
    constexpr upx_uint64_t header_size = sizeof(CompressedSegmentTableHeader);
    if (table_size < header_size)
        return false;
    return entry_count <= (table_size - header_size) / sizeof(CompressedSegment);
}

class LegacyCompressionProvider final : public ICompressionProvider {
public:
    explicit LegacyCompressionProvider(CompressionKind kind) noexcept : kind_(kind) {}

    CompressionKind kind() const noexcept override { return kind_; }
    const char *name() const noexcept override { return compressionKindName(kind_); }
    unsigned maxCompressedSize(unsigned source_size) const override {
        return MemBuffer::getSizeForCompression(source_size);
    }
    int compress(const byte *source, unsigned source_size, byte *destination,
                 unsigned *destination_size, int level) const override {
        return upx_compress(source, source_size, destination, destination_size, nullptr,
                            static_cast<int>(kind_), level, nullptr, nullptr);
    }
    int decompress(const byte *source, unsigned source_size, byte *destination,
                   unsigned *destination_size) const override {
        return upx_decompress(source, source_size, destination, destination_size,
                              static_cast<int>(kind_), nullptr);
    }

private:
    CompressionKind kind_;
};

class Lz4CompressionProvider final : public ICompressionProvider {
public:
    explicit Lz4CompressionProvider(bool high_compression) noexcept
        : high_compression_(high_compression) {}

    CompressionKind kind() const noexcept override {
        return high_compression_ ? CompressionKind::Lz4Hc : CompressionKind::Lz4;
    }
    const char *name() const noexcept override { return high_compression_ ? "lz4-hc" : "lz4"; }
    unsigned maxCompressedSize(unsigned source_size) const override {
        if (source_size > static_cast<unsigned>(LZ4_MAX_INPUT_SIZE))
            throwCantPack("LZ4 input block is too large");
        const int bound = LZ4_compressBound(static_cast<int>(source_size));
        if (bound <= 0)
            throwCantPack("invalid LZ4 input block size");
        return static_cast<unsigned>(bound);
    }
    int compress(const byte *source, unsigned source_size, byte *destination,
                 unsigned *destination_size, int level) const override {
        if (source == nullptr || destination == nullptr || destination_size == nullptr ||
            source_size > static_cast<unsigned>(LZ4_MAX_INPUT_SIZE) ||
            *destination_size > static_cast<unsigned>(INT_MAX))
            return UPX_E_INVALID_ARGUMENT;
        int result;
        if (high_compression_) {
            const int hc_level = level < 1 ? 1 : (level > LZ4HC_CLEVEL_MAX ? LZ4HC_CLEVEL_MAX : level);
            result = LZ4_compress_HC(reinterpret_cast<const char *>(source),
                                     reinterpret_cast<char *>(destination),
                                     static_cast<int>(source_size),
                                     static_cast<int>(*destination_size), hc_level);
        } else {
            result = LZ4_compress_default(reinterpret_cast<const char *>(source),
                                          reinterpret_cast<char *>(destination),
                                          static_cast<int>(source_size),
                                          static_cast<int>(*destination_size));
        }
        if (result <= 0)
            return UPX_E_OUTPUT_OVERRUN;
        *destination_size = static_cast<unsigned>(result);
        return UPX_E_OK;
    }
    int decompress(const byte *source, unsigned source_size, byte *destination,
                   unsigned *destination_size) const override {
        if (source == nullptr || destination == nullptr || destination_size == nullptr ||
            source_size > static_cast<unsigned>(INT_MAX) ||
            *destination_size > static_cast<unsigned>(INT_MAX))
            return UPX_E_INVALID_ARGUMENT;
        const int result = LZ4_decompress_safe(reinterpret_cast<const char *>(source),
                                               reinterpret_cast<char *>(destination),
                                               static_cast<int>(source_size),
                                               static_cast<int>(*destination_size));
        if (result < 0)
            return UPX_E_INPUT_OVERRUN;
        *destination_size = static_cast<unsigned>(result);
        return UPX_E_OK;
    }

private:
    bool high_compression_;
};

const ICompressionProvider &getCompressionProvider(CompressionKind kind) {
    static const LegacyCompressionProvider nrv2b(CompressionKind::Nrv2b);
    static const LegacyCompressionProvider nrv2d(CompressionKind::Nrv2d);
    static const LegacyCompressionProvider nrv2e(CompressionKind::Nrv2e);
    static const LegacyCompressionProvider lzma(CompressionKind::Lzma);
    static const Lz4CompressionProvider lz4(false);
    static const Lz4CompressionProvider lz4_hc(true);
    static const LegacyCompressionProvider misa77(CompressionKind::Misa77);
    switch (kind) {
    case CompressionKind::Nrv2b: return nrv2b;
    case CompressionKind::Nrv2d: return nrv2d;
    case CompressionKind::Nrv2e: return nrv2e;
    case CompressionKind::Lzma: return lzma;
    case CompressionKind::Lz4: return lz4;
    case CompressionKind::Lz4Hc: return lz4_hc;
    case CompressionKind::Misa77: return misa77;
    }
    throwInternalError("unknown Next Generation compression provider");
    return lz4; // unreachable; keeps compilers without noreturn knowledge happy
}

const char *compressionKindName(CompressionKind kind) noexcept {
    switch (kind) {
    case CompressionKind::Nrv2b: return "nrv2b";
    case CompressionKind::Nrv2d: return "nrv2d";
    case CompressionKind::Nrv2e: return "nrv2e";
    case CompressionKind::Lzma: return "lzma";
    case CompressionKind::Lz4: return "lz4";
    case CompressionKind::Lz4Hc: return "lz4-hc";
    case CompressionKind::Misa77: return "misa77";
    }
    return "unknown";
}

const char *upx_lz4_version_string() noexcept { return LZ4_versionString(); }

const char *upx_misa77_version_string() noexcept { return MISA77_VERSION_STR; }

bool supportsReleaseMemory(int format) noexcept {
    switch (format) {
    case UPX_F_W32PE_I386:
    case UPX_F_W64PE_AMD64:
    case UPX_F_W64PE_ARM64:
    case UPX_F_LINUX_i386:
    case UPX_F_LINUX_ELF_i386:
    case UPX_F_LINUX_SH_i386:
    case UPX_F_LINUX_ELFI_i386:
    case UPX_F_LINUX_ELF64_AMD64:
    case UPX_F_LINUX_ELF32_ARM:
    case UPX_F_LINUX_ELF32_MIPSEL:
    case UPX_F_LINUX_ELF64_PPC64LE:
    case UPX_F_LINUX_ELF64_ARM64:
    case UPX_F_LINUX_ELF64_RISCV64:
    case UPX_F_LINUX_ELF32_PPC32:
    case UPX_F_LINUX_ELF32_ARMEB:
    case UPX_F_LINUX_ELF32_MIPS:
    case UPX_F_LINUX_ELF64_PPC64:
    case UPX_F_MACH_i386:
    case UPX_F_MACH_ARM:
    case UPX_F_DYLIB_i386:
    case UPX_F_MACH_AMD64:
    case UPX_F_DYLIB_AMD64:
    case UPX_F_MACH_ARM64:
    case UPX_F_MACH_PPC32:
    case UPX_F_MACH_FAT:
    case UPX_F_DYLIB_PPC32:
    case UPX_F_MACH_PPC64:
    case UPX_F_DYLIB_PPC64:
        return true;
    default:
        return false;
    }
}

bool supportsNextGenerationTarget(int format) noexcept {
    if (supportsReleaseMemory(format))
        return true;
    switch (format) {
    case UPX_F_W32PE_I386:
    case UPX_F_W64PE_AMD64:
    case UPX_F_W64PE_ARM64:
        return true;
    default:
        return false;
    }
}

bool hasLz4Runtime(int format) noexcept {
    switch (format) {
    case UPX_F_W32PE_I386:
    case UPX_F_W64PE_AMD64:
    case UPX_F_W64PE_ARM64:
    case UPX_F_LINUX_ELF_i386:
    case UPX_F_LINUX_ELF32_ARM:
    case UPX_F_LINUX_ELF64_AMD64:
    case UPX_F_LINUX_ELF64_ARM64:
    case UPX_F_MACH_AMD64:
    case UPX_F_MACH_ARM64:
        return true;
    default:
        return false;
    }
}

bool hasMisa77Runtime(int format) noexcept {
    switch (format) {
    case UPX_F_W32PE_I386:
    case UPX_F_W64PE_AMD64:
    case UPX_F_W64PE_ARM64:
    case UPX_F_LINUX_ELF_i386:
    case UPX_F_LINUX_ELF32_ARM:
    case UPX_F_LINUX_ELF64_AMD64:
    case UPX_F_LINUX_ELF64_ARM64:
    case UPX_F_MACH_AMD64:
    case UPX_F_MACH_ARM64:
        return true;
    default:
        return false;
    }
}

TEST_CASE("nextgen compressed segment validation") {
    CompressedSegmentTableHeader header = {CompressedSegmentTableHeader::Magic,
                                           CompressedSegmentTableHeader::Version,
                                           sizeof(CompressedSegment), 1, 0};
    CHECK(header.isValid(sizeof(header) + sizeof(CompressedSegment)));
    header.entry_count = 2;
    CHECK_FALSE(header.isValid(sizeof(header) + sizeof(CompressedSegment)));

    CompressedSegment segment = {0x1000, 64, 32, 128, 0, CompressionKind::Lz4,
                                 PermissionRead | PermissionExecute,
                                 SegmentDiscardCompressedPages};
    CHECK(segment.isValid(96));
    segment.compressed_size = 33;
    CHECK_FALSE(segment.isValid(96));
}

TEST_CASE("nextgen LZ4 providers round trip") {
    byte source[4096];
    byte compressed[8192];
    byte restored[4096];
    for (unsigned i = 0; i < sizeof(source); ++i)
        source[i] = static_cast<byte>((i / 32) & 7);

    for (CompressionKind kind : {CompressionKind::Lz4, CompressionKind::Lz4Hc}) {
        const ICompressionProvider &provider = getCompressionProvider(kind);
        unsigned compressed_size = sizeof(compressed);
        REQUIRE(provider.compress(source, sizeof(source), compressed, &compressed_size, 9) ==
                UPX_E_OK);
        CHECK(compressed_size < sizeof(source));
        unsigned restored_size = sizeof(restored);
        REQUIRE(provider.decompress(compressed, compressed_size, restored, &restored_size) ==
                UPX_E_OK);
        CHECK(restored_size == sizeof(source));
        CHECK(memcmp(source, restored, sizeof(source)) == 0);
    }
}

TEST_CASE("nextgen misa77 provider round trip at all levels") {
    byte source[4096];
    byte compressed[8192];
    byte restored[4096];
    for (unsigned i = 0; i < sizeof(source); ++i)
        source[i] = static_cast<byte>((i / 29) & 15);

    const ICompressionProvider &provider = getCompressionProvider(CompressionKind::Misa77);
    for (int level = 1; level <= 6; ++level) {
        unsigned compressed_size = sizeof(compressed);
        REQUIRE(provider.compress(source, sizeof(source), compressed, &compressed_size, level) ==
                UPX_E_OK);
        CHECK(compressed_size < sizeof(source));
        unsigned restored_size = sizeof(restored);
        REQUIRE(provider.decompress(compressed, compressed_size, restored, &restored_size) ==
                UPX_E_OK);
        CHECK(restored_size == sizeof(source));
        CHECK(memcmp(source, restored, sizeof(source)) == 0);
    }
}

TEST_CASE("nextgen release-memory target capabilities") {
    CHECK(supportsReleaseMemory(UPX_F_W64PE_AMD64));
    CHECK(supportsReleaseMemory(UPX_F_W32PE_I386));
    CHECK(supportsReleaseMemory(UPX_F_W64PE_ARM64));
    CHECK(supportsReleaseMemory(UPX_F_LINUX_ELF64_AMD64));
    CHECK(supportsReleaseMemory(UPX_F_MACH_AMD64));
}

TEST_CASE("nextgen LZ4 runtime target capabilities") {
    CHECK(hasLz4Runtime(UPX_F_W32PE_I386));
    CHECK(hasLz4Runtime(UPX_F_W64PE_AMD64));
    CHECK(hasLz4Runtime(UPX_F_W64PE_ARM64));
    CHECK(hasLz4Runtime(UPX_F_LINUX_ELF_i386));
    CHECK(hasLz4Runtime(UPX_F_LINUX_ELF32_ARM));
    CHECK(hasLz4Runtime(UPX_F_LINUX_ELF64_AMD64));
    CHECK(hasLz4Runtime(UPX_F_LINUX_ELF64_ARM64));
    CHECK(hasLz4Runtime(UPX_F_MACH_AMD64));
    CHECK(hasLz4Runtime(UPX_F_MACH_ARM64));
    CHECK_FALSE(hasLz4Runtime(UPX_F_LINUX_ELF64_RISCV64));
    CHECK_FALSE(hasLz4Runtime(UPX_F_MACH_i386));
}

TEST_CASE("nextgen misa77 runtime target capabilities") {
    CHECK(hasMisa77Runtime(UPX_F_W64PE_AMD64));
    CHECK(hasMisa77Runtime(UPX_F_LINUX_ELF64_AMD64));
    CHECK(hasMisa77Runtime(UPX_F_MACH_AMD64));
    CHECK(hasMisa77Runtime(UPX_F_W32PE_I386));
    CHECK(hasMisa77Runtime(UPX_F_LINUX_ELF_i386));
    CHECK(hasMisa77Runtime(UPX_F_LINUX_ELF32_ARM));
    CHECK(hasMisa77Runtime(UPX_F_W64PE_ARM64));
    CHECK(hasMisa77Runtime(UPX_F_LINUX_ELF64_ARM64));
    CHECK(hasMisa77Runtime(UPX_F_MACH_ARM64));
}

} // namespace upx::nextgen
