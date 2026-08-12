/* Raw LZ4 block decoder for ARMv4 UPX stubs.
 * ABI: r0=input, r1=compressed length, r2=output, r3=&output length.
 * Unaligned multi-byte loads are avoided for ARMv4 compatibility.
 */
        stmdb   sp!,{r4-r11,lr}
        add     r4,r0,r1              @ input end
        mov     r5,r2                 @ original output
        mov     r6,r3                 @ output-length pointer
.Llz4_arm_sequence:
        ldrb    r7,[r0],#1            @ token
        mov     r8,r7,lsr #4          @ literal length
        cmp     r8,#15
        bne     .Llz4_arm_copy_literals
.Llz4_arm_literal_length:
        ldrb    r11,[r0],#1
        add     r8,r8,r11
        cmp     r11,#255
        beq     .Llz4_arm_literal_length
.Llz4_arm_copy_literals:
        cmp     r8,#0
        beq     .Llz4_arm_literals_done
.Llz4_arm_literal_loop:
        ldrb    r11,[r0],#1
        strb    r11,[r2],#1
        subs    r8,r8,#1
        bne     .Llz4_arm_literal_loop
.Llz4_arm_literals_done:
        cmp     r0,r4
        bhs     .Llz4_arm_finished

        ldrb    r9,[r0],#1            @ little-endian match offset
        ldrb    r11,[r0],#1
        orr     r9,r9,r11,lsl #8
        sub     r10,r2,r9             @ match cursor
        and     r8,r7,#15             @ match length minus four
        cmp     r8,#15
        bne     .Llz4_arm_match_length_done
.Llz4_arm_match_length:
        ldrb    r11,[r0],#1
        add     r8,r8,r11
        cmp     r11,#255
        beq     .Llz4_arm_match_length
.Llz4_arm_match_length_done:
        add     r8,r8,#4
.Llz4_arm_match_loop:
        ldrb    r11,[r10],#1
        strb    r11,[r2],#1
        subs    r8,r8,#1
        bne     .Llz4_arm_match_loop
        b       .Llz4_arm_sequence

.Llz4_arm_finished:
        sub     r8,r2,r5
        str     r8,[r6]
        mov     r0,#0
        ldmia   sp!,{r4-r11,pc}
