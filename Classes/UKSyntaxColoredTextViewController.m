//
//  UKSyntaxColoredTextViewController.m
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

#import "UKSyntaxColoredTextViewController.h"
#import "NSArray+Color.h"
#import "NSScanner+SkipUpToCharset.h"

static BOOL			sSyntaxColoredTextDocPrefsInited = NO;

@interface UKSyntaxColoredTextViewController ()

/** Set while recolorRange is busy, so we don't recursively call recolorRange. */
@property (assign, nonatomic) BOOL syntaxColoringBusy;

@property (assign, nonatomic) NSRange affectedCharRange;
@property (strong, nonatomic) NSString *replacementString;
@property (readonly) NSTextView *textView;


- (void)turnOffWrapping;

- (void)recolorRange:(NSRange)range;

- (void)colorOneLineComment: (NSString*) startCh inString: (NSMutableAttributedString*) s
                  withColor: (NSColor*) col andMode:(NSString*)attr;
- (void)colorCommentsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
				withColor: (NSColor*) col andMode:(NSString*)attr;
- (void)colorIdentifier: (NSString*) ident inString: (NSMutableAttributedString*) s
              withColor: (NSColor*) col andMode:(NSString*)attr charset: (NSCharacterSet*)cset;
- (void)colorStringsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
               withColor: (NSColor*) col andMode:(NSString*)attr andEscapeChar: (NSString*)vStringEscapeCharacter;
- (void)colorTagFrom: (NSString*) startCh to: (NSString*)endCh inString: (NSMutableAttributedString*) s
           withColor: (NSColor*) col andMode:(NSString*)attr exceptIfMode: (NSString*)ignoreAttr;

@end


@implementation UKSyntaxColoredTextViewController

- (NSTextView *)textView {
    return (NSTextView *)self.view;
}

/**
 * Called by each view on creation to make sure we load the default colors
 * and user-defined identifiers from SyntaxColorDefaults.plist.
 */
+ (void)makeSurePrefsAreInited {
	if (!sSyntaxColoredTextDocPrefsInited) {
        NSString *path = [NSBundle.mainBundle pathForResource:@"SyntaxColorDefaults" ofType:@"plist"];
        NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:path];
		[NSUserDefaults.standardUserDefaults registerDefaults:defaults];
		sSyntaxColoredTextDocPrefsInited = YES;
	}
}

/**
 * Constructor that inits sourceCode member variable as a flag.
 * It's storage for the text until the NIB's been loaded.
 */
- (id)initWithNibName:(NSString *)inNibName bundle:(NSBundle *)inBundle {
    self = [super initWithNibName:inNibName bundle:inBundle];
    if (self) {
		_autoSyntaxColoring = YES;
		_maintainIndentation = YES;
		_syntaxColoringBusy = NO;
	}
    return self;
}


- (void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver: self];
}


- (void)setUpSyntaxColoring {
	// Set up some sensible defaults for syntax coloring:
	[self.class makeSurePrefsAreInited];
	
	// Register for "text changed" notifications of our text storage:
	[NSNotificationCenter.defaultCenter addObserver: self selector: @selector(processEditing:)
					name: NSTextStorageDidProcessEditingNotification
                                               object:self.textView.textStorage];
	
	// Make sure text isn't wrapped:
	[self turnOffWrapping];
	
	// Do initial syntax coloring of our file:
	[self recolorCompleteFile: nil];
	
	// Text view selects at end of text, use something more sensible:
	NSRange	startSelRange = self.defaultSelectedRange;
    self.textView.selectedRange = startSelRange;
	
	[self textView:self.textView willChangeSelectionFromCharacterRange:startSelRange
					toCharacterRange:startSelRange];	// Update UI to show selection.
	
	// Make sure we can use "find" if we're on 10.3:
	if( [self.textView respondsToSelector:@selector(setUsesFindPanel:)] )
		self.textView.usesFindPanel = YES;
}

/**
 * We've just been given a view! Apply initial syntax coloring.
 */
- (void)setView:(NSView *)theView {
    [super setView:theView];
	
	[(NSTextView*)theView setDelegate:self];
	[self setUpSyntaxColoring];	// TODO: If someone calls this twice, we should only call part of this twice!
}

/**
 * Part of the text was changed. Recolor it.
 */
- (void)processEditing:(NSNotification *)notification {
    NSTextStorage	*textStorage = [notification object];
	NSRange			range = [textStorage editedRange];
	NSUInteger				changeInLen = [textStorage changeInLength];
	BOOL			wasInUndoRedo = [self.undoManager isUndoing] || [self.undoManager isRedoing];
	BOOL			textLengthMayHaveChanged = NO;
	
	// Was delete op or undo that could have changed text length?
	if( wasInUndoRedo )
	{
		textLengthMayHaveChanged = YES;
		range = self.textView.selectedRange;
	}
	if( changeInLen <= 0 )
		textLengthMayHaveChanged = YES;
	
	//	Try to get chars around this to recolor any identifier we're in:
	if( textLengthMayHaveChanged )
	{
		if( range.location > 0 )
			range.location--;
		if( (range.location +range.length +2) < textStorage.length )
			range.length += 2;
		else if( (range.location +range.length +1) < textStorage.length )
			range.length += 1;
	}
	
	NSRange						currRange = range;
    
	// Perform the syntax coloring:
	if( self.autoSyntaxColoring && range.length > 0 )
	{
		NSRange			effectiveRange;
		NSString*		rangeMode;
		
		
		rangeMode = [textStorage attribute: TD_SYNTAX_COLORING_MODE_ATTR
								atIndex: currRange.location
								effectiveRange: &effectiveRange];
		
		NSUInteger		x = range.location;
		
		/** TODO: If we're in a multi-line comment and we're typing a comment-end
			character, or we're in a string and we're typing a quote character,
			this should include the rest of the text up to the next comment/string
			end character in the recalc. */
		
		// Scan up to prev line break:
		while( x > 0 )
		{
			unichar theCh = [textStorage.string characterAtIndex: x];
			if( theCh == '\n' || theCh == '\r' )
				break;
			--x;
		}
		
		currRange.location = x;
		
		// Scan up to next line break:
		x = range.location +range.length;
		
		while( x < textStorage.length )
		{
			unichar theCh = [textStorage.string characterAtIndex: x];
			if( theCh == '\n' || theCh == '\r' )
				break;
			++x;
		}
		
		currRange.length = x -currRange.location;
		
		// Open identifier, comment etc.? Make sure we include the whole range.
		if( rangeMode != nil )
			currRange = NSUnionRange( currRange, effectiveRange );
		
		// Actually recolor the changed part:
		[self recolorRange: currRange];
	}
}

/**
 * Perform indentation-maintaining if we're supposed to.
 */
- (BOOL)textView:(NSTextView *)tv shouldChangeTextInRange:(NSRange)afcr replacementString:(NSString *)rps {
	if( self.maintainIndentation ) {
		self.affectedCharRange = afcr;
        self.replacementString = rps;
		
		[self performSelector: @selector(didChangeText) withObject: nil afterDelay: 0.0];	// Queue this up on the event loop. If we change the text here, we only confuse the undo stack.
	}
	
	return YES;
}


/**
 * This actually does what we want to do in textView:shouldChangeTextInRange:
 */
- (void)didChangeText {
	if( self.maintainIndentation && self.replacementString && ([self.replacementString isEqualToString:@"\n"]
		|| [self.replacementString isEqualToString:@"\r"]) ) {
        
		NSMutableAttributedString*  textStore = self.textView.textStorage;
		BOOL						hadSpaces = NO;
		NSUInteger				lastSpace = self.affectedCharRange.location,
									prevLineBreak = 0;
		NSRange						spacesRange = { 0, 0 };
		unichar						theChar = 0;
		NSUInteger				x = (self.affectedCharRange.location == 0) ? 0 : self.affectedCharRange.location -1;
		NSString*					tsString = textStore.string;
		
		while( YES )
		{
			if( x > (tsString.length -1) )
				break;
			
			theChar = [tsString characterAtIndex: x];
			
			switch( theChar )
			{
				case '\n':
				case '\r':
					prevLineBreak = x +1;
					x = 0;  // Terminate the loop.
					break;
				
				case ' ':
				case '\t':
					if( !hadSpaces )
					{
						lastSpace = x;
						hadSpaces = YES;
					}
					break;
				
				default:
					hadSpaces = NO;
					break;
			}
			
			if( x == 0 )
				break;
			
			x--;
		}
		
		if( hadSpaces )
		{
			spacesRange.location = prevLineBreak;
			spacesRange.length = lastSpace -prevLineBreak +1;
			if( spacesRange.length > 0 )
				[self.textView insertText: [tsString substringWithRange:spacesRange]];
		}
	}
}

/**
 * Action for menu item that toggles automatic syntax coloring on and off.
 */
- (IBAction)toggleAutoSyntaxColoring:(id)sender {
    self.autoSyntaxColoring = !self.autoSyntaxColoring;
	[self recolorCompleteFile:nil];
}

/**
 * Action for menu item that toggles indentation maintaining on and off.
 */
- (IBAction)toggleMaintainIndentation:(id)sender {
    self.maintainIndentation = !self.maintainIndentation;
}

/**
 * This selects the specified line of the document.
 */
- (void)goToLine:(NSInteger)lineNum {
	NSRange			theRange = { 0, 0 };
	NSString*		vString = self.textView.string;
	unsigned		currLine = 1;
	NSCharacterSet* vSet = [NSCharacterSet characterSetWithCharactersInString: @"\n\r"];
	unsigned		x;
	unsigned		lastBreakOffs = 0;
	unichar			lastBreakChar = 0;
	
	for( x = 0; x < vString.length; x++ )
	{
		unichar		theCh = [vString characterAtIndex: x];
		
		// Skip non-linebreak chars:
		if( ![vSet characterIsMember: theCh] )
			continue;
		
		// If this is the LF in a CRLF sequence, only count it as one line break:
		if( theCh == '\n' && lastBreakOffs == (x-1)
			&& lastBreakChar == '\r' )
		{
			lastBreakOffs = 0;
			lastBreakChar = 0;
			theRange.location++;
			continue;
		}
		
		// Calc range and increase line number:
		theRange.length = x -theRange.location +1;
		if( currLine >= lineNum )
			break;
		currLine++;
		theRange.location = theRange.location +theRange.length;
		lastBreakOffs = x;
		lastBreakChar = theCh;
	}
	
	[self.textView scrollRangeToVisible:theRange];
	self.textView.selectedRange = theRange;
}

#define REALLY_LARGE_NUMBER	1.0e7	// FLT_MAX is too large and causes our rect to be shortened again.

/**
 * Makes the view so wide that text won't wrap anymore.
 */
- (void)turnOffWrapping {
	NSTextContainer*	textContainer = self.textView.textContainer;
	NSRect				frame = { { 0, 0 }, { 0, 0 } };
	NSScrollView*		scrollView = self.textView.enclosingScrollView;
	
	// Make sure we can see right edge of line:
    scrollView.hasHorizontalScroller = YES;
	
	// Make text container so wide it won't wrap:
	textContainer.containerSize = NSMakeSize(REALLY_LARGE_NUMBER, REALLY_LARGE_NUMBER);
	textContainer.widthTracksTextView = NO;
    textContainer.heightTracksTextView = NO;

	// Make sure text view is wide enough:
	frame.origin = NSMakePoint( 0.0, 0.0 );
    frame.size = scrollView.contentSize;
	
    self.textView.maxSize = NSMakeSize(REALLY_LARGE_NUMBER, REALLY_LARGE_NUMBER);
    self.textView.horizontallyResizable = YES;
    self.textView.verticallyResizable = YES;
    self.textView.autoresizingMask = NSViewNotSizable;
}

/**
 * This selects the specified character in the document.
 */
- (void)goToCharacter:(NSInteger)charNum {
	[self goToRangeFrom:charNum toChar:charNum + 1];
}

/**
 * Main bottleneck for selecting ranges in our file.
 */
- (void)goToRangeFrom:(NSInteger)startCh toChar:(NSInteger)endCh {
	NSRange	theRange = { 0, 0 };

	theRange.location = startCh -1;
	theRange.length = endCh -startCh;
	
	if( startCh == 0 || startCh > self.textView.string.length )
		return;
	
	[self.textView scrollRangeToVisible: theRange];
    self.textView.selectedRange = theRange;
}

/**
 * Main bottleneck for our (very primitive and inefficient) undo implementation. 
 * This takes a copy of the previous state of the *entire text* and restores it.
 */
- (void)restoreText:(NSString *)textToRestore {
	[self.undoManager disableUndoRegistration];
	self.textView.string = textToRestore;
	[self.undoManager enableUndoRegistration];
}

/**
 * Indent the selected lines by one more level (i.e. one more tab).
 */
- (IBAction)indentSelection:(id)sender {
	[self.undoManager beginUndoGrouping];
	NSString*	prevText = [self.textView.textStorage.string copy];
	[self.undoManager registerUndoWithTarget: self selector: @selector(restoreText:) object: prevText];
	
	NSRange				selRange = self.textView.selectedRange,
						nuSelRange = selRange;
	NSUInteger			x;
	NSMutableString*	str = [self.textView.textStorage mutableString];
	
	// Unselect any trailing returns so we don't indent the next line after a full-line selection.
	if( selRange.length > 1 && ([str characterAtIndex: selRange.location +selRange.length -1] == '\n'
		|| [str characterAtIndex: selRange.location +selRange.length -1] == '\r') )
		selRange.length--;
	
	for( x = selRange.location +selRange.length -1; x >= selRange.location; x-- )
	{
		if( [str characterAtIndex: x] == '\n'
			|| [str characterAtIndex: x] == '\r' )
		{
			[str insertString: @"\t" atIndex: x+1];
			nuSelRange.length++;
		}
		
		if( x == 0 )
			break;
	}
	
	[str insertString: @"\t" atIndex: nuSelRange.location];
	nuSelRange.length++;
    self.textView.selectedRange = nuSelRange;
	[self.undoManager endUndoGrouping];
}

/**
 * Un-indent the selected lines by one level (i.e. remove one tab from each line's start).
 */
- (IBAction)unindentSelection:(id)sender {
	NSRange				selRange = self.textView.selectedRange,
						nuSelRange = selRange;
	NSUInteger			x, n;
	NSUInteger			lastIndex = selRange.location +selRange.length -1;
	NSMutableString*	str = [self.textView.textStorage mutableString];
	
	// Unselect any trailing returns so we don't indent the next line after a full-line selection.
	if( selRange.length > 1 && ([str characterAtIndex: selRange.location +selRange.length -1] == '\n'
		|| [str characterAtIndex: selRange.location +selRange.length -1] == '\r') )
		selRange.length--;
	
	if( selRange.length == 0 )
		return;
	
	[self.undoManager beginUndoGrouping];
	NSString*	prevText = [self.textView.textStorage.string copy];
	[self.undoManager registerUndoWithTarget: self selector: @selector(restoreText:) object: prevText];
		
	for( x = lastIndex; x >= selRange.location; x-- )
	{
		if( [str characterAtIndex: x] == '\n'
			|| [str characterAtIndex: x] == '\r' )
		{
			if( (x +1) <= lastIndex)
			{
				if( [str characterAtIndex: x+1] == '\t' )
				{
					[str deleteCharactersInRange: NSMakeRange(x+1,1)];
					nuSelRange.length--;
				}
				else
				{
					for( n = x+1; (n <= (x+4)) && (n <= lastIndex); n++ )
					{
						if( [str characterAtIndex: x+1] != ' ' )
							break;
						[str deleteCharactersInRange: NSMakeRange(x+1,1)];
						nuSelRange.length--;
					}
				}
			}
		}
		
		if( x == 0 )
			break;
	}
	
	if( [str characterAtIndex: nuSelRange.location] == '\t' )
	{
		[str deleteCharactersInRange: NSMakeRange(nuSelRange.location,1)];
		nuSelRange.length--;
	}
	else
	{
		for( n = 1; (n <= 4) && (n <= lastIndex); n++ )
		{
			if( [str characterAtIndex: nuSelRange.location] != ' ' )
				break;
			[str deleteCharactersInRange: NSMakeRange(nuSelRange.location,1)];
			nuSelRange.length--;
		}
	}
	
    self.textView.selectedRange = nuSelRange;
	[self.undoManager endUndoGrouping];
}

/**
 * Add a comment to the start of this line/remove an existing comment.
 */
- (IBAction)toggleCommentForSelection:(id)sender {
	NSRange				selRange = self.textView.selectedRange;
	NSUInteger			x;
	NSMutableString*	str = [self.textView.textStorage mutableString];
	
	if( selRange.length == 0 )
		selRange.length++;
	
	// Are we at the end of a line?
	if ([str characterAtIndex: selRange.location] == '\n' ||
			[str characterAtIndex: selRange.location] == '\r') 
	{
		if( selRange.location > 0 )
		{
			selRange.location--;
			selRange.length++;
		}
	}
	
	// Move the selection to the start of a line
	while( selRange.location > 0 )
	{
		if( [str characterAtIndex: selRange.location] == '\n'
			|| [str characterAtIndex: selRange.location] == '\r')
		{
			selRange.location++;
			selRange.length--;
			break;
		}
		selRange.location--;
		selRange.length++;
	}

	// Select up to the end of a line
	while ( (selRange.location +selRange.length) < str.length
				&& !([str characterAtIndex:selRange.location+selRange.length-1] == '\n' 
					|| [str characterAtIndex:selRange.location+selRange.length-1] == '\r') ) 
	{
		selRange.length++;
	}
	
	if (selRange.length == 0)
		return;
	
	[self.undoManager beginUndoGrouping];
	NSString*	prevText = [self.textView.textStorage.string copy];
	[self.undoManager registerUndoWithTarget: self selector: @selector(restoreText:) object: prevText];
	
	// Unselect any trailing returns so we don't comment the next line after a full-line selection.
	while( [str characterAtIndex: selRange.location +selRange.length -1] == '\n' || (
				[str characterAtIndex: selRange.location +selRange.length -1] == '\r'
				&& selRange.length > 0 ))
	{
		selRange.length--;
	}
	
	
	NSRange nuSelRange = selRange;
	
	NSString*	commentPrefix = self.syntaxDefinitionDictionary[@"OneLineCommentPrefix"];
	if( !commentPrefix || commentPrefix.length == 0 )
		commentPrefix = @"# ";
	NSInteger	commentPrefixLength = commentPrefix.length;
	NSString*	trimmedCommentPrefix = [commentPrefix stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	if( !trimmedCommentPrefix || trimmedCommentPrefix.length == 0 )	// Comments apparently *are* whitespace.
		trimmedCommentPrefix = commentPrefix;
	NSInteger	trimmedCommentPrefixLength = trimmedCommentPrefix.length;
	
	for( x = selRange.location +selRange.length -1; x >= selRange.location; x-- )
	{
		BOOL	hitEnd = (x == selRange.location);
		BOOL	hitLineBreak = [str characterAtIndex: x] == '\n' || [str characterAtIndex: x] == '\r';
		if( hitLineBreak || hitEnd )
		{
			NSUInteger	startOffs = x+1;
			if( hitEnd && !hitLineBreak )
				startOffs = x;
			NSInteger	possibleCommentLength = 0;
			if( commentPrefixLength <= (selRange.length +selRange.location -startOffs) )
				possibleCommentLength = commentPrefixLength;
			else if( trimmedCommentPrefixLength <= (selRange.length +selRange.location -startOffs) )
				possibleCommentLength = trimmedCommentPrefixLength;
			
			NSString	*	lineStart = [str substringWithRange: NSMakeRange( startOffs, possibleCommentLength )];
			BOOL			haveWhitespaceToo = [lineStart hasPrefix: commentPrefix];
			if( [lineStart hasPrefix: trimmedCommentPrefix] )
			{
				NSInteger	commentLength = haveWhitespaceToo ? commentPrefixLength : trimmedCommentPrefixLength;
				[str deleteCharactersInRange: NSMakeRange(startOffs, commentLength)];
				nuSelRange.length -= commentLength;
			}
			else
			{
				[str insertString: commentPrefix atIndex: startOffs];
				nuSelRange.length += commentPrefixLength;
			}
		}
		
		if( x == 0 )
			break;
	}
	self.textView.selectedRange = nuSelRange;
	[self.undoManager endUndoGrouping];
	
}

/**
 * Make sure check marks of the "Toggle auto syntax coloring" and "Maintain indentation" menu items are set up properly.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if( menuItem.action == @selector(toggleAutoSyntaxColoring:) ) {
        menuItem.state = self.autoSyntaxColoring;
		return YES;
	}
	else if( menuItem.action == @selector(toggleMaintainIndentation:) )
	{
        menuItem.state = self.maintainIndentation;
		return YES;
	}
	else
		return [super validateMenuItem: menuItem];
}

/**
 * IBAction to do a complete recolor of the whole friggin' document.
 * This is called once after the document's been loaded and leaves some
 * custom styles in the document which are used by recolorRange to properly
 * perform recoloring of parts.
 */
- (IBAction)recolorCompleteFile:(id)sender {
	NSRange	range = NSMakeRange( 0, self.textView.textStorage.length );
	[self recolorRange: range];
}

/**
 * Try to apply syntax coloring to the text in our text view. 
 * This overwrites any styles the text may have had before.
 * This function guarantees that it'll preserve the selection.
 * 
 * Note that the order in which the different things are colorized is
 * important. E.g. identifiers go first, followed by comments, since that
 * way colors are removed from identifiers inside a comment and replaced
 * with the comment color, etc. 
 * 
 * The range passed in here is special, and may not include partial
 * identifiers or the end of a comment. Make sure you include the entire
 * multi-line comment etc. or it'll lose color.
 */
- (void)recolorRange:(NSRange)range {
	if( self.syntaxColoringBusy )	// Prevent endless loop when recoloring's replacement of text causes processEditing to fire again.
		return;
	
	if( self.textView == nil || range.length == 0 )	// Don't like doing useless stuff.
		return;
	
	@try
	{
		self.syntaxColoringBusy = YES;
		if( [self.delegate respondsToSelector: @selector(textViewControllerWillStartSyntaxRecoloring:)] )
			[self.delegate textViewControllerWillStartSyntaxRecoloring: self];
		
		// Kludge fix for case where we sometimes exceed text length:ra
		NSInteger diff = self.textView.textStorage.length -(range.location +range.length);
		if( diff < 0 )
			range.length += diff;
				
		// Get the text we'll be working with:
		NSDictionary*				vStyles = self.defaultTextAttributes;
		NSMutableAttributedString*	vString = [[NSMutableAttributedString alloc] initWithString: [self.textView.textStorage.string substringWithRange: range] attributes: vStyles];
				
		// Load colors and fonts to use from preferences:
		// Load our dictionary which contains info on coloring this language:
		NSDictionary*				vSyntaxDefinition = self.syntaxDefinitionDictionary;
		NSEnumerator*				vComponentsEnny = [vSyntaxDefinition[@"Components"] objectEnumerator];
		
		if( vComponentsEnny == nil )	// No list of components to colorize?
		{
			// @finally takes care of cleaning up syntaxColoringBusy etc. here.
			return;
		}
		
		// Loop over all available components:
		NSDictionary*				vCurrComponent = nil;
		NSUserDefaults*				vPrefs = NSUserDefaults.standardUserDefaults;

		while( (vCurrComponent = [vComponentsEnny nextObject]) )
		{
			NSString*   vComponentType = vCurrComponent[@"Type"];
			NSString*   vComponentName = vCurrComponent[@"Name"];
			NSString*   vColorKeyName = [@"SyntaxColoring:Color:" stringByAppendingString: vComponentName];
			NSColor*	vColor = [[vPrefs arrayForKey: vColorKeyName] colorValue];
			
			if( !vColor )
				vColor = [vCurrComponent[@"Color"] colorValue];
			
			if( [vComponentType isEqualToString: @"BlockComment"] )
			{
				[self colorCommentsFrom: vCurrComponent[@"Start"]
						to: vCurrComponent[@"End"] inString: vString
						withColor: vColor andMode: vComponentName];
			}
			else if( [vComponentType isEqualToString: @"OneLineComment"] )
			{
				[self colorOneLineComment: vCurrComponent[@"Start"]
						inString: vString withColor: vColor andMode: vComponentName];
			}
			else if( [vComponentType isEqualToString: @"String"] )
			{
				[self colorStringsFrom: vCurrComponent[@"Start"]
						to: vCurrComponent[@"End"]
						inString: vString withColor: vColor andMode: vComponentName
						andEscapeChar: vCurrComponent[@"EscapeChar"]]; 
			}
			else if( [vComponentType isEqualToString: @"Tag"] )
			{
				[self colorTagFrom: vCurrComponent[@"Start"]
						to: vCurrComponent[@"End"] inString: vString
						withColor: vColor andMode: vComponentName
						exceptIfMode: vCurrComponent[@"IgnoredComponent"]];
			}
			else if( [vComponentType isEqualToString: @"Keywords"] )
			{
				NSArray* vIdents = vCurrComponent[@"Keywords"];
				if( !vIdents && [self.delegate respondsToSelector: @selector(userIdentifiersForKeywordModeName)] )
					vIdents = [self.delegate userIdentifiersForKeywordComponentName: vComponentName];
				if( !vIdents )
					vIdents = [NSUserDefaults.standardUserDefaults objectForKey: [@"SyntaxColoring:Keywords:" stringByAppendingString: vComponentName]];
				if( !vIdents && [vComponentName isEqualToString: @"UserIdentifiers"] )
					vIdents = [NSUserDefaults.standardUserDefaults objectForKey: TD_USER_DEFINED_IDENTIFIERS];
				if( vIdents )
				{
					NSCharacterSet*		vIdentCharset = nil;
					NSString*			vCurrIdent = nil;
					NSString*			vCsStr = vCurrComponent[@"Charset"];
					if( vCsStr )
						vIdentCharset = [NSCharacterSet characterSetWithCharactersInString: vCsStr];
					
					NSEnumerator*	vItty = [vIdents objectEnumerator];
					while( vCurrIdent = [vItty nextObject] )
						[self colorIdentifier: vCurrIdent inString: vString withColor: vColor
									andMode: vComponentName charset: vIdentCharset];
				}
			}
		}
		
		// Replace the range with our recolored part:
		[self.textView.textStorage replaceCharactersInRange: range withAttributedString: vString];
		[self.textView.textStorage fixFontAttributeInRange: range];	// Make sure Japanese etc. fallback fonts get applied.
	}
	@finally
	{
		if( [self.delegate respondsToSelector: @selector(textViewControllerDidFinishSyntaxRecoloring:)] )
			[self.delegate textViewControllerDidFinishSyntaxRecoloring: self];
		self.syntaxColoringBusy = NO;
		[self textView:self.textView willChangeSelectionFromCharacterRange:self.textView.selectedRange
      toCharacterRange:self.textView.selectedRange];
	}
}

/**
 * Delegate method called when our selection changes.
 * Updates our status display to indicate which characters are selected.
 */
- (NSRange)textView: (NSTextView *)theTextView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange
					toCharacterRange:(NSRange)newSelectedCharRange {
	NSUInteger		startCh = newSelectedCharRange.location,
					endCh = newSelectedCharRange.location +newSelectedCharRange.length;
	NSUInteger		lineNo = 0,
					lastLineStart = 0,
					x = 0;
	NSUInteger		startChLine = 0, endChLine = 0;
	unichar			lastBreakChar = 0;
	NSUInteger		lastBreakOffs = 0;

	// Calc line number:
	for( x = 0; (x < startCh) && (x < theTextView.string.length); x++ )
	{
		unichar		theCh = [theTextView.string characterAtIndex: x];
		switch( theCh )
		{
			case '\n':
				if( lastBreakOffs == (x-1) && lastBreakChar == '\r' )   // LF in CRLF sequence? Treat this as a single line break.
				{
					lastBreakOffs = 0;
					lastBreakChar = 0;
					continue;
				}
				// Else fall through!
				
			case '\r':
				lineNo++;
				lastLineStart = x +1;
				lastBreakOffs = x;
				lastBreakChar = theCh;
				break;
		}
	}
	
	startChLine = (newSelectedCharRange.location -lastLineStart);
	endChLine = (newSelectedCharRange.location -lastLineStart) +newSelectedCharRange.length;
	
	// Let delegate know what to display:
	if( [self.delegate respondsToSelector: @selector(selectionInTextViewController:changedToStartCharacter:endCharacter:inLine:startCharacterInDocument:endCharacterInDocument:)] )
		[self.delegate selectionInTextViewController: self
			changedToStartCharacter: startChLine endCharacter: endChLine
			inLine: lineNo startCharacterInDocument: startCh
			endCharacterInDocument: endCh];
	
	return newSelectedCharRange;
}

/**
 * Like nibName, this should return the name of the syntax definition file to use. 
 * Advanced users may use this to allow different coloring to take place depending on the file extension 
 * by returning different file names here.
 * 
 * Note that the ".plist" extension is automatically appended to the file name.
 * By default, this asks the delegate for a file name, and if that doesn't
 * provide one, it returns "SyntaxDefinition".
 */
- (NSString *)syntaxDefinitionFilename {
	NSString*	syntaxDefFN = nil;
	if( [self.delegate respondsToSelector: @selector(syntaxDefinitionFilenameForTextViewController:)] )
		syntaxDefFN = [self.delegate syntaxDefinitionFilenameForTextViewController: self];
	
	if( !syntaxDefFN )
		syntaxDefFN = @"SyntaxDefinition";
	
	return syntaxDefFN;
}

/**
 * This returns the syntax definition dictionary to use, which indicates what ranges of text to colorize. 
 * Advanced users may use this to allow different coloring to take place depending on the file extension by
 * returning different dictionaries here.
 * 
 * By default, this asks the delegate for a syntax definition dictionary, or if that doesn't provide one, 
 * reads a dictionary from the .plist file in Resources indicated by -syntaxDefinitionFilename.
 */
- (NSDictionary *)syntaxDefinitionDictionary {
	NSDictionary*	theDict = nil;
	
	if( [self.delegate respondsToSelector: @selector(syntaxDefinitionDictionaryForTextViewController:)] )
		theDict = [self.delegate syntaxDefinitionDictionaryForTextViewController: self];
	
	if( !theDict )
	{
		NSBundle*	theBundle = [self nibBundle];
		if( !theBundle )
			theBundle = [NSBundle bundleForClass:self.class];	// Usually the main bundle, but be nice to plugins.
		theDict = [NSDictionary dictionaryWithContentsOfFile: [theBundle pathForResource: [self syntaxDefinitionFilename] ofType: @"plist"]];
	}
	
	return theDict;
}

/**
 * Return the styles to use for the given mode/color. This calls upon the delegate to provide the styles, 
 * or if not, just set the color. This is also responsible for setting the TD_SYNTAX_COLORING_MODE_ATTR attribute
 * so we can extend a range for partial recoloring to color the full block comment or whatever which is being 
 * changed (in case the user types a sequence that would end that block comment or similar).
 */
- (NSDictionary *)textAttributesForComponentName:(NSString *)attr color: (NSColor *)col {
	NSDictionary*		vLocalStyles = [self.delegate respondsToSelector:@selector(textAttributesForComponentName:color:)] ? [self.delegate textAttributesForComponentName: attr color: col] : nil;
	NSMutableDictionary*vStyles = [self.defaultTextAttributes mutableCopy];
	if( vLocalStyles )
		[vStyles addEntriesFromDictionary: vLocalStyles];
	else
		vStyles[NSForegroundColorAttributeName] = col;
	
	// Make sure partial recoloring works:
	vStyles[TD_SYNTAX_COLORING_MODE_ATTR] = attr;
	
	return vStyles;
}

/**
 * Apply syntax coloring to all strings. 
 * This is basically the same code as used for multi-line comments, except that it ignores the end
 * character if it is preceded by a backslash.
 */
- (void)colorStringsFrom:(NSString *)startCh to:(NSString *)endCh inString:(NSMutableAttributedString *)s
							withColor:(NSColor *) col andMode:(NSString *)attr andEscapeChar:(NSString *)vStringEscapeCharacter {
	NS_DURING
		NSScanner*			vScanner = [NSScanner scannerWithString: s.string];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		BOOL				vIsEndChar = NO;
		unichar				vEscChar = '\\';
		BOOL				vDelegateHandlesProgress = [self.delegate respondsToSelector: @selector(textViewControllerProgressedWhileSyntaxRecoloring:)];
		
		if( vStringEscapeCharacter )
		{
			if( vStringEscapeCharacter.length != 0 )
				vEscChar = [vStringEscapeCharacter characterAtIndex: 0];
		}
		
		while( !vScanner.isAtEnd )
		{
			NSUInteger		vStartOffs,
                            vEndOffs;
			vIsEndChar = NO;
			
			if( vDelegateHandlesProgress )
				[self.delegate textViewControllerProgressedWhileSyntaxRecoloring: self];
			
			// Look for start of string:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = vScanner.scanLocation;
			if( ![vScanner scanString:startCh intoString:nil] )
				NS_VOIDRETURN;

			while( !vIsEndChar && !vScanner.isAtEnd )	// Loop until we find end-of-string marker or our text to color is finished:
			{
				[vScanner scanUpToString: endCh intoString: nil];
				if( (vStringEscapeCharacter.length == 0) || [s.string characterAtIndex: (vScanner.scanLocation -1)] != vEscChar )	// Backslash before the end marker? That means ignore the end marker.
					vIsEndChar = YES;	// A real one! Terminate loop.
				if( ![vScanner scanString:endCh intoString:nil] )	// But skip this char before that.
					return;
				
				if( vDelegateHandlesProgress )
					[self.delegate textViewControllerProgressedWhileSyntaxRecoloring: self];
			}
			
			vEndOffs = vScanner.scanLocation;
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
		}
	NS_HANDLER
		// Just ignore it, syntax coloring isn't that important.
	NS_ENDHANDLER
}


/**
 * Colorize block-comments in the text view.
 */
- (void)colorCommentsFrom:(NSString *)startCh to:(NSString *)endCh inString:(NSMutableAttributedString *)s
							withColor:(NSColor *)col andMode:(NSString *)attr {
	@try {
		NSScanner*			vScanner = [NSScanner scannerWithString: s.string];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		BOOL				vDelegateHandlesProgress = [self.delegate respondsToSelector: @selector(textViewControllerProgressedWhileSyntaxRecoloring:)];
		
		while( !vScanner.isAtEnd ) {
			NSUInteger		vStartOffs,
                            vEndOffs;
			
			// Look for start of multi-line comment:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = vScanner.scanLocation;
			if( ![vScanner scanString:startCh intoString:nil] )
				return;

			// Look for associated end-of-comment marker:
			[vScanner scanUpToString: endCh intoString: nil];
			if( ![vScanner scanString: endCh intoString: nil] )
				/**return*/;  // Don't exit. If user forgot trailing marker, indicate this by "bleeding" until end of string.
			vEndOffs = vScanner.scanLocation;
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
			
			if( vDelegateHandlesProgress )
				[self.delegate textViewControllerProgressedWhileSyntaxRecoloring: self];
		}
	}
	@catch( ... ) {
		// Just ignore it, syntax coloring isn't that important.
	}
}

/**
 * Colorize one-line-comments in the text view.
 */
- (void)colorOneLineComment:(NSString *)startCh inString:(NSMutableAttributedString *)s
				withColor:(NSColor *)col andMode:(NSString *)attr {
	@try {
		NSScanner*			vScanner = [NSScanner scannerWithString: s.string];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		BOOL				vDelegateHandlesProgress = [self.delegate respondsToSelector: @selector(textViewControllerProgressedWhileSyntaxRecoloring:)];
		
		while( !vScanner.isAtEnd )
		{
			NSUInteger		vStartOffs,
                            vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = vScanner.scanLocation;
			if( ![vScanner scanString:startCh intoString:nil] )
				return;

			// Look for associated line break:
			if( ![vScanner skipUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString: @"\n\r"]] )
				;
			
			vEndOffs = vScanner.scanLocation;
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
			
			if( vDelegateHandlesProgress )
				[self.delegate textViewControllerProgressedWhileSyntaxRecoloring: self];
		}
	}
	@catch( ... ) {
		// Just ignore it, syntax coloring isn't that important.
	}
}

/**
 * Colorize keywords in the text view.
 */
- (void)colorIdentifier:(NSString *)ident inString:(NSMutableAttributedString *)s
			withColor:(NSColor *)col andMode:(NSString *)attr charset:(NSCharacterSet *)cset {
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: s.string];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		NSUInteger			vStartOffs = 0;
		BOOL				vDelegateHandlesProgress = [self.delegate respondsToSelector: @selector(textViewControllerProgressedWhileSyntaxRecoloring:)];
		
		// Skip any leading whitespace chars, somehow NSScanner doesn't do that:
		if( cset )
		{
			while( vStartOffs < s.string.length )
			{
				if( [cset characterIsMember: [s.string characterAtIndex: vStartOffs]] )
					break;
				vStartOffs++;
			}
		}
		
        vScanner.scanLocation = vStartOffs;
		
		while( !vScanner.isAtEnd )
		{
			// Look for start of identifier:
			[vScanner scanUpToString: ident intoString: nil];
			vStartOffs = vScanner.scanLocation;
			if( ![vScanner scanString:ident intoString:nil] )
				return;
			
			if( vStartOffs > 0 )	// Check that we're not in the middle of an identifier:
			{
				// Alphanum character before identifier start?
				if( [cset characterIsMember: [s.string characterAtIndex: (vStartOffs -1)]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			if( (vStartOffs +ident.length +1) < s.length )
			{
				// Alphanum character following our identifier?
				if( [cset characterIsMember: [s.string characterAtIndex: (vStartOffs +ident.length)]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, ident.length )];
				
			if( vDelegateHandlesProgress )
				[self.delegate textViewControllerProgressedWhileSyntaxRecoloring: self];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}

/**
 * Colorize HTML tags or similar constructs in the text view.
 */
- (void)colorTagFrom:(NSString *)startCh to:(NSString *)endCh inString:(NSMutableAttributedString *)s
				withColor:(NSColor *)col andMode:(NSString *)attr exceptIfMode:(NSString *)ignoreAttr {
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: s.string];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		BOOL				vDelegateHandlesProgress = [self.delegate respondsToSelector: @selector(textViewControllerProgressedWhileSyntaxRecoloring:)];
		
		while( !vScanner.isAtEnd )
		{
			NSUInteger		vStartOffs,
                            vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = vScanner.scanLocation;
			if( vStartOffs >= s.length )
				return;
			NSString*   scMode = [s attributesAtIndex:vStartOffs effectiveRange: nil][TD_SYNTAX_COLORING_MODE_ATTR];
			if( ![vScanner scanString:startCh intoString:nil] )
				return;
			
			// If start lies in range of ignored style, don't colorize it:
			if( ignoreAttr != nil && [scMode isEqualToString: ignoreAttr] )
				continue;

			// Look for matching end marker:
			while( !vScanner.isAtEnd )
			{
				// Scan up to the next occurence of the terminating sequence:
				[vScanner scanUpToString: endCh intoString:nil];
				
				// Now, if the mode of the end marker is not the mode we were told to ignore,
				//  we're finished now and we can exit the inner loop:
				vEndOffs = vScanner.scanLocation;
				if( vEndOffs < s.length )
				{
					scMode = [s attributesAtIndex:vEndOffs effectiveRange: nil][TD_SYNTAX_COLORING_MODE_ATTR];
					[vScanner scanString: endCh intoString: nil];   // Also skip the terminating sequence.
					if( ignoreAttr == nil || ![scMode isEqualToString: ignoreAttr] )
						break;
				}
				
				// Otherwise we keep going, look for the next occurence of endCh and hope it isn't in that style.
			}
			
			vEndOffs = vScanner.scanLocation;
			
			if( vDelegateHandlesProgress )
				[self.delegate textViewControllerProgressedWhileSyntaxRecoloring: self];
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}

/**
 * Return the text attributes to use for the text in our text view.
 */
- (NSDictionary *)defaultTextAttributes {
	return @{NSFontAttributeName: [NSFont userFixedPitchFontOfSize: 10.0]};
}

/**
 * Put selection at top like Project Builder has it, so user sees it.
 * You can also override this and save/restore the selection for each document.
 */
- (NSRange)defaultSelectedRange {
	return NSMakeRange(0,0);
}

@end
