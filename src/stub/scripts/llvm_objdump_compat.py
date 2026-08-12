#!/usr/bin/env python3
"""Create the GNU objdump metadata consumed by UPX's in-process ELF linker.

Modern LLVM supports all architectures used by the next-generation stubs, but
its section table is not formatted like ``objdump -htr`` from GNU binutils.
This helper combines LLVM's JSON section information with its symbol and
relocation tables and emits the stable legacy format expected by linker.cpp.
"""

import argparse
import json
import math
import re
import subprocess
from pathlib import Path


def run(tool: Path, *args: str) -> str:
    return subprocess.check_output(
        [str(tool), *args], stderr=subprocess.STDOUT, text=True, encoding="utf-8"
    )


def table_from(text: str, marker: str) -> str:
    pos = text.find(marker)
    return "" if pos < 0 else text[pos:].strip()


def discard_mapping_symbols(text: str) -> str:
    """Drop local ARM/AArch64 mapping symbols, whose names are not unique."""
    return "\n".join(
        line
        for line in text.splitlines()
        if not re.search(r"\s\$(?:a|d|t|x)(?:\.\d+)?$", line)
    )


def normalize_relocation_addends(text: str, address_bits: int) -> str:
    width = address_bits // 4

    def replace(match: re.Match[str]) -> str:
        sign, digits = match.groups()
        return f"{sign}0x{int(digits, 16):0{width}x}"

    return re.sub(r"([+-])0x([0-9a-fA-F]+)", replace, text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--readelf", required=True, type=Path)
    parser.add_argument("--objdump", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--append-to", type=Path)
    parser.add_argument("input", type=Path)
    args = parser.parse_args()

    section_json = run(
        args.readelf, "--elf-output-style=JSON", "--sections", str(args.input)
    )
    root = json.loads(section_json)[0]
    summary = root["FileSummary"]
    address_bits = int(summary["AddressSize"].removesuffix("bit"))

    sections = []
    for wrapped in root["Sections"]:
        section = wrapped["Section"]
        section_type = section["Type"]["Name"]
        name = section["Name"]["Name"]
        if section_type in {"SHT_NULL", "SHT_NOBITS", "SHT_SYMTAB", "SHT_STRTAB"}:
            continue
        alignment = section["AddressAlignment"]
        align_power = 0 if alignment <= 1 else int(math.log2(alignment))
        assert 1 << align_power == max(1, alignment), (name, alignment)
        sections.append(
            (name, section["Size"], section["Address"], section["Offset"], align_power)
        )

    lines = [
        f"file format {summary['Format']}",
        "",
        "Sections:",
        "Idx Name Size VMA LMA File off Algn Flags",
    ]
    hex_width = address_bits // 4
    for index, (name, size, address, offset, align_power) in enumerate(sections):
        lines.append(
            f"{index:3d} {name} {size:0{hex_width}x} {address:0{hex_width}x} "
            f"{address:0{hex_width}x} {offset:0{hex_width}x} 2**{align_power} CONTENTS"
        )

    symbols = discard_mapping_symbols(
        table_from(run(args.objdump, "-t", str(args.input)), "SYMBOL TABLE:")
    )
    if symbols:
        lines.extend([symbols, ""])

    relocations = table_from(
        run(args.objdump, "-r", "-w", str(args.input)), "RELOCATION RECORDS FOR "
    )
    if relocations:
        lines.append(normalize_relocation_addends(relocations, address_bits))

    dump = ("\n".join(lines).rstrip() + "\n").encode("ascii")
    args.output.write_bytes(dump)
    if args.append_to:
        with args.append_to.open("ab") as output:
            output.write(dump)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
