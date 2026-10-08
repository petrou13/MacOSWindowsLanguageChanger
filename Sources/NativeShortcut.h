#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
static NSDictionary *WSNativeShortcut(id all) {
    if(![all isKindOfClass:NSDictionary.class]) return nil;
    for(NSString *identifier in @[@"61",@"60"]) {
        id entry=all[identifier];
        if(![entry isKindOfClass:NSDictionary.class] || ![entry[@"enabled"] isKindOfClass:NSNumber.class] || ![entry[@"enabled"] boolValue]) continue;
        id value=entry[@"value"];
        if(![value isKindOfClass:NSDictionary.class] || ![value[@"type"] isEqual:@"standard"]) continue;
        id params=value[@"parameters"];
        if(![params isKindOfClass:NSArray.class] || [params count]!=3 || ![params[1] isKindOfClass:NSNumber.class] || ![params[2] isKindOfClass:NSNumber.class]) continue;
        NSInteger code=[params[1] integerValue]; uint64_t flags=[params[2] unsignedLongLongValue];
        uint64_t allowed=kCGEventFlagMaskShift|kCGEventFlagMaskControl|kCGEventFlagMaskAlternate|kCGEventFlagMaskCommand;
        // A shortcut must include a normal key, never a modifier or Power.
        if(code<0 || code>=127 || (code>=54 && code<=63) || !flags || (flags & ~allowed)) continue;
        return @{@"code":@(code),@"flags":@(flags)};
    }
    return nil;
}
