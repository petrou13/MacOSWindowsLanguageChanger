#include "../Sources/Chord.h"
#include <assert.h>
#include <stdio.h>
static void gesture(WSChord *s,uint32_t first,uint32_t pair,uint32_t remaining) {
    assert(!WSFlags(s,first)); assert(!WSFlags(s,pair)); assert(!WSFlags(s,remaining));
    assert(WSFlags(s,0)); assert(!WSFlags(s,0));
}
int main(void) {
    WSChord s;
    for(uint32_t second=WS_COMMAND;second<=WS_CONTROL;second*=2) {
        uint32_t pair=WS_SHIFT|second; WSReset(&s,pair);
        for(int i=0;i<10000;i++) {
            // Typing between every gesture must not cancel the NEXT gesture (v1 regression).
            WSInterrupt(&s);
            gesture(&s,WS_SHIFT,pair,second);
            WSInterrupt(&s);
            gesture(&s,second,pair,WS_SHIFT);
        }
        WSFlags(&s,WS_SHIFT); WSFlags(&s,pair); WSInterrupt(&s); assert(!WSFlags(&s,0));
        gesture(&s,WS_SHIFT,pair,second);
        WSFlags(&s,pair|WS_OTHER); WSFlags(&s,pair); assert(!WSFlags(&s,0));
        gesture(&s,second,pair,WS_SHIFT);
        // A letter held before the first modifier cancels only this gesture.
        WSFlags(&s,WS_SHIFT); WSInterrupt(&s); WSFlags(&s,pair); assert(!WSFlags(&s,0));
        gesture(&s,second,pair,WS_SHIFT);
        WSFlags(&s,WS_SHIFT); assert(!WSFlags(&s,0)); WSFlags(&s,second); assert(!WSFlags(&s,0));
        // Focus change, sleep and pause reset partial gestures.
        WSFlags(&s,pair); WSReset(&s,pair); assert(!WSFlags(&s,0));
        gesture(&s,WS_SHIFT,pair,second);
    }
    puts("60,000 gestures passed: typing regression, both orders, cancellation, no timing threshold.");
}
