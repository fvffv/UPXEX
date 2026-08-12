/* Raw LZ4 block decoder for AArch64 UPX stubs.
 *
 * ABI on entry:
 *   x0      compressed input
 *   w1      compressed length
 *   x2      output
 *   x3      pointer to output length
 *
 * The routine uses only volatile registers, stores the actual output length,
 * returns zero in x0, and is safe for overlapping LZ4 matches.
 */

        add     x5,x0,x1              // input end
        mov     x6,x2                 // original output
        mov     x7,x3                 // output-length pointer
.Llz4_sequence:
        ldrb    w8,[x0],#1            // token
        lsr     w9,w8,#4              // literal length
        cmp     w9,#15
        b.ne    .Llz4_copy_literals
.Llz4_literal_length:
        ldrb    w10,[x0],#1
        add     w9,w9,w10
        cmp     w10,#255
        b.eq    .Llz4_literal_length
.Llz4_copy_literals:
        cbz     w9,.Llz4_literals_done
.Llz4_literal_loop:
        ldrb    w10,[x0],#1
        strb    w10,[x2],#1
        subs    w9,w9,#1
        b.ne    .Llz4_literal_loop
.Llz4_literals_done:
        cmp     x0,x5
        b.hs    .Llz4_finished

        ldrh    w10,[x0],#2           // little-endian match offset
        sub     x11,x2,x10            // match cursor
        and     w9,w8,#15             // match length minus four
        cmp     w9,#15
        b.ne    .Llz4_match_length_done
.Llz4_match_length:
        ldrb    w10,[x0],#1
        add     w9,w9,w10
        cmp     w10,#255
        b.eq    .Llz4_match_length
.Llz4_match_length_done:
        add     w9,w9,#4
.Llz4_match_loop:
        ldrb    w12,[x11],#1
        strb    w12,[x2],#1
        subs    w9,w9,#1
        b.ne    .Llz4_match_loop
        b       .Llz4_sequence

.Llz4_finished:
        sub     x9,x2,x6
        str     w9,[x7]
        mov     x0,#0
        ret

