# UPX Next Generation development status

The Next Generation layer introduces a format-neutral compressed segment table,
compression-provider abstraction, startup-oriented command profiles and a
repeatable benchmark harness. It deliberately refuses to emit an executable
when the selected target stub cannot implement the requested runtime contract.

## Commands

- `--fast-start` selects misa77 level `1` and enables `--release-memory` as a
  single startup-oriented preset. It preserves the original fast-start intent
  flag while also enabling memory reclamation and misa77 level `1`. Because
  the misa77 runtime decoder is currently implemented only for Win64 PE
  x86-64, other executable targets are rejected before output is created.
- `--release-memory` uses the ELF `munmap` path and the Mach-O payload-page
  unmap path. On x86, x64 and ARM64 PE executables the stub creates a tiny
  cleanup thread after decompression, imports, relocation and
  header-protection repair. The thread waits one second and then calls
  `SetProcessWorkingSetSize(GetCurrentProcess(), -1, -1)`, allowing the first
  window to appear before decompression-touched pages are evicted. A PE
  `MEM_IMAGE` subrange cannot safely be released with
  `VirtualFree(..., MEM_RELEASE)`, so the address space remains mapped.
  PE DLL and EFI images are rejected because trimming the host process from a
  DLL attach routine would be unsafe and EFI does not provide this Win32 API.
  Linux ELF shared objects are also rejected; the supported Linux targets are
  executable images, including PIE, whose startup loader owns the compressed
  mapping lifetime.
  This reduces resident and private working-set pages; it does not reduce the
  process private-commit counter because decompression has already created
  copy-on-write image pages. Removing that commit requires a different loader
  architecture backed by a new section mapping, not a working-set API.
- `--analyze` reports original and compressed sizes. Startup overhead and
  runtime memory remain explicitly unmeasured until the benchmark is run.
- `--stub-timing` is a Win64/x64 executable diagnostic mode. It inserts five
  `QueryPerformanceCounter` checkpoints around decompression, filters/imports/
  relocations, runtime setup, and final cleanup. After the last checkpoint it
  writes a fixed 64-byte `upx-stub-timing.bin` record in the program's current
  working directory. File creation and writing are excluded from every timed
  interval. Parse the record with `misc/nextgen/read-stub-timing.ps1`. The
  option is intentionally opt-in so release builds pay no import, size, or
  runtime cost.
- `--lz4` and `--lz4-hc` emit the same raw LZ4 block format. `--lz4` uses the
  startup-first fast encoder and `--lz4-hc` spends more packing time for a
  smaller stream. All eight targets listed above have an in-place runtime
  decoder; unsupported formats are rejected instead of producing an unusable
  executable.
- `--lz4-acceleration=N` tunes the LZ4 fast encoder from `1` through `65537`.
  The default is `16`. Lower values improve compression ratio but take longer
  to pack; higher values trade file size for faster packing and can reduce
  decompression work. This option applies to `--lz4`; it cannot be combined
  with `--lz4-hc`, whose encoder does not use the acceleration setting.
- `--misa77` selects misa77 0.6 with its default level `1`.
  `--misa77-level=N` accepts every upstream effort level from `-1` through
  `4`. Levels `-1` and `0` prioritize packing speed, level `1` generally has
  the fastest decompression, levels `2` and `3` spend progressively more time
  packing for a smaller stream, and level `4` selects misa77's heavy format.
  The runtime decoder is currently implemented only for Win64 PE x86-64;
  selecting misa77 for another executable format is rejected before output is
  created. The LZ4 providers and their supported targets are unchanged.

Compression-provider options are processed from left to right, so the last
provider option wins. The complete recommended preset is now:

```powershell
./upx.exe --fast-start -o app-packed.exe app.exe
./upx.exe --fast-start --misa77-level=4 -o app-smallest.exe app.exe
```

The first command automatically includes `--release-memory` and misa77 level
`1`. The second retains memory reclamation while overriding only the misa77
level; it usually creates a smaller file but takes much longer to pack and does
not normally decode faster than level `1`.

On Windows, the checked-in x86-64 PE stub can be regenerated with LLVM MC and
GNU binutils by running `src/stub/scripts/build-amd64-win64-modern.ps1`.
The script auto-detects MSVC and accepts explicit paths for every tool when a
different local toolchain layout is used.

## Benchmark

On Windows, pass representative 1 MB, 10 MB, 100 MB and 500 MB native
executables to:

```powershell
./misc/nextgen/benchmark.ps1 `
  -UpxPath ./build/upx.exe `
  -InputFiles ./samples/1mb.exe,./samples/10mb.exe,./samples/100mb.exe,./samples/500mb.exe `
  -Iterations 20
```

The CSV contains file size, median startup time, startup overhead relative to
the uncompressed executable, peak working set, peak private memory and CPU time.

## Validation scope

Every generated stub is checked for its LZ4/release section, relocation types
and the 64 KiB loader-size limit. Native execution is still required on each
target OS and architecture before treating ASLR, DEP/NX, PIE, relocation, TLS,
exception and unwind behavior as release-qualified. Cross-building and packing
alone do not replace that runtime validation. The current Mach-O x64 and ARM64
checks cover packing, `upx -t`, load-command inspection and byte-identical
unpack round trips; actual execution still requires matching macOS hardware.
