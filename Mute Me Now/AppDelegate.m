#import "AppDelegate.h"
#import "TouchBar.h"
#import <ServiceManagement/ServiceManagement.h>
#import "TouchButton.h"
#import "TouchDelegate.h"
#import <Cocoa/Cocoa.h>

static const NSTouchBarItemIdentifier muteIdentifier = @"pp.mute";

@interface AppDelegate () <TouchDelegate>

@end

@implementation AppDelegate

@synthesize statusBar;

- (void) awakeFromNib {

    self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    self.statusBar.title = @"M";
    //self.statusBar.image = [NSImage imageNamed:@"AppIcon"];

    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;

}



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[[[NSApplication sharedApplication] windows] lastObject] close];

    DFRSystemModalShowsCloseBoxWhenFrontMost(YES);

    NSCustomTouchBarItem *mute =
    [[NSCustomTouchBarItem alloc] initWithIdentifier:muteIdentifier];

    NSImage *muteImage = [NSImage imageNamed:NSImageNameTouchBarAudioInputMuteTemplate];
    TouchButton *button = [TouchButton buttonWithImage: muteImage target:nil action:nil];
    [button setBezelColor: [self colorState: [self currentState]]];
    [button setDelegate: self];
    mute.view = button;

    [NSTouchBarItem addSystemTrayItem:mute];
    DFRElementSetControlStripPresenceForIdentifier(muteIdentifier, YES);

    [self enableLoginAutostart];

}

-(void) enableLoginAutostart {
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

-(double) changeState {
    NSAppleEventDescriptor *result = [self excecuteAppleScript:@"mute_sript"];
    NSData *data = [result data];
    double currentPosition = 0;
    [data getBytes:&currentPosition length:[data length]];
    return currentPosition;
}

-(NSAppleEventDescriptor *) excecuteAppleScript:(NSString *)withName {
    NSString* path = [[NSBundle mainBundle] pathForResource:withName ofType:@"scpt"];
    NSURL* url = [NSURL fileURLWithPath:path];
    NSDictionary* errors = [NSDictionary dictionary];
    NSAppleScript* appleScript = [[NSAppleScript alloc] initWithContentsOfURL:url error:&errors];
    return [appleScript executeAndReturnError:nil];
}

-(NSColor *)colorState:(double)volume {
    if(volume == 0.0) {
        return NSColor.redColor;
    } else {
        return NSColor.clearColor;
    }
}

- (void)onPressed:(TouchButton*)sender
{
    double volume = [self changeState];
    NSButton *button = (NSButton *)sender;
    [button setBezelColor: [self colorState: volume]];
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


@end
