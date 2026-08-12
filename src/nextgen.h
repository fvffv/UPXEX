/* nextgen.h -- shared UPX Next Generation compression model

   This file is part of the UPX executable compressor.

   The types in this file are independent of PE, ELF and Mach-O. Format
   packers translate their native section/segment metadata into this model;
   runtime stubs consume the serialized table only after validating it.
 */

#pragma once

namespace upx::nextgen {

enum class CompressionKind : upx_uint8_t {
    Nrv2b = M_NRV2B_LE32,
    Nrv2d = M_NRV2D_LE32,
    Nrv2e = M_NRV2E_LE32,
    Lzma = M_LZMA,
    Lz4 = 18,
    Lz4Hc = 19,
    Misa77 = M_MISA77,
};

enum SegmentPermission : upx_uint8_t {
    PermissionRead = 1u << 0,
    PermissionWrite = 1u << 1,
    PermissionExecute = 1u << 2,
};

enum SegmentFlag : upx_uint16_t {
    SegmentNone = 0,
    SegmentContainsMetadata = 1u << 0,
    SegmentDiscardCompressedPages = 1u << 1,
    SegmentRequiresRelocation = 1u << 2,
};

struct CompressedSegment final {
    upx_uint64_t virtual_address;
    upx_uint64_t compressed_offset;
    upx_uint64_t compressed_size;
    upx_uint64_t original_size;
    upx_uint32_t checksum;
    CompressionKind compression;
    upx_uint8_t permissions;
    upx_uint16_t flags;

    bool isValid(upx_uint64_t payload_size) const noexcept;
};

static_assert(sizeof(CompressedSegment) == 40, "stable compressed segment ABI");

struct CompressedSegmentTableHeader final {
    static constexpr upx_uint32_t Magic = 0x53475055u; // "UPGS" in little endian
    static constexpr upx_uint16_t Version = 1;

    upx_uint32_t magic;
    upx_uint16_t version;
    upx_uint16_t entry_size;
    upx_uint32_t entry_count;
    upx_uint32_t flags;

    bool isValid(upx_uint64_t table_size) const noexcept;
};

static_assert(sizeof(CompressedSegmentTableHeader) == 16, "stable segment table header ABI");

class ICompressionProvider {
public:
    virtual ~ICompressionProvider() noexcept = default;

    virtual CompressionKind kind() const noexcept = 0;
    virtual const char *name() const noexcept = 0;
    virtual unsigned maxCompressedSize(unsigned source_size) const = 0;
    virtual int compress(const byte *source, unsigned source_size, byte *destination,
                         unsigned *destination_size, int level) const = 0;
    virtual int decompress(const byte *source, unsigned source_size, byte *destination,
                           unsigned *destination_size) const = 0;
};

const ICompressionProvider &getCompressionProvider(CompressionKind kind);
const char *compressionKindName(CompressionKind kind) noexcept;
const char *upx_lz4_version_string() noexcept;
const char *upx_misa77_version_string() noexcept;
bool supportsReleaseMemory(int format) noexcept;
bool supportsNextGenerationTarget(int format) noexcept;
bool hasLz4Runtime(int format) noexcept;
bool hasMisa77Runtime(int format) noexcept;

} // namespace upx::nextgen
