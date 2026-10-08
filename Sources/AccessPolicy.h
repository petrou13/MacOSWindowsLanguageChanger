#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
static BOOL WSModeHasAccess(NSInteger mode,BOOL listenAllowed,BOOL accessibilityAllowed) {
    return mode==1 ? accessibilityAllowed : listenAllowed;
}
static CGEventTapOptions WSTapOptions(NSInteger mode) {
    return mode==1 ? kCGEventTapOptionDefault : kCGEventTapOptionListenOnly;
}
