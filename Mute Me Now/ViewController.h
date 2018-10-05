#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSButton *githubButton;
@property (weak) IBOutlet NSButton *websiteButton;
@property (weak) IBOutlet NSButton *autoLoginState;
@property (weak) IBOutlet NSButton *showInMenuBarState;
@property (weak) IBOutlet NSButton *statusBarButtonToggle;
@property (weak) IBOutlet NSButton *useAlternateStatusBarIcons;
@property (weak) IBOutlet NSTextFieldCell *versionTextFieldCell;

@property (strong) IBOutlet MASShortcutView *masShortCutView;

- (IBAction)showMenuBarChanged:(id)sender;
- (IBAction)statusBarToggleChanged:(id)sender;
- (IBAction)useAlternateStatusBarIconsChanged:(id)sender;

@end

