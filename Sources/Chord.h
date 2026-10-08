#ifndef LANGUAGE_CHORD_H
#define LANGUAGE_CHORD_H
#include <stdbool.h>
#include <stdint.h>
enum { WS_SHIFT=1, WS_COMMAND=2, WS_OPTION=4, WS_CONTROL=8, WS_OTHER=16 };
typedef struct { uint32_t target, previous; bool armed, cancelled; } WSChord;
static inline void WSReset(WSChord *s, uint32_t target) { *s=(WSChord){.target=target}; }
static inline void WSInterrupt(WSChord *s) { if(s->previous) { s->cancelled=true; s->armed=false; } }
// There is deliberately no clock, delay, or simultaneity threshold.
static inline bool WSFlags(WSChord *s, uint32_t flags) {
    if (!s->previous && flags) { s->armed=false; s->cancelled=false; }
    if (flags & ~s->target) { s->cancelled=true; s->armed=false; }
    if (flags==s->target && !s->cancelled) s->armed=true;
    bool fire=flags==0 && s->armed && !s->cancelled;
    if (!flags) { s->armed=false; s->cancelled=false; }
    s->previous=flags;
    return fire;
}
#endif
