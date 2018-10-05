#import "AppDelegate.h"
#import "TouchBar.h"
#import <ServiceManagement/ServiceManagement.h>
#import "TouchButton.h"
#import "TouchDelegate.h"
#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioServices.h>

static const NSTouchBarItemIdentifier muteIdentifier = @"pp.mute";
static NSString *const MASCustomShortcutKey = @"customShortcut";

@interface AppDelegate () <TouchDelegate>

@end

@implementation AppDelegate

@synthesize statusBar;

TouchButton *touchBarButton;

NSString *STATUS_ICON_BLACK = @"tray-unactive-black";
NSString *STATUS_ICON_RED = @"tray-active";
NSString *STATUS_ICON_WHITE = @"tray-unactive-white";

NSString *STATUS_ICON_OFF = @"micOff";
NSString *STATUS_ICON_ON = @"micOn";

AudioDeviceID currentAudioDeviceID = kAudioObjectUnknown;
AudioObjectPropertyListenerBlock onDefaultInputDeviceChange = NULL;
AudioObjectPropertyListenerBlock onAudioDeviceMuteChange = NULL;

- (void) awakeFromNib {
    BOOL hideStatusBar = NO;
    BOOL statusBarButtonToggle = NO;
    BOOL useAlternateStatusBarIcons = NO;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"hide_status_bar"] != nil) {
        hideStatusBar = [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_status_bar"];
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"status_bar_button_toggle"] != nil) {
        statusBarButtonToggle = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar_button_toggle"];
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"status_bar_alternate_icons"] != nil) {
        useAlternateStatusBarIcons = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar_alternate_icons"];
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:hideStatusBar forKey:@"hide_status_bar"];
    [[NSUserDefaults standardUserDefaults] setBool:statusBarButtonToggle forKey:@"status_bar_button_toggle"];
    [[NSUserDefaults standardUserDefaults] setBool:useAlternateStatusBarIcons forKey:@"status_bar_alternate_icons"];
    
    if (!hideStatusBar) {
        [self setupStatusBarItem];
    }
    
    // masshortcut
    [self setShortcutKey];
}

- (void) setupStatusBarItem {
    BOOL statusBarButtonToggle = NO;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"status_bar_button_toggle"] != nil) {
        statusBarButtonToggle = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar_button_toggle"];
    }
    
    if (statusBarButtonToggle) {
        NSStatusItem *statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        NSStatusBarButton *statusButton = statusItem.button;
        
        statusButton.target = self;
        statusButton.action = @selector(handleStatusButtonAction);
        
        [statusButton sendActionOn:NSEventMaskLeftMouseUp|NSEventMaskRightMouseUp];
        
        self.statusBar = statusItem;
    } else {
        self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        self.statusBar.menu = self.statusMenu;
    }
    
    NSImage* statusImage = [self getStatusBarImage];
    
    statusImage.size = NSMakeSize(18, 18);
    
    // allows cocoa to change the background of the icon
    [statusImage setTemplate:YES];
    
    self.statusBar.image = statusImage;
    self.statusBar.highlightMode = YES;
    self.statusBar.enabled = YES;
    
    [self updateMenuItemIcon];
}

- (void) setShortcutKey {
    // default shortcut is "Shift Command 0"
    MASShortcut *firstLaunchShortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_0 modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    NSData *firstLaunchShortcutData = [NSKeyedArchiver archivedDataWithRootObject:firstLaunchShortcut];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{ MASCustomShortcutKey : firstLaunchShortcutData }];
    [defaults synchronize];
    
    [[MASShortcutMonitor sharedMonitor] registerShortcut:firstLaunchShortcut withAction:^{
        [self shortCutKeyPressed];
    }];
}

- (void) hideMenuBar: (BOOL) enableState {
    if (!enableState) {
        [self setupStatusBarItem];
    } else {
        self.statusBar = nil;
    }
}

- (void) shortCutKeyPressed {
    [self toggleMute];
}

- (void) showMenu {
    [self.statusBar popUpStatusItemMenu:self.statusMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[[[NSApplication sharedApplication] windows] lastObject] close];

    DFRSystemModalShowsCloseBoxWhenFrontMost(YES);

    NSCustomTouchBarItem *mute = [[NSCustomTouchBarItem alloc] initWithIdentifier:muteIdentifier];
    NSImage *muteImage = [NSImage imageNamed:NSImageNameTouchBarAudioInputMuteTemplate];
    TouchButton *button = [TouchButton buttonWithImage: muteImage target:nil action:nil];
    [button setDelegate: self];
    mute.view = button;
    
    touchBarButton = button;

    [NSTouchBarItem addSystemTrayItem:mute];
    DFRElementSetControlStripPresenceForIdentifier(muteIdentifier, YES);
    
    onDefaultInputDeviceChange = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress * _Nonnull inAddresses) {
        BOOL muted = false;
        BOOL setMuted = false;
        
        if (currentAudioDeviceID != kAudioObjectUnknown) {
            setMuted = true;
            muted = [self getInputDeviceMute:currentAudioDeviceID];
            
            [self unlistenInputDevice:currentAudioDeviceID];
        }
        
        [self setDefaultInputDeviceAsCurrentAndListen];
        
        if (setMuted) {
            [self setInputDevice:currentAudioDeviceID mute:muted];
        }
    };
    
    onAudioDeviceMuteChange = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress * _Nonnull inAddresses) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updatePresentation];
        });
    };

    [self enableLoginAutostart];
    [self listenInputDevices];
    
    // fires if we enter / exit dark mode
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}

- (void) unlistenCurrentDevice {
    if (currentAudioDeviceID != kAudioObjectUnknown) {
        [self unlistenInputDevice:currentAudioDeviceID];
    }
}

- (void) setDefaultInputDeviceAsCurrentAndListen {
    currentAudioDeviceID = [self getDefaultInputDevice];
    
    if (currentAudioDeviceID != kAudioObjectUnknown) {
        OSStatus error = [self listenInputDevice:currentAudioDeviceID];
        if (error != noErr) {
            currentAudioDeviceID = kAudioObjectUnknown;
        } else {
            NSLog(@"Listen device: 0x%0x", currentAudioDeviceID);
        }
    }
}

- (void) listenInputDevices {
    AudioObjectPropertyAddress propertyAddress = [self defaultInputDevicePropertyAddress];
    
    OSStatus error = AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &propertyAddress, NULL, onDefaultInputDeviceChange);
    if (error != noErr) {
        NSLog(@"Can't listen change of default device. Error: %d", error);
    }
    
    [self setDefaultInputDeviceAsCurrentAndListen];
}

- (OSStatus) listenInputDevice:(AudioDeviceID)deviceID {
    AudioObjectPropertyAddress muteAddress = [self mutePropertyAddress];
    
    OSStatus error = AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, NULL, onAudioDeviceMuteChange);
    if (error != noErr) {
        NSLog(@"Can't listen mute change of device: 0x%0x. Error: %d", deviceID, error);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePresentation];
    });
    
    return error;
}

- (void) unlistenInputDevice:(AudioDeviceID)deviceID {
    AudioObjectPropertyAddress muteAddress = [self mutePropertyAddress];
    
    OSStatus error = AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, NULL, onAudioDeviceMuteChange);
    if (error != noErr) {
        NSLog(@"Can't unlisten mute change of device: 0x%0x. Error: %d", deviceID, error);
    }
    
    [self setInputDevice:deviceID mute:false];
}

- (void) updatePresentation {
    if (currentAudioDeviceID == kAudioObjectUnknown) {
        return;
    }
    
    BOOL muted = [self getInputDeviceMute:currentAudioDeviceID];
    [self updateTouchBarButtonWithMuted:muted];
    [self updateStatusBarIconWithMuted:muted];
}

- (void) updateTouchBarButtonWithMuted:(BOOL)muted {
    [touchBarButton setBezelColor: [self colorForMuted: muted]];
    [touchBarButton layout];
}

- (void) updateStatusBarIconWithMuted:(BOOL)muted {
    [self setStatusBarImgRed: muted];
}

-(void)darkModeChanged:(NSNotification *)notif {
    [self updatePresentation];
}


- (NSImage*) getStatusBarImage {

    BOOL useAlternateIcons = NO;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"status_bar_alternate_icons"] != nil) {
        useAlternateIcons = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar_alternate_icons"];
    }
    
    NSImage* statusImage;
    
    if (useAlternateIcons) {
        statusImage = [NSImage imageNamed:STATUS_ICON_ON];
    } else {
        statusImage = [NSImage imageNamed:STATUS_ICON_BLACK];
        
        // see https://stackoverflow.com/questions/25379525/how-to-detect-dark-mode-in-yosemite-to-change-the-status-bar-menu-icon
        NSDictionary *dict = [[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain];
        id style = [dict objectForKey:@"AppleInterfaceStyle"];
        
        BOOL darkModeOn = ( style && [style isKindOfClass:[NSString class]] && NSOrderedSame == [style caseInsensitiveCompare:@"dark"] );
        
        if (darkModeOn) {
            statusImage = [NSImage imageNamed:STATUS_ICON_WHITE];
        }
    }

    return statusImage;
}


- (void) setStatusBarImgRed:(BOOL) shouldBeRed {
    NSImage* statusImage = [self getStatusBarImage];

    if (shouldBeRed) {
        BOOL useAlternateIcons = NO;
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"status_bar_alternate_icons"] != nil) {
            useAlternateIcons = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar_alternate_icons"];
        }
        
        if (useAlternateIcons) {
            statusImage = [NSImage imageNamed:STATUS_ICON_OFF];
            [statusImage setTemplate:YES];
        } else {
            statusImage = [NSImage imageNamed:STATUS_ICON_RED];
            [statusImage setTemplate:!shouldBeRed];
        }
        
    }
    
    statusImage.size = NSMakeSize(18, 18);
    
    self.statusBar.image = statusImage;
    
}

- (BOOL) setAudioObject:(AudioObjectID)audioObjectID
               property:(AudioObjectPropertyAddress)propertyAddress
               dataSize:(UInt32)dataSize
                   data:(const void *)data
{
    if (!AudioObjectHasProperty(audioObjectID, &propertyAddress) ) {
        NSLog(@"No property for audioObject 0x%0x", audioObjectID);
        return false;
    }
    
    Boolean settable;
    OSStatus theError = AudioObjectIsPropertySettable(audioObjectID, &propertyAddress, &settable);
    if (theError != noErr || !settable) {
        NSLog(@"The property of audioObject 0x%0x cannot be set", audioObjectID);
        return false;
    }
    
    //now read the property and correct it, if outside [0...1]
    theError = AudioObjectSetPropertyData(audioObjectID, &propertyAddress, 0, NULL, dataSize, data);
    if (theError != noErr) {
        NSLog(@"Unable to set property for audioObject 0x%0x", audioObjectID);
        return false;
    }
    
    return true;
}

- (BOOL) getAudioObject:(AudioObjectID)audioObjectID
                       property:(AudioObjectPropertyAddress)propertyAddress
                       dataSize:(UInt32)dataSize
                           data:(void *)data
{
    if (!AudioObjectHasProperty(audioObjectID, &propertyAddress) ) {
        NSLog(@"No property for audioObject 0x%0x", audioObjectID);
        return false;
    }
    
    OSStatus theError = AudioObjectGetPropertyData(audioObjectID, &propertyAddress, 0, NULL, &dataSize, data);
    if (theError != noErr)    {
        NSLog(@"Unable to read property for audioObject 0x%0x", audioObjectID);
        return false;
    }
    
    return true;
}

- (AudioObjectPropertyAddress) mutePropertyAddress {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    return propertyAddress;
}

- (AudioObjectPropertyAddress) defaultInputDevicePropertyAddress {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    
    return propertyAddress;
}

- (BOOL) getInputDeviceMute:(AudioDeviceID)deviceID {
    AudioObjectPropertyAddress propertyAddress = [self mutePropertyAddress];
    UInt32 data;
    
    BOOL success = [self getAudioObject:deviceID property:propertyAddress dataSize:sizeof(data) data:&data];
    return success ? data == 1 : false;
}

- (void) setInputDevice:(AudioDeviceID)deviceID mute:(BOOL)mute {
    UInt32 value = mute ? 1 : 0;
    AudioObjectPropertyAddress propertyAddress = [self mutePropertyAddress];
    
    BOOL s = [self setAudioObject:deviceID property:propertyAddress dataSize:sizeof(value) data:&value];
    
    if (s) {
        printf("123");
        AudioObjectShow(deviceID);
        NSLog(@"Set property for audioObject 0x%0x to %d", deviceID, value);
    }
}

-(void) enableLoginAutostart {

    // on the first run this should be nil. So don't setup auto run
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"auto_login"] == nil) {
        return;
    }

    BOOL state = [[NSUserDefaults standardUserDefaults] boolForKey:@"auto_login"];
    if(!SMLoginItemSetEnabled((__bridge CFStringRef)@"Pixel-Point.Mute-Me-Now-Launcher", !state)) {
        NSLog(@"The login was not succesfull");
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self unlistenCurrentDevice];
}

- (AudioDeviceID) getDefaultInputDevice {
    AudioDeviceID defaultDevice = kAudioObjectUnknown;
    AudioObjectPropertyAddress address = [self defaultInputDevicePropertyAddress];
    
    [self getAudioObject:kAudioObjectSystemObject property:address dataSize:sizeof(AudioDeviceID) data:&defaultDevice];
    
    return defaultDevice;
}

-(NSColor *)colorForMuted:(BOOL)muted {
    if(muted) {
        return NSColor.redColor;
    } else {
        return NSColor.clearColor;
    }
}

- (void)onPressed:(TouchButton*)sender {
    [self toggleMute];
}

- (void) toggleMute {
    if (currentAudioDeviceID == kAudioObjectUnknown) {
        NSLog(@"Can't toggle mute. No audio device.");
        return;
    }
    
    BOOL isMuted = [self getInputDeviceMute:currentAudioDeviceID];
    [self setInputDevice:currentAudioDeviceID mute:!isMuted];
}

- (void) openPrefsWindow {
    // todo I saw a bug when pref window doesn't open (after night)
    [[[[NSApplication sharedApplication] windows] lastObject] makeKeyAndOrderFront:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:true];
}

- (void)onLongPressed:(TouchButton*)sender {
    [self openPrefsWindow];
}

- (IBAction)muteMenuItemAction:(id)sender {
    [self toggleMute];
}

- (IBAction)prefsMenuItemAction:(id)sender {
    [self openPrefsWindow];
}

- (IBAction)quitMenuItemAction:(id)sender {
    [NSApp terminate:nil];
}

- (void) updateMenuItemIcon {
    if (self.muteMenuItem.state == NSOnState) {
        [self setStatusBarImgRed:YES];
    } else {
        [self setStatusBarImgRed:NO];
    }
}

- (void) handleStatusButtonAction {
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    
    if ((event.modifierFlags & NSEventModifierFlagControl) || (event.modifierFlags & NSEventModifierFlagOption) || (event.type == NSEventTypeRightMouseUp)) {
        [self showMenu];
        return;
    }
    
    [self toggleMute];
}

@end
