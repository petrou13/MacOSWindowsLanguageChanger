#import "Engine.h"
#import "Chord.h"
#import "NativeShortcut.h"
#import "SwitchEvents.h"
#import "AccessPolicy.h"
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
static CGEventRef FlagsCallback(CGEventTapProxy p,CGEventType t,CGEventRef e,void *ctx);
static const int64_t LanguageSwitchEventTag=0x4D574C430024;
static BOOL IsRemoteApplication(NSRunningApplication *app) {
    NSString *bid=app.bundleIdentifier.lowercaseString ?: @"";
    return [bid hasPrefix:@"com.microsoft.rdc."] || [bid isEqualToString:@"com.microsoft.windowsapp"] || [bid hasPrefix:@"com.microsoft.windowsapp."];
}
@interface LanguageEngine () {
    CFMachPortRef _flagsTap;
    CFRunLoopSourceRef _flagsSource;
    WSChord _chord;
    BOOL _remote, _started;
    pid_t _frontPID;
    NSArray *_sources;
    NSMutableArray *_observers;
    NSString *_languageName, *_languageCode, *_currentSourceID, *_message;
    NSMutableIndexSet *_heldKeys;
    NSUInteger _modifierEvents, _gestures, _changes;
    NSString *_lastEvent;
    NSString *_nativeBefore, *_nativeTarget;
    NSUInteger _nativeSteps;
    pid_t _nativePID;
    NSUInteger _refreshGeneration;
}
@end
@implementation LanguageEngine
- (instancetype)init {
    if((self=[super init])) {
        NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
        [d registerDefaults:@{@"enabled":@YES,@"shortcut":@0,@"excludeRDP":@YES}];
        [d registerDefaults:@{@"accessMode":@(CGPreflightPostEventAccess() ? 1 : 0)}];
        _accessMode=[d integerForKey:@"accessMode"]==1 ? 1 : 0;
        _excludeRDP=[d boolForKey:@"excludeRDP"];
        _enabled=[d boolForKey:@"enabled"]; _shortcut=MAX(0,MIN(2,[d integerForKey:@"shortcut"]));
        _observers=[NSMutableArray new]; _languageName=@""; _languageCode=@""; _currentSourceID=@""; _message=@"";
        _heldKeys=[NSMutableIndexSet new]; _lastEvent=@"Ожидание сочетания";
        WSReset(&_chord,[self target]);
    } return self;
}
- (uint32_t)target { return WS_SHIFT|(_shortcut==1 ? WS_OPTION : _shortcut==2 ? WS_CONTROL : WS_COMMAND); }
- (BOOL)remote { return _excludeRDP && IsRemoteApplication(NSWorkspace.sharedWorkspace.frontmostApplication); }
- (void)setExcludeRDP:(BOOL)value {
    _excludeRDP=value; [NSUserDefaults.standardUserDefaults setBool:value forKey:@"excludeRDP"];
    [self frontChanged];
}
- (BOOL)permitted { return WSModeHasAccess(_accessMode,CGPreflightListenEventAccess(),AXIsProcessTrusted()); }
- (void)setAccessMode:(NSInteger)value {
    _accessMode=value==1 ? 1 : 0;
    [NSUserDefaults.standardUserDefaults setInteger:_accessMode forKey:@"accessMode"];
    _nativeBefore=nil; _nativeTarget=nil; _refreshGeneration++;
    [self destroyTaps]; [self updateMonitoring]; [self notify];
}
- (BOOL)listening { return _flagsTap && CGEventTapIsEnabled(_flagsTap); }
- (BOOL)systemSwitchPermitted { return CGPreflightPostEventAccess(); }
// Read the user's enabled system shortcut, including custom key assignments.
// No system preferences are changed and no modifier is remapped.
- (NSDictionary *)systemShortcut {
    CFPreferencesAppSynchronize(CFSTR("com.apple.symbolichotkeys"));
    NSDictionary *all=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("AppleSymbolicHotKeys"),CFSTR("com.apple.symbolichotkeys")));
    return WSNativeShortcut(all);
}
- (NSString *)systemSwitchStatus {
    if(_accessMode==0) return WSLocalized(@"Базовый режим: прямая смена раскладки. Системный значок возле курсора может отставать.");
    if(!self.systemSwitchPermitted) return WSLocalized(@"Для синхронизации значка возле курсора разрешите «Универсальный доступ».");
    if(![self systemShortcut]) return WSLocalized(@"Включите системное сочетание выбора источника ввода в настройках клавиатуры.");
    return WSLocalized(@"Системное переключение: раскладку и значок возле курсора обновляет macOS.");
}
- (BOOL)postSystemSwitch {
    NSRunningApplication *front=NSWorkspace.sharedWorkspace.frontmostApplication;
    if(_accessMode!=1 || !_enabled || (_excludeRDP && IsRemoteApplication(front)) || !self.systemSwitchPermitted) return NO;
    NSDictionary *shortcut=[self systemShortcut];
    if(!shortcut) return NO;
    CGEventFlags physical=CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState);
    if(physical & (kCGEventFlagMaskShift|kCGEventFlagMaskControl|kCGEventFlagMaskAlternate|kCGEventFlagMaskCommand|kCGEventFlagMaskSecondaryFn|kCGEventFlagMaskHelp)) return NO;
    CGKeyCode code=[shortcut[@"code"] unsignedShortValue];
    CGEventFlags flags=[shortcut[@"flags"] unsignedLongLongValue];
    // Complete the modifier lifecycle. A key-up with modifiers still set leaves
    // the cursor accessory stale until the next physical modifier event.
    WSSwitchEvents events=WSCreateSwitchEvents(code,flags,physical);
    if(!events.count) return NO;
    if(NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier!=front.processIdentifier) {
        WSReleaseSwitchEvents(&events); return NO;
    }
    _nativeBefore=[_currentSourceID copy]; _nativePID=front.processIdentifier;
    for(NSUInteger i=0;i<events.count;i++) {
        CGEventSetIntegerValueField(events.items[i],kCGEventSourceUserData,LanguageSwitchEventTag);
        CGEventPost(kCGHIDEventTap,events.items[i]);
    }
    WSReleaseSwitchEvents(&events);
    _message=@"";
    [self scheduleSourceRefresh];
    return YES;
}
// Only a bounded refresh following a switch; no idle polling and no timing
// threshold on recognition. Notifications remain the primary update path.
- (void)scheduleSourceRefresh {
    NSUInteger generation=++_refreshGeneration;
    pid_t origin=NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
    __weak LanguageEngine *weakSelf=self;
    for(NSNumber *delay in @[@0,@0.04,@0.12,@0.3]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            LanguageEngine *engine=weakSelf;
            if(!engine || generation!=engine->_refreshGeneration || NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier!=origin) return;
            [engine readSelectedSource];
        });
    }
}
- (NSString *)languageName { return WSLocalized(_languageName); }
- (NSString *)languageCode { return _languageCode; }
- (NSString *)currentSourceID { return _currentSourceID; }
- (NSString *)message { return WSLocalized(_message); }
- (NSString *)diagnostic {
    return [NSString stringWithFormat:WSLocalized(@"События модификаторов: %lu · Распознано сочетаний: %lu · Смен раскладки: %lu\n%@"),(unsigned long)_modifierEvents,(unsigned long)_gestures,(unsigned long)_changes,WSLocalized(_lastEvent)];
}
- (void)setDiagnosticVisible:(BOOL)value { _diagnosticVisible=value; [self notify]; }
- (void)notify { [NSNotificationCenter.defaultCenter postNotificationName:@"LanguageEngineChanged" object:self]; }
- (void)setShortcut:(NSInteger)value {
    _shortcut=MAX(0,MIN(2,value)); [NSUserDefaults.standardUserDefaults setInteger:_shortcut forKey:@"shortcut"];
    [self reset]; [self notify];
}
- (void)setEnabled:(BOOL)value {
    _enabled=value; [NSUserDefaults.standardUserDefaults setBool:value forKey:@"enabled"];
    if(!value) { _nativeBefore=nil; _nativeTarget=nil; _refreshGeneration++; }
    [self updateMonitoring]; [self notify];
}
- (void)reset {
    WSReset(&_chord,[self target]);
}
- (void)loadSources {
    NSDictionary *filter=@{(__bridge NSString *)kTISPropertyInputSourceCategory:(__bridge NSString *)kTISCategoryKeyboardInputSource,
        (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable:@YES,
        (__bridge NSString *)kTISPropertyInputSourceIsEnabled:@YES};
    _sources=CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)filter,false)) ?: @[];
}
- (NSArray<NSDictionary<NSString *,NSString *> *> *)inputSources {
    NSMutableArray *items=[NSMutableArray new];
    for(id obj in _sources) {
        TISInputSourceRef source=(__bridge TISInputSourceRef)obj;
        NSString *identifier=(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyInputSourceID);
        NSString *name=(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyLocalizedName);
        if(identifier) [items addObject:@{@"id":identifier,@"name":name ?: identifier}];
    } return items;
}
- (void)readSelectedSource {
    TISInputSourceRef source=TISCopyCurrentKeyboardInputSource();
    if(source) {
        _languageName=[(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyLocalizedName) copy] ?: @"Раскладка";
        _currentSourceID=[(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyInputSourceID) copy] ?: @"";
        NSArray *languages=(__bridge NSArray *)TISGetInputSourceProperty(source,kTISPropertyInputSourceLanguages);
        NSString *code=[[languages.firstObject componentsSeparatedByString:@"-"].firstObject uppercaseString];
        _languageCode=code ?: @"";
        CFRelease(source);
    }
    if(_nativeBefore && ![_nativeBefore isEqualToString:_currentSourceID]) {
        _nativeBefore=nil; _changes++; _lastEvent=@"Системная смена раскладки подтверждена macOS";
        if(_nativeTarget && ![_nativeTarget isEqualToString:_currentSourceID] && _nativeSteps>0 && NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier==_nativePID) {
            _nativeSteps--;
            if(![self postSystemSwitch]) _nativeTarget=nil;
        } else _nativeTarget=nil;
    }
    [self notify];
}
- (void)selectSource:(NSString *)identifier {
    if(self.remote || !_enabled) return;
    [self loadSources];
    if([identifier isEqualToString:_currentSourceID]) return;
    if(_accessMode==1) {
        if(!self.permitted || !self.systemSwitchPermitted || ![self systemShortcut]) { _message=@"Проверьте выбранный режим доступа и системное сочетание в настройках."; [self notify]; return; }
        BOOL exists=NO;
        for(NSDictionary *item in self.inputSources) if([item[@"id"] isEqualToString:identifier]) exists=YES;
        if(!exists) return;
        _nativeTarget=[identifier copy]; _nativeSteps=_sources.count;
        if([self postSystemSwitch]) return;
        _nativeTarget=nil;
        _message=@"Отпустите модификаторы и повторите переключение."; [self notify]; return;
    }
    for(id obj in _sources) {
        TISInputSourceRef source=(__bridge TISInputSourceRef)obj;
        NSString *candidate=(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyInputSourceID);
        if([candidate isEqualToString:identifier]) {
            OSStatus result=TISSelectInputSource(source);
            [self scheduleSourceRefresh];
            _message=result==noErr ? @"" : [NSString stringWithFormat:WSLocalized(@"macOS не разрешила изменить раскладку (код %d)."),(int)result];
            // Never predict the selected language; use TIS state after the native change.
            NSString *expected=[identifier copy];
            dispatch_async(dispatch_get_main_queue(),^{
                [self readSelectedSource];
                if(result==noErr && [self->_currentSourceID isEqualToString:expected]) {
                    self->_changes++; self->_lastEvent=@"Смена раскладки подтверждена macOS";
                } else if(result==noErr) {
                    self->_message=@"macOS не подтвердила выбранную раскладку. Проверьте поле ввода.";
                    self->_lastEvent=@"Смена раскладки не подтверждена";
                }
                [self notify];
            });
            return;
        }
    }
    _message=@"Раскладка больше не доступна. Проверьте настройки клавиатуры."; [self notify];
}
- (void)switchLanguage {
    if(self.remote || !_enabled) return;
    [self loadSources];
    if(_sources.count<2) { _message=@"Добавьте ещё одну раскладку в настройках клавиатуры."; [self notify]; return; }
    if(_accessMode==1) {
        if(!self.permitted || !self.systemSwitchPermitted || ![self systemShortcut]) { _message=@"Проверьте выбранный режим доступа и системное сочетание в настройках."; [self notify]; return; }
        _nativeTarget=nil;
        if(![self postSystemSwitch]) { _message=@"Отпустите модификаторы и повторите переключение."; [self notify]; }
        return;
    }
    TISInputSourceRef source=TISCopyCurrentKeyboardInputSource();
    NSString *identifier=source ? [(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyInputSourceID) copy] : nil;
    if(source) CFRelease(source);
    NSUInteger index=NSNotFound;
    for(NSUInteger i=0;i<_sources.count;i++) {
        NSString *candidate=(__bridge NSString *)TISGetInputSourceProperty((__bridge TISInputSourceRef)_sources[i],kTISPropertyInputSourceID);
        if(identifier && [candidate isEqualToString:identifier]) { index=i; break; }
    }
    TISInputSourceRef next=(__bridge TISInputSourceRef)_sources[index==NSNotFound ? 0 : (index+1)%_sources.count];
    NSString *nextID=(__bridge NSString *)TISGetInputSourceProperty(next,kTISPropertyInputSourceID);
    [self selectSource:nextID];
}
- (void)applyFront:(NSRunningApplication *)front {
    _remote=_excludeRDP && IsRemoteApplication(front);
    if(_frontPID!=front.processIdentifier) { _nativeBefore=nil; _nativeTarget=nil; _refreshGeneration++; }
    _frontPID=front.processIdentifier;
    [self updateMonitoring]; [self readSelectedSource];
}
- (void)frontChanged { [self applyFront:NSWorkspace.sharedWorkspace.frontmostApplication]; }
- (void)workspaceActivated:(NSNotification *)notification {
    NSRunningApplication *front=notification.userInfo[NSWorkspaceApplicationKey];
    if(front) [self applyFront:front];
    // Reconcile after the activation notification has finished, when the
    // workspace's frontmostApplication is guaranteed to reflect the new focus.
    dispatch_async(dispatch_get_main_queue(),^{ [self frontChanged]; });
}
- (void)sourceChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(),^{ [self readSelectedSource]; });
}
- (void)sourcesChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(),^{ [self loadSources]; [self readSelectedSource]; });
}
- (void)createTaps {
    if(_flagsTap || !self.permitted) return;
    CGEventMask mask=CGEventMaskBit(kCGEventFlagsChanged)|CGEventMaskBit(kCGEventKeyDown)|CGEventMaskBit(kCGEventKeyUp)|CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventRightMouseDown)|CGEventMaskBit(kCGEventOtherMouseDown)|CGEventMaskBit(kCGEventScrollWheel);
    // Accessibility authorizes an active tap; its callback still returns every
    // original event unchanged. Basic mode uses a strictly passive listener.
    CGEventTapOptions options=WSTapOptions(_accessMode);
    _flagsTap=CGEventTapCreate(kCGSessionEventTap,kCGHeadInsertEventTap,options,mask,FlagsCallback,(__bridge void *)self);
    if(!_flagsTap) return;
    _flagsSource=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,_flagsTap,0);
    if(!_flagsSource) { [self destroyTaps]; return; }
    CFRunLoopAddSource(CFRunLoopGetMain(),_flagsSource,kCFRunLoopCommonModes);
}
- (void)updateMonitoring {
    [self reset];
    [_heldKeys removeAllIndexes];
    if(_enabled && !_remote) [self createTaps];
    if(_flagsTap) CGEventTapEnable(_flagsTap,_enabled && !_remote && self.permitted);
}
- (void)suspend {
    _nativeBefore=nil; _nativeTarget=nil; _refreshGeneration++;
    [self reset]; if(_flagsTap) CGEventTapEnable(_flagsTap,false);
}
- (void)start {
    if(_started) return; _started=YES;
    [self loadSources];
    __weak LanguageEngine *weakSelf=self;
    NSNotificationCenter *workspace=NSWorkspace.sharedWorkspace.notificationCenter;
    [workspace addObserver:self selector:@selector(workspaceActivated:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
    for(NSString *name in @[NSWorkspaceDidWakeNotification,NSWorkspaceSessionDidBecomeActiveNotification]) {
        [_observers addObject:[workspace addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){ [weakSelf frontChanged]; }]];
    }
    [_observers addObject:[workspace addObserverForName:NSWorkspaceWillSleepNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){ [weakSelf suspend]; }]];
    NSDistributedNotificationCenter *distributed=NSDistributedNotificationCenter.defaultCenter;
    [distributed addObserver:self selector:@selector(sourceChanged:) name:(__bridge NSString *)kTISNotifySelectedKeyboardInputSourceChanged object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [distributed addObserver:self selector:@selector(sourcesChanged:) name:(__bridge NSString *)kTISNotifyEnabledKeyboardInputSourcesChanged object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [self frontChanged];
}
- (void)recheck { [self frontChanged]; }
- (void)refreshLocalization { _message=@""; [self notify]; }
- (void)requestPermission {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"]];
}
- (void)requestSystemSwitchPermission {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
- (void)observeFlags:(CGEventType)type event:(CGEventRef)event {
    if(type==kCGEventTapDisabledByTimeout || type==kCGEventTapDisabledByUserInput) {
        _lastEvent=@"Мониторинг восстановлен после приостановки macOS";
        [self updateMonitoring]; if(_diagnosticVisible) [self notify]; return;
    }
    if(CGEventGetIntegerValueField(event,kCGEventSourceUserData)==LanguageSwitchEventTag) return;
    // Keep the active event tap fast: use the focus cache maintained by workspace
    // notifications. The queued switch checks the real foreground again.
    if(!_enabled || _remote) return;
    if(type==kCGEventKeyDown || type==kCGEventKeyUp) {
        CGKeyCode code=(CGKeyCode)CGEventGetIntegerValueField(event,kCGKeyboardEventKeycode);
        if(code>=54 && code<=63) return;
        if(type==kCGEventKeyDown) {
            [_heldKeys addIndex:code];
            if(_chord.previous) { WSInterrupt(&_chord); _lastEvent=@"Сочетание отменено: добавлена другая клавиша"; }
        } else [_heldKeys removeIndex:code];
        return;
    }
    if(type!=kCGEventFlagsChanged) {
        if(_chord.previous) { WSInterrupt(&_chord); _lastEvent=@"Сочетание отменено: щелчок или прокрутка"; }
        return;
    }
    _modifierEvents++;
    CGEventFlags f=CGEventGetFlags(event); uint32_t flags=0;
    if(f & kCGEventFlagMaskShift) flags|=WS_SHIFT;
    if(f & kCGEventFlagMaskCommand) flags|=WS_COMMAND;
    if(f & kCGEventFlagMaskAlternate) flags|=WS_OPTION;
    if(f & kCGEventFlagMaskControl) flags|=WS_CONTROL;
    if(f & (kCGEventFlagMaskSecondaryFn|kCGEventFlagMaskHelp)) flags|=WS_OTHER;
    BOOL beginning=_chord.previous==0 && flags!=0;
    BOOL fire=WSFlags(&_chord,flags);
    if(beginning) {
        _lastEvent=@"Начато сочетание";
        if(_heldKeys.count) { WSInterrupt(&_chord); _lastEvent=@"Сочетание отменено: другая клавиша ещё удерживается"; }
    }
    if(fire) {
        _gestures++; _lastEvent=@"Сочетание распознано";
        pid_t origin=_frontPID;
        // Leave the event callback and release native modifiers before changing TIS.
        // This queues work, with no timed delay or debounce threshold.
        dispatch_async(dispatch_get_main_queue(),^{
            if(self->_enabled && !self.remote && self->_frontPID==origin && NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier==origin) [self switchLanguage];
        });
    }
    if(_diagnosticVisible) [self notify];
}
- (void)destroyTaps {
    if(_flagsSource) { CFRunLoopRemoveSource(CFRunLoopGetMain(),_flagsSource,kCFRunLoopCommonModes); CFRelease(_flagsSource); _flagsSource=NULL; }
    if(_flagsTap) { CFMachPortInvalidate(_flagsTap); CFRelease(_flagsTap); _flagsTap=NULL; }
}
- (void)dealloc {
    [self destroyTaps];
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    for(id token in _observers) [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:token];
}
@end
static CGEventRef FlagsCallback(CGEventTapProxy p,CGEventType t,CGEventRef e,void *ctx) {
    @autoreleasepool { [(__bridge LanguageEngine *)ctx observeFlags:t event:e]; } return e;
}
