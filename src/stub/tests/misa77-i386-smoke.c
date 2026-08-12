#include <stdio.h>

static const unsigned char payload[131072] = {[0 ... 131071] = 0x41};

int main(void)
{
    if (payload[0] != 0x41 || payload[sizeof(payload) - 1] != 0x41)
        return 1;
    puts("misa77-i386-ok");
    return 0;
}
