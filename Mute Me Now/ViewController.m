#import "ViewController.h"

static NSString *githubURL = @"https://github.com/pixel-point/mute-me";
static NSString *projectURL = @"https://muteme.pixelpoint.io/";
static NSString *companyURL = @"https://pixelpoint.io/";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"auto_login"] == nil) {
    
        // the opposite is used later
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"auto_login"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

        
    BOOL state = [[NSUserDefaults standardUserDefaults] boolForKey:@"auto_login"];
    [self.autoLoginState setState: !state];
    
    
    BOOL statusBarState = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar"];
    [self.showInMenuBarState setState: statusBarState];
    
    
    
    // enable to nil out preferences
    //[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"status_bar"];
    //[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"auto_login"];
    //[[NSUserDefaults standardUserDefaults] synchronize];
    
}

-(void)viewDidAppear {
    [super viewDidAppear];
    [[self.view window] setTitle:@"Mute me"];
    [[self.view window] center];
    
    
    
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    [[[[NSApplication sharedApplication] windows] lastObject] setTitle:@"Mute Me"];
}

- (IBAction)quitPressed:(id)sender {
    [NSApp terminate:nil]; //TODO or quit about window
}
- (IBAction)onGithubPressed:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:githubURL]];
}

- (IBAction)onWebsitePressed:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:projectURL]];
}
- (IBAction)onLoginStartChanged:(id)sender {
    NSInteger state = [self.autoLoginState state];
    BOOL enableState = NO;
    if(state == NSOnState) {
        enableState = YES;
    }
    if(SMLoginItemSetEnabled((__bridge CFStringRef)@"Pixel-Point.Mute-Me-Now-Launcher", enableState)) {
        [[NSUserDefaults standardUserDefaults] setBool:!enableState forKey:@"auto_login"];
    }
}

- (IBAction)showMenuBarChanged:(id)sender {

    NSInteger state = [self.showInMenuBarState state];

    BOOL enableState = NO;
    if(state == NSOnState) {
        enableState = YES;
    }

    [[NSUserDefaults standardUserDefaults] setBool:!enableState forKey:@"status_bar"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSString *msgText = @"You will need to restart the App for this change to be applied.";
    
    if (enableState == NO) {
        msgText = [NSString stringWithFormat:@"%@ Long press on the Touch Bar Mute Button to show Preferences when the Menu Item is disabled.", msgText];
    }
    
    NSAlert* msgBox = [[NSAlert alloc] init] ;
    [msgBox setMessageText:msgText];
    [msgBox addButtonWithTitle: @"OK"];
    [msgBox runModal];
}




- (IBAction)onMainWebsitePressed:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:companyURL]];
}

@end
