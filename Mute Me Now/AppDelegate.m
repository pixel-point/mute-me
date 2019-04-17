#import "AppDelegate.h"
#import "TouchBar.h"
#import <ServiceManagement/ServiceManagement.h>
#import "TouchButton.h"
#import "TouchDelegate.h"
#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioServices.h>
#import "ViewController.h"
#import "Mute_Me-Swift.h"

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

MuteState lastMuteState;

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
    DFRSystemModalShowsCloseBoxWhenFrontMost(YES);

    NSCustomTouchBarItem *mute = [[NSCustomTouchBarItem alloc] initWithIdentifier:muteIdentifier];
    NSImage *muteImage = [NSImage imageNamed:NSImageNameTouchBarAudioInputMuteTemplate];
    touchBarButton = [TouchButton buttonWithImage: muteImage target:self action:@selector(onPressed:)];
    mute.view = touchBarButton;
    [NSTouchBarItem addSystemTrayItem:mute];
    DFRElementSetControlStripPresenceForIdentifier(muteIdentifier, YES);
    
    [Mute preformInitializationWithChangeCallback:^(enum MuteState state) {
        dispatch_async(dispatch_get_main_queue(), ^{
            lastMuteState = state;
            [self updatePresentationWithLastState];
        });
    }];

    [self enableLoginAutostart];
    
    // fires if we enter / exit dark mode
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}

- (void) updatePresentationWithLastState {
    [self updateTouchBarButtonWithMuteState:lastMuteState];
    [self updateStatusBarIconWithMuteState:lastMuteState];
}

- (void) updateTouchBarButtonWithMuteState:(MuteState) state {
    [touchBarButton setBezelColor: [self colorForMuteState: state]];
    [touchBarButton layout];
}

- (void) updateStatusBarIconWithMuteState:(MuteState) state {
    [self setStatusBarImgRed: state == MuteStateAll];
}

-(void)darkModeChanged:(NSNotification *)notif {
    [self updatePresentationWithLastState];
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
    [Mute deinitialize];
}

-(NSColor *)colorForMuteState:(MuteState)state {
    if(state == MuteStateAll) return NSColor.redColor;
    if(state == MuteStatePartially) return NSColor.yellowColor;
    return NSColor.clearColor;
}

- (void)onPressed:(TouchButton*)sender {
    [self toggleMute];
}

- (void) toggleMute {
    [Mute toggleMuteOfAllInputDevices];
}

- (void) openPrefsWindow {
    NSStoryboard *mainStoryboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    NSWindowController *prefsWindowController = [mainStoryboard instantiateControllerWithIdentifier:@"prefsWindowController"];
    
    [prefsWindowController showWindow:self];
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
