//
//  UKAppDelegate.h
//  UKSyntaxColoredTextView
//
//  Created by Ryan Maxwell on 10/10/12.
//
//

#import <Cocoa/Cocoa.h>
#import "UKSyntaxColoredTextViewController.h"

@interface UKAppDelegate : NSObject <NSApplicationDelegate, UKSyntaxColoredTextViewDelegate>

@property (assign, nonatomic) IBOutlet NSWindow *window;
@property (assign, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;

@property (strong, nonatomic) IBOutlet UKSyntaxColoredTextViewController *syntaxColorController;

@property (assign, nonatomic) IBOutlet NSTextView *codePreviewTextView;
@property (assign, nonatomic) IBOutlet NSPopUpButton *syntaxPopUpButton;

- (IBAction)syntaxMenuChanged:(id)sender;

@end
