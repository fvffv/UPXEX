/*
;  i086-cpm86.cmd.S -- loader & decompressor for the CP/M-86 .cmd format
;
;  This file is part of the UPX executable compressor.
;
;  Copyright (C) Markus Franz Xaver Johannes Oberhumer
;  Copyright (C) Laszlo Molnar
;  Copyright (C) Jeffrey H. Johnson
;  All Rights Reserved.
;
;  UPX and the UCL library are free software; you can redistribute them
;  and/or modify them under the terms of the GNU General Public License as
;  published by the Free Software Foundation; either version 2 of
;  the License, or (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program; see the file COPYING.
;  If not, write to the Free Software Foundation, Inc.,
;  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
;
;  Markus F.X.J. Oberhumer              Laszlo Molnar
;  <markus@oberhumer.com>               <ezerotven+github@gmail.com>
;
*/

/*
; Run-time strategy (method 0, BDOS scratch): the packed file is a small-model
; .cmd; the stub MC_ALLOCs a scratch, decompresses the whole original file into it,
; then MC_ALLOCs and fills one segment per group, rebuilds the base page, and enters
; the program.  CPMINFO byte +127 selects the method and is currently always 0; an
; in-place (no-BDOS) method 1 is planned but not yet enabled (see p_cpm86.cpp and
; the saved WIP), so the entry branch for method 1 is wired to cpm_fail.
*/

#include        "arch/i086/macros.S"

#define         BDOS    0xe0    /* CP/M-86 system call: INT 0E0h, func in CL */
#define         MC_ALLOC 55     /* allocate MCB.len paragraphs, segment -> MCB+0 */

/*
; =============
; ============= ENTRY POINT  (CS:0)
; =============
*/

section         CPMENTRY
                cld
                mov     al, [cs:cpm_info + 127]  /* method: 0 = BDOS scratch, 1 = in-place */
                test    al, al
                /* method 1: jump to cpm_ip_entry via a packer-set offset (CPMINFO+96).
                   The indirect jump avoids a link-time reference into CPMIP, so the
                   method-0-only loader can omit the in-place tail entirely. */
                jz      cpm_m0
                jmp     word ptr [cs:cpm_info + 96]
cpm_m0:

                /* ---- method 0: BDOS scratch ---- */
                mov     [cs:our_base], ds        /* our data/base group (set by CP/M) */
                push    cs
                pop     es
                xor     si, si
                mov     di, offset cpmbase
                mov     cx, 128
                rep     movsw                    /* save our base page */

                push    cs
                pop     ds
                mov     ax, [cs:cpm_info + 2]     /* scratch_paras */
                mov     [cs:mcb + 2], ax
                mov     byte ptr [cs:mcb + 4], 0
                mov     dx, offset mcb
                mov     cl, MC_ALLOC
                int     BDOS
                cmp     ax, 0xffff
                je      cpm_fail
                mov     ax, [cs:mcb + 0]
                mov     [cs:scratch_seg], ax

                push    cs
                pop     ds
                mov     dx, ds                   /* source segment */
                mov     si, offset cpm_src
                mov     es, [cs:scratch_seg]
                xor     di, di
                xor     cx, cx
                mov     bx, 0x800f
                mov     bp, 1
                call    decompr_start_n2b
                jmp     cpm_m1_tail

cpm_fail:
                mov     cl, 0
                int     BDOS                     /* BDOS 0: system reset / terminate */

/* ============= nrv2b_d8 decompressor (used as a subroutine) ============= */

#include        "arch/i086/nrv2b_d8.S"

section         CPMDRET
                ret                              /* return to caller after decomp_done */

/*
; =============
; ============= method 0 tail: rebuild groups via MC_ALLOC + enter program
; =============
*/

section         CPMTAIL
cpm_m1_tail:
                cld
                mov     word ptr [cs:cum_paras], 8   /* skip the 128-byte header */
                mov     word ptr [cs:gidx], 0

cpm_gloop:
                mov     bx, [cs:gidx]
                cmp     bl, [cs:cpm_info + 0]        /* ngroups */
                jae     cpm_gdone
                mov     cl, 3
                shl     bx, cl                       /* gidx * 8 */
                add     bx, offset cpm_info + 30     /* -> group entry */
                mov     al, [cs:bx + 0]              /* type */
                xor     ah, ah
                mov     [cs:cur_type], ax
                mov     ax, [cs:bx + 2]              /* length_paras */
                mov     [cs:cur_len], ax
                mov     ax, [cs:bx + 4]              /* alloc_paras */
                mov     [cs:cur_alloc], ax

                mov     al, [cs:cur_type]
                cmp     al, 4
                ja      cpm_advance                  /* aux/escape: only advance cum */
                cmp     al, 1
                jb      cpm_advance

                /* allocate this group; if the requested size is unavailable,
                   fall back to the largest free block (MC_MAX), like emu2 */
                push    cs
                pop     ds
                mov     ax, [cs:cur_alloc]
                mov     [cs:mcb + 2], ax
                mov     byte ptr [cs:mcb + 4], 0
                mov     dx, offset mcb
                mov     cl, MC_ALLOC                 /* 55: allocate exactly */
                int     BDOS
                cmp     ax, 0xffff
                jne     cpm_got
                mov     ax, [cs:cur_alloc]
                mov     [cs:mcb + 2], ax
                mov     cl, 53                       /* MC_MAX: size largest free (frees) */
                int     BDOS
                cmp     ax, 0xffff
                je      cpm_fail
                mov     cl, MC_ALLOC                 /* allocate that size (mcb+2 set) */
                int     BDOS
                cmp     ax, 0xffff
                je      cpm_fail
cpm_got:
                mov     ax, [cs:mcb + 0]
                mov     [cs:cur_seg], ax
                mov     ax, [cs:mcb + 2]
                mov     [cs:cur_got], ax

                /* copy cur_len paragraphs from scratch+cum to cur_seg:0 */
                mov     ax, [cs:scratch_seg]
                add     ax, [cs:cum_paras]
                mov     ds, ax
                mov     es, [cs:cur_seg]
                xor     si, si
                xor     di, di
                mov     cx, [cs:cur_len]
                shl     cx, 1
                shl     cx, 1
                shl     cx, 1                        /* len_paras * 8 = words */
                rep     movsw                        /* di now = cur_len*16 */

                /* zero up to 64K of BSS (cur_got - cur_len paragraphs, capped) */
                mov     ax, [cs:cur_got]
                sub     ax, [cs:cur_len]
                jbe     cpm_nobss
                cmp     ax, 0x1000
                jbe     cpm_zsz
                mov     ax, 0x1000
cpm_zsz:
                mov     cx, ax
                shl     cx, 1
                shl     cx, 1
                shl     cx, 1
                xor     ax, ax
                rep     stosw
cpm_nobss:
                /* base-page descriptor slot = cpm_info + 6 + (type-1)*6 */
                mov     bx, [cs:cur_type]
                dec     bx
                mov     ax, bx
                shl     ax, 1                        /* (type-1)*2 */
                shl     bx, 1
                shl     bx, 1                        /* (type-1)*4 */
                add     bx, ax                       /* (type-1)*6 */
                add     bx, offset cpm_info + 6
                mov     ax, [cs:cur_seg]
                mov     [cs:bx + 3], ax              /* segment */
                cmp     byte ptr [cs:cur_type], 2
                je      cpm_seg_done                 /* data: keep packer's sp_top length */
                mov     ax, [cs:cur_got]
                mov     dx, ax
                mov     cl, 4
                shl     ax, cl
                mov     [cs:bx + 0], ax              /* length low word = got<<4 */
                mov     ax, dx
                mov     cl, 12
                shr     ax, cl
                mov     [cs:bx + 2], al              /* length high byte */
cpm_seg_done:
                /* remember code/data/stack segments for register setup */
                mov     bx, [cs:cur_type]
                mov     ax, [cs:cur_seg]
                cmp     bl, 1
                jne     cpm_nr2
                mov     [cs:code_seg], ax
                jmp     cpm_advance
cpm_nr2:
                cmp     bl, 2
                jne     cpm_nr4
                mov     [cs:data_seg], ax
cpm_nr4:
                cmp     bl, 4
                jne     cpm_advance
                mov     [cs:stack_seg], ax
cpm_advance:
                mov     ax, [cs:cum_paras]
                add     ax, [cs:cur_len]
                mov     [cs:cum_paras], ax
                inc     word ptr [cs:gidx]
                jmp     cpm_gloop

cpm_gdone:
                /* free the scratch region; the program gets that memory back */
                push    cs
                pop     ds
                mov     ax, [cs:scratch_seg]
                mov     [cs:mcb + 0], ax
                mov     byte ptr [cs:mcb + 4], 0
                mov     dx, offset mcb
                mov     cl, 57                       /* MC_FREE */
                int     BDOS

                /* 8080 model: the data descriptor shares the code segment */
                cmp     byte ptr [cs:cpm_info + 1], 0
                je      cpm_not8080
                mov     ax, [cs:code_seg]
                mov     [cs:cpm_info + 6 + 6 + 3], ax    /* data slot seg = code seg */
                mov     [cs:data_seg], ax
cpm_not8080:
                mov     bx, [cs:data_seg]
                cmp     byte ptr [cs:cpm_info + 1], 0
                je      cpm_base_ok
                mov     bx, [cs:code_seg]
cpm_base_ok:
                mov     [cs:base_seg], bx

                push    cs
                pop     ds
                mov     si, offset cpmbase
                mov     es, [cs:base_seg]
                xor     di, di
                mov     cx, 128
                rep     movsw                        /* copy 256-byte base page */

                mov     si, offset cpm_info + 6
                mov     es, [cs:base_seg]
                xor     di, di
                mov     cx, 12
                rep     movsw                        /* overlay 24-byte descriptors */

                mov     es, [cs:base_seg]
                mov     word ptr es:[0x50], 0x00b1   /* exit trampoline: mov cl,0 */
                mov     word ptr es:[0x52], 0xe0cd   /*                  int 0E0h */

                mov     dx, [cs:base_seg]            /* set default DMA = base:0x80 */
                mov     cl, 51
                int     BDOS
                mov     dx, 0x80
                mov     cl, 26
                int     BDOS

                cli
                mov     ax, [cs:base_seg]
                mov     ss, ax
                mov     sp, [cs:cpm_info + 4]        /* sp_top */
                sti
                mov     ax, [cs:base_seg]
                push    ax
                mov     ax, 0x50
                push    ax
                mov     ax, [cs:code_seg]
                push    ax
                xor     ax, ax
                cmp     byte ptr [cs:cpm_info + 1], 0
                je      cpm_ip_ok
                mov     ax, 0x100                    /* 8080 model enters at 0x100 */
cpm_ip_ok:
                push    ax
                mov     ax, [cs:base_seg]
                mov     ds, ax
                mov     es, ax
                xor     ax, ax
                mov     bx, ax
                mov     cx, ax
                mov     dx, 0x80
                xor     si, si
                xor     di, di
                xor     bp, bp
                lret

/*
; =============
; ============= method 1 tail: in-place, no BDOS
; =============
; The packed .cmd mirrors the original group structure, so the CP/M-86 loader
; itself allocates the data/extra/stack segments and builds the base page.  The
; stub decompresses the whole original file into the (loader-given) DATA group,
; copies each non-code group's slice to its own segment, moves the data slice down
; to data_seg:0, restores the base page, then relocates a tiny copy routine into
; the code group's spare allocation (above the final code) and enters it; that
; routine copies the staged code down to code:0 and far-jumps to the program.
*/
section         CPMIP
cpm_ip_entry:
                /* private stack in the code group (decompressing into the data
                   group must not corrupt our entry stack, which is SS=data_seg) */
                mov     ax, cs
                cli
                mov     ss, ax
                mov     sp, offset cpm_ip_stack_top
                sti
                /* DS = base_seg on entry; read the loader-built descriptors */
                mov     ax, [0x09]                   /* data_seg  (desc +0x06 +3) */
                mov     [cs:data_seg], ax
                mov     ax, [0x0f]                   /* extra_seg (desc +0x0C +3) */
                mov     [cs:extra_seg], ax
                mov     ax, [0x15]                   /* stack_seg (desc +0x12 +3) */
                mov     [cs:stack_seg], ax
                mov     ax, ds
                mov     [cs:base_seg], ax
                mov     ax, cs
                mov     [cs:code_seg], ax
                /* Code staging reuses the (now-consumed) compressed-data region at
                   cs:cpm_src, so the code group need not be inflated by our whole
                   compressed image -- only by the staged code + copy routine. */
                mov     word ptr [cs:cpm_temp_off], offset cpm_src
                /* save our base page (reuse the method-0 cpmbase buffer; the main
                   stub restores it before relocating the copy routine) */
                push    cs
                pop     es
                xor     si, si
                mov     di, offset cpmbase
                mov     cx, 128
                rep     movsw
                mov     word ptr [cs:cpmbase + 0x50], 0x00b1
                mov     word ptr [cs:cpmbase + 0x52], 0xe0cd

                /* decompress the whole original file into the data group */
                push    cs
                pop     ds
                mov     dx, ds
                mov     si, offset cpm_src
                mov     es, [cs:data_seg]
                xor     di, di
                xor     cx, cx
                mov     bx, 0x800f
                mov     bp, 1
                call    decompr_start_n2b

                /* Pass 1: stage the code into code_seg:cpm_temp_off and copy any
                   extra/stack groups into their own segments; defer the data group. */
                mov     word ptr [cs:cum_paras], 8   /* group data starts at +128 */
                mov     word ptr [cs:gidx], 0
                mov     word ptr [cs:data_len], 0
cpm_ip_gloop:
                mov     bx, [cs:gidx]
                cmp     bl, [cs:cpm_info + 0]
                jae     cpm_ip_gdone
                mov     cl, 3
                shl     bx, cl
                add     bx, offset cpm_info + 30
                mov     al, [cs:bx + 0]
                xor     ah, ah
                mov     [cs:cur_type], ax
                mov     ax, [cs:bx + 2]
                mov     [cs:cur_len], ax
                mov     ax, [cs:bx + 4]
                mov     [cs:cur_alloc], ax
                /* src = data_seg : (cum_paras * 16) */
                mov     ax, [cs:cum_paras]
                mov     cl, 4
                shl     ax, cl
                mov     [cs:cur_src], ax

                mov     al, [cs:cur_type]
                cmp     al, 1
                jne     cpm_ip_t2
                /* code: stage into code_seg:cpm_temp_off, remember code_len, and
                   compute the copy-routine offset just above the staged code */
                mov     ds, [cs:data_seg]
                mov     si, [cs:cur_src]
                push    cs
                pop     es
                mov     di, [cs:cpm_temp_off]
                mov     cx, [cs:cur_len]
                shl     cx, 1
                shl     cx, 1
                shl     cx, 1
                rep     movsw
                mov     ax, [cs:cur_len]
                mov     [cs:code_len], ax
                mov     ax, [cs:cur_len]            /* cpm_copyr = cpm_temp + code_len*16 */
                mov     cl, 4
                shl     ax, cl
                add     ax, [cs:cpm_temp_off]
                mov     [cs:cpm_copyr_off], ax
                jmp     cpm_ip_advance
cpm_ip_t2:
                cmp     al, 2
                jne     cpm_ip_t3
                /* data: defer to pass 2 */
                mov     ax, [cs:cur_src]
                mov     [cs:data_src], ax
                mov     ax, [cs:cur_len]
                mov     [cs:data_len], ax
                mov     ax, [cs:cur_alloc]
                mov     [cs:data_alloc_v], ax
                jmp     cpm_ip_advance
cpm_ip_t3:
                cmp     al, 3
                jne     cpm_ip_t4
                mov     dx, [cs:extra_seg]
                jmp     cpm_ip_copyout
cpm_ip_t4:
                cmp     al, 4
                jne     cpm_ip_advance
                mov     dx, [cs:stack_seg]
cpm_ip_copyout:
                test    dx, dx
                jz      cpm_ip_advance               /* absent group: nothing to do */
                mov     ds, [cs:data_seg]
                mov     si, [cs:cur_src]
                mov     es, dx
                xor     di, di
                mov     cx, [cs:cur_len]
                shl     cx, 1
                shl     cx, 1
                shl     cx, 1
                rep     movsw                        /* di = cur_len*16 */
                mov     ax, [cs:cur_alloc]
                sub     ax, [cs:cur_len]
                jbe     cpm_ip_advance
                cmp     ax, 0x1000
                jbe     cpm_ip_zsz
                mov     ax, 0x1000
cpm_ip_zsz:
                mov     cx, ax
                shl     cx, 1
                shl     cx, 1
                shl     cx, 1
                xor     ax, ax
                rep     stosw
cpm_ip_advance:
                mov     ax, [cs:cum_paras]
                add     ax, [cs:cur_len]
                mov     [cs:cum_paras], ax
                inc     word ptr [cs:gidx]
                jmp     cpm_ip_gloop

cpm_ip_gdone:
                /* Pass 2: move the data slice down to data_seg:0 (every other group
                   is copied out now), zero its BSS, then restore the base page. */
                mov     ax, [cs:data_seg]
                mov     ds, ax
                mov     es, ax
                mov     si, [cs:data_src]
                xor     di, di
                mov     cx, [cs:data_len]
                shl     cx, 1
                shl     cx, 1
                shl     cx, 1
                rep     movsw                        /* di = data_len*16 */
                mov     ax, [cs:data_alloc_v]
                sub     ax, [cs:data_len]
                jbe     cpm_ip_nobss
                cmp     ax, 0x1000
                jbe     cpm_ip_dzsz
                mov     ax, 0x1000
cpm_ip_dzsz:
                mov     cx, ax
                shl     cx, 1
                shl     cx, 1
                shl     cx, 1
                xor     ax, ax
                rep     stosw                        /* es = data_seg, di = data_len*16 */
cpm_ip_nobss:
                /* restore the base page into data_seg:0 */
                push    cs
                pop     ds
                mov     si, offset cpmbase
                mov     es, [cs:data_seg]
                xor     di, di
                mov     cx, 128
                rep     movsw

                /* relocate the copy routine above the final code and enter it */
                push    cs
                pop     ds
                push    cs
                pop     es
                mov     si, offset cpm_cc_start
                mov     di, [cs:cpm_copyr_off]
                mov     cx, offset cpm_cc_end - offset cpm_cc_start
                rep     movsb
                mov     bx, [cs:cpm_copyr_off]
                mov     ax, [cs:code_seg]
                mov     [cs:bx + cpm_ccp_codeseg - cpm_cc_start], ax
                mov     ax, [cs:base_seg]
                mov     [cs:bx + cpm_ccp_baseseg - cpm_cc_start], ax
                mov     ax, [cs:cpm_info + 4]
                mov     [cs:bx + cpm_ccp_sptop - cpm_cc_start], ax
                xor     ax, ax
                cmp     byte ptr [cs:cpm_info + 1], 0
                je      cpm_ip_ip0
                mov     ax, 0x100
cpm_ip_ip0:
                mov     [cs:bx + cpm_ccp_entryip - cpm_cc_start], ax
                mov     ax, [cs:cpm_temp_off]
                mov     [cs:bx + cpm_ccp_codesrc - cpm_cc_start], ax
                mov     ax, [cs:code_len]
                shl     ax, 1
                shl     ax, 1
                shl     ax, 1
                mov     [cs:bx + cpm_ccp_codewords - cpm_cc_start], ax
                mov     bp, [cs:cpm_copyr_off]
                jmp     bp                           /* enter the relocated copy routine */

/*
; The copy routine runs from its relocated (high) location in the code group, so
; it survives overwriting code:0.  It is position-independent: BP = its own base,
; and all parameters are read via cs:[bp + const].
*/
section         CPMCOPY
cpm_cc_start:
                mov     ax, cs:[bp + cpm_ccp_codeseg - cpm_cc_start]
                mov     ds, ax
                mov     es, ax
                mov     si, cs:[bp + cpm_ccp_codesrc - cpm_cc_start]
                xor     di, di
                mov     cx, cs:[bp + cpm_ccp_codewords - cpm_cc_start]
                rep     movsw                        /* staged code -> code_seg:0 */
                mov     ax, cs:[bp + cpm_ccp_baseseg - cpm_cc_start]
                cli
                mov     ss, ax
                mov     sp, cs:[bp + cpm_ccp_sptop - cpm_cc_start]
                sti
                push    ax                           /* exit far addr seg = base_seg */
                mov     ax, 0x50
                push    ax                           /* exit far addr off (trampoline) */
                mov     ax, cs:[bp + cpm_ccp_codeseg - cpm_cc_start]
                push    ax
                mov     ax, cs:[bp + cpm_ccp_entryip - cpm_cc_start]
                push    ax
                mov     ax, cs:[bp + cpm_ccp_baseseg - cpm_cc_start]
                mov     ds, ax
                mov     es, ax
                xor     ax, ax
                mov     bx, ax
                mov     cx, ax
                mov     dx, 0x80
                xor     si, si
                xor     di, di
                xor     bp, bp
                lret
cpm_ccp_codeseg:   .word 0
cpm_ccp_baseseg:   .word 0
cpm_ccp_sptop:     .word 0
cpm_ccp_entryip:   .word 0
cpm_ccp_codesrc:   .word 0
cpm_ccp_codewords: .word 0
cpm_cc_end:

/*
; =============
; ============= LOADER DATA
; =============
*/

section         CPMVARS
our_base:       .word   0
scratch_seg:    .word   0
cum_paras:      .word   0
gidx:           .word   0
cur_type:       .word   0
cur_len:        .word   0
cur_alloc:      .word   0
cur_got:        .word   0
cur_seg:        .word   0
cur_src:        .word   0       /* byte offset of current group in the decompress buf */
code_seg:       .word   0
code_len:       .word   0       /* code group length (paragraphs) */
data_seg:       .word   0
data_src:       .word   0       /* data group byte offset in the decompress buffer */
data_len:       .word   0       /* data group length (paragraphs) */
data_alloc_v:   .word   0       /* data group allocation (paragraphs) */
extra_seg:      .word   0
stack_seg:      .word   0
base_seg:       .word   0
cpm_temp_off:   .word   0       /* in-place: byte offset of the code staging area */
cpm_copyr_off:  .word   0       /* in-place: byte offset of the relocated copy routine */
mcb:            .word   0       /* +0 segment (out) */
                .word   0       /* +2 length in paragraphs (in) */
                .byte   0       /* +4 ext */
                .byte   0       /* pad */
cpmbase:        .space  256     /* saved base page (method 0) */
                .space  256     /* in-place private stack (decompressing into the
                                   loader's data group must not clobber our stack) */
cpm_ip_stack_top:

/*
; CPMINFO: filled in by the packer (see p_cpm86.cpp).
;   +0  byte  ngroups
;   +1  byte  model_8080
;   +2  word  scratch_paras / whole-file paras
;   +4  word  sp_top
;   +6  desc[4][6]  base-page descriptors (method 0)
;   +30 group[8][8] type, _, length_paras, alloc_paras, _
;   +94 word  code_file_paras (in-place: paras of our code-group file image)
;   +127 byte method (0 = BDOS scratch, 1 = in-place)
*/
section         CPMINFO
cpm_info:       .space  128

#include        "include/header.S"

section         CPMCUT
cpm_src:

/* vim:set ts=8 sw=8 et: */
