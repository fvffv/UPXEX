/*  mipsel.r3000-linux.elf-so_entry.S -- Linux DT_INIT & decompressor (Elf shared lib)
*
*  This file is part of the UPX executable compressor.
*
*  Copyright (C) Markus Franz Xaver Johannes Oberhumer
*  Copyright (C) Laszlo Molnar
*  Copyright (C) John F. Reiser
*  All Rights Reserved.
*
*  UPX and the UCL library are free software; you can redistribute them
*  and/or modify them under the terms of the GNU General Public License as
*  published by the Free Software Foundation; either version 2 of
*  the License, or (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with this program; see the file COPYING.
*  If not, write to the Free Software Foundation, Inc.,
*  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*
*  Markus F.X.J. Oberhumer              Laszlo Molnar
*  <markus@oberhumer.com>               <ezerotven+github@gmail.com>
*
*  John F. Reiser
*  <jreiser@users.sourceforge.net>
*/

NBPW= 4
  .set mips1
  .set noat  // assembler may not automatically use $at.
  .set noreorder  // we handle branch delay sots explicitly
  .altmacro

#include "arch/mips/r3000/macros.ash"
#include "arch/mips/r3000/bits.ash"

#ifndef DEBUG
#define DEBUG 0
#endif

sz_Elf64_Ehdr = 8*NBPW
sz_Elf64_Phdr = 7*NBPW

sz_b_info= 12
  sz_unc= 0
  sz_cpr= 4
  b_method= 8
sz_l_info= 12
sz_p_info= 12

PROT_READ=  1
PROT_WRITE= 2
PROT_EXEC=  4

MAP_PRIVATE= 2
MAP_FIXED=     0x10
MAP_ANONYMOUS= 0x20

// /usr/include/asm-generic/unistd.h
__NR_Linux = 4000
__NR_cachuflush = -1
__NR_close    =   6+ __NR_Linux
__NR_exit     =   1+ __NR_Linux
__NR_memfd_create = 354 + __NR_Linux  /* Needs Linux >=3.17 */
  MFD_EXEC= 0x10
  EINVAL= 22
  ENOSYS= 38
__NR_mmap     =   90+ __NR_Linux
__NR_mprotect =  125+ __NR_Linux
__NR_munmap   =   91+ __NR_Linux
__NR_open     =    5+ __NR_Linux  /* still exists despite openat() */
__NR_openat   =  288+ __NR_Linux
__NR_read     =    3+ __NR_Linux
__NR_write    =    4+ __NR_Linux

#define arg1 a0
#define arg2 a1
#define arg3 a2
#define arg4 a3
#define arg5 a4  /* must move to stack */
#define arg6 a5  /* must move to stack */

#define bkpt break
#define call bal

  section ELFMAINX
//  .long offset(b_info)|(asl_delta>>12)  src for f_exp  FIXME: really?
//SO_INFO:
//  .word offset(.)  // detect relocation
//  .word offset(user DT_INIT)
//  .word offset(escape_hatch)  // override with round_up(2, PT_LOAD[0]{.p_memsz + .p_vaddr})
//  .word offset(dst for f_exp)
#if DEBUG_SO_MAIN  //{ fake SO_INFO for debugging as main program instead of shlib
   .word 1  // offset
   .word 2  // usdr _DT_INIT
   .word 3  // hatch
   .word 4  // dst for f_exp ??
#endif  //}

        .balign 4
 _start: .globl  _start
__start: .globl __start
        PUSH4 arg1,arg2,arg3,ra  // MATCH_00
        call fold_info  // returns ra= &b_info; arg3 = L5
          nop
L5:
#define foldi t8
        move foldi,ra

        addiu sp,sp,-6*NBPW
//empty 0 * NBPW
F_MFD=  1 * NBPW
F_PMSK= 2 * NBPW
F_S4=   3 * NBPW
F_ADRU= 4 * NBPW
F_LENU= 5 * NBPW

F_ARGC= 6 * NBPW  # %,MFD,PMSK,S4,ADRU,LENU; ==> &{arg1= argc; arg2= &argv; arg3= &envp}

        sw s4,F_S4(sp)
#define old_sp s4
        move old_sp,sp
        lw at,sz_unc(foldi)
          nop  // r3000 load delay
        sw at,F_LENU(old_sp)
        sub at,sp,at  // alloca
        li v1,-2*NBPW
        and sp,at,v1  // align stack

#define psa_fd  a5
#define aux_end a6
#define p_mask  a7

AT_PAGESZ= 6
O_RDONLY= 0
        call L10; nop
          .asciz "/proc/self/auxv"; .balign 4  # XXX: ENDIAN TROUBLE
L10:
        li   arg2,O_RDONLY
        move arg1,ra
        bal sysgo; li v0,__NR_open; move psa_fd,v0

        move arg1,psa_fd
        move arg2,sp  // buffer
        li   arg3,512  // len
        bal sysgo; li v0,__NR_read
        move arg1,psa_fd; bal sysgo; li v0,__NR_close
#undef psa_fd

0:  // search auxv
        lw v0,   0(arg2)  // tag
        lw v1,NBPW(arg2)  // value
        li at,AT_PAGESZ
        beq at,v0,1f
          addi arg2,arg2,2*NBPW  // next
        bne arg2,aux_end,0b
          li v1,1<<12  // default 4KiB
#undef aux_end
1:
        neg p_mask,v1  // PAGE_MASK
        sw p_mask,F_PMSK(old_sp)

        addiu arg4,old_sp,F_LENU  // &dstlen
        move  arg3,sp  // dst for decompress
        lw    arg2,sz_cpr(foldi)  // srclen
        call f_decompress
          addiu arg1,foldi,sz_b_info  // src
        lw at,F_PMSK(old_sp)
          nop  // LOAD delay slot
        sw at,0(sp)
#undef foldi

        call name_MFD
          li arg2,MFD_EXEC  # try newest flag bit
        .asciz "upx"  # XXX: ENDIAN TROUBLE
        .balign 4

#define src  a0
#define lsrc a1
#define dst  a2
#define ldst a3  /* Out: actually a reference: &len_dst */
sz_binfo= 3*4

eof_n2b: .globl eof_n2b
.if DEBUG_NRV
        li at,LEN_ROV
        addu sp,sp,at
        POP4 s0,s1,s2,s3
.endif
        POP4 v1,dst,old_sp,ra  // MATCH_46
        lw ldst,F_LENU(old_sp)  # actual len generated
        sub lsrc,a0,v1 # actual len consumed
        lw v0,sz_cpr - sz_binfo(v1)  # desired len consumed
        ret  // to caller of f_decompress
          subu v0,lsrc,v0  # deviation at EOF

name_MFD:
        move arg1,ra
tryMfd:
        li v0,__NR_memfd_create; syscall  // handle failure here
        bgez a3,OKmemfd  # success
          li at,ENOSYS
        beq at,v0,tryDevMem  # Linux does not implement memfd_create
          nop
        bnez arg2,tryMfd
          li arg2,0  # backwards-compat: no MFD_EXEC flag bit
        # assume EINVAL from some other cause; try next alternative

O_RDWR= 2
// WARNING: $ARCH DEPENDENT
// See src/upxfd_linux.c and linux/include/uapi/asm-generic-fcntl.h
O_DIRECTORY=  00200000  //  0x10000
__O_TMPFILE= 020000000  // 0x400000

// linux-stable commit 8c15abc94 2013-10-01  Linux 3.10.14
O_TMPFILE= (__O_TMPFILE | O_DIRECTORY)

tryDevMem:
        call 0f; nop; .asciz "/dev/shm"; .balign 4  # XXX: ENDiAN TROUBLE
0:
        li arg3,0700  // file mode rwx------
        li arg2,O_TMPFILE | O_RDWR
        move arg1,ra  // "/dev/shm"
        bal sysgo; li v0,__NR_open
OKmemfd:
#define mfd a5
        move mfd,v0
        sw v0,F_MFD(old_sp)

// detect big-endian; re-write get4unal if so
        lbu at,0(sp)  # lowest-addressed byte of PAGE_MASK
          lw v1,9*NBPW(sp)
        beqz at,0f  # 0 ==> little endian
          lw at,7*NBPW(sp)
        sw v1,6*NBPW(sp)
        sw at,4*NBPW(sp)
0:

        move arg1,mfd
        move arg2,sp
        lw arg3,F_LENU(old_sp)
        bal sysgo; li v0,__NR_write

        move sp,old_sp  // de-alloca
        lw s4,F_S4(sp)

sp_frame= 0x20
a4_sys=  4*NBPW
a5_sys=  5*NBPW
        lw   arg2,F_LENU(sp)
      addiu sp,sp,-sp_frame  # 6 args to mmap, but MIPS allows only 4 in registers
        sw zero,a5_sys(sp)  # beginning of file
        sw mfd, a4_sys(sp)
        li   arg4,MAP_PRIVATE  // modes
        li   arg3,PROT_READ|PROT_EXEC  // prot
        li   arg1,0  // addr (kernel chooses)
        bal sysgo; li v0,__NR_mmap
      addiu sp,sp,sp_frame
        move jp,v0
        sw v0,F_ADRU(sp)
OKmmap:

        lw arg1,F_MFD(sp)
        bal sysgo; li v0,__NR_close
#undef mfd
        bal 0f  // ra = 1f
          lw arg1,(ra)
1:        .int __start - 4*NBPW - 1b  // 'lw' in branch delay slot loads this
0:
        addiu arg2,sp,F_ARGC  // &{argc, argv, envp}
        addu arg1,arg1,ra  // & SO_INFO
        addiu jp,jp,2*NBPW  // skip PAGE_MASK and upxfn_path
        jr jp
          addiu sp,sp,F_ADRU  // &{ADRU,LENU,arg1,arg2,arg3,ra}

sysgo:
        syscall
        bltz a3,HALT
          nop
        ret
          nop
HALT:
        bkpt  // syscall error; see $ra


//%esp:
//  MATCH_04  ptr unfolded_code
//  MATCH_10  len unfolded_code
//  MATCH_00  argc,argv,envp,lr(_start)

f_decompress:
        PUSH4 src, dst, old_sp, ra  // MATCH_46
#undef old_sp
// nrv2b code is hard-wired here
#define NO_METHOD_CHECK 1

// only one de-compressor; build 'eof' return
#undef DAISY_CHAIN

// use of mmap() forces implcit cache sync
#define NO_SYNC_CACHE 1

// macro sets parameters to choose code style
        UCL_init    32,1,0  // 32 bits (not 8), UCL_SMALL, !UCL_FAST
        decomp_done = eof_n2b  // label name
#include "arch/mips/r3000/nrv2b_d.ash"
        build nrv2b, full
#undef src
#undef lsrc
#undef dst
#undef ldst


// IDENTSTR goes here

  section ELFMAINZ
fold_info:
        move arg3,ra
        jalr arg3  # go back to caller, with ra= &b_info
          nop
//  b_info (sz_unc, sz_cpr, method) of folded code (stage2 of de-compressor: C-language, etc.)

/* vim:set ts=8 sw=8 et: */
