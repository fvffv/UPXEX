/* misa77 0.6 decoder for ARMv4 UPX stubs.
 * ABI: r0=input, r1=compressed length, r2=output, r3=&output length.
 * Levels -1..3 use light format; level 4 uses heavy format.
 */
        stmdb   sp!,{r4-r11,lr}
        add     r5,r0,r1              @ compressed stream end
        mov     r4,r2                 @ original output
        ldrb    r9,[r0]
        ldrb    r12,[r0,#1]; orr r9,r9,r12,lsl #8
        ldrb    r12,[r0,#2]; orr r9,r9,r12,lsl #16
        ldrb    r12,[r0,#3]; orr r9,r9,r12,lsl #24
        ldrb    r12,[r0,#7]
        tst     r12,#1
        bne     .Lmisa_arm_heavy_entry

        cmp     r9,#32
        bls     .Lmisa_arm_small
        ldrb    r8,[r0,#8]
        ldrb    r12,[r0,#9];  orr r8,r8,r12,lsl #8
        ldrb    r12,[r0,#10]; orr r8,r8,r12,lsl #16
        ldrb    r12,[r0,#11]; orr r8,r8,r12,lsl #24
        add     r6,r0,#16             @ forward control stream
        sub     r7,r5,r8              @ backwards literal stream

.Lmisa_arm_light_token:
        cmp     r6,r7
        bhs     .Lmisa_arm_suffix
        ldrb    r12,[r6]
        mov     r9,r12,lsr #5         @ literal length
        and     r10,r12,#31
        add     r10,r10,#3            @ match length
        ldrb    r11,[r6,#1]
        ldrb    r12,[r6,#2]
        orr     r11,r11,r12,lsl #8
        add     r11,r11,#33           @ match distance
        add     r6,r6,#3
        cmp     r9,#7
        bne     .Lmisa_arm_light_literals
.Lmisa_arm_light_lit_ext:
        ldrb    r12,[r6],#1
        add     r9,r9,r12
        cmp     r12,#255
        beq     .Lmisa_arm_light_lit_ext
.Lmisa_arm_light_literals:
        sub     r7,r7,r9
        mov     r12,r7
        cmp     r9,#0
        beq     .Lmisa_arm_light_match_ready
.Lmisa_arm_light_literal_loop:
        ldrb    r1,[r12],#1
        strb    r1,[r2],#1
        subs    r9,r9,#1
        bne     .Lmisa_arm_light_literal_loop
.Lmisa_arm_light_match_ready:
        sub     r12,r2,r11
.Lmisa_arm_light_match_loop:
        ldrb    r1,[r12],#1
        strb    r1,[r2],#1
        subs    r10,r10,#1
        bne     .Lmisa_arm_light_match_loop
        b       .Lmisa_arm_light_token

.Lmisa_arm_heavy_entry:
        cmp     r9,#64
        bls     .Lmisa_arm_small
        ldrb    r8,[r0,#8]
        ldrb    r12,[r0,#9];  orr r8,r8,r12,lsl #8
        ldrb    r12,[r0,#10]; orr r8,r8,r12,lsl #16
        ldrb    r12,[r0,#11]; orr r8,r8,r12,lsl #24
        add     r6,r0,#16
        sub     r7,r5,r8

.Lmisa_arm_heavy_token:
        cmp     r6,r7
        bhs     .Lmisa_arm_suffix
        ldrb    r12,[r6]
        ldrb    r1,[r6,#1]; orr r12,r12,r1,lsl #8
        ldrb    r1,[r6,#2]; orr r12,r12,r1,lsl #16
        ldrb    r1,[r6,#3]; orr r12,r12,r1,lsl #24
        add     r6,r6,#4
        mov     r9,r12,lsr #26        @ literal length
        mov     r10,r12,lsr #20
        and     r10,r10,#63           @ match length code
        mov     r11,r12,lsl #12
        mov     r11,r11,lsr #12
        add     r11,r11,#33           @ match distance

        cmp     r10,#0
        beq     .Lmisa_arm_heavy_match_ready
        cmp     r10,#29
        bhi     .Lmisa_arm_heavy_match_30
        add     r10,r10,#3
        b       .Lmisa_arm_heavy_match_ready
.Lmisa_arm_heavy_match_30:
        cmp     r10,#45
        bhi     .Lmisa_arm_heavy_match_46
        mov     r10,r10,lsl #1
        sub     r10,r10,#26
        b       .Lmisa_arm_heavy_match_ready
.Lmisa_arm_heavy_match_46:
        cmp     r10,#61
        bhi     .Lmisa_arm_heavy_match_62
        mov     r10,r10,lsl #2
        sub     r10,r10,#116
        b       .Lmisa_arm_heavy_match_ready
.Lmisa_arm_heavy_match_62:
        cmp     r10,#62
        moveq   r10,#160
        movne   r10,#192
.Lmisa_arm_heavy_match_ready:
        cmp     r9,#63
        bne     .Lmisa_arm_heavy_literals
.Lmisa_arm_heavy_lit_ext:
        ldrb    r12,[r6],#1
        add     r9,r9,r12
        cmp     r12,#255
        beq     .Lmisa_arm_heavy_lit_ext
.Lmisa_arm_heavy_literals:
        sub     r7,r7,r9
        mov     r12,r7
        cmp     r9,#0
        beq     .Lmisa_arm_heavy_after_literals
.Lmisa_arm_heavy_literal_loop:
        ldrb    r1,[r12],#1
        strb    r1,[r2],#1
        subs    r9,r9,#1
        bne     .Lmisa_arm_heavy_literal_loop
.Lmisa_arm_heavy_after_literals:
        cmp     r10,#0
        beq     .Lmisa_arm_heavy_token
        sub     r12,r2,r11
.Lmisa_arm_heavy_match_loop:
        ldrb    r1,[r12],#1
        strb    r1,[r2],#1
        subs    r10,r10,#1
        bne     .Lmisa_arm_heavy_match_loop
        b       .Lmisa_arm_heavy_token

.Lmisa_arm_suffix:
        sub     r12,r5,r8
        cmp     r8,#0
        beq     .Lmisa_arm_finished
.Lmisa_arm_suffix_loop:
        ldrb    r1,[r12],#1
        strb    r1,[r2],#1
        subs    r8,r8,#1
        bne     .Lmisa_arm_suffix_loop
        b       .Lmisa_arm_finished

.Lmisa_arm_small:
        add     r12,r0,#8
        cmp     r9,#0
        beq     .Lmisa_arm_finished
.Lmisa_arm_small_loop:
        ldrb    r1,[r12],#1
        strb    r1,[r2],#1
        subs    r9,r9,#1
        bne     .Lmisa_arm_small_loop

.Lmisa_arm_finished:
        sub     r1,r2,r4
        str     r1,[r3]
        mov     r0,#0
        ldmia   sp!,{r4-r11,pc}
