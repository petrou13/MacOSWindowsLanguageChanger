#import "Localization.h"
NSString *WSInterfaceLanguage(void) {
    NSString *saved=[NSUserDefaults.standardUserDefaults stringForKey:@"interfaceLanguage"];
    if([saved isEqualToString:@"ru"] || [saved isEqualToString:@"en"]) return saved;
    return [NSLocale.preferredLanguages.firstObject hasPrefix:@"ru"] ? @"ru" : @"en";
}
NSString *WSLocalized(NSString *key) {
    // Cache the two resource bundles. No filesystem work occurs in the event tap.
    static NSDictionary<NSString *,NSBundle *> *bundles;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        NSMutableDictionary *found=[NSMutableDictionary new];
        for(NSString *language in @[@"ru",@"en"]) {
            NSString *path=[NSBundle.mainBundle pathForResource:language ofType:@"lproj"];
            NSBundle *bundle=path ? [NSBundle bundleWithPath:path] : nil;
            if(bundle) found[language]=bundle;
        }
        bundles=[found copy];
    });
    NSBundle *bundle=bundles[WSInterfaceLanguage()] ?: NSBundle.mainBundle;
    return [bundle localizedStringForKey:key value:key table:@"Localizable"];
}
