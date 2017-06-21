#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSButton *githubButton;
@property (weak) IBOutlet NSButton *websiteButton;
@property (weak) IBOutlet NSButton *autoLoginState;
@property (weak) IBOutlet NSButton *showInMenuBarState;

- (IBAction)showMenuBarChanged:(id)sender;

@end

