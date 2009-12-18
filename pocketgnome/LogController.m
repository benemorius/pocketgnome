//
//  LogController.m
//  Pocket Gnome
//
//  Created by benemorius on 12/17/09.
//  Copyright 2009 Savory Software, LLC. All rights reserved.
//

#import "LogController.h"


@implementation LogController

+ (NSString*) print:(int)type, ...
{
	va_list args;
	va_start(args, type);
	NSString* format = va_arg(args, NSString*);
	NSMutableString* output = [[NSMutableString alloc] initWithFormat:format arguments:args];
	va_end(args);
	
	
	
	switch(type)
	{
		case LOG_FUNCTION:
			if([[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"log_function"] boolValue])
			{
				output = [NSString stringWithFormat:@"%s %@", LOG_FUNCTION_S, output];
				return output;
			}
			break;
		default:
			return nil;
	}

	
	
	
	return nil;
}

@end