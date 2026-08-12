//  mipsel.r3000-linux.elf-so_fold.S -- linkage to C code to process Elf shared library
//
//  This file is part of the UPX executable compressor.
//
//  Copyright (C) John F. Reiser
//  All Rights Reserved.
//
//  UPX and the UCL library are free software; you can redistribute them
//  and/or modify them under the terms of the GNU General Public License as
//  published by the Free Software Foundation; either version 2 of
//  the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; see the file COPYING.
//  If not, write to the Free Software Foundation, Inc.,
//  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
//
//  Markus F.X.J. Oberhumer              Laszlo Molnar
//  <markus@oberhumer.com>               <ezerotven+github@gmail.com>
//
//  John F. Reiser
//  <jreiser@users.sourceforge.net>
//

NBPW= 4
#include "arch/mips/r3000/macros.ash"
#include "arch/mips/r3000/bits.ash"

#include "../../../src/MAX_ELF_HDR.h"

  .set mips1
  .set noat
  .set noreorder  // we handle branch delay sots explicitly
  .altmacro

#define arg1 a0
#define arg2 a1
#define arg3 a2
#define arg4 a3
#define arg5 a4  /* must move to stack */
#define arg6 a5  /* must move to stack */
#define bkpt break

// /usr/include/asm-generic/unistd.h
__NR_Linux = 4000
__NR_brk      =  45+ __NR_Linux
__NR_close    =   6+ __NR_Linux
__NR_exit     =   1+ __NR_Linux
__NR_ftruncate=  93+ __NR_Linux
__NR_getpid=     20+ __NR_Linux
__NR_lseek=      19+ __NR_Linux
__NR_memfd_create= 354+ __NR_Linux
__NR_mmap=       90+ __NR_Linux
__NR_mkdir=      39+ __NR_Linux
__NR_mprotect = 125+ __NR_Linux
__NR_msync =    144+ __NR_Linux
__NR_munmap   =  91+ __NR_Linux
__NR_oldstat=    18+ __NR_Linux
__NR_open     =   5+ __NR_Linux
__NR_read     =   3+ __NR_Linux
__NR_readlink =  85+ __NR_Linux
__NR_uname=     122+ __NR_Linux
__NR_unlink=     10+ __NR_Linux
__NR_write    =   4+ __NR_Linux

MAP_ANONYMOUS= 0x20
MAP_PRIVATE=   0x02
MAP_FIXED=     0x10

EINVAL= 22
ENOSYS= 38
MFD_EXEC= 0x10  // 16

#ifndef DEBUG  /*{*/
#define DEBUG 0
#endif  /*}*/

#define call bal

  section SO_HEAD
ZERO:
PAGE_MASK: .word 0xfffff000  // default
upxfn_path:.word 0  // displacement from "zero"

fold_begin: .globl fold
        b fold
          nop

// KNOWN OFFSET == 4*NBPW == 16  (for re-writing little_endian to BIG_ENDIAN)
get4unal: .globl get4unal
        lwr v0,0(a0)  # little-endian (default)
        ret
          lwl v0,3(a0)

        lwl v0,0(a0)  # big-endian (replacement)
        ret
          lwr v0,3(a0)
get_page_mask: .globl get_page_mask
        move v1,ra
        bal 0f  // ra = 1f
          lw v0,(ra)
1:        .int PAGE_MASK - 1b  // 'lw' in branch delay slot loads this
0:
        addu v0,v0,ra
        lw v0,0(v0)
        jr v1
          nop

adj_page:  // entry: v1= ra; v0= __NR
        bal 0f  // ra = 1f
          lw at,(ra)
1:        .int PAGE_MASK - 1b  // 'lw' in branch delay slot loads this
0:
        addu at,at,ra
        lw at,0(at)  // PAGE_MASK
          nop  // r3000 load delay
        not at,at  // frag mask
        and at,at,arg1  // frag
        sub arg1,arg1,at  // decrease the addr
        add arg2,arg2,at  // increase the length
        li at,__NR_mmap
        bne at,v0,sysgo
          move ra,v1
// mmap has 6 args, but MIPS allows only 4 in registers
mm_frame= 0x20
a4_sys=  4*NBPW
a5_sys=  5*NBPW
    addiu sp,sp,-mm_frame
      sw a0,0*NBPW(sp)  # evidence for err in  "qemu -strace"
      sw a1,1*NBPW(sp)
      sw a2,2*NBPW(sp)
      sw a3,3*NBPW(sp)
      sw a4,a4_sys(sp)  # fd
      bal sysgo  # v1 still has ra from call to mmap
        sw a5,a5_sys(sp)  # file offset
      jr v1
    addiu sp,sp,mm_frame

Punmap: .globl Punmap
munmap: .globl munmap
        move v1,ra
        b adj_page
          li v0,__NR_munmap

// Sometimes Linux enforces page-aligned address
Pprotect: .globl Pprotect
mprotect: .globl mprotect
        move v1,ra
        b adj_page
          li v0,__NR_mprotect

mmap_privanon: .globl mmap_privanon
        li at,MAP_PRIVATE|MAP_ANONYMOUS
        or arg4,arg4,at  // combine with input (such as MAP_FIXED)
        li  arg5,-1  // fd= -1
        li  arg6,0  // offset= 0
        // FALL THROUGH to mmap

Pmap: .globl Pmap
mmap: .globl mmap
        move v1,ra
        b adj_page
          li v0,__NR_mmap

Psync: .globl Psync
msync: .globl msync
// Linux should do this implicitly, but apparently not.
        move v1,ra
        b adj_page
          li v0, __NR_msync

fold:  // enter here (a0= &so_info; a1= &{argc,argv,envp,lr} //%esp:
//  MATCH_04  ptr unfolded_code
//  MATCH_10  len unfolded_code
//  MATCH_00  argc,argv,envp,lr(_start)
        addiu sp,sp,-MAX_ELF_HDR_32
        call upx_so_main  // (&so_info, &argc, elf_tmp); returns &escape_hatch
          move arg3,sp  // space for Elf64_Ehdr and Elf64_Phdrs
        addiu sp,sp,MAX_ELF_HDR_32
        lw arg1,0*NBPW(sp)  // F_ADRU
        lw arg2,1*NBPW(sp)  // F_LENU
        lw   ra,5*NBPW(sp)
        addiu sp,sp,6*NBPW  // toss a0,a1,a2: already used by dt_init(a0,a1,a2)
        jr v0  // goto hatch: svc; jr ra; nop
          li v0,__NR_munmap


  section ptr_NEXT
        call 0f
          move arg1,ra
0:

// De-compressor sections inserted here:
// section EXP_HEAD
// section NRV_HEAD
// section NRV2B
// section NRV2D
// section NRV2E
// section NRV_TAIL
// section LZMA_*
// section ZSTD  future
// section EXP_TAIL

  section SO_TAIL

        .globl my_bkpt
my_bkpt:
        bkpt; nop  // my_bkpt
        ret
          nop

PIC_call: .globl PIC_call
        move v0,a0
        jr ra
          move t9,a0

memfd_create: .globl memfd_create
        b sysgo; li v0,__NR_memfd_create
#if 0  //{
        call 0f
          li arg2,MFD_EXEC  # try newest flag bit
        .asciz "upx"  # XXX: ENDIAN TROUBLE
0:
        move arg1,ra
tryMfd:
        li v0,__NR_memfd_create; syscall
        bgez a3,OKmemfd  # success
          li at,ENOSYS
        beq at,v0,tryDevMem  # Linux does not implement memfd_create
          nop
        bnez arg2,tryMfd
          li arg2,0  # backwards-compat: no MFD_EXEC flag bit
        # assume EINVAL from some other cause; try next alternative

O_RDWR= 2
O_DIRECTORY= 0200000  // 0x010000
O_TMPFILE= 020000000  // 0x400000  XXX: This bit can be problematic

tryDevMem:
        call 0f; nop; .asciz "/dev/shm"; .balign 4  # XXX: ENDiAN TROUBLE
0:
        li arg3,0700  // file mode rwx------
        li arg2,O_DIRECTORY | O_TMPFILE | O_RDWR  # XXX: O_TMPFILE trouble
        move arg1,ra  // "/dev/shm"
        li v0,__NR_open; syscall
        bgez a3,OKmemfd  # success
          nop
        bkpt  # failure of both memfd_create and /dev/shm
OKmemfd:
        jr ra

#define mfd a5
        move mfd,v0
#endif  //}

sysgo: .globl sysgo  // src/mipsel.r3000-linux.elf-fold.S
        syscall
sysret:
        beqz a3,sysOK  // Linux MIPS convention
          nop
        sub v0,zero,v0  // -errno:  < 0, and > 0xfffff000
sysOK:
        jr ra
          nop

close: .globl close
        b sysgo; li v0,__NR_close
exit: .globl exit
        b sysgo; li v0,__NR_exit
brk: .globl brk
        b sysgo; li v0,__NR_brk
ftruncate: .globl ftruncate
        b sysgo; li v0,__NR_ftruncate
getpid: .globl getpid
        b sysgo; li v0,__NR_getpid
lseek: .globl lseek
        b sysgo; li v0,__NR_lseek
mkdir: .globl mkdir
        b sysgo; li v0,__NR_mkdir
stat: .globl stat
        b sysgo; li v0,__NR_oldstat  // WARNING: oldstat
open: .globl open
        b sysgo; li v0,__NR_open
read: .globl read
        b sysgo; li v0,__NR_read
readlink: .globl readlink
        b sysgo; li v0,__NR_readlink
uname: .globl uname
        b sysgo; li v0,__NR_uname
unlink: .globl unlink
        b sysgo; li v0,__NR_unlink
write: .globl write
        b sysgo; li v0,__NR_write

memcpy: .globl memcpy  // void *memcpy(void *dst, void const *src, size_t len)
        move v0,arg1  // rv= dst0
0:
        lb arg4,0(arg2)
          addiu arg2,arg2,1  // r3000 load delay
        sb arg4,0(arg1)
        addiu arg3,arg3,-1
        bnez arg3,0b
          addiu arg1,arg1,1
        jr ra
          nop

memset: .globl memset  // void *memset(void *dst, int c, size_t len);
        move v0,arg1  // rv= dst0
0:
        sb zero,0(arg1)
        addiu arg3,arg3,-1
        bnez arg3,0b
          addiu arg1,arg1,1
        jr ra
          nop

/* vim:set ts=8 sw=8 et: */
