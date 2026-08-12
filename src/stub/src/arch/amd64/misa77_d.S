/* misa77 0.6 decoder for AMD64 UPX stubs.
 *
 * Required definitions:
 *   src             input cursor (%rsi)
 *   dst             output cursor (%rdi)
 *   misa_src_end    first byte after the compressed block
 *   eof_misa77      caller-provided completion label
 *
 * Levels -1..3 use the light format and level 4 uses the heavy format.
 * Match copies are deliberately forward byte copies: misa77 guarantees a
 * minimum distance of 33 bytes, and byte copies also handle long overlapping
 * heavy matches without depending on memcpy overlap behaviour.
 */

        cld
        mov     misa_src_end,%r11       /* compressed stream end */
        mov     (src),%rax              /* low 56 bits: original size */
        shl     $8,%rax
        shr     $8,%rax
        testb   $1,7(src)               /* format bit: 0 light, 1 heavy */
        jnz     .Lmisa_heavy_entry

        cmp     $32,%rax
        jbe     .Lmisa_small
        mov     8(src),%r10             /* literal suffix size */
        lea     16(src),%r8             /* forward control stream */
        mov     %r11,%r9
        sub     %r10,%r9                /* backwards literal stream */

.Lmisa_light_token:
        cmp     %r9,%r8
        jae     .Lmisa_suffix
        movzbl  (%r8),%ecx
        mov     %ecx,%eax
        shr     $5,%eax                 /* literal length */
        and     $31,%ecx
        lea     3(%rcx),%edx            /* match length */
        movzwl  1(%r8),%ebx
        add     $33,%ebx                /* match distance */
        add     $3,%r8
        cmp     $7,%eax
        jne     .Lmisa_light_literals
.Lmisa_light_lit_ext:
        movzbl  (%r8),%ecx
        inc     %r8
        add     %rcx,%rax
        cmp     $255,%ecx
        je      .Lmisa_light_lit_ext

.Lmisa_light_literals:
        sub     %rax,%r9
        mov     %r9,src
        mov     %rax,%rcx
        rep movsb

        mov     dst,%rbp
        sub     %rbx,%rbp
        mov     %edx,%ecx
.Lmisa_light_match:
        mov     (%rbp),%al
        inc     %rbp
        mov     %al,(dst)
        inc     dst
        dec     %ecx
        jne     .Lmisa_light_match
        jmp     .Lmisa_light_token

.Lmisa_heavy_entry:
        cmp     $64,%rax
        jbe     .Lmisa_small
        mov     8(src),%r10
        lea     16(src),%r8
        mov     %r11,%r9
        sub     %r10,%r9

.Lmisa_heavy_token:
        cmp     %r9,%r8
        jae     .Lmisa_suffix
        mov     (%r8),%ecx
        mov     %ecx,%eax
        shr     $26,%eax                /* literal length */
        mov     %ecx,%edx
        shr     $20,%edx
        and     $63,%edx                /* match length code */
        and     $0xfffff,%ecx
        lea     33(%rcx),%ebx           /* match distance */
        add     $4,%r8

        test    %edx,%edx
        jz      .Lmisa_heavy_match_ready
        cmp     $29,%edx
        ja      .Lmisa_heavy_match_30
        add     $3,%edx
        jmp     .Lmisa_heavy_match_ready
.Lmisa_heavy_match_30:
        cmp     $45,%edx
        ja      .Lmisa_heavy_match_46
        lea     -26(%rdx,%rdx),%edx
        jmp     .Lmisa_heavy_match_ready
.Lmisa_heavy_match_46:
        cmp     $61,%edx
        ja      .Lmisa_heavy_match_62
        lea     -116(,%rdx,4),%edx
        jmp     .Lmisa_heavy_match_ready
.Lmisa_heavy_match_62:
        cmp     $62,%edx
        mov     $160,%edx
        je      .Lmisa_heavy_match_ready
        mov     $192,%edx
.Lmisa_heavy_match_ready:
        cmp     $63,%eax
        jne     .Lmisa_heavy_literals
.Lmisa_heavy_lit_ext:
        movzbl  (%r8),%ecx
        inc     %r8
        add     %rcx,%rax
        cmp     $255,%ecx
        je      .Lmisa_heavy_lit_ext

.Lmisa_heavy_literals:
        sub     %rax,%r9
        mov     %r9,src
        mov     %rax,%rcx
        rep movsb

        test    %edx,%edx
        jz      .Lmisa_heavy_token
        mov     dst,%rbp
        sub     %rbx,%rbp
        mov     %edx,%ecx
.Lmisa_heavy_match:
        mov     (%rbp),%al
        inc     %rbp
        mov     %al,(dst)
        inc     dst
        dec     %ecx
        jne     .Lmisa_heavy_match
        jmp     .Lmisa_heavy_token

.Lmisa_suffix:
        mov     %r11,src
        sub     %r10,src
        mov     %r10,%rcx
        rep movsb
        jmp     eof_misa77

.Lmisa_small:
        add     $8,src
        mov     %rax,%rcx
        rep movsb
        mov     %r11,src
        jmp     eof_misa77
