#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>
#import "Mute_Me-Swift.h"

@interface ViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSButton *githubButton;
@property (weak) IBOutlet NSButton *websiteButton;
@property (weak) IBOutlet NSButton *autoLoginState;
@property (weak) IBOutlet NSButton *showInMenuBarState;
@property (weak) IBOutlet NSButton *statusBarButtonToggle;
@property (weak) IBOutlet NSButton *useAlternateStatusBarIcons;
@property (weak) IBOutlet NSTextFieldCell *versionTextFieldCell;
@property (weak) IBOutlet NSTableView *devicesTable;

@property (strong) IBOutlet MASShortcutView *masShortCutView;

@property NSArray<DeviceInfo*> *deviceInfos;

- (IBAction)showMenuBarChanged:(id)sender;
- (IBAction)statusBarToggleChanged:(id)sender;
- (IBAction)useAlternateStatusBarIconsChanged:(id)sender;

@end

