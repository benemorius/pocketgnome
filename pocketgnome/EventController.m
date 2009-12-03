//
//  EventController.m
//  Pocket Gnome
//
//  Created by Josh on 11/23/09.
//  Copyright 2009 Savory Software, LLC. All rights reserved.
//

#import "EventController.h"
#import "Controller.h"
#import "PlayerDataController.h"

#import "Player.h"
#import "MemoryAccess.h"

@interface EventController (Internal)

@end

@implementation EventController

- (id) init{
    self = [super init];
    if (self != nil) {
		
		_uberQuickTimer = nil;
		_lastPlayerZone = -1;
		_lastBGStatus = -1;
		
		// Notifications
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(playerIsValid:) 
													 name: PlayerIsValidNotification 
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(playerIsInvalid:) 
                                                     name: PlayerIsInvalidNotification 
                                                   object: nil];
		
		_fiveSecondTimer = [NSTimer scheduledTimerWithTimeInterval: 5.0f target: self selector: @selector(fiveSecondTimer:) userInfo: nil repeats: YES];
    }
    return self;
}

- (void) dealloc{
    [super dealloc];
}

#pragma mark Notifications

- (void)playerIsValid: (NSNotification*)not {
	_uberQuickTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1f target: self selector: @selector(uberQuickTimer:) userInfo: nil repeats: YES];
}

- (void)playerIsInvalid: (NSNotification*)not {
	[_uberQuickTimer invalidate]; _uberQuickTimer = nil;
}

#pragma mark Timers

- (void)fiveSecondTimer: (NSTimer*)timer {
	// invalidate timers!
	if ( ![controller isWoWOpen] ){
		[_uberQuickTimer invalidate]; _uberQuickTimer = nil;
	}
}

- (void)uberQuickTimer: (NSTimer*)timer {
	
	// check for a zone change!
	int currentZone = [playerController zone];
	if ( _lastPlayerZone != currentZone ){
		// only send notification if the zone had been set already!
		if ( _lastPlayerZone != -1 ){
			[[NSNotificationCenter defaultCenter] postNotificationName: EventZoneChanged object: [NSNumber numberWithInt:_lastPlayerZone]];
		}
	}
	
	int bgStatus = [playerController battlegroundStatus];
	if ( _lastBGStatus != bgStatus ){
		// only send notification if the zone had been set already!
		if ( _lastBGStatus != -1 ){
			[[NSNotificationCenter defaultCenter] postNotificationName: EventBattlegroundStatusChange object: [NSNumber numberWithInt:bgStatus]];
		}
		PGLog(@"[Events] BGStatus change from %d to %d", _lastBGStatus, bgStatus);
	}
	
	_lastBGStatus = bgStatus;
	_lastPlayerZone = currentZone;
}

@end
