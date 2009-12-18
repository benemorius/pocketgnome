//
//  LogController.h
//  Pocket Gnome
//
//  Created by benemorius on 12/17/09.
//  Copyright 2009 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#define log(...) if([LogController canLog:__VA_ARGS__]) PGLog(@"%@", [LogController log: __VA_ARGS__]);
//just for autocomplete and convenience really
#define LOG_FUNCTION "function"
#define LOG_DEV "dev"
#define LOG_DEV1 "dev1"
#define LOG_DEV2 "dev2"
#define LOG_TARGET "target"
#define LOG_MOVEMENT_CORRECTION "movement_correction"
#define LOG_MOVEMENT "movement"
#define LOG_RULE "rule"
#define LOG_CONDITION "condition"
#define LOG_BEHAVIOR "behavior"
#define LOG_LOOT "loot"
#define LOG_HEAL "heal"
#define LOG_COMBAT "combat"

@interface LogController : NSObject {

}

+ (BOOL) canLog:(char*)type_s, ...;
+ (NSString*) log:(char*)type_s, ...;

@end
