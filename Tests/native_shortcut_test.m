#import "../Sources/NativeShortcut.h"
#import "../Sources/SwitchEvents.h"
#import "../Sources/AccessPolicy.h"
#include <assert.h>
static NSDictionary *entry(BOOL enabled, NSInteger code, uint64_t flags) {
    return @{@"enabled":@(enabled),@"value":@{@"type":@"standard",@"parameters":@[@32,@(code),@(flags)]}};
}
int main(void) { @autoreleasepool {
    for(unsigned listen=0;listen<2;listen++) for(unsigned accessibility=0;accessibility<2;accessibility++) {
        assert(WSModeHasAccess(0,listen,accessibility)==listen);
        assert(WSModeHasAccess(1,listen,accessibility)==accessibility);
    }
    assert(WSTapOptions(0)==kCGEventTapOptionListenOnly);
    assert(WSTapOptions(1)==kCGEventTapOptionDefault);
    puts("Access modes passed: basic needs only ListenEvent; system needs only Accessibility.");
    NSDictionary *next=entry(YES,49,kCGEventFlagMaskAlternate);
    NSDictionary *previous=entry(YES,49,kCGEventFlagMaskControl);
    assert([WSNativeShortcut(@{@"61":next,@"60":previous})[@"flags"] unsignedLongLongValue]==kCGEventFlagMaskAlternate);
    assert([WSNativeShortcut(@{@"61":entry(NO,49,kCGEventFlagMaskAlternate),@"60":previous})[@"flags"] unsignedLongLongValue]==kCGEventFlagMaskControl);
    assert([WSNativeShortcut(@{@"61":entry(YES,12,kCGEventFlagMaskCommand|kCGEventFlagMaskShift)})[@"code"] integerValue]==12);
    assert(!WSNativeShortcut(@{@"61":entry(NO,49,kCGEventFlagMaskAlternate)}));
    assert(!WSNativeShortcut(@{@"61":entry(YES,65535,kCGEventFlagMaskAlternate)}));
    assert(!WSNativeShortcut(@{@"61":entry(YES,127,kCGEventFlagMaskAlternate)}));
    for(NSInteger key=54;key<=63;key++) assert(!WSNativeShortcut(@{@"61":entry(YES,key,kCGEventFlagMaskControl)}));
    assert(!WSNativeShortcut(@{@"61":entry(YES,49,kCGEventFlagMaskSecondaryFn)}));
    assert(!WSNativeShortcut(@{@"61":entry(YES,49,0)}));
    assert(!WSNativeShortcut(@[@1]));
    assert(!WSNativeShortcut(@{@"61":@"invalid"}));
    assert(!WSNativeShortcut(@{@"61":@{@"enabled":@YES,@"value":@{@"type":@"standard",@"parameters":@[@32,@"bad",@524288]}}}));
    CGEventFlags masks[]={kCGEventFlagMaskControl,kCGEventFlagMaskAlternate,kCGEventFlagMaskShift,kCGEventFlagMaskCommand};
    for(unsigned subset=1;subset<16;subset++) for(unsigned caps=0;caps<2;caps++) {
        CGEventFlags flags=0; unsigned modifiers=0;
        for(unsigned i=0;i<4;i++) if(subset & (1u<<i)) { flags|=masks[i]; modifiers++; }
        CGEventFlags base=caps ? kCGEventFlagMaskAlphaShift : 0;
        WSSwitchEvents events=WSCreateSwitchEvents(49,flags,base);
        assert(events.count==modifiers*2+2);
        assert(CGEventGetType(events.items[modifiers])==kCGEventKeyDown);
        assert(CGEventGetType(events.items[modifiers+1])==kCGEventKeyUp);
        assert(CGEventGetIntegerValueField(events.items[modifiers],kCGKeyboardEventKeycode)==49);
        assert(CGEventGetFlags(events.items[modifiers])==(flags|base));
        assert(CGEventGetType(events.items[events.count-1])==kCGEventFlagsChanged);
        assert(CGEventGetFlags(events.items[events.count-1])==base);
        WSReleaseSwitchEvents(&events);
    }
    puts("Modifier lifecycle passed: 15 combinations, complete release, Caps Lock preserved; no events posted.");
    puts("Native shortcuts passed: custom assignment, preference order, disabled and malformed entries.");
} return 0; }
