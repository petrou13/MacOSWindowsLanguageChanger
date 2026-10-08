#import <ApplicationServices/ApplicationServices.h>
typedef struct { CGEventRef items[10]; NSUInteger count; } WSSwitchEvents;
static void WSReleaseSwitchEvents(WSSwitchEvents *events) {
    for(NSUInteger i=0;i<events->count;i++) if(events->items[i]) CFRelease(events->items[i]);
    events->count=0;
}
static WSSwitchEvents WSCreateSwitchEvents(CGKeyCode code,CGEventFlags flags,CGEventFlags physical) {
    WSSwitchEvents events={0};
    CGEventSourceRef source=CGEventSourceCreate(kCGEventSourceStatePrivate);
    CGEventFlags masks[]={kCGEventFlagMaskControl,kCGEventFlagMaskAlternate,kCGEventFlagMaskShift,kCGEventFlagMaskCommand};
    CGKeyCode codes[]={59,58,56,55};
    CGEventFlags current=physical & kCGEventFlagMaskAlphaShift;
    for(NSUInteger i=0;i<4;i++) if(flags & masks[i]) {
        current|=masks[i];
        CGEventRef event=CGEventCreateKeyboardEvent(source,codes[i],true);
        if(event) { CGEventSetType(event,kCGEventFlagsChanged); CGEventSetFlags(event,current); }
        events.items[events.count++]=event;
    }
    for(NSUInteger i=0;i<2;i++) {
        CGEventRef event=CGEventCreateKeyboardEvent(source,code,i==0);
        if(event) CGEventSetFlags(event,current);
        events.items[events.count++]=event;
    }
    for(NSInteger i=3;i>=0;i--) if(flags & masks[i]) {
        current&=~masks[i];
        CGEventRef event=CGEventCreateKeyboardEvent(source,codes[i],false);
        if(event) { CGEventSetType(event,kCGEventFlagsChanged); CGEventSetFlags(event,current); }
        events.items[events.count++]=event;
    }
    if(source) CFRelease(source);
    for(NSUInteger i=0;i<events.count;i++) if(!events.items[i]) { WSReleaseSwitchEvents(&events); break; }
    return events;
}
