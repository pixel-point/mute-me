#import "ViewController.h"

static NSString *githubURL = @"https://github.com/pixel-point/mute-me";
static NSString *projectURL = @"https://muteme.pixelpoint.io/";
static NSString *companyURL = @"https://pixelpoint.io/";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    BOOL state = [[NSUserDefaults standardUserDefaults] boolForKey:@"auto_login"];
    [self.autoLoginState setState: !state];
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
- (IBAction)onMainWebsitePressed:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:companyURL]];
}

@end
