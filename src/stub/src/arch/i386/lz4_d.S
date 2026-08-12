/* Raw LZ4 block decoder for i386 UPX stubs.
 *
 * Required definitions:
 *   src          input cursor (%esi)
 *   dst          output cursor (%edi)
 *   lz4_src_end  register holding the first byte after the compressed block
 *   eof_lz4      caller-provided completion label
 *
 * Uses %ebx for the token and %ebp for the match cursor. Both are already
 * saved by the i386 expand/PE wrappers.
 */

        cld
.Llz4_sequence:
        movzbl  (src),%ebx
        inc     src
        mov     %ebx,%ecx
        shr     $4,%ecx
        cmp     $15,%ecx
        jne     .Llz4_copy_literals
.Llz4_literal_length:
        movzbl  (src),%eax
        inc     src
        add     %eax,%ecx
        cmp     $255,%eax
        je      .Llz4_literal_length
.Llz4_copy_literals:
        rep movsb
        cmp     lz4_src_end,src
        jae     eof_lz4

        movzwl  (src),%eax
        add     $2,src
        mov     dst,%ebp
        sub     %eax,%ebp

        mov     %ebx,%ecx
        and     $15,%ecx
        cmp     $15,%ecx
        jne     .Llz4_match_length_done
.Llz4_match_length:
        movzbl  (src),%eax
        inc     src
        add     %eax,%ecx
        cmp     $255,%eax
        je      .Llz4_match_length
.Llz4_match_length_done:
        add     $4,%ecx
.Llz4_match_byte_loop:
        mov     (%ebp),%al
        inc     %ebp
        mov     %al,(dst)
        inc     dst
        dec     %ecx
        jne     .Llz4_match_byte_loop
        jmp     .Llz4_sequence

