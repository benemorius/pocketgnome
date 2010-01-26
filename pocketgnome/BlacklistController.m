//
//  BlacklistController.m
//  Pocket Gnome
//
//  Created by Josh on 12/13/09.
//  Copyright 2009 Savory Software, LLC. All rights reserved.
//

#import "BlacklistController.h"

#import "WoWObject.h"
#import "Unit.h"

@interface BlacklistController (Internal)

@end

@implementation BlacklistController

- (id) init{
    self = [super init];
    if (self != nil) {
		_blacklist = [[NSMutableArray alloc] init];
		
    }
    return self;
}

- (void) dealloc{
	[_blacklist release];
    [super dealloc];
}

#pragma mark Blacklisting

// remove all instances of the object from the blacklist
- (void)removeFromBlacklist: (WoWObject*)obj
{
    NSMutableArray *blacklist = [NSMutableArray array];
	[blacklist addObjectsFromArray:_blacklist];
	
    for ( NSDictionary *unit in blacklist ) {
        if ( [[unit objectForKey: @"Object"] isEqualToObject: obj] ){
            log(LOG_BLACKLIST, @"Removing unit: %@", [unit objectForKey:@"Object"]);
            [_blacklist removeObject: unit];
		}
    }
}

// what is the blacklist count?
- (int)blacklistCount: (WoWObject*)obj {
	
	for ( NSDictionary *black in _blacklist ){
		if ( [black objectForKey: @"Object"] == obj ){
			return [[black objectForKey: @"Count"] intValue];
		}
	}
	
    return 0;
}

- (NSMutableArray*)blacklistedUnits
{
    NSMutableArray *blacklist = [NSMutableArray array];
    for(NSDictionary *dict in _blacklist)
    {
        if(![blacklist containsObject:[dict objectForKey: @"Object"]])
            [blacklist addObject:[dict objectForKey: @"Object"]];
    }
    return blacklist;
}

- (void)blacklistObject:(WoWObject*)obj forSeconds:(float)seconds{
	if(![obj isValid])
		return;

	int blackCount = [self blacklistCount:obj];
	
	if ( blackCount == 0) {
		log(LOG_BLACKLIST, @"Adding object %@", obj);
	}
	// object is already blacklisted! increase count
	else{
		log(LOG_BLACKLIST, @"Increasing count for object %@ to %d", obj, blackCount + 1);	
	}
	
	//[self removeFromBlacklist:obj];
	
	// update our object in our dictionary
	blackCount++;
	[_blacklist addObject: [NSDictionary dictionaryWithObjectsAndKeys: 
							obj,										@"Object",
							[NSDate date],								@"Date",
                            [NSNumber numberWithFloat:seconds],         @"Expire",
							[NSNumber numberWithInt: blackCount],       @"Count", nil]];
}

// remove old objects from the blacklist
- (void)refreshBlacklist{
	
	if ( [_blacklist count] ){
		NSMutableArray *blacklist = [NSMutableArray array];
		[blacklist addObjectsFromArray:_blacklist];
		
		for ( NSDictionary *unit in blacklist ){
			
			WoWObject *obj = [unit objectForKey: @"Object"];
			
			float timeSinceBlacklisted = [[unit objectForKey: @"Date"] timeIntervalSinceNow] * -1.0f;
			
			if ( timeSinceBlacklisted > [[unit objectForKey:@"Expire"] floatValue] ){
				[self removeFromBlacklist:obj];
				log(LOG_BLACKLIST, @"Removing object %@ from blacklist after %0.0f seconds", obj, [[unit objectForKey:@"Expire"] floatValue]);
			}
			
			// mob/player checks
			//if ( [obj isNPC] || [obj isPlayer] ){
			//	if(![obj isValid])
			//	{
			//		[self removeFromBlacklist:obj];
			//		log(LOG_BLACKLIST, @"Removing object %@ from blacklist for being dead(%d) or invalid(%d)", obj, [(Unit*)obj isDead], ![obj isValid]);
			//	}
			//}
		}
	}
}

- (BOOL)isBlacklisted: (WoWObject*)obj {
	
	// refresh the blacklist (we could do this on a timer to be more "efficient"
	[self refreshBlacklist];
	
    int blackCount = [self blacklistCount: obj];
    if ( blackCount == 0 )  return NO;
    if ( blackCount >= 3 )  return YES;
    
    // check the time on the blacklist
	for ( NSDictionary *black in _blacklist ){
		WoWObject *blObj = [black objectForKey: @"Object"];
		
		if ( blObj == obj ){
			int count = [[black objectForKey: @"Count"] intValue];
			if ( count < 1 ) count = 1;
			
			//log(LOG_BLACKLIST, @"%0.2f > %0.2f", [[black objectForKey: @"Date"] timeIntervalSinceNow]*-1.0, (15.0*count) );
			
			if ( [[black objectForKey: @"Date"] timeIntervalSinceNow]*-1.0 > (15.0*count) ) 
				return NO;
		}		
	}
    return YES;
}

- (void)removeAllUnits{
	log(LOG_BLACKLIST, @"Removing all units...");
    [_blacklist release];
    _blacklist = [[NSMutableArray alloc] init];
}

@end
