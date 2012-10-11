//
//  NSArray+Color.h
//  CocoaTADS
//
//  Created by Uli Kusterer on Mon Jun 02 2003.
//  Copyright (c) 2003 Uli Kusterer.
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
 * Methods to treat an NSArray with three/four elements as an RGB/RGBA color.
 * 
 * Useful for storing colors in NSUserDefaults and other Property Lists.
 * Note that this isn't quite the same as storing an NSData of the color, as
 * some colors can't be correctly represented in RGB, but this makes for more
 * readable property lists than NSData.
 * 
 * If we wanted to get fancy, we could use an NSDictionary instead and save
 * different color types in different ways.
 */
@interface NSArray (UKColor)

/**
 * Converts the color to an RGB color if needed, and then creates an array
 * with its red, green, blue and alpha components (in that order).
 */
+ (NSArray *)arrayWithColor:(NSColor *)col;

/**
 * Converts an NSArray with three (or four) NSValues into an RGB Color (plus alpha, if specified).
 */
- (NSColor *)colorValue;

@end
