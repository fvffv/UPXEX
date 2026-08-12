/* misa77 0.6 decoder for i386 UPX stubs.
 * Required: src=%esi, dst=%edi, misa_src_end, eof_misa77.
 * Stack words hold control, literals, suffix size and input end.
 */
        cld
        mov     misa_src_end,%ebp
        push    %ebp
        mov     (src),%eax
        testb   $1,7(src)
        jnz     .Lmisa32_heavy_entry
        cmp     $32,%eax
        jbe     .Lmisa32_small
        mov     8(src),%ecx
        mov     %ebp,%edx
        sub     %ecx,%edx
        lea     16(src),%ebp
        push    %ecx
        push    %edx
        push    %ebp
.Lmisa32_light_token:
        mov     0(%esp),%ebp
        cmp     4(%esp),%ebp
        jae     .Lmisa32_suffix
        movzbl  0(%ebp),%eax
        mov     %eax,%edx
        shr     $5,%eax
        and     $31,%edx
        add     $3,%edx
        movzwl  1(%ebp),%ebx
        add     $33,%ebx
        add     $3,%ebp
        mov     %ebp,0(%esp)
        cmp     $7,%eax
        jne     .Lmisa32_light_literals
.Lmisa32_light_lit_ext:
        mov     0(%esp),%ebp
        movzbl  (%ebp),%ecx
        inc     %ebp
        mov     %ebp,0(%esp)
        add     %ecx,%eax
        cmp     $255,%ecx
        je      .Lmisa32_light_lit_ext
.Lmisa32_light_literals:
        sub     %eax,4(%esp)
        mov     4(%esp),src
        mov     %eax,%ecx
        rep movsb
        mov     dst,%ebp
        sub     %ebx,%ebp
        mov     %edx,%ecx
.Lmisa32_light_match:
        mov     (%ebp),%al
        inc     %ebp
        mov     %al,(dst)
        inc     dst
        dec     %ecx
        jne     .Lmisa32_light_match
        jmp     .Lmisa32_light_token
.Lmisa32_heavy_entry:
        cmp     $64,%eax
        jbe     .Lmisa32_small
        mov     8(src),%ecx
        mov     %ebp,%edx
        sub     %ecx,%edx
        lea     16(src),%ebp
        push    %ecx
        push    %edx
        push    %ebp
.Lmisa32_heavy_token:
        mov     0(%esp),%ebp
        cmp     4(%esp),%ebp
        jae     .Lmisa32_suffix
        mov     (%ebp),%ecx
        add     $4,%ebp
        mov     %ebp,0(%esp)
        mov     %ecx,%eax
        shr     $26,%eax
        mov     %ecx,%edx
        shr     $20,%edx
        and     $63,%edx
        and     $0xfffff,%ecx
        lea     33(%ecx),%ebx
        test    %edx,%edx
        jz      .Lmisa32_heavy_match_ready
        cmp     $29,%edx
        ja      .Lmisa32_heavy_match_30
        add     $3,%edx
        jmp     .Lmisa32_heavy_match_ready
.Lmisa32_heavy_match_30:
        cmp     $45,%edx
        ja      .Lmisa32_heavy_match_46
        lea     -26(%edx,%edx),%edx
        jmp     .Lmisa32_heavy_match_ready
.Lmisa32_heavy_match_46:
        cmp     $61,%edx
        ja      .Lmisa32_heavy_match_62
        lea     -116(,%edx,4),%edx
        jmp     .Lmisa32_heavy_match_ready
.Lmisa32_heavy_match_62:
        cmp     $62,%edx
        mov     $160,%edx
        je      .Lmisa32_heavy_match_ready
        mov     $192,%edx
.Lmisa32_heavy_match_ready:
        cmp     $63,%eax
        jne     .Lmisa32_heavy_literals
.Lmisa32_heavy_lit_ext:
        mov     0(%esp),%ebp
        movzbl  (%ebp),%ecx
        inc     %ebp
        mov     %ebp,0(%esp)
        add     %ecx,%eax
        cmp     $255,%ecx
        je      .Lmisa32_heavy_lit_ext
.Lmisa32_heavy_literals:
        sub     %eax,4(%esp)
        mov     4(%esp),src
        mov     %eax,%ecx
        rep movsb
        test    %edx,%edx
        jz      .Lmisa32_heavy_token
        mov     dst,%ebp
        sub     %ebx,%ebp
        mov     %edx,%ecx
.Lmisa32_heavy_match:
        mov     (%ebp),%al
        inc     %ebp
        mov     %al,(dst)
        inc     dst
        dec     %ecx
        jne     .Lmisa32_heavy_match
        jmp     .Lmisa32_heavy_token
.Lmisa32_suffix:
        mov     12(%esp),src
        sub     8(%esp),src
        mov     8(%esp),%ecx
        rep movsb
        mov     12(%esp),src
        add     $16,%esp
        jmp     eof_misa77
.Lmisa32_small:
        add     $8,src
        mov     %eax,%ecx
        rep movsb
        mov     0(%esp),src
        add     $4,%esp
        jmp     eof_misa77
