//
//  UKAppDelegate.m
//  UKSyntaxColoredTextViewController
//
//  Created by Ryan Maxwell on 10/10/12.
//
//

#import "UKAppDelegate.h"
#import "UKSyntaxColoredTextViewController.h"

@interface UKAppDelegate () <UKSyntaxColoredTextViewDelegate>
@property (strong, nonatomic) UKSyntaxColoredTextViewController *syntaxColorController;
@end

@implementation UKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.codePreviewTextView.string =
    @"- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {\
    \n\treturn YES;\
    \n}";
    
    self.syntaxColorController = [[UKSyntaxColoredTextViewController alloc] init];
    self.syntaxColorController.view = self.codePreviewTextView;
    self.syntaxColorController.delegate = self;
}

- (IBAction)syntaxMenuChanged:(id)sender {
    
}

#pragma mark - UKSyntaxColoredTextViewDelegate

- (void)textViewControllerWillStartSyntaxRecoloring:(UKSyntaxColoredTextViewController *)sender {
    [self.progressIndicator startAnimation:nil];
}

- (void)textViewControllerDidFinishSyntaxRecoloring:(UKSyntaxColoredTextViewController *)sender {
    [self.progressIndicator stopAnimation:nil];
}

@end
