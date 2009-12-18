//
//  LogController.h
//  Pocket Gnome
//
//  Created by benemorius on 12/17/09.
//  Copyright 2009 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define LOG_FUNCTION 1
#define LOG_FUNCTION_S "[function]"
#define LOG_DEV 2
#define LOG_DEV_S "[dev]"
#define LOG_DEV1 3
#define LOG_DEV1_S "[dev1]"
#define LOG_DEV2 4
#define LOG_DEV2_S "[dev2]"
#define LOG_TARGET_LOGIC 5
#define LOG_TARGET_LOGIC_S "[target logic]"
#define LOG_MOVEMENT_CORRECTION 6
#define LOG_MOVEMENT_CORRECTION_S "[movement correction]"

@interface LogController : NSObject {

}

+ (NSString*) print:(int)type, ...;

@end
