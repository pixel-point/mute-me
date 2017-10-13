#import "AppDelegate.h"
#import "TouchBar.h"
#import <ServiceManagement/ServiceManagement.h>
#import "TouchButton.h"
#import "TouchDelegate.h"
#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>

static const NSTouchBarItemIdentifier muteIdentifier = @"pp.mute";
static NSString *const MASCustomShortcutKey = @"customShortcut";

@interface AppDelegate () <TouchDelegate>

@end

@implementation AppDelegate

NSButton *touchBarButton;

@synthesize statusBar;

TouchButton *button;

NSString *STATUS_ICON_BLACK = @"tray-unactive-black";
NSString *STATUS_ICON_RED = @"tray-active";
NSString *STATUS_ICON_WHITE = @"tray-unactive-white";

NSString *STATUS_ICON_OFF = @"micOff";
NSString *STATUS_ICON_ON = @"micOn";


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

    [self updateMenuItem];

}

- (void) showMenu {
    
    [self.statusBar popUpStatusItemMenu:self.statusMenu];
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[[[NSApplication sharedApplication] windows] lastObject] close];

    DFRSystemModalShowsCloseBoxWhenFrontMost(YES);

    NSCustomTouchBarItem *mute =
    [[NSCustomTouchBarItem alloc] initWithIdentifier:muteIdentifier];

    NSImage *muteImage = [NSImage imageNamed:NSImageNameTouchBarAudioInputMuteTemplate];
    button = [TouchButton buttonWithImage: muteImage target:nil action:nil];
    [button setBezelColor: [self colorState: [self currentStateFixed]]];
    [button setDelegate: self];
    mute.view = button;

    touchBarButton = button;

    [NSTouchBarItem addSystemTrayItem:mute];
    DFRElementSetControlStripPresenceForIdentifier(muteIdentifier, YES);

    // set the menuBar Item
    double currentState = [self currentStateFixed];

    NSLog(@"currentState : %f", currentState);

    if (currentState == 0) {
        [self.muteMenuItem setState:NSOnState];
        
        [self setStatusBarImgRed:YES];
    }


    [self enableLoginAutostart];
    
    // fires if we enter / exit dark mode
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}

-(void)darkModeChanged:(NSNotification *)notif
{
    double volume = [self currentStateFixed];
    [self setStatusBarImgRed: !volume];
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
        NSLog (@"using red");
        
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

-(double) currentState {
    NSAppleEventDescriptor *result = [self excecuteAppleScript:@"volume_sript"];
    NSData *data = [result data];
    double currentPosition = 0;
    [data getBytes:&currentPosition length:[data length]];
    return currentPosition;
}

// return the correct microphone volume
-(double) currentStateFixed {
    NSAppleEventDescriptor *result = [self excecuteAppleScript:@"volume_sript"];
    return [result doubleValue];
}


-(double) changeState {
    NSAppleEventDescriptor *result = [self excecuteAppleScript:@"mute_sript"];
    NSData *data = [result data];
    double currentPosition = 0;
    [data getBytes:&currentPosition length:[data length]];
    return currentPosition;
}

-(double) changeStateFixed {
    NSAppleEventDescriptor *result = [self excecuteAppleScript:@"mute_sript"];
    return [result doubleValue];
}


-(NSAppleEventDescriptor *) excecuteAppleScript:(NSString *)withName {
    NSString* path = [[NSBundle mainBundle] pathForResource:withName ofType:@"scpt"];
    NSURL* url = [NSURL fileURLWithPath:path];
    
    NSDictionary* errors = [NSDictionary dictionary];
    NSAppleScript* appleScript = [[NSAppleScript alloc] initWithContentsOfURL:url error:&errors];
    
    return [appleScript executeAndReturnError:nil];
}

-(NSColor *)colorState:(double)volume {

    if(!volume) {
        return NSColor.redColor;
    } else {
        return NSColor.clearColor;
    }
}

- (void)onPressed:(TouchButton*)sender
{
    double volume = [self changeStateFixed];
    
    NSLog (@"volume : %f", volume);
    
    NSButton *button = (NSButton *)sender;
    [button setBezelColor: [self colorState: volume]];
    
    [self setStatusBarImgRed: !volume];

    if (!volume) {
        self.muteMenuItem.state = NSOnState;
    } else {
        self.muteMenuItem.state = NSOffState;
    }
    
}

- (void)onLongPressed:(TouchButton*)sender
{
    [[[[NSApplication sharedApplication] windows] lastObject] makeKeyAndOrderFront:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:true];
}

- (IBAction)prefsMenuItemAction:(id)sender {

    [self onLongPressed:sender];
}

- (IBAction)quitMenuItemAction:(id)sender {
    [NSApp terminate:nil];
}

- (IBAction)menuMenuItemAction:(id)sender {

    [self updateMenuItem];
}

- (void) updateMenuItemIcon {
    if (self.muteMenuItem.state == NSOnState) {
        [self setStatusBarImgRed:YES];
    } else {
        [self setStatusBarImgRed:NO];
    }
}

- (void) updateMenuItem {

    if (self.muteMenuItem.state == NSOffState) {
        self.muteMenuItem.state = NSOnState;
        [self setStatusBarImgRed:YES];
        [button setBezelColor: NSColor.redColor];
        
    } else {
        self.muteMenuItem.state = NSOffState;
        [self setStatusBarImgRed:NO];
        [button setBezelColor: NSColor.clearColor];
    }
    
    [self changeState];

}

- (void) handleStatusButtonAction {
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    
    if ((event.modifierFlags & NSEventModifierFlagControl) || (event.modifierFlags & NSEventModifierFlagOption) || (event.type == NSEventTypeRightMouseUp)) {
        
        [self showMenu];
        
        return;
    }
    
    [self updateMenuItem];
}


@end
