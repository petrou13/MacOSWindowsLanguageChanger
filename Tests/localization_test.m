#import <Foundation/Foundation.h>
#import "../Sources/Localization.h"
#include <assert.h>

static NSDictionary *Strings(NSString *path) {
    NSData *data=[NSData dataWithContentsOfFile:path];
    assert(data);
    NSError *error=nil;
    NSDictionary *strings=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    assert(!error && [strings isKindOfClass:NSDictionary.class]);
    return strings;
}
static NSArray *Formats(NSString *text) {
    NSRegularExpression *expression=[NSRegularExpression regularExpressionWithPattern:@"%(?:[0-9]+\\$)?(?:lu|ld|d|@)" options:0 error:NULL];
    NSMutableArray *result=[NSMutableArray new];
    for(NSTextCheckingResult *match in [expression matchesInString:text options:0 range:NSMakeRange(0,text.length)]) {
        [result addObject:[text substringWithRange:match.range]];
    }
    return result;
}
int main(void) {
    @autoreleasepool {
        NSString *resources=NSBundle.mainBundle.resourcePath;
        NSDictionary *ru=Strings([resources stringByAppendingPathComponent:@"ru.lproj/Localizable.strings"]);
        NSDictionary *en=Strings([resources stringByAppendingPathComponent:@"en.lproj/Localizable.strings"]);
        assert([[NSSet setWithArray:ru.allKeys] isEqualToSet:[NSSet setWithArray:en.allKeys]]);
        for(NSString *key in ru) {
            assert([en[key] isKindOfClass:NSString.class] && [en[key] length]>0);
            assert([Formats(ru[key]) isEqualToArray:Formats(en[key])]);
        }
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        // Volatile arguments isolate tests from all persisted user preferences.
        [defaults setVolatileDomain:@{@"interfaceLanguage":@"en"} forName:NSArgumentDomain];
        assert([WSInterfaceLanguage() isEqualToString:@"en"]);
        assert([WSLocalized(@"Основные") isEqualToString:@"General"]);
        NSString *permission=[NSString stringWithFormat:WSLocalized(@"Нет доступа: %@"),WSLocalized(@"Универсальный доступ")];
        assert([permission isEqualToString:@"Permission needed: Accessibility"]);
        [defaults setVolatileDomain:@{@"interfaceLanguage":@"ru"} forName:NSArgumentDomain];
        assert([WSInterfaceLanguage() isEqualToString:@"ru"]);
        assert([WSLocalized(@"Основные") isEqualToString:@"Основные"]);
        assert([WSLocalized(@"Сочетание распознано") isEqualToString:@"Сочетание распознано"]);
        assert([WSLocalized(@"unknown-fallback-key") isEqualToString:@"unknown-fallback-key"]);
        printf("Localization passed: %lu matching keys, format arguments, live language changes and fallback.\n",(unsigned long)en.count);
    }
    return 0;
}
