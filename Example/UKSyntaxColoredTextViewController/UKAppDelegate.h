//
//  UKAppDelegate.h
//  UKSyntaxColoredTextViewController
//
//  Created by Ryan Maxwell on 10/10/12.
//
//

#import <Cocoa/Cocoa.h>

@interface UKAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (strong, nonatomic) IBOutlet NSTextView *codePreviewTextView;

@end
