/* p_cpm86.h -- CP/M-86 .cmd executable format

   This file is part of the UPX executable compressor.

   Copyright (C) Markus Franz Xaver Johannes Oberhumer
   Copyright (C) Laszlo Molnar
   Copyright (C) Jeffrey H. Johnson
   All Rights Reserved.

   UPX and the UCL library are free software; you can redistribute them
   and/or modify them under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of
   the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; see the file COPYING.
   If not, write to the Free Software Foundation, Inc.,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   Markus F.X.J. Oberhumer              Laszlo Molnar
   <markus@oberhumer.com>               <ezerotven+github@gmail.com>
 */

#pragma once

/*************************************************************************
// CP/M-86 .cmd
//
// A .cmd file begins with a 128-byte header of up to 8 group descriptors
// (9 bytes each, sizes in 16-byte paragraphs):
//   +0 type (1=code 2=data 3=extra 4=stack 5..8=aux 9=escape, 0=unused)
//   +1 length  (paragraphs stored in the file)
//   +3 a_base  (absolute base paragraph)
//   +5 min     (paragraphs to allocate, minimum)
//   +7 max     (paragraphs to allocate, maximum)
// Group data follows the header in group order.  Three memory models exist:
//   8080    : code group only (base page at seg:0, entry seg:0x100)
//   small   : separate code + data groups (entry code:0)
//   compact : code + data + extra + stack groups
**************************************************************************/

class PackCpm86 final : public Packer {
    typedef Packer super;

public:
    explicit PackCpm86(InputFile *f);
    virtual int getVersion() const override { return 13; }
    virtual int getFormat() const override { return UPX_F_CPM86_CMD; }
    virtual const char *getName() const override { return "cpm86/cmd"; }
    virtual const char *getFullName(const Options *) const override { return "i086-cpm86.cmd"; }
    virtual const int *getCompressionMethods(int method, int level) const override;
    virtual const int *getFilters() const override;

    virtual void pack(OutputFile *fo) override;
    virtual void unpack(OutputFile *fo) override;

    virtual tribool canPack() override;
    virtual tribool canUnpack() override;

protected:
    virtual Linker *newLinker() const override;
    virtual void buildLoader(const Filter *ft) override;

    static constexpr unsigned CMD_HDR_SIZE = 128;
    static constexpr unsigned CMD_NGROUPS = 8;
    static constexpr unsigned GD_SIZE = 9;

    enum { GT_UNUSED = 0, GT_CODE = 1, GT_DATA = 2, GT_EXTRA = 3, GT_STACK = 4, GT_ESCAPE = 9 };

    struct Group {
        unsigned type;
        unsigned length;   // paragraphs stored in the file
        unsigned base;     // absolute base paragraph
        unsigned min;      // paragraphs to allocate (min)
        unsigned max;      // paragraphs to allocate (max)
        unsigned file_off; // byte offset of this group's data in the file
    };

    int readFileHeader(); // parse 'ih' header bytes into groups[]; returns format or 0
    // run-time allocation size (paragraphs) for a group, mirroring emu2's loader
    static unsigned allocParas(const Group *g, unsigned type, bool model_8080);

    byte ih[CMD_HDR_SIZE]; // original 128-byte header (kept verbatim for unpack)
    Group groups[CMD_NGROUPS];
    int ngroups = 0;
    unsigned image_end = 0; // file offset just past the last group's declared data
    // convenience pointers into groups[] (nullptr if absent)
    const Group *grp_code, *grp_data, *grp_extra, *grp_stack;
    bool model_8080 = false;
    // buildLoader links the in-place tail (CPMIP/CPMCOPY) only when this is set, so
    // method-0-only packs get a leaner loader (pack() clears it to fall back when
    // in-place would not meet the compression ratio).
    bool link_in_place = false;
};

/* vim:set ts=4 sw=4 et: */
