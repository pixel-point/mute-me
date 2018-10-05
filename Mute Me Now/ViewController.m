#import "ViewController.h"
#import "AppDelegate.h"

static NSString *githubURL = @"https://github.com/pixel-point/mute-me";
static NSString *projectURL = @"https://muteme.pixelpoint.io/";
static NSString *companyURL = @"https://pixelpoint.io/";

static NSString *const MASCustomShortcutKey = @"customShortcut";

static void *MASObservingContext = &MASObservingContext;

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
    
    BOOL hideStatusBarState = [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_status_bar"];
    [self.showInMenuBarState setState: hideStatusBarState];
    
    BOOL statusBarButtonToggle = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar_button_toggle"];
    [self.statusBarButtonToggle setState: statusBarButtonToggle];
    
    BOOL useAlternateStatusBarIcons = [[NSUserDefaults standardUserDefaults] boolForKey:@"status_bar_alternate_icons"];
    [self.useAlternateStatusBarIcons setState: useAlternateStatusBarIcons];


    // enable to nil out preferences
    //[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"hide_status_bar"];
    //[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"auto_login"];
    //[[NSUserDefaults standardUserDefaults] synchronize];
    
    // Make a global context reference
    void *kGlobalShortcutContext = &kGlobalShortcutContext;
    
    // this sets the existing shortcut and allows it to save
    [self.masShortCutView setAssociatedUserDefaultsKey:MASCustomShortcutKey];

    
    // Implement when loading view
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults addObserver:self forKeyPath:MASCustomShortcutKey
                  options:NSKeyValueObservingOptionInitial
                  context:MASObservingContext];

    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *versionFieldValue = [NSString stringWithFormat:@"Version %@", version];
    [self.versionTextFieldCell setStringValue:versionFieldValue];
}

- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context: (void*) context
{

    if (context != MASObservingContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    if ([keyPath isEqualToString:MASCustomShortcutKey]) {
    
        NSLog (@"change key");
        
        [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:MASCustomShortcutKey toAction:^{
        
            AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
            [appDelegate shortCutKeyPressed];
        }];
        
    }
    
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

    [[NSUserDefaults standardUserDefaults] setBool:enableState forKey:@"hide_status_bar"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    [appDelegate hideMenuBar:enableState];

    
    if (enableState == YES) {
    
        NSString *msgText = @"Long press on the Touch Bar Mute Button to show Preferences when the Menu Item is disabled.";
        
        NSAlert* msgBox = [[NSAlert alloc] init] ;
        [msgBox setMessageText:msgText];
        [msgBox addButtonWithTitle: @"OK"];
        [msgBox runModal];
    }
    
    
    
}

- (IBAction)statusBarToggleChanged:(id)sender {
    
    NSInteger hideState = [self.showInMenuBarState state];
    
    if(hideState == NSOnState) {
        return;
    }
    
    NSInteger state = [self.statusBarButtonToggle state];
    
    BOOL enableState = NO;
    if(state == NSOnState) {
        enableState = YES;
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:enableState forKey:@"status_bar_button_toggle"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    [appDelegate hideMenuBar:NO];
    
}

- (IBAction)useAlternateStatusBarIconsChanged:(id)sender {
    
    NSInteger hideState = [self.showInMenuBarState state];
    
    if(hideState == NSOnState) {
        return;
    }
    
    NSInteger state = [self.useAlternateStatusBarIcons state];
    
    BOOL enableState = NO;
    if(state == NSOnState) {
        enableState = YES;
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:enableState forKey:@"status_bar_alternate_icons"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    [appDelegate hideMenuBar:NO];
    
}


- (IBAction)onMainWebsitePressed:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:companyURL]];
}

@end
