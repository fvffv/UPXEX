#include <stdio.h>

static const unsigned char payload[131072] = {0x41, 0x42, 0x43, 0x44};

int main(void)
{
    if (payload[0] != 0x41 || payload[3] != 0x44)
        return 1;
    puts("misa77-win32-ok");
    return 0;
}
