#import <Foundation/Foundation.h>
#import "Localization.h"
NS_ASSUME_NONNULL_BEGIN
@interface LanguageEngine : NSObject
@property(nonatomic) NSInteger shortcut;
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL diagnosticVisible;
@property(nonatomic) BOOL excludeRDP;
@property(nonatomic) NSInteger accessMode;
@property(nonatomic,readonly) BOOL remote;
@property(nonatomic,readonly) BOOL permitted;
@property(nonatomic,readonly) BOOL listening;
@property(nonatomic,readonly) BOOL systemSwitchPermitted;
@property(nonatomic,readonly) NSString *systemSwitchStatus;
@property(nonatomic,readonly) NSString *languageName;
@property(nonatomic,readonly) NSString *languageCode;
@property(nonatomic,readonly) NSString *message;
@property(nonatomic,readonly) NSString *diagnostic;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString *,NSString *> *> *inputSources;
@property(nonatomic,readonly) NSString *currentSourceID;
- (void)start;
- (void)recheck;
- (void)refreshLocalization;
- (void)requestPermission;
- (void)requestSystemSwitchPermission;
- (void)selectSource:(NSString *)identifier;
- (void)switchLanguage;
@end
NS_ASSUME_NONNULL_END
