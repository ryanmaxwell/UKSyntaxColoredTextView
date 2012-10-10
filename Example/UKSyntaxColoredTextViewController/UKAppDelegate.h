//
//  UKAppDelegate.h
//  UKSyntaxColoredTextViewController
//
//  Created by Ryan Maxwell on 10/10/12.
//
//

#import <Cocoa/Cocoa.h>

@interface UKAppDelegate : NSObject <NSApplicationDelegate>

@property (assign, nonatomic) IBOutlet NSWindow *window;
@property (assign, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign, nonatomic) IBOutlet NSTextView *codePreviewTextView;
@property (assign, nonatomic) IBOutlet NSPopUpButton *syntaxPopUpButton;

- (IBAction)syntaxMenuChanged:(id)sender;

@end