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

float savedInputVolume = 1;

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
    [defaults registerDefaults:@{
                                 MASCustomShortcutKey : firstLaunchShortcutData
                                 }];
    
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
    [self toggleDefaultInputVolume];
    [self updatePresentation];
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

    [self updatePresentation];
    [self enableLoginAutostart];
    
    // fires if we enter / exit dark mode
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}

- (void) updatePresentation {
    [self updateTouchBarButton];
    [self updateStatusBarIcon];
}

- (void) updateTouchBarButton {
    float currentVolume = [self getSystemInputVolume];
    
    [touchBarButton setBezelColor: [self colorState: currentVolume]];
    [touchBarButton layout];
}

- (void) updateStatusBarIcon {
    float currentVolume = [self getSystemInputVolume];
    BOOL isRed = currentVolume == 0;
    
    [self setStatusBarImgRed: isRed];
}

-(void)darkModeChanged:(NSNotification *)notif {
    [self updateStatusBarIcon];
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
}

-(AudioDeviceID) obtainDefaultOutputDevice {
    AudioDeviceID theAnswer = kAudioObjectUnknown;
    UInt32 theSize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress theAddress;
    
    theAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    theAddress.mScope = kAudioObjectPropertyScopeGlobal;
    theAddress.mElement = kAudioObjectPropertyElementMaster;
    
    //first be sure that a default device exists
    if (! AudioObjectHasProperty(kAudioObjectSystemObject, &theAddress) )    {
        NSLog(@"Unable to get default input audio device");
        return theAnswer;
    }
    
    //get the property 'default output device'
    OSStatus theError = AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &theSize, &theAnswer);
    if (theError != noErr) {
        NSLog(@"Unable to get output audio device");
        return theAnswer;
    }
    
    return theAnswer;
}

-(float) getSystemInputVolume {
    AudioDeviceID                defaultDevID = [self obtainDefaultOutputDevice];
    
    if (defaultDevID == kAudioObjectUnknown) {
        return 0.0;
    }
    
    UInt32                     theSize = sizeof(Float32);
    OSStatus                   theError;
    Float32                    theVolume = 0;
    AudioObjectPropertyAddress theAddress;
    
    theAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume;
    theAddress.mScope = kAudioDevicePropertyScopeInput;
    theAddress.mElement = kAudioObjectPropertyElementMaster;
    
    //be sure that the default device has the volume property
    if (! AudioObjectHasProperty(defaultDevID, &theAddress) ) {
        NSLog(@"No volume control for device 0x%0x",defaultDevID);
        return 0.0;
    }
    
    //now read the property and correct it, if outside [0...1]
    theError = AudioObjectGetPropertyData(defaultDevID, &theAddress, 0, NULL, &theSize, &theVolume);
    if ( theError != noErr )    {
        NSLog(@"Unable to read volume for device 0x%0x", defaultDevID);
        return 0.0;
    }
    theVolume = theVolume > 1.0 ? 1.0 : (theVolume < 0.0 ? 0.0 : theVolume);
    
    return theVolume;
}

- (void) setSystemInputVolume:(float)volume {
    AudioDeviceID defaultDevID = [self obtainDefaultOutputDevice];
    
    if (defaultDevID == kAudioObjectUnknown) {
        return;
    }
    
    // check if the new value is in the correct range - normalize it if not
    volume = volume > 1.0 ? 1.0 : (volume < 0.0 ? 0.0 : volume);
    
    OSStatus                   theError;
    AudioObjectPropertyAddress theAddress;
    Boolean                    canSetVol = YES;
    
    theAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume;
    theAddress.mScope = kAudioDevicePropertyScopeInput;
    theAddress.mElement = kAudioObjectPropertyElementMaster;
    
    //be sure that the default device has the volume property
    if (! AudioObjectHasProperty(defaultDevID, &theAddress) ) {
        NSLog(@"No volume control for device 0x%0x", defaultDevID);
        return;
    }
    
    //be sure the device can set the volume
    theError = AudioObjectIsPropertySettable(defaultDevID, &theAddress, &canSetVol);
    if ( theError!=noErr || !canSetVol ) {
        NSLog(@"The volume of device 0x%0x cannot be set", defaultDevID);
        return;
    }
    
    //now read the property and correct it, if outside [0...1]
    theError = AudioObjectSetPropertyData(defaultDevID, &theAddress, 0, NULL, sizeof(volume), &volume);
    if ( theError != noErr ) {
        NSLog(@"Unable to read volume for device 0x%0x", defaultDevID);
        return;
    }
}

-(NSColor *)colorState:(double)volume {
    if(!volume) {
        return NSColor.redColor;
    } else {
        return NSColor.clearColor;
    }
}

- (void)onPressed:(TouchButton*)sender {
    [self toggleDefaultInputVolume];
    [self updatePresentation];
}

- (void) toggleDefaultInputVolume {
    float volume = [self getSystemInputVolume];
    
    if (volume > 0) {
        savedInputVolume = volume;
        [self setSystemInputVolume:0];
    } else {
        [self setSystemInputVolume:savedInputVolume];
    }
}

- (void)onLongPressed:(TouchButton*)sender
{
    [[[[NSApplication sharedApplication] windows] lastObject] makeKeyAndOrderFront:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:true];
}

- (IBAction)muteMenuItemAction:(id)sender {
    [self toggleDefaultInputVolume];
    [self updatePresentation];
}

- (IBAction)prefsMenuItemAction:(id)sender {

    [self onLongPressed:sender];
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
    
    [self toggleDefaultInputVolume];
    [self updatePresentation];
}

@end
