//
//  UKSyntaxColoredTextViewController.h
//  UKSyntaxColoredDocument
//
//  Created by Uli Kusterer on 13.03.10.
//  Copyright 2010 Uli Kusterer.
//
//	This software is provided 'as-is', without any express or implied
//	warranty. In no event will the authors be held liable for any damages
//	arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	   1. The origin of this software must not be misrepresented; you must not
//	   claim that you wrote the original software. If you use this software
//	   in a product, an acknowledgment in the product documentation would be
//	   appreciated but is not required.
//
//	   2. Altered source versions must be plainly marked as such, and must not be
//	   misrepresented as being the original software.
//
//	   3. This notice may not be removed or altered from any source
//	   distribution.
//

#import <Cocoa/Cocoa.h>

/**
 * Key in user defaults holding user-defined identifiers to colorize.
 */
#define TD_USER_DEFINED_IDENTIFIERS			@"SyntaxColoring:UserIdentifiers"

/**
 * Anything we colorize gets this attribute. The value is an NSString holding the component name.
 */
#define TD_SYNTAX_COLORING_MODE_ATTR		@"UKTextDocumentSyntaxColoringMode"

@protocol UKSyntaxColoredTextViewDelegate;

@interface UKSyntaxColoredTextViewController : NSViewController <NSTextViewDelegate>

- (IBAction)recolorCompleteFile:(id)sender;
- (IBAction)toggleAutoSyntaxColoring:(id)sender;
- (IBAction)toggleMaintainIndentation:(id)sender;
- (IBAction)indentSelection:(id)sender;
- (IBAction)unindentSelection:(id)sender;
- (IBAction)toggleCommentForSelection:(id)sender;

@property (assign, nonatomic) IBOutlet id<UKSyntaxColoredTextViewDelegate>	delegate;

/** 
 * Automatically refresh syntax coloring when text is changed
 */
@property (assign, nonatomic) BOOL autoSyntaxColoring;

/** 
 * Keep new lines indented at same depth as their predecessor?
 */
@property (assign, nonatomic) BOOL maintainIndentation;

- (void)goToLine:(NSInteger)lineNum;
- (void)goToCharacter:(NSInteger)charNum;
- (void)goToRangeFrom:(NSInteger)startCh toChar:(NSInteger)endCh;

// Override any of the following in one of your subclasses to customize this object further:

/**
 * Defaults to "SyntaxDefinition.plist" in the app bundle's "Resources" directory.
 */
- (NSString *)syntaxDefinitionFilename;

/**
 * Defaults to loading plist from -syntaxDefinitionFilename.
 */
- (NSDictionary *)syntaxDefinitionDictionary;

/**
 * Style attributes dictionary for an NSAttributedString.
 */
- (NSDictionary *)defaultTextAttributes;

/**
 * Selected text range when document is opened.
 */
- (NSRange)defaultSelectedRange;

@end

@protocol UKSyntaxColoredTextViewDelegate <NSObject>

@optional

/**
 * Show your progress indicator.
 */
- (void)textViewControllerWillStartSyntaxRecoloring:(UKSyntaxColoredTextViewController *)sender;

/**
 * Make sure it gets redrawn.
 */
- (void)textViewControllerProgressedWhileSyntaxRecoloring:(UKSyntaxColoredTextViewController *)sender;

/**
 * Hide your progress indicator.
 */
- (void)textViewControllerDidFinishSyntaxRecoloring:(UKSyntaxColoredTextViewController *)sender;

/**
 * Update any selection status display.
 */
- (void)selectionInTextViewController:(UKSyntaxColoredTextViewController *)sender
              changedToStartCharacter:(NSUInteger)startCharInLine endCharacter:(NSUInteger)endCharInLine
                               inLine:(NSUInteger)lineInDoc startCharacterInDocument:(NSUInteger)startCharInDoc
               endCharacterInDocument:(NSUInteger)endCharInDoc;

/**
 * Won't get called if you override syntaxDefinitionDictionaryForTextViewController:.
 */
- (NSString *)syntaxDefinitionFilenameForTextViewController:(UKSyntaxColoredTextViewController *)sender;

- (NSDictionary *)syntaxDefinitionDictionaryForTextViewController:(UKSyntaxColoredTextViewController *)sender;

/**
 * If you can parse your code & provide a list of identifiers the user uses, you can provide this method to tell the editor about them.
 */
- (NSArray *)userIdentifiersForKeywordComponentName:(NSString *)inModeName;

/**
 * If you don't just want a color, provide an NSAttributedString attributes dictionary here.
 */
- (NSDictionary *)textAttributesForComponentName:(NSString *)inModeName color:(NSColor *)inColor;

@end
