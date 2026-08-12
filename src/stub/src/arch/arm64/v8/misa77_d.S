/* misa77 0.6 decoder for AArch64 UPX stubs.
 *
 * ABI on entry:
 *   x0      compressed input
 *   w1      compressed length
 *   x2      output
 *   x3      pointer to output length
 *
 * Levels -1..3 use the light format and level 4 uses the heavy format.
 * Only volatile registers x0..x17 are used.  Matches are copied forwards
 * byte-by-byte so overlapping matches have the same semantics on every OS.
 */

        add     x5,x0,x1              // compressed stream end
        mov     x6,x2                 // original output
        mov     x7,x3                 // output-length pointer
        ldr     x8,[x0]               // low 56 bits: original size
        ubfx    x8,x8,#0,#56
        ldrb    w15,[x0,#7]           // high byte bit 0: heavy format
        tbnz    w15,#0,.Lmisa64_heavy_entry

        cmp     x8,#32
        b.ls    .Lmisa64_small
        ldr     x17,[x0,#8]           // literal suffix size
        add     x10,x0,#16            // forward control stream
        sub     x9,x5,x17             // backwards literal stream

.Lmisa64_light_token:
        cmp     x10,x9
        b.hs    .Lmisa64_suffix
        ldrb    w11,[x10]
        lsr     w12,w11,#5            // literal length
        and     w14,w11,#31
        add     w14,w14,#3            // match length
        ldrh    w13,[x10,#1]
        add     w13,w13,#33           // match distance
        add     x10,x10,#3
        cmp     w12,#7
        b.ne    .Lmisa64_light_literals
.Lmisa64_light_lit_ext:
        ldrb    w15,[x10],#1
        add     w12,w12,w15
        cmp     w15,#255
        b.eq    .Lmisa64_light_lit_ext

.Lmisa64_light_literals:
        sub     x9,x9,w12,uxtw
        mov     x16,x9
        cbz     w12,.Lmisa64_light_match_ready
.Lmisa64_light_literal_loop:
        ldrb    w15,[x16],#1
        strb    w15,[x2],#1
        subs    w12,w12,#1
        b.ne    .Lmisa64_light_literal_loop
.Lmisa64_light_match_ready:
        sub     x16,x2,w13,uxtw
.Lmisa64_light_match_loop:
        ldrb    w15,[x16],#1
        strb    w15,[x2],#1
        subs    w14,w14,#1
        b.ne    .Lmisa64_light_match_loop
        b       .Lmisa64_light_token

.Lmisa64_heavy_entry:
        cmp     x8,#64
        b.ls    .Lmisa64_small
        ldr     x17,[x0,#8]
        add     x10,x0,#16
        sub     x9,x5,x17

.Lmisa64_heavy_token:
        cmp     x10,x9
        b.hs    .Lmisa64_suffix
        ldr     w11,[x10],#4
        lsr     w12,w11,#26           // literal length
        ubfx    w14,w11,#20,#6        // match length code
        ubfx    w13,w11,#0,#20
        add     w13,w13,#33           // match distance

        cbz     w14,.Lmisa64_heavy_match_ready
        cmp     w14,#29
        b.hi    .Lmisa64_heavy_match_30
        add     w14,w14,#3
        b       .Lmisa64_heavy_match_ready
.Lmisa64_heavy_match_30:
        cmp     w14,#45
        b.hi    .Lmisa64_heavy_match_46
        lsl     w14,w14,#1
        sub     w14,w14,#26
        b       .Lmisa64_heavy_match_ready
.Lmisa64_heavy_match_46:
        cmp     w14,#61
        b.hi    .Lmisa64_heavy_match_62
        lsl     w14,w14,#2
        sub     w14,w14,#116
        b       .Lmisa64_heavy_match_ready
.Lmisa64_heavy_match_62:
        cmp     w14,#62
        mov     w14,#160
        b.eq    .Lmisa64_heavy_match_ready
        mov     w14,#192
.Lmisa64_heavy_match_ready:
        cmp     w12,#63
        b.ne    .Lmisa64_heavy_literals
.Lmisa64_heavy_lit_ext:
        ldrb    w15,[x10],#1
        add     w12,w12,w15
        cmp     w15,#255
        b.eq    .Lmisa64_heavy_lit_ext

.Lmisa64_heavy_literals:
        sub     x9,x9,w12,uxtw
        mov     x16,x9
        cbz     w12,.Lmisa64_heavy_after_literals
.Lmisa64_heavy_literal_loop:
        ldrb    w15,[x16],#1
        strb    w15,[x2],#1
        subs    w12,w12,#1
        b.ne    .Lmisa64_heavy_literal_loop
.Lmisa64_heavy_after_literals:
        cbz     w14,.Lmisa64_heavy_token
        sub     x16,x2,w13,uxtw
.Lmisa64_heavy_match_loop:
        ldrb    w15,[x16],#1
        strb    w15,[x2],#1
        subs    w14,w14,#1
        b.ne    .Lmisa64_heavy_match_loop
        b       .Lmisa64_heavy_token

.Lmisa64_suffix:
        sub     x16,x5,x17
        cbz     x17,.Lmisa64_finished
.Lmisa64_suffix_loop:
        ldrb    w15,[x16],#1
        strb    w15,[x2],#1
        subs    x17,x17,#1
        b.ne    .Lmisa64_suffix_loop
        b       .Lmisa64_finished

.Lmisa64_small:
        add     x16,x0,#8
        mov     x17,x8
        cbz     x17,.Lmisa64_finished
.Lmisa64_small_loop:
        ldrb    w15,[x16],#1
        strb    w15,[x2],#1
        subs    x17,x17,#1
        b.ne    .Lmisa64_small_loop

.Lmisa64_finished:
        sub     x9,x2,x6
        str     w9,[x7]
        mov     x0,#0
        ret
