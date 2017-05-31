#import "AppDelegate.h"
#import "TouchBar.h"

static const NSTouchBarItemIdentifier muteIdentifier = @"pp.mute";

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    DFRSystemModalShowsCloseBoxWhenFrontMost(YES);

    NSCustomTouchBarItem *mute =
    [[NSCustomTouchBarItem alloc] initWithIdentifier:muteIdentifier];

    NSImage *muteImage = [NSImage imageNamed:NSImageNameTouchBarAudioInputMuteTemplate];
    NSButton *button = [NSButton buttonWithImage: muteImage target:self action:@selector(present:)];
    [button setBezelColor: [self colorState: [self currentState]]];
    mute.view = button;

    [NSTouchBarItem addSystemTrayItem:mute];
    DFRElementSetControlStripPresenceForIdentifier(muteIdentifier, YES);
}

- (void)present:(id)sender
{
    double volume = [self changeState];
    NSButton *button = (NSButton *)sender;
    [button setBezelColor: [self colorState: volume]];
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

@end
