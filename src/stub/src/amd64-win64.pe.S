/*
;  AMD64-win64.pe.S -- loader & decompressor for the w64/pe32+ format
;
;  This file is part of the UPX executable compressor.
;
;  Copyright (C) Markus Franz Xaver Johannes Oberhumer
;  Copyright (C) Laszlo Molnar
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
;---------------------------------------------------------------------
;
; 64 bit modifications (C) Stefan Widmann
;
; Major changes when porting 32 bit code to 64 bit:
;  - there are no pusha/popa instructions
;  - since we cannot use pusha/popa, we save rbx, rsi, rdi and rbp instead
;  - inc <reg> are now being encoded in 2 byte instructions
;  - functions use fast call calling convention (parameters are passed in registers)
;    rcx, rdx,  r8, r9
;  - caller is responsible for stack allocation for callee
;  - caller cleans up stack
;  - caller must keep the stack 16 byte aligned, 32 bytes shadow space on stack
; For more information about the 64 bit calling convention see http://blogs.msdn.com/oldnewthing/archive/2004/01/14/58579.aspx
*/

#include "arch/amd64/macros.S"

#define         IMM8(value) 0; \
                .reloc . - 1, R_X86_64_8, value

#define         IMM16(value) (1<<15); \
                .reloc . - 2, R_X86_64_16, (1<<15) + value

#define         IMM32(value) (1<<31); \
                .reloc . - 4, R_X86_64_32, (1<<31) + value

#define         IMM64(value) (1<<63); \
                .reloc . - 8, R_X86_64_64, (1<<63) + value

#define         SHORT(label) label

//; debugging is not too user friendly under wine:
//; by adding the "DEBUG" macro into the code
//; an exception will be raised, and a register dump is printed
//; WINEDEBUG=trace+seh wine x.exe &> x.debug
#define         DEBUG           mov byte ptr [0], 0

.intel_syntax noprefix

// =============
// ============= ENTRY POINT
// =============

section         START
section         PEISDLL0
                mov     [rsp + 8], rcx
                mov     [rsp + 0x10], rdx
                mov     [rsp + 0x18], r8
section         PEISEFI0
                push     rcx
                push     rdx

section         PEISDLL1
                cmp     dl, 1
                jnz     reloc_end_jmp
section         PEMAIN01
                //; remember to keep stack aligned!
                push    rbx
                push    rsi
                push    rdi
                push    rbp
                lea     rsi, [rip + start_of_compressed]
                lea     rdi, [rsi + start_of_uncompressed]

section         PEICONS1
                inc     word ptr [rdi + icon_offset]
section         PEICONS2
                add     word ptr [rdi + icon_offset], IMM16(icon_delta)
section         PETLSHAK
                lea     rax, [rdi + tls_address]
                push    [rax]   // save the TLS index
                mov     dword ptr [rax], IMM32(tls_value) // restore compressed data overwritten by the TLS index
                push    rax

section         PEMAIN02
                push    rdi
section         PEMAIN03

// ============= Optional stub phase timing (Win64/x64 executable diagnostics)
// The first measured interval begins immediately before decompression.  QPC
// collection overhead is deliberately outside each interval boundary.
section         PETIMING0
                // PEMAIN02 has one extra saved pointer on the stack here, so
                // 0x20 bytes (not 0x28) preserve 16-byte call alignment.
                sub     rsp, 0x20
                lea     rcx, [rip + timing_frequency]
                call    [rip + QueryPerformanceFrequency]
                lea     rcx, [rip + timing_qpc0]
                call    [rip + QueryPerformanceCounter]
                add     rsp, 0x20

// =============
// ============= DECOMPRESSION
// =============

.att_syntax
section         NRV_HEAD
/* Working registers */
#define off  %eax  /* XXX: 2GB */
#define len  %ecx  /* XXX: 2GB */
#define lenq %rcx
#define bits %ebx
#define displ %ebp
#define dispq %rbp

        xor bits,bits  // empty; force refill
        xor len,len  // create loop invariant
        orq $(~0),dispq  // -1: initial displacement
        call setup  // push &getbit [TUNED]
ra_setup:

#define jnextb0np jnextb0yp
#define jnextb0yp GETBITp; jnc
#define jnextb1np jnextb1yp
#define jnextb1yp GETBITp; jc
#define GETBITp \
        addl bits,bits; jnz 0f; \
        movl (%rsi),bits; subq $-4,%rsi; \
        adcl bits,bits; movb (%rsi),%dl; \
0:
/* Same, but without prefetch (not useful for length of match.) */
#define jnextb0n jnextb0y
#define jnextb0y GETBIT; jnc
#define jnextb1n jnextb1y
#define jnextb1y GETBIT; jc
#define GETBIT \
        addl bits,bits; jnz 0f; \
        movl (%rsi),bits; subq $-4,%rsi; \
        adcl bits,bits; \
0:

/* rotate next bit into bottom bit of reg */
#define getnextbp(reg) call *%r11; adcl reg,reg
#define getnextb(reg)  getnextbp(reg)


getbit:
        // endbr64  // but WINDOWS_BACK?
        addl bits,bits; jz refill  // Carry= next bit
        rep; ret
refill:
        movl (%rsi),bits; subq $-4,%rsi  // next 32 bits; set Carry
        adcl bits,bits  // LSB= 1 (CarryIn); CarryOut= next bit
        movb (%rsi),%dl  // speculate: literal, or bottom 8 bits of offset
        rep; ret

copy:  // In: len, %rdi, dispq;  Out: 0==len, %rdi, dispq;  trashes %rax, %rdx
        leaq (%rdi,dispq),%rax; cmpl $5,len  // <=3 is forced
        movb (%rax),%dl; jbe copy1  // <=5 for better branch predict
        cmpq $-4,dispq;   ja  copy1  // 4-byte chunks would overlap
        subl $4,len  // adjust for termination cases
copy4:
        movl (%rax),%edx; addq $4,      %rax; subl $4,len
        movl %edx,(%rdi); leaq  4(%rdi),%rdi; jnc copy4
        addl $4,len; movb (%rax),%dl; jz copy0
copy1:
        incq %rax; movb %dl,(%rdi); subl $1,len
                   movb (%rax),%dl
        leaq 1(%rdi),%rdi;          jnz copy1
copy0:
        rep; ret

setup:
        cld
        pop %r11  // addq $ getbit - ra_setup,%r11  # &getbit

#define NO_METHOD_CHECK

section         NRV2B
#define eof eofb
#include "arch/amd64/nrv2b_d.S"
eofb:

section         NRV2D
#undef eof
#define eof eofd
#include "arch/amd64/nrv2d_d.S"
eofd:

section         NRV2E
#undef eof
#define eof eofe
#include "arch/amd64/nrv2e_d.S"
eofe:

#undef eof
#undef len
.intel_syntax noprefix
section         LZMA_HEAD
                mov     eax, IMM32(lzma_u_len)
                push    rax
                mov     rcx, rsp
                mov     rdx, rdi
                mov     rdi, rsi
                mov     esi, IMM32(lzma_c_len)

.att_syntax
#define NO_RED_ZONE
#include "arch/amd64/regs.h"
#include "arch/amd64/lzma_d.S"

.intel_syntax noprefix
section         LZMA_TAIL
                leave
                pop     rax

// =============
// Raw LZ4 block decoder. Input is [rsi, rsi+lz4_c_len), output is
// [rdi, rdi+lz4_u_len). The packer guarantees a safe in-place gap.
section         LZ4
                cld
                mov     eax, IMM32(lz4_c_len)
                lea     r8, [rsi + rax]
                mov     eax, IMM32(lz4_u_len)
                lea     r9, [rdi + rax]
lz4_sequence:
                movzx   r10d, byte ptr [rsi]
                inc     rsi
                mov     eax, r10d
                shr     eax, 4
                cmp     eax, 15
                jne     lz4_copy_literals
lz4_literal_length:
                movzx   ecx, byte ptr [rsi]
                inc     rsi
                add     eax, ecx
                cmp     ecx, 255
                je      lz4_literal_length
lz4_copy_literals:
                mov     ecx, eax
                cmp     ecx, 8
                jb      lz4_literal_bytes
lz4_literal_qwords:
                mov     rax, [rsi]
                mov     [rdi], rax
                add     rsi, 8
                add     rdi, 8
                sub     ecx, 8
                cmp     ecx, 8
                jae     lz4_literal_qwords
lz4_literal_bytes:
                test    ecx, ecx
                jz      lz4_literals_done
lz4_literal_byte_loop:
                mov     al, [rsi]
                inc     rsi
                mov     [rdi], al
                inc     rdi
                dec     ecx
                jne     lz4_literal_byte_loop
lz4_literals_done:
                cmp     rsi, r8
                jae     lz4_finished
                movzx   eax, word ptr [rsi]
                add     rsi, 2
                mov     r11, rdi
                sub     r11, rax
                mov     eax, r10d
                and     eax, 15
                cmp     eax, 15
                jne     lz4_match_length_done
lz4_match_length:
                movzx   ecx, byte ptr [rsi]
                inc     rsi
                add     eax, ecx
                cmp     ecx, 255
                je      lz4_match_length
lz4_match_length_done:
                add     eax, 4
                mov     ecx, eax
                mov     rbx, rdi
                sub     rbx, r11
                cmp     ebx, 8
                jb      lz4_match_bytes
                cmp     ecx, 8
                jb      lz4_match_bytes
lz4_match_qwords:
                mov     rax, [r11]
                mov     [rdi], rax
                add     r11, 8
                add     rdi, 8
                sub     ecx, 8
                cmp     ecx, 8
                jae     lz4_match_qwords
lz4_match_bytes:
                test    ecx, ecx
                jz      lz4_match_done
lz4_match_byte_loop:
                mov     al, [r11]
                inc     r11
                mov     [rdi], al
                inc     rdi
                dec     ecx
                jne     lz4_match_byte_loop
lz4_match_done:
                cmp     rdi, r9
                jb      lz4_sequence
lz4_finished:
// =============
// misa77 0.6 raw stream decoder for Win64/x86-64. Both the light stream
// (levels -1..3) and heavy stream (level 4) share this section. The stream
// is produced and checksummed by the UPX host, so this follows the upstream
// unsafe decoder and its suffix-padding guarantees.
section         MISA77
                cld
                mov     r10, [rsi]              // stream flags in high byte
                shr     r10, 56                 // format flags
                mov     eax, IMM32(misa77_u_len)
                test    r10b, 1
                jnz     misa77_heavy_entry

                cmp     rax, 32
                jbe     misa77_small
                mov     r11, [rsi + 8]          // raw literal suffix length
                mov     ebp, IMM32(misa77_c_len)
                add     rbp, rsi                 // end of compressed stream
                lea     r8, [rsi + 16]           // control stream
                mov     r9, rbp
                sub     r9, r11                  // backwards literal stream

misa77_light_token:
                cmp     r8, r9
                jae     misa77_suffix
                movzx   ecx, byte ptr [r8]
                mov     eax, ecx
                shr     eax, 5                   // literal length
                and     ecx, 31
                lea     edx, [rcx + 3]           // match length
                movzx   ebx, word ptr [r8 + 1]
                add     ebx, 33                  // match distance
                add     r8, 3
                cmp     eax, 7
                jne     misa77_light_literals
misa77_light_lit_ext:
                movzx   ecx, byte ptr [r8]
                inc     r8
                add     eax, ecx
                cmp     ecx, 255
                je      misa77_light_lit_ext

misa77_light_literals:
                sub     r9, rax
                cmp     eax, 16
                ja      misa77_light_literals_large
                movdqu  xmm0, [r9]
                movdqu  [rdi], xmm0
                add     rdi, rax
                jmp     misa77_light_match
misa77_light_literals_large:
                movdqu  xmm0, [r9]
                movdqu  xmm1, [r9 + 16]
                movdqu  [rdi], xmm0
                movdqu  [rdi + 16], xmm1
                cmp     eax, 32
                jbe     misa77_light_literals_advance
                lea     rsi, [r9 + 32]
                add     rdi, 32
                mov     ecx, eax
                sub     ecx, 32
                rep movsb
                jmp     misa77_light_match
misa77_light_literals_advance:
                add     rdi, rax

misa77_light_match:
                mov     rsi, rdi
                sub     rsi, rbx
                movdqu  xmm0, [rsi]
                movdqu  xmm1, [rsi + 16]
                movdqu  [rdi], xmm0
                movdqu  [rdi + 16], xmm1
                add     rdi, rdx
                jmp     misa77_light_token

misa77_heavy_entry:
                cmp     rax, 64
                jbe     misa77_small
                mov     r11, [rsi + 8]
                mov     ebp, IMM32(misa77_c_len)
                add     rbp, rsi
                lea     r8, [rsi + 16]
                mov     r9, rbp
                sub     r9, r11

misa77_heavy_token:
                cmp     r8, r9
                jae     misa77_suffix
                mov     ecx, [r8]
                mov     eax, ecx
                shr     eax, 26                  // literal length
                mov     edx, ecx
                shr     edx, 20
                and     edx, 63                  // match length code
                and     ecx, 0xfffff
                lea     ebx, [rcx + 33]          // match distance
                add     r8, 4
                cmp     edx, 29
                ja      misa77_heavy_match_30
                add     edx, 3
                jmp     misa77_heavy_match_ready
misa77_heavy_match_30:
                cmp     edx, 45
                ja      misa77_heavy_match_46
                lea     edx, [rdx * 2 - 26]
                jmp     misa77_heavy_match_ready
misa77_heavy_match_46:
                cmp     edx, 61
                ja      misa77_heavy_match_62
                lea     edx, [rdx * 4 - 116]
                jmp     misa77_heavy_match_ready
misa77_heavy_match_62:
                cmp     edx, 62
                mov     edx, 160
                je      misa77_heavy_match_ready
                mov     edx, 192
misa77_heavy_match_ready:
                cmp     eax, 63
                jne     misa77_heavy_literals
misa77_heavy_lit_ext:
                movzx   ecx, byte ptr [r8]
                inc     r8
                add     eax, ecx
                cmp     ecx, 255
                je      misa77_heavy_lit_ext

misa77_heavy_literals:
                sub     r9, rax
                cmp     eax, 16
                ja      misa77_heavy_literals_large
                movdqu  xmm0, [r9]
                movdqu  [rdi], xmm0
                add     rdi, rax
                jmp     misa77_heavy_match
misa77_heavy_literals_large:
                movdqu  xmm0, [r9]
                movdqu  xmm1, [r9 + 16]
                movdqu  [rdi], xmm0
                movdqu  [rdi + 16], xmm1
                cmp     eax, 32
                jbe     misa77_heavy_literals_advance
                lea     rsi, [r9 + 32]
                add     rdi, 32
                mov     ecx, eax
                sub     ecx, 32
                rep movsb
                jmp     misa77_heavy_match
misa77_heavy_literals_advance:
                add     rdi, rax

misa77_heavy_match:
                mov     rsi, rdi
                sub     rsi, rbx
                movdqu  xmm0, [rsi]
                movdqu  xmm1, [rsi + 16]
                movdqu  [rdi], xmm0
                movdqu  [rdi + 16], xmm1
                movdqu  xmm0, [rsi + 32]
                movdqu  xmm1, [rsi + 48]
                movdqu  [rdi + 32], xmm0
                movdqu  [rdi + 48], xmm1
                cmp     edx, 64
                jbe     misa77_heavy_match_advance
                mov     ecx, 64
misa77_heavy_match_more:
                movdqu  xmm0, [rsi + rcx]
                movdqu  xmm1, [rsi + rcx + 16]
                movdqu  [rdi + rcx], xmm0
                movdqu  [rdi + rcx + 16], xmm1
                add     ecx, 32
                cmp     ecx, edx
                jb      misa77_heavy_match_more
misa77_heavy_match_advance:
                add     rdi, rdx
                jmp     misa77_heavy_token

misa77_suffix:
                mov     rsi, rbp
                sub     rsi, r11
                mov     rcx, r11
                rep movsb
                jmp     misa77_finished

misa77_small:
                mov     rcx, rax
                add     rsi, 8
                rep movsb
misa77_finished:
// =============
section         PEMAIN10
                pop     rsi             // load vaddr

section         PETIMING1
                sub     rsp, 0x28
                lea     rcx, [rip + timing_qpc1]
                call    [rip + QueryPerformanceCounter]
                add     rsp, 0x28

section         PETLSHAK2               // restore the TLS index
                pop     rdi
                pop     rax
                mov     [rdi], eax

// =============
// ============= FILTERS
// =============

section         PECTTPOS
                lea     rdi, [rsi + filter_buffer_start]
section         PECTTNUL
                mov     rdi, rsi

section         PEFILTER49
                push    rsi
                mov     rdi, rsi
                mov     rsi, offset filter_length
                mov     dl, IMM8(filter_cto)
.att_syntax
#include "arch/amd64/bxx.S"
.intel_syntax noprefix
                pop     rsi

// =============
// ============= IMPORTS
// =============

section PEIMPORT
                sub     rsp, 0x28
                lea     rdi, [rsi + compressed_imports]
next_dll:
                mov     eax, [rdi]
                or      eax, eax
                jz      SHORT(imports_done)
                mov     ebx, [rdi + 4]    // iat
                lea     rcx, [rax + rsi + start_of_imports]
                add     rbx, rsi
                add     rdi, 8

                call    [rip + LoadLibraryA]

                xchg    rax, rbp
next_func:
                mov     al, [rdi]
                inc     rdi
                or      al, al
                jz      next_dll
section         PEIBYORD
                jns     SHORT(byname)
section         PEK32ORD
                jpe     not_kernel32
                mov     eax, [rdi]
                add     rdi, 4
                mov     rax, [rax + rsi + kernel32_ordinals]
                jmp     SHORT(next_imp)
not_kernel32:
section         PEIMORD1
                movzx   rdx, word ptr [rdi]
                add     rdi, 2
                jmp     SHORT(first_imp)

byname:
section         PEIMPOR2
                mov     rcx, rdi        // something > 0
                mov     rdx, rdi
                dec     eax
                repne
                scasb
first_imp:
                mov     rcx, rbp

                call    [rip + GetProcAddress]

#if 1
;// FIXME: is this error handling really needed?
                or      rax, rax
                jz      imp_failed
#endif
next_imp:
                mov     [rbx], rax
                add     rbx, 8
                jmp     SHORT(next_func)
imp_failed:
section         PEIERDLL
                add     rsp, 0x28
                pop     rbp
                pop     rdi
                pop     rsi
                pop     rbx
                xor     eax, eax
                ret

section         PEIEREXE
                //      rcx contains garbage -> garbage return code
                jmp     [rip + ExitProcess]
section         PEIMDONE
imports_done:
                add     rsp, 0x28

// =============
// ============= RELOCATION
// =============

section         PERELOC1
                lea     rdi, [rsi + start_of_relocs]
section         PERELOC2
                add     rdi, 4
section         PERELOC3
                lea     rbx, [rsi - 4]
reloc_main:
                xor     eax, eax
                mov     al, [rdi]
                inc     rdi
                or      eax, eax
                jz      SHORT(reloc_endx)
                cmp     al, 0xEF
                ja      reloc_fx
reloc_add:
                add     rbx, rax
                mov     rax, [rbx]
                bswap   rax
                add     rax, rsi
                mov     [rbx], rax
                jmp     reloc_main
reloc_fx:
                and     al, 0x0F
                shl     eax, 16
                mov     ax, [rdi]
                add     rdi, 2
section         REL64BIG
                or      eax, eax
                jnz     SHORT(reloc_add)
                mov     eax, [rdi]
                add     rdi, 4
section         RELOC64J
                jmp     SHORT(reloc_add)
reloc_endx:

section         PETIMING2
                sub     rsp, 0x28
                lea     rcx, [rip + timing_qpc2]
                call    [rip + QueryPerformanceCounter]
                add     rsp, 0x28


// =============

// FIXME: depends on that in PERELOC1 rdi is set!!
section         PERLOHI0
                xchg    rdi, rsi
                lea     rcx, [rdi + reloc_delt]

section         PERELLO0
                jmp     1f
rello0:
                add     [rdi + rax], cx
1:
                lodsd
                or      eax, eax
                jnz     rello0

// =============

section         PERELHI0
                shr     ecx, 16
                jmp     1f
relhi0:
                add     [rdi + rax], cx
1:
                lodsd
                or      eax, eax
                jnz     relhi0

// =============
section         PEDEPHAK
                mov     rbp, [rip + VirtualProtect]
                lea     rdi, [rsi + vp_base]
                mov     ebx, IMM32(vp_size)     // 0x1000 or 0x2000

                push    rax                     // provide 8 bytes stack
                mov     r9, rsp
// FIXME        push    4; pop     r8
                mov     r8d, 4                  // PAGE_READWRITE
                mov     rdx, rbx                // size
                mov     rcx, rdi                // address

                sub     rsp, 0x20
                call    rbp                     // VirtualProtect

                lea     rax, [rdi + swri]
                and     byte ptr [rax], 0x7f             // marks UPX0 non writeable
                and     byte ptr [rax + 0x28], 0x7f      // marks UPX1 non writeable

                lea     r9, [rsp + 0x20]
                mov     r8, qword ptr [r9]      // original protection
                mov     rdx, rbx
                mov     rcx, rdi

                call    rbp
                add     rsp, 0x28

// =============
// ============= TLS callback support part 1
// =============

section         PETLSC
                mov     byte ptr [rip + PETLSC2], 0xfc   // "cld" instead of "ret"
                lea     rcx, [rsi + tls_module_base] // module base
                push    1                       // DLL_PROCESS_ATTACH
                pop     rdx
                xor     r8, r8                  // 0 - reserved

                push    rax                     // align stack
                call    PETLSC2
                pop     rax

section         PETIMING3
                sub     rsp, 0x28
                lea     rcx, [rip + timing_qpc3]
                call    [rip + QueryPerformanceCounter]
                add     rsp, 0x28

// ============= Release decompression working set

section         PERELEASEMEM
                // A PE image is a section mapping, so VirtualFree(MEM_RELEASE)
                // cannot safely release only UPX1. Trim after a short delay so
                // the application can create its first window without refaulting
                // every page that the decompressor has just written.
                sub     rsp, 0x38
                xor     ecx, ecx                // default security attributes
                xor     edx, edx                // default stack size
                lea     r8, [rip + release_worker]
                xor     r9d, r9d                // thread argument
                mov     qword ptr [rsp + 0x20], 0 // creation flags
                mov     qword ptr [rsp + 0x28], 0 // no thread id output
                call    [rip + CreateThread]
                test    rax, rax
                jz      release_main_done
                mov     rcx, rax
                call    [rip + CloseHandle]
release_main_done:
                add     rsp, 0x38
                jmp     release_main_end
release_worker:
                sub     rsp, 0x28
                mov     ecx, 1000                // let startup finish first
                call    [rip + Sleep]
                or      rcx, -1                  // current process pseudo-handle
                or      rdx, -1                  // minimum working set size
                or      r8, -1                   // maximum working set size
                call    [rip + SetProcessWorkingSetSize]
                xor     eax, eax
                add     rsp, 0x28
                ret
release_main_end:

// ============= Cleanup

section         PEMAIN20
                pop     rbp
                pop     rdi
                pop     rsi
                pop     rbx

// clear the dirty stack
.macro          clearstack128  tmp_reg
                lea     \tmp_reg, [rsp - 128]
.Lclearstack_loop\@:
                push    0
                cmp     rsp, \tmp_reg
                jnz     .Lclearstack_loop\@
                sub     rsp, -128
.endm

section         CLEARSTACK
                clearstack128 rax

section         PEMAIN21
reloc_end_jmp:

section         PETIMING4
                sub     rsp, 0x28
                lea     rcx, [rip + timing_qpc4]
                call    [rip + QueryPerformanceCounter]
                add     rsp, 0x28

// Write a fixed-size binary record after qpc4.  File I/O is therefore not
// included in total_stub.  Failure to create/write the diagnostic file never
// prevents the original executable from starting.
section         PETIMING_WRITE
                push    rbx
                sub     rsp, 0x40
                lea     rcx, [rip + timing_filename]
                mov     edx, 0x40000000          // GENERIC_WRITE
                mov     r8d, 1                   // FILE_SHARE_READ
                xor     r9d, r9d                 // lpSecurityAttributes
                mov     qword ptr [rsp + 0x20], 2    // CREATE_ALWAYS
                mov     qword ptr [rsp + 0x28], 0x80 // FILE_ATTRIBUTE_NORMAL
                mov     qword ptr [rsp + 0x30], 0    // hTemplateFile
                call    [rip + CreateFileA]
                cmp     rax, -1                  // INVALID_HANDLE_VALUE
                je      timing_write_done
                mov     rbx, rax
                mov     rcx, rbx
                lea     rdx, [rip + timing_record]
                mov     r8d, 64
                lea     r9, [rip + timing_bytes_written]
                mov     qword ptr [rsp + 0x20], 0
                call    [rip + WriteFile]
                mov     rcx, rbx
                call    [rip + TimingCloseHandle]
timing_write_done:
                add     rsp, 0x40
                pop     rbx

section         PEISDLL9
                mov     r8, [rsp + 0x18]
                mov     rdx, [rsp + 0x10]
                mov     rcx, [rsp + 8]
section         PEISEFI9
                pop     rdx
                pop     rcx

section         PERETURN
                push    1
                pop     rax
                ret
section         PEDOJUMP
                jmp     original_entry

// Binary layout (64 bytes, little-endian):
//   char magic[8] = "UPXSTB01"; uint32 version; uint32 size;
//   uint64 qpc_frequency; uint64 qpc[5].
section         PETIMING_DATA
timing_filename:
                .asciz  "upx-stub-timing.bin"
                .balign 8, 0
timing_record:
                .ascii  "UPXSTB01"
                .long   1
                .long   64
timing_frequency:
                .quad   0
timing_qpc0:
                .quad   0
timing_qpc1:
                .quad   0
timing_qpc2:
                .quad   0
timing_qpc3:
                .quad   0
timing_qpc4:
                .quad   0
timing_bytes_written:
                .long   0

// =============
// ============= TLS callback support part 2
// =============

// this is the new TLS callback handler
// it calls the original callbacks ONLY after the decompression is done

section         PETLSC2         // TLS_CALLBACK(hModule, reason, reserved)
                ret             // this ret gets overwritten with cld by PETLSC
                push    rsi
                lea     rsi, [rip + tls_callbacks_ptr]
walk_tlsc_chain2:
                lodsq
                test    rax, rax
                jz      done_callbacks

                push    rcx
                push    rdx
                push    r8

                sub     rsp, 0x28
                call    rax
                add     rsp, 0x28

                pop     r8
                pop     rdx
                pop     rcx

                jmp     walk_tlsc_chain2
done_callbacks:
                pop     rsi
                ret

// =============
// ============= CUT HERE
// =============

#include        "include/header.S"

/* vim:set ts=8 sw=8 et: */
