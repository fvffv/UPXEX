/* Minimal Linux/i386 executable used to exercise the standalone UPX stub. */
        .section .text
        .globl _start
_start:
        mov     $4,%eax                 /* write */
        mov     $1,%ebx                 /* stdout */
        mov     $message,%ecx
        mov     $message_end-message,%edx
        int     $0x80
        mov     $1,%eax                 /* exit */
        xor     %ebx,%ebx
        int     $0x80

        .section .rodata
message:
        .ascii  "misa77-i386-ok\n"
message_end:
        .balign 16
payload:
        .fill   131072,1,0x41
