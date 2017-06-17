#import "ViewController.h"
#import "MMNLaunchAtLoginController.h"

static NSString *githubURL = @"https://github.com/pixel-point/mute-me";
static NSString *projectURL = @"https://muteme.pixelpoint.io/";
static NSString *companyURL = @"https://pixelpoint.io/";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Bind "Launch at login" checkbox state to the corresponding value in the controller object
    [self.autoLoginState bind:NSValueBinding
                     toObject:[MMNLaunchAtLoginController sharedController]
                  withKeyPath:@"shouldLaunchOnLogin"
                      options:nil];
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
- (IBAction)onMainWebsitePressed:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:companyURL]];
}

@end
