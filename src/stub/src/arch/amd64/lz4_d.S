/* Raw LZ4 block decoder for AMD64 UPX stubs.
 *
 * Required definitions:
 *   src          input cursor (%rsi in current stubs)
 *   dst          output cursor (%rdi in current stubs)
 *   lz4_src_end  register holding the first byte after the compressed block
 *   eof_lz4      caller-provided completion label
 *
 * The host-side overlap check guarantees that literal reads cannot destroy
 * compressed input which has not been consumed yet.
 */

        cld
.Llz4_sequence:
        movzbl  (src),%r10d
        inc     src
        mov     %r10d,%eax
        shr     $4,%eax
        cmp     $15,%eax
        jne     .Llz4_copy_literals
.Llz4_literal_length:
        movzbl  (src),%ecx
        inc     src
        add     %ecx,%eax
        cmp     $255,%ecx
        je      .Llz4_literal_length
.Llz4_copy_literals:
        mov     %eax,%ecx
        cmp     $8,%ecx
        jb      .Llz4_literal_bytes
.Llz4_literal_qwords:
        mov     (src),%rax
        mov     %rax,(dst)
        add     $8,src
        add     $8,dst
        sub     $8,%ecx
        cmp     $8,%ecx
        jae     .Llz4_literal_qwords
.Llz4_literal_bytes:
        test    %ecx,%ecx
        jz      .Llz4_literals_done
.Llz4_literal_byte_loop:
        mov     (src),%al
        inc     src
        mov     %al,(dst)
        inc     dst
        dec     %ecx
        jne     .Llz4_literal_byte_loop
.Llz4_literals_done:
        cmp     lz4_src_end,src
        jae     eof_lz4

        movzwl  (src),%eax
        add     $2,src
        mov     dst,%r11
        sub     %rax,%r11

        mov     %r10d,%eax
        and     $15,%eax
        cmp     $15,%eax
        jne     .Llz4_match_length_done
.Llz4_match_length:
        movzbl  (src),%ecx
        inc     src
        add     %ecx,%eax
        cmp     $255,%ecx
        je      .Llz4_match_length
.Llz4_match_length_done:
        add     $4,%eax
        mov     %eax,%ecx

        mov     dst,%rax
        sub     %r11,%rax
        cmp     $8,%eax
        jb      .Llz4_match_bytes
        cmp     $8,%ecx
        jb      .Llz4_match_bytes
.Llz4_match_qwords:
        mov     (%r11),%rax
        mov     %rax,(dst)
        add     $8,%r11
        add     $8,dst
        sub     $8,%ecx
        cmp     $8,%ecx
        jae     .Llz4_match_qwords
.Llz4_match_bytes:
        test    %ecx,%ecx
        jz      .Llz4_sequence
.Llz4_match_byte_loop:
        mov     (%r11),%al
        inc     %r11
        mov     %al,(dst)
        inc     dst
        dec     %ecx
        jne     .Llz4_match_byte_loop
        jmp     .Llz4_sequence

