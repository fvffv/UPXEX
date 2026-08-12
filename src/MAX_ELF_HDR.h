#pragma once
// Bound on byte length of ELF headers (Ehdr + Phdr[]).
// Possible 3-byte overrun during expansion of NRV2B
// must be handled in ::canPack etc.
#define MAX_ELF_HDR_32 1024
#define MAX_ELF_HDR_64 4096
