//
//  UKAppDelegate.m
//  UKSyntaxColoredTextViewController
//
//  Created by Ryan Maxwell on 10/10/12.
//
//

#import "UKAppDelegate.h"

@implementation UKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.codePreviewTextView.string =
    @"- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {\
    \n\treturn YES;\
    \n}";
    [self.syntaxColorController recolorCompleteFile:self];
}

- (IBAction)syntaxMenuChanged:(id)sender {
    [self.syntaxColorController recolorCompleteFile:self];
}

#pragma mark - UKSyntaxColoredTextViewDelegate

- (void)textViewControllerWillStartSyntaxRecoloring:(UKSyntaxColoredTextViewController *)sender {
    [self.progressIndicator startAnimation:nil];
}

- (void)textViewControllerDidFinishSyntaxRecoloring:(UKSyntaxColoredTextViewController *)sender {
    [self.progressIndicator stopAnimation:nil];
}

- (NSString *)syntaxDefinitionFilenameForTextViewController:(UKSyntaxColoredTextViewController *)sender {
    return self.syntaxPopUpButton.selectedItem.title;
}

@end
