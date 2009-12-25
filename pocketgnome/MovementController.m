//
//  MovementController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/16/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import <Carbon/Carbon.h>

#import "MovementController.h"
#import "Controller.h"
#import "PlayerDataController.h"
#import "Position.h"
#import "MobController.h"
#import "BotController.h"
#import "CombatController.h"
#import "ChatController.h"
#import "OffsetController.h"
#import "AuraController.h"
#import "MacroController.h"
#import "BlacklistController.h"

#import "WoWObject.h"
#import "Offsets.h"

#import "Route.h"
#import "RouteSet.h"
#import "Waypoint.h"
#import "Action.h"
#import "Node.h"
#import "Player.h"

#define STUCK_THRESHOLD		5

@interface MovementController ()
@property (readwrite, retain) Waypoint *destination;
@property (readwrite, retain) Waypoint *lastTriedWaypoint;
@property (readwrite, retain) WoWObject *unit;
@property (readwrite, retain) NSDate *lastJumpTime;
@property (readwrite, retain) NSDate *lastDirectionCorrection;
@property (readwrite, retain) NSDate *movementExpiration;
@property (readwrite, retain) Position *lastSavedPosition;
@property (readwrite, retain) Position *lastPlayerPosition;
@property (readwrite, retain) Position *lastAttemptedPosition;
@property (readwrite, assign) int jumpCooldown;
@property (readwrite, assign) float lastDistance;
@property BOOL shouldAttack;
@property BOOL isPaused;
@property BOOL stopAtEnd;
@property BOOL shouldNotify;
@property int waypointDoneCount;
@property int lastInteraction;
@end

@interface MovementController (Internal)
- (void)moveToPosition: (Position*)position;

- (void)finishAlt;
- (void)finishRoute;
- (void)resetMovementTimer;
- (void)moveToNextWaypoint;
- (void)resetSpeedDistanceCheck;
- (void)checkCurrentPosition;
- (void)checkProximity;

- (void)turnToward: (Position*)position;

- (void)moveBackwardStart;

- (void)correctDirection: (BOOL)force;

- (Waypoint*)closestWaypoint;
- (void)checkSpeedDistance: (Position*)timer;

- (BOOL)isCTMActive;

- (void)moveUpStart;
- (void)moveUpStop;
- (void)unstick;
@end

@implementation MovementController

+ (void)initialize {
    NSDictionary *defaultValues = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithBool: YES],  @"MovementShouldJump",
                                   [NSNumber numberWithInt: 2],     @"MovementMinJumpTime",
                                   [NSNumber numberWithInt: 6],     @"MovementMaxJumpTime",
                                   nil];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultValues];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues: defaultValues];
}

- (id) init
{
    self = [super init];
    if (self != nil) {
        self.isMoving = NO;
        self.isPaused = NO;
        _route = nil;
        self.jumpCooldown = 3;
        self.lastJumpTime = [NSDate distantPast];
        self.lastDirectionCorrection = [NSDate distantPast];
        self.lastSavedPosition = nil;
		self.lastPlayerPosition = nil;
		self.lastAttemptedPosition = nil;
		self.lastTriedWaypoint = nil;
		_isStuck = 0;
		_unstickAttempt = 0;
		_successfulMoves = 0;
		self.lastTriedWaypoint = nil;
		_lastResumeCorrection = [[NSDate date] retain];

        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(applicationWillTerminate:) name: NSApplicationWillTerminateNotification object: nil];
    }
    return self;
}

- (void)awakeFromNib {
    self.shouldJump = [[[NSUserDefaults standardUserDefaults] objectForKey: @"MovementShouldJump"] boolValue];
}

@synthesize isMoving = _isMoving;
@synthesize isPatrolling = _isPatrolling;
@synthesize destination = _destination;
@synthesize unit = _unit;
@synthesize lastTriedWaypoint = _lastTriedWaypoint;

@synthesize shouldJump = _shouldJump;
@synthesize lastJumpTime = _lastJumpTime;
@synthesize jumpCooldown = _jumpCooldown;
@synthesize lastDistance = _lastDistance;

@synthesize lastDirectionCorrection = _lastDirectionCorrection;
@synthesize shouldAttack = _shouldAttack;
@synthesize isPaused = _isPaused;
@synthesize lastSavedPosition;
@synthesize lastPlayerPosition;
@synthesize lastAttemptedPosition;
@synthesize movementExpiration;
@synthesize waypointDoneCount = _waypointDoneCount;
@synthesize stopAtEnd = _stopAtEnd;
@synthesize lastInteraction = _lastInteraction;
@synthesize averageSpeed = _averageSpeed;
@synthesize averageDistance = _averageDistance;

@synthesize shouldNotify = _notifyForObjectMove;

- (int)movementType{
	return [movementType selectedTag];
}

typedef enum MovementType {
	MOVE_MOUSE = 0,
	MOVE_KEYBOARD = 1,
	MOVE_CTM = 2	
} MovementType;

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if( [playerData playerIsValid:self] ) {
        [self resetMovementState];
    }
}

- (void)pauseMovement {
    
    // stop timers
    [self resetMovementTimer];
	[self resetSpeedDistanceCheck];
    
    if(!self.isPaused || (([playerData movementFlags] & 0x1) == 0x1)) {
        // stop movement if we haven't already
        log(LOG_MOVEMENT, @"Pause movement.");
		
		[self moveForwardStop];
        
        self.isPaused = YES;
        usleep(100000);
    }
}

- (BOOL)shouldResume {
    
    if(self.isPaused || (([playerData movementFlags] & 0x1) == 0x0)) {
		
        if(self.unit)
		{
			log(LOG_MOVEMENT, @"Resume unit movement: %@", self.unit);
		}
        else{
			Position *playerPosition = [playerData position];
			float distance = [playerPosition distanceToPosition:[self.destination position]];
            log(LOG_MOVEMENT, @"Resume waypoint movement: %@ Distance: %0.2f", self.destination, distance );
			
			// Umm I don't like this, search for a new waypoint?
			if ( distance > 200.0f ){
				
				Waypoint *closestWaypoint = [self closestWaypoint];
				float newDistance = [playerPosition distanceToPosition:[closestWaypoint position]];
				
				log(LOG_MOVEMENT, @"Searching for closer wp! %@, %0.2f route: %@", closestWaypoint, newDistance, _route);
				
				if ( newDistance < distance ){
					self.destination = closestWaypoint;
					log(LOG_MOVEMENT, @"Found a closer waypoint! Using %@, %0.2f away!", closestWaypoint, newDistance);
				}
			}
		}
        
        self.isPaused = NO;
        return YES;
    }
    return NO;
}

- (void)resumeMovement {
	if ( _isStuck > STUCK_THRESHOLD ){
		log(LOG_MOVEMENT, @"NOT resumeMovement");
		return;		
	}
	
    if([self shouldResume]) {
		log(LOG_MOVEMENT, @"resumeMovement");
        // if we were moving to a unit, go there
        // otherwise, resume to the next waypoint
        [self moveToPosition: (self.unit ? [self.unit position] : [[self destination] position])];
    }
}

- (void)resumeMovementToNearestWaypoint {
	if ( _isStuck > STUCK_THRESHOLD ){
		log(LOG_MOVEMENT, @"NOT resumeMovementToNearestWaypoint");
		return;		
	}
	
    if([self shouldResume]) {
		log(LOG_MOVEMENT, @"resumeMovementToNearestWaypoint");

		if ( self.unit ){
			Position *position = [self.unit position];
			if ( ![self isCTMActive] ){
				[self moveToPosition:position];
			}
		}
		else {
			Position *playerPosition = [playerData position];
			Waypoint *waypoint = [[self patrolRoute] waypointClosestToPosition: playerPosition];
			
			int newIndex = [[[self patrolRoute] waypoints] indexOfObject: waypoint];
			int oldIndex = [[[self patrolRoute] waypoints] indexOfObject: [self destination]];
			
			if(newIndex > oldIndex && (newIndex < (oldIndex + 10))) {
				log(LOG_MOVEMENT, @"Found new, closer waypoint.");
				[self moveToWaypoint: waypoint];
			} else {
				[self moveToWaypoint: [self destination]];
			}
		}
    }
}

- (WoWObject*)moveToObject {
    return self.unit;
}

- (void)finishMovingToObject:(WoWObject*)unit {
    if(self.unit == unit) {
        self.unit = nil;
        self.shouldNotify = NO;
        log(LOG_MOVEMENT, @"Finishing movement to %@", unit);
    }
}


#pragma mark -

- (void)beginPatrol: (unsigned)count andAttack: (BOOL)attack {
    Route *route = [self patrolRoute];
    if( !route ) return;

    if( [route waypointCount] > 0 ) {
        [combatController setCombatEnabled: attack];
        [self setIsPatrolling: YES];
        _patrolCount = count;
        self.shouldAttack = attack;
        
        // determine at which waypoint to start the patrol
        Waypoint *startWaypoint = [self closestWaypoint];
        
        // reset jump timer and head to the WP
        if(startWaypoint) {
            log(LOG_MOVEMENT, @"Doing route: %@.", route);
            self.lastJumpTime = [NSDate date];
            [self moveToWaypoint: startWaypoint];
        } else {
            log(LOG_MOVEMENT, @"StartWaypoint was nil. Ending route %@", route);
            [self resetMovementState];
            return;
        }
    } else {
        log(LOG_MOVEMENT, @"%@ has no waypoints. Ending route.", route);
        [self resetMovementState];
        return;
    }
}

- (Waypoint*)closestWaypoint{
	Waypoint *startWaypoint = nil;
	Position *playerPosition = [playerData position];
	float minDist = INFINITY, tempDist;
	for(Waypoint *waypoint in [[self patrolRoute] waypoints]) {
		tempDist = [playerPosition distanceToPosition: [waypoint position]];
		if( (tempDist < minDist) && (tempDist >= 0.0f)) {
			minDist = tempDist;
			startWaypoint = waypoint;
		}
	}
	
	return startWaypoint;
}

- (void)beginPatrolAndStopAtLastPoint {
    self.stopAtEnd = YES;
    [self beginPatrol: 1 andAttack: NO];
}

- (Route*)patrolRoute {
    return [[_route retain] autorelease];
}

- (void)setPatrolRoute: (Route*)route {
    [self resetMovementState];
    [_route autorelease];
    _route = [route retain];
    
    if(!_route) [combatController setCombatEnabled: NO];
}

- (void)moveToPosition: (Position*)position {
    [self resetMovementTimer];
	
    Position *playerPosition = [playerData position];
    float distance = [playerPosition distanceToPosition: position];
	self.lastDistance = 0;
	
	//PGLog(@"[Move] Want to move %0.2f yards to %@", distance, position);

    if(!position || distance == INFINITY) { // sanity check
        log(LOG_MOVEMENT, @"Invalid waypoint (distance: %f). Ending patrol.", distance);
        if(self.unit)   [self finishAlt];
        else            [self finishRoute];
        return;
    }
    
    if(!self.unit && (distance < ([playerData speedMax]/2.0f))) {
        log(LOG_MOVEMENT, @"Waypoint is too close. Moving to the next one.");
        [self moveToNextWaypoint];
        return;
    }
	
	// BEGIN - new stuck check
	NSString *checkPosition = @"";
	
	// Only reset our timer if the position is different!
	if ( ![self.lastAttemptedPosition isEqual:position] ){
		
		// Remove the check that is going on!
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(checkSpeedDistance:) object: self.lastAttemptedPosition];
		
		self.lastPlayerPosition = playerPosition;
		_movementChecks = 0; _totalMovementSpeed = 0.0f; _totalDistance = 0.0f;	_isStuck = 0; 
		[self performSelector:@selector(checkSpeedDistance:) withObject:position afterDelay:0.1f];
		
		log(LOG_MOVEMENT, @"Checking speed/distance %@  %@", self.lastAttemptedPosition, position);
		[checkPosition release];
		checkPosition = [NSString stringWithFormat:@"[] Last attempt %@", self.lastAttemptedPosition];
	}
	self.lastAttemptedPosition = position;
	
	// END - new stuck check
	
	log(LOG_MOVEMENT, @"Moving to %@ %@", position, checkPosition);

    self.lastSavedPosition = playerPosition;
    self.lastDirectionCorrection = [NSDate date];
    self.movementExpiration = [NSDate dateWithTimeIntervalSinceNow: (distance/[playerData speedMax]) + 4.0];
    
	if ( [movementType selectedTag] == MOVE_MOUSE ){
		//PGLog(@"[Move] Stopping forward movement, refacing, then restarting");
		[self moveForwardStop];
		[self correctDirection: YES];
		//PGLog(@"[Move] Moving forward");
		[self moveForwardStart];
	}
	else if ( [movementType selectedTag] == MOVE_KEYBOARD ){
        if(!self.isMoving)  [self moveForwardStop];
        [self correctDirection: YES];
        if(!self.isMoving)  [self moveForwardStart];
    } else {
		[self setClickToMove:position andType:ctmWalkTo andGUID:0];
    }
	
    _movementTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5 target: self selector: @selector(checkCurrentPosition:) userInfo: nil repeats: YES];
    _proximityTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05 target: self selector: @selector(checkProximity:) userInfo: nil repeats: YES];
}

// Basically it just checks our speed over time to see if we're actually moving toward our target
- (void)checkSpeedDistance: (Position*)position {
	
	// Then we should stop checking :(
	if ( ![self.lastAttemptedPosition isEqual:position] || ![botController isBotting]){
		return;
	}
	
	Position *playerPosition = [playerData position];
	_movementChecks++;
	
	// Speed check (doesn't always work - i.e. auto running against a wall)
	_totalMovementSpeed += [playerData speed];
	self.averageSpeed = _totalMovementSpeed/(float)_movementChecks;

	// Distance check (to account for running against a wall!)
	_totalDistance += [playerPosition distanceToPosition: self.lastPlayerPosition];
	self.averageDistance = _totalDistance/(float)_movementChecks;
	self.lastPlayerPosition = playerPosition;
	
	// Take a sample of our speed over a second or longer
	if ( _movementChecks > 15 && self.averageSpeed <= 1.0f ){
		log(LOG_MOVEMENT_CORRECTION, @"We're stuck! Found by speed check! %0.2f", self.averageSpeed);
		_isStuck++;
	}
	
	// Check the distance moved!
	if ( _movementChecks > 15 && self.averageDistance < 0.25f ){
		log(LOG_MOVEMENT_CORRECTION, @"We're stuck! Found by distance check! %0.2f", self.averageDistance);
		_isStuck++;
	}
	
	// check to see if we're flying off into space?
	float distance = [self.lastAttemptedPosition distanceToPosition:playerPosition];
	if ( distance > 250.0f ){
		
		
		float horizontalAngleToward = [playerPosition angleTo:self.lastAttemptedPosition];
		float directionFacing = [playerData directionFacing];
		
		//[self setHorizontalDirectionFacing: [ourPosition angleTo: position]];
        //[self setVerticalDirectionFacing: [ourPosition verticalAngleTo: position]];
		
		log(LOG_MOVEMENT_CORRECTION, @"Too far away for my liking! %0.2f == %0.2f near %0.2f %0.2f", distance, horizontalAngleToward, directionFacing, [[NSDate date] timeIntervalSinceDate:_lastResumeCorrection] );
		
		float difference = fabs(horizontalAngleToward - directionFacing);
		
		// then we have a problem + need to start going back to our waypoint!
		if ( difference > 0.1f && ( [[NSDate date] timeIntervalSinceDate:_lastResumeCorrection] > 15.0f )){
			[_lastResumeCorrection release]; _lastResumeCorrection = nil;
			_lastResumeCorrection = [[NSDate date] retain];
			
			log(LOG_MOVEMENT_CORRECTION, @"Flying in the wrong direction, correcting");
			
			[self moveUpStop];
			
			[self moveForwardStop];
			usleep(10000);
			[self resumeMovement];
		}
	}
	
	// Crap we're stuck, we need to do something now :(
	if ( _isStuck > STUCK_THRESHOLD ){
		log(LOG_MOVEMENT_CORRECTION, @"Stuck after %d checks, attempting to unstick!", _movementChecks);
		[controller setCurrentStatus: @"Bot: Stuck, attempting to un-stick ourselves"];
		[self unstick];
		return;
	}
	
	//log(LOG_MOVEMENT, @"%d   Speed: %0.2f   Distance:  %0.2f", _movementChecks, averageSpeed, averageDistance);
	
	[self performSelector:_cmd withObject:position afterDelay:0.1f];
}

// This function will try to unstick us!
- (void)unstick{
	_successfulMoves = 0;	// clearly if we're stuck the next move won't be considered a success :(  reset our counter
	_isStuck = 0;_movementChecks = 0;	// reset these so we're able to continue check if we're stuck!

	if (self.unit) { 
		log(LOG_MOVEMENT, @"... Unable to reach unit %@; Blacklisting and resuming route.", self.unit);
		
		// Blacklist the unit for a bit since we can't get to it :(
		[blacklistController blacklistObject:self.unit];
		
		self.unit = nil;
		
		[botController evaluateSituation];		// we either want to do this or resume to the next WP, not sure which, will test this out :-)
		//[self resumeMovementToNearestWaypoint];
		//[self finishAlt];
	} else {
		
		// What waypoint did we try last?
		if ( self.lastTriedWaypoint == nil ){
			self.lastTriedWaypoint = self.destination;
		}
		
		// move to the previous waypoint and try this again
		NSArray *waypoints = [[self patrolRoute] waypoints];
		int index = [waypoints indexOfObject: self.lastTriedWaypoint];
		if(index != NSNotFound) {
			if(index == 0) {
				index = [waypoints count];
			}
			_unstickAttempt++;
			
			// Should we play an alarm?
			if ( [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"AlarmOnStuck"] boolValue] ){
				int stuckThreshold = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"AlarmOnStuckAttempts"] intValue];
				if ( _unstickAttempt > stuckThreshold ){
					log(LOG_GENERAL, @"We're stuck, playing an alarm!");
					[[NSSound soundNamed: @"alarm"] play];
				}
			}
			
			// Check to see if we should log out!
			if ( [[botController logOutAfterStuckCheckbox] state] ){
				int stuckTries = [logOutStuckAttemptsTextField intValue];
				
				if ( _unstickAttempt > stuckTries ){
					log(LOG_GENERAL, @"We're stuck, closing wow!");
					[botController logOut];
					[controller setCurrentStatus: @"Bot: Logged out due to being stuck"];
					return;
				}
			}
			
			log(LOG_MOVEMENT, @"... Moving to prevous waypoint, attempt %d", _unstickAttempt);
			[self moveToWaypoint: [waypoints objectAtIndex: index-1]];
			self.lastTriedWaypoint = [waypoints objectAtIndex: index-1];
		} else {
			[self finishRoute];
		}
	}
}

- (void)resetSpeedDistanceCheck{
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(checkSpeedDistance:) object: self.lastAttemptedPosition];
	self.lastAttemptedPosition = nil;
}

- (void)moveToWaypoint: (Waypoint*)waypoint {
	if ( _isStuck > STUCK_THRESHOLD ){
		log(LOG_MOVEMENT, @"NOT moveToWaypoint %@", waypoint);
		return;		
	}
	
    [self setDestination: waypoint];
    [self moveToPosition: [waypoint position]];
	
	log(LOG_MOVEMENT, @"Moving to %@", waypoint );
}

- (void)moveNearPosition: (Position*)position andCloseness: (float)closeness{
	[self setClickToMove:position andType:ctmWalkTo andGUID:0];
}

- (void)moveToObject: (WoWObject*)unit andNotify: (BOOL)notify {
    //if(self.unit == unit) {
    //    return;
    //}
	if ( _isStuck > STUCK_THRESHOLD ){
		log(LOG_MOVEMENT, @"NOT moveToObject %@", unit);
		return;		
	}
    
    if(unit && [unit isValid] && [unit conformsToProtocol: @protocol(UnitPosition)]) {		
        if( ![self.unit isEqualToObject: unit]) {
            log(LOG_MOVEMENT, @"Moving to: %@", unit);
			
			self.unit = unit;
            self.shouldNotify = notify;

			Position *position = [unit position];
			[self moveToPosition: position];
        } else {
            [self resumeMovement];
        }
    } else {
        log(LOG_MOVEMENT, @"Cannot move to invalid unit %@ (%d)", self.unit, notify);
        self.unit = nil;
        self.shouldNotify = NO;
		
		[self resumeMovement];
    }
}

- (void)resetUnit{
	self.unit = nil;
	self.shouldNotify = NO;
}

- (void)establishPosition {
	log(LOG_MOVEMENT, @"establishPosition");
	
    [self moveForwardStart];
    usleep(100000);
    [self moveForwardStop];
    usleep(30000);
}

- (void)backEstablishPosition {
	log(LOG_MOVEMENT, @"backEstablishPosition");
	
    [self moveBackwardStart];
    usleep(100000);
    [self moveBackwardStop];
    usleep(30000);
}

#pragma mark -
#pragma mark Internal

- (void)finishAlt {
    id unit = self.unit;
    BOOL notify = self.shouldNotify;
    //[self moveForwardStop];
    [self resetMovementTimer];
	//[self resetSpeedDistanceCheck];
    [self finishMovingToObject: unit];
    
    log(LOG_MOVEMENT, @"finishAlt: %@", unit);
    
    if(notify)
        [botController reachedUnit: unit];
}

- (void)finishRoute {
    Route *finishedRoute = [self patrolRoute];
    // stop our movement
    [self resetMovementState];
    
    log(LOG_MOVEMENT, @"Finished Route: %@", finishedRoute);
    
    // send route finished notification
    [botController finishedRoute: finishedRoute];
}


- (void)realMoveToNextWaypoint {
	// This will reset our "last tried waypoint" variable.  This variable is used to store the last waypoint we tried to move to when we're stuck!
	//  we only want to reset it once we're moving through our route correctly!
	_successfulMoves++;
	if ( _successfulMoves > 10 ){
		self.lastTriedWaypoint = nil;
		_unstickAttempt = 0;
	}
	
    NSArray *waypoints = [[self patrolRoute] waypoints];
    if([self isPatrolling] && [self patrolRoute] && [waypoints count]) {
        
        int index = [waypoints indexOfObject: [self destination]];
        if(index != NSNotFound) {
            
            if(index == [waypoints count]-1) {   // if we're at the end, loop around
                if(self.stopAtEnd) {
                    [self finishRoute];
                    return;
                }
                index = 0;
            } else if(index < [[[self patrolRoute] waypoints] count]-1)
                index++;
            
            self.waypointDoneCount++;
            // check to see if we've hit our max WP
            if(_patrolCount && (self.waypointDoneCount > _patrolCount*[waypoints count]))   {
                log(LOG_MOVEMENT, @"Patrol count expired. Ending patrol.");
                [self finishRoute];
            } else {
                [self moveToWaypoint: [waypoints objectAtIndex: index]];
            }
        } else {
            log(LOG_MOVEMENT, @"Waypoint not found. Ending route.");
            [self finishRoute];
        }
    } else {
        // otherwise just cancel all movement
        log(LOG_MOVEMENT, @"Patrol route or waypoints invalid. Ending patrol.");
        [self finishRoute];
    }

}

- (void)moveToNextWaypoint {
	if( [[self destination] action].type != ActionType_Interact ) {
		self.lastInteraction = -1;
	}
    // check for waypoint-initiated actions
	log(LOG_MOVEMENT, @"Performing type %d at waypoint %d.", [[self destination] action].type, [[[self patrolRoute] waypoints] indexOfObject: [self destination]]);
	
	// NO ACTION
	if( [[self destination] action].type == ActionType_None ) {
        [self realMoveToNextWaypoint];
		return;
		
	
	}
	// delay
	else if( [[self destination] action].type == ActionType_Delay ) {
        log(LOG_MOVEMENT, @"Performing %.2f second delay at waypoint %d.", [[self destination] action].delay, [[[self patrolRoute] waypoints] indexOfObject: [self destination]]);
        [self pauseMovement];
        [self performSelector: @selector(realMoveToNextWaypoint)
                   withObject: nil
                   afterDelay: [[[self destination] action] delay]];
        return;
		
	}
	// interaction
	else if( [[self destination] action].type == ActionType_Interact ) {

		// Stop moving
		[self pauseMovement];
		log(LOG_MOVEMENT, @"Performing interaction %d at waypoint %d.", self.lastInteraction, [[[self patrolRoute] waypoints] indexOfObject: [self destination]]);
		NSNumber *n = [[self destination] action].value;
		
		// Lets interact w/the target!
		[botController interactWithMob:[n unsignedIntValue]];
		
		usleep(100000);
		// Also call interact w/node, not sure which it is unfortunately - lazy to do it otherwise heh
		[botController interactWithNode:[n unsignedIntValue]];

		[self performSelector: @selector(realMoveToNextWaypoint)
				   withObject: nil
				   afterDelay: 2.0];

  		return;
    }
	else if ( [[self destination] action].type == ActionType_Jump ) {
		// send escape to close chat box if it's open!
		if ( [controller isWoWChatBoxOpen] ){
			log(LOG_MACRO, @"Sending escape!");
			[chatController sendKeySequence: [NSString stringWithFormat: @"%c", kEscapeCharCode]];
			usleep(100000);
		}
		
		[chatController jump];
		log(LOG_MOVEMENT, @"Jumping at waypoint %d", [[[self patrolRoute] waypoints] indexOfObject: [self destination]]);
		
		[self performSelector: @selector(realMoveToNextWaypoint)
				   withObject: nil
				   afterDelay: 0.1f];
		
		return;
	}
	
	// use an item/macro/spell
	else{
		
		// Stop moving
		[self pauseMovement];
        log(LOG_MOVEMENT, @"Performing action %d at waypoint %d.", [[self destination] action].actionID, [[[self patrolRoute] waypoints] indexOfObject: [self destination]]);
		
		int32_t actionID = [[self destination] action].actionID;
		//		 BOOL canPerformAction = YES;
		switch([[self destination] action].type) {
			case ActionType_Item: 
				actionID = (USE_ITEM_MASK + actionID);
				break;
			case ActionType_Macro:
				actionID = (USE_MACRO_MASK + actionID);
				break;
			// We don't need to do anything here since we don't need a mask for a spell!
			case ActionType_Spell:
				//				canPerformAction = [spellController canCastSpellWithID: [NSNumber numberWithUnsignedInt: actionID]];
				break;
			default:
				break;
		}
		[botController performAction:actionID];
		
		[self performSelector: @selector(realMoveToNextWaypoint)
				   withObject: nil
				   afterDelay: 2.0];
        return;
    }
}

- (void)jump {
    // correct direction
    [self correctDirection: YES];
    
    // update variables
    self.lastJumpTime = [NSDate date];
    int min = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"MovementMinJumpTime"] intValue];
    int max = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"MovementMaxJumpTime"] intValue];
    self.jumpCooldown = SSRandomIntBetween(min, max);
    log(LOG_MOVEMENT, @"Set jump cooldown to %d (between %d, and %d)", self.jumpCooldown, min, max);
    
    // jump!
    if(![controller isWoWChatBoxOpen]) {
        [chatController jump];
    }
}

- (void)checkProximity: (NSTimer*)timer {
	//this is a streamlined remake of checkCurrentPosition
	//intended to maintain efficienty while allowing high callback rates
	//it will call checkCurrentPosition when destination is in range

	//PGLog(@"checkproximity"); //don't forget this fires at 50hz
	
    Position *playerPosition = [playerData position];
    Position *destPosition = (self.unit) ? [self.unit position] : [[self destination] position];
	
    float distance = [playerData isOnGround] ? [playerPosition distanceToPosition2D: destPosition] : [playerPosition distanceToPosition: destPosition];
	
	// if we're near our target, move to the next
    //float playerSpeed = [playerData speed];
    //if(distance2d < playerSpeed/2.0)  {
	float distanceToUnit = WAYPOINT_SENSITIVITY;
	
	// ideally for nodes we'd also want to check the 2D distance so we drop RIGHT on the node
	if (self.unit)
	{
        if([self.unit isKindOfClass: [Node class]])
            distanceToUnit = NODE_DISTANCE_UNTIL_DISMOUNT;
        else
            distanceToUnit = UNIT_DISTANCE;
	}
	// We're close enough to take action or move to the next waypoint!
	if( distance <= distanceToUnit )  {
		if(self.unit)
			[self moveForwardStop];
		[self checkCurrentPosition];
	}
}

- (void)checkCurrentPosition: (NSTimer*)timer {
	if ( ![botController isBotting] ) return;
	
	if ( _isStuck > STUCK_THRESHOLD ){
		log(LOG_MOVEMENT_CORRECTION, @"NOT checkCurrentPosition %@", timer);
		return;		
	}
	
	log(LOG_MOVEMENT_CORRECTION, @"checkCurrentPosition");
	
    Position *playerPosition = [playerData position];
    Position *destPosition = (self.unit) ? [self.unit position] : [[self destination] position];

    float distance = [playerData isOnGround] ? [playerPosition distanceToPosition2D: destPosition] : [playerPosition distanceToPosition: destPosition];
    //float distance2D = [playerPosition distanceToPosition2D: destPosition];
	
	//maintain a record of the previous distance to destination
	//to be checked against the current distance to destination
	//the plethora of flyaway checks isn't really necessary when we do this
	if ([self lastDistance]) {
		if (distance > [self lastDistance]) {
			log(LOG_MOVEMENT_CORRECTION, @"We're moving away from our destination! %0.2f > %0.2f", distance, self.lastDistance);
			[self moveForwardStop];
			[self correctDirection: YES];
			[self moveForwardStart];
		}
	}
	else {
		log(LOG_MOVEMENT_CORRECTION, @"lastDistance not set");
	}

	
	
	self.lastDistance = distance;

    // sanity check, incase something happens
    if(distance == INFINITY) {
        log(LOG_MOVEMENT, @"Player distance == infinity. Stopping.");
        if(self.unit)   [self finishAlt];
        else            [self finishRoute];
        return;
    }

	//log(LOG_MOVEMENT, @"Distance: %0.2f %0.2f", distance, distance2d);
    
    // poll the bot controller
    if([botController isBotting]) {
        if( [self isPatrolling] && [botController evaluateSituation]) {
			log(LOG_MOVEMENT, @"Action taken, we don't need to check anything");
            // there was an action taken
            return;
        }
    }
	
	// if we're near our target, move to the next
    float playerSpeed = [playerData speed];
    //if(distance2d < playerSpeed/2.0)  {
	float distanceToUnit = WAYPOINT_SENSITIVITY;
	
	// ideally for nodes we'd also want to check the 2D distance so we drop RIGHT on the node
	if (self.unit){
		distanceToUnit = NODE_DISTANCE_UNTIL_DISMOUNT;
	}
	
	// We're close enough to take action or move to the next waypoint!
	if( distance <= distanceToUnit )  {
		log(LOG_MOVEMENT, @"Reached waypoint. %0.2f <= %0.2f", distance, distanceToUnit);
		// Moving to a waypoint
        if(!self.unit) {
            if([botController isBotting]) {
                if([botController shouldProceedFromWaypoint: [self destination]]) {
                    [self moveToNextWaypoint];
                }
            } else {
                [self moveToNextWaypoint];
            }
        } else {
            log(LOG_MOVEMENT, @"We're close to the unit. Stopping movement.");
            [self finishAlt];
        }
        return;
    } else {
		log(LOG_MOVEMENT, @"Not yet reached waypoint. %0.2f > %0.2f", distance, distanceToUnit);
        // if we're far enough away from our target, see if we should jump
        if( (distance > playerSpeed) && (!self.unit)) {
            if( self.shouldJump && ([[NSDate date] timeIntervalSinceDate: self.lastJumpTime] > self.jumpCooldown) ) {
                [self jump];
            }
        } else {
            [self correctDirection: NO];
        }
    }
    
	
    // if we're not moving forward for some reason, start moving again
    if( (([movementType selectedTag] == MOVE_CTM && ![self isCTMActive]) || [movementType selectedTag] != MOVE_CTM ) && !self.isPaused && (([playerData movementFlags] & 0x1) != 0x1)) {   // [self isPatrolling] && 
        log(LOG_MOVEMENT, @"We are stopped for some reason... starting again.");
        [self moveForwardStop];
        [self moveToPosition: (self.unit ? [self.unit position] : [[self destination] position])];
        return;
    }
    
}

#pragma mark -

- (void)resetMovementTimer {
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(realMoveToNextWaypoint) object: nil];
    [_movementTimer invalidate]; _movementTimer = nil;
}

- (void)resetMovementState {
	log(LOG_FUNCTION, @"entering function");
	if ( [movementType selectedTag] == MOVE_CTM ){
		[self setClickToMove:nil andType:ctmIdle andGUID:0x0];
	}
    [self moveForwardStop];
    [self resetMovementTimer];
	[self resetSpeedDistanceCheck];
    [self setDestination: nil];
    [self setIsPatrolling: NO];
    self.unit = nil;
    self.shouldNotify = NO;
    self.isPaused = NO;
    self.stopAtEnd = NO;
    _patrolCount = 0;
    self.waypointDoneCount = 0;
    self.shouldAttack = NO;
    self.lastSavedPosition = nil;
    self.movementExpiration = nil;
}

- (void)moveUpStart {
	log(LOG_MOVEMENT, @"Moving up...");
    [self setIsMoving: YES];
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    CGEventRef wKeyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_Space, TRUE);
    if(wKeyDown) {
        CGEventPostToPSN(&wowPSN, wKeyDown);
        CFRelease(wKeyDown);
    }
}

- (void)moveForwardStart {
    [self setIsMoving: YES];
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    CGEventRef wKeyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_UpArrow, TRUE);
    if(wKeyDown) {
        CGEventPostToPSN(&wowPSN, wKeyDown);
        CFRelease(wKeyDown);
    }
}

- (void)moveBackwardStart {
    [self setIsMoving: YES];
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    CGEventRef wKeyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_DownArrow, TRUE);
    if(wKeyDown) {
        CGEventPostToPSN(&wowPSN, wKeyDown);
        CFRelease(wKeyDown);
    }
}

- (void)moveUpStop {
	log(LOG_MOVEMENT, @"Releasing jump button!");

    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    
    // post another key down
    CGEventRef wKeyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_Space, TRUE);
    if(wKeyDown) {
        CGEventPostToPSN(&wowPSN, wKeyDown);
        CFRelease(wKeyDown);
    }
    
    // then post key up, twice
    CGEventRef wKeyUp = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_Space, FALSE);
    if(wKeyUp) {
        CGEventPostToPSN(&wowPSN, wKeyUp);
        CGEventPostToPSN(&wowPSN, wKeyUp);
        CFRelease(wKeyUp);
    }
}

- (void)moveForwardStop {
	
	[self setIsMoving: NO];
	
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    
    // post another key down
    CGEventRef wKeyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_UpArrow, TRUE);
    if(wKeyDown) {
        CGEventPostToPSN(&wowPSN, wKeyDown);
        CFRelease(wKeyDown);
    }
    
    // then post key up, twice
    CGEventRef wKeyUp = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_UpArrow, FALSE);
    if(wKeyUp) {
        CGEventPostToPSN(&wowPSN, wKeyUp);
        CGEventPostToPSN(&wowPSN, wKeyUp);
        CFRelease(wKeyUp);
    }
}

- (void)moveBackwardStop {
    [self setIsMoving: NO];
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    
    // post another key down
    CGEventRef wKeyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_DownArrow, TRUE);
    if(wKeyDown) {
        CGEventPostToPSN(&wowPSN, wKeyDown);
        CFRelease(wKeyDown);
    }
    
    // then post key up, twice
    CGEventRef wKeyUp = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_DownArrow, FALSE);
    if(wKeyUp) {
        CGEventPostToPSN(&wowPSN, wKeyUp);
        CGEventPostToPSN(&wowPSN, wKeyUp);
        CFRelease(wKeyUp);
    }
}

- (void)turnLeft: (BOOL)go {
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    
    if(go) {
        CGEventRef keyStroke = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_LeftArrow, TRUE);
        if(keyStroke) {
        CGEventPostToPSN(&wowPSN, keyStroke);
            CFRelease(keyStroke);
        }
    } else {
        // post another key down
        CGEventRef keyStroke = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_LeftArrow, TRUE);
        if(keyStroke) {
            CGEventPostToPSN(&wowPSN, keyStroke);
            CFRelease(keyStroke);
            
            // then post key up, twice
            keyStroke = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_LeftArrow, FALSE);
            if(keyStroke) {
                CGEventPostToPSN(&wowPSN, keyStroke);
                CGEventPostToPSN(&wowPSN, keyStroke);
                CFRelease(keyStroke);
            }
        }
    }
}

- (void)turnRight: (BOOL)go {
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    
    if(go) {
        CGEventRef keyStroke = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_RightArrow, TRUE);
        if(keyStroke) {
            CGEventPostToPSN(&wowPSN, keyStroke);
            CFRelease(keyStroke);
        }
    } else { 
        // post another key down
        CGEventRef keyStroke = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_RightArrow, TRUE);
        if(keyStroke) {
            CGEventPostToPSN(&wowPSN, keyStroke);
            CFRelease(keyStroke);
        }
        
        // then post key up, twice
        keyStroke = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)kVK_RightArrow, FALSE);
        if(keyStroke) {
            CGEventPostToPSN(&wowPSN, keyStroke);
            CGEventPostToPSN(&wowPSN, keyStroke);
            CFRelease(keyStroke);
        }
    }
}

//#define StillTurnRadianPerSec   3.5f
//#define MovingTurnRadianPerSec  2.25f

#define OneDegree   0.0174532925

- (void)turnTowardObject: (WoWObject*)unit{
	
	[self turnToward: [unit position]];
	
	/*// Turn toward a unit!
	if ( [movementType selectedTag] == MOVE_CTM ){
		[self setClickToMove:nil andType:ctmFaceTarget andGUID:[unit GUID]];
		return;
	}
	// for all other movement types!
	else{
		[self turnToward: [unit position]];
	}*/
}

- (void)turnToward: (Position*)position {
	
	/*if ( [movementType selectedTag] == MOVE_CTM ){
		log(LOG_MOVEMENT, @"In theory we should never be here!");
		return;
	}*/
	
    BOOL printTurnInfo = NO;
    if( ![controller isWoWFront] || ((GetCurrentButtonState() & 0x2) != 0x2) ) {  // don't change position if the right mouse button is down
        Position *playerPosition = [playerData position];
        if( [movementType selectedTag] == MOVE_KEYBOARD ) {
            // check player facing vs. unit position
            float playerDirection, savedDirection;
            playerDirection = savedDirection = [playerData directionFacing];
            float theAngle = [playerPosition angleTo: position];
    
            if(fabsf(theAngle - playerDirection) > M_PI) {
                if(theAngle < playerDirection)  theAngle += (M_PI*2);
                else                            playerDirection += (M_PI*2);
            }
            
            // find the difference between the angles
            float angleTo = (theAngle - playerDirection), absAngleTo = fabsf(angleTo);
            
            // tan(angle) = error / distance; error = distance * tan(angle);
            float speedMax = [playerData speedMax];
            float startDistance = [playerPosition distanceToPosition2D: position];
            float errorLimit = (startDistance < speedMax) ?  1.0f : (1.0f + ((startDistance-speedMax)/12.5f)); // (speedMax/3.0f);
            //([playerData speed] > 0) ? ([playerData speedMax]/4.0f) : ((startDistance < [playerData speedMax]) ? 1.0f : 2.0f);
            float errorStart = (absAngleTo < M_PI_2) ? (startDistance * sinf(absAngleTo)) : INFINITY;
            
            
            if( errorStart > (errorLimit) ) { // (fabsf(angleTo) > OneDegree*5) 
            
                // compensate for time taken for WoW to process keystrokes.
                // response time is directly proportional to WoW's refresh rate (FPS)
                // 2.25 rad/sec is an approximate turning speed
                float compensationFactor = ([controller refreshDelay]/2000000.0f) * 2.25f;
                
                log(LOG_MOVEMENT, @"[Turn] ------");
                log(LOG_MOVEMENT, @"[Turn] %.3f rad turn with %.2f error (lim %.2f) for distance %.2f.", absAngleTo, errorStart, errorLimit, startDistance);
                
                NSDate *date = [NSDate date];
                ( angleTo > 0) ? [self turnLeft: YES] : [self turnRight: YES];
                
                int delayCount = 0;
                float errorPrev = errorStart, errorNow;
                float lastDiff = angleTo, currDiff;
                
                
                while( delayCount < 2500 ) { // && (signbit(lastDiff) == signbit(currDiff))
                    
                    // get current values
                    Position *currPlayerPosition = [playerData position];
                    float currAngle = [currPlayerPosition angleTo: position];
                    float currPlayerDirection = [playerData directionFacing];
                    
                    // correct for looping around the circle
                    if(fabsf(currAngle - currPlayerDirection) > M_PI) {
                        if(currAngle < currPlayerDirection) currAngle += (M_PI*2);
                        else                                currPlayerDirection += (M_PI*2);
                    }
                    currDiff = (currAngle - currPlayerDirection);
                    
                    // get current diff and apply compensation factor
                    float modifiedDiff = fabsf(currDiff);
                    if(modifiedDiff > compensationFactor) modifiedDiff -= compensationFactor;
                    
                    float currentDistance = [currPlayerPosition distanceToPosition2D: position];
                    errorNow = (fabsf(currDiff) < M_PI_2) ? (currentDistance * sinf(modifiedDiff)) : INFINITY;
                    
                    if( (errorNow < errorLimit) ) {
                        log(LOG_MOVEMENT, @"[Turn] [Range is Good] %.2f < %.2f", errorNow, errorLimit);
                        log(LOG_MOVEMENT, @"Expected additional movement: %.2f", currentDistance * sinf(0.035*2.25));
                        break;
                    }
                    
                    if( (delayCount > 250) ) {
                        if( (signbit(lastDiff) != signbit(currDiff)) ) {
                            log(LOG_MOVEMENT, @"[Turn] [Sign Diff] %.3f vs. %.3f (Error: %.2f vs. %.2f)", lastDiff, currDiff, errorNow, errorPrev);
                            break;
                        }
                        if( (errorNow > (errorPrev + errorLimit)) ) {
                            log(LOG_MOVEMENT, @"[Turn] [Error Growing] %.2f > %.2f", errorNow, errorPrev);
                            break;
                        }
                    }
                    
                    if(errorNow < errorPrev)
                        errorPrev = errorNow;
                        
                    lastDiff = currDiff;
                    
                    delayCount++;
                    usleep(1000);
                }
                
                ( angleTo > 0) ? [self turnLeft: NO] : [self turnRight: NO];
                
                float finalFacing = [playerData directionFacing];

                /*int j = 0;
                while(1) {
                    j++;
                    usleep(2000);
                    if(finalFacing != [playerData directionFacing]) {
                        float currentDistance = [[playerData position] distanceToPosition2D: position];
                        float diff = fabsf([playerData directionFacing] - finalFacing);
                        PGLog(@"[Turn] Stabalized at ~%d ms (wow delay: %d) with %.3f diff --> %.2f yards.", j*2, [controller refreshDelay], diff, currentDistance * sinf(diff) );
                        break;
                    }
                }*/
                
                // [playerData setDirectionFacing: newPlayerDirection];
                
                if(fabsf(finalFacing - savedDirection) > M_PI) {
                    if(finalFacing < savedDirection)    finalFacing += (M_PI*2);
                    else                                savedDirection += (M_PI*2);
                }
                float interval = -1*[date timeIntervalSinceNow], turnRad = fabsf(savedDirection - finalFacing);
                if(printTurnInfo) log(LOG_MOVEMENT, @"[Turn] %.3f rad/sec (%.2f/%.2f) at pSpeed %.2f.", turnRad/interval, turnRad, interval, [playerData speed] );
                
            }
        } else /*if ( [movementType selectedTag] == MOVE_MOUSE )*/{
            log(LOG_MOVEMENT, @"Doing sharp turn to %.2f", [playerPosition angleTo: position]);
            [playerData faceToward: position];
            usleep([controller refreshDelay]);
        }
    } else {
        log(LOG_MOVEMENT, @"Skipping turn because right mouse button is down.");
    }
    
}

- (void)correctDirection: (BOOL)force {
	// We don't correct our direction if we're using CTM!
	if ( [movementType selectedTag] == MOVE_CTM ){
		return;
	}
	
    if(force) {
        // every 2 seconds, we should cover around [playerData speedMax]*2
        // check to ensure that we've moved 1/4 of that
        log(LOG_MOVEMENT_CORRECTION, @"Expiration in: %.2f seconds (%@).", [self.movementExpiration timeIntervalSinceNow], self.movementExpiration);
        if( self.movementExpiration && ([self.movementExpiration compare: [NSDate date]] == NSOrderedAscending) ) {
            log(LOG_MOVEMENT_CORRECTION, @"**** Movement timer expired!! ****");
            // if we can't reach the unit, just bail it
            if (self.unit) { 
                log(LOG_MOVEMENT_CORRECTION, @"... Unable to reach unit %@; cancelling.", self.unit);
                [self finishAlt];
            } else {
                // move to the previous waypoint and try this again
                NSArray *waypoints = [[self patrolRoute] waypoints];
                int index = [waypoints indexOfObject: [self destination]];
                if(index != NSNotFound) {
                    if(index == 0) {
                        index = [waypoints count];
                    }
                    log(LOG_MOVEMENT_CORRECTION, @"... Moving to prevous waypoint.");
                    [self moveToWaypoint: [waypoints objectAtIndex: index-1]];
                } else {
                    [self finishRoute];
                }
            }
            return;
        }
        
        // float timeSpan = [[NSDate date] timeIntervalSinceDate: self.lastDirectionCorrection];
        // if(distanceMoved > 0.01)
        //    PGLog(@"Moved %.2f yards in %.2f seconds.", distanceMoved, timeSpan);
        
        // update the direction we're facing
		Position *position = self.unit ? [self.unit position] : [self.destination position];
		if ( self.unit ){
			//PGLog(@"[Move] Refacing unit");
			//[self moveForwardStop];
			[self turnTowardObject:self.unit];
			//[self moveForwardStart];
		}
		else{
			//PGLog(@"[Move] Refacing waypoint");
			//[self moveForwardStop];
			[self turnToward: position];
			//[self moveForwardStart];
		}
                
        // find distance moved since last check
        Position *playerPosition = [playerData position];
        float distanceMoved = [playerPosition distanceToPosition2D: self.lastSavedPosition];
        self.lastSavedPosition = playerPosition;
        self.lastDirectionCorrection = [NSDate date];
        
        // update movement expiration if we are actually moving
        if(self.lastSavedPosition && (distanceMoved > ([playerData speedMax]/2.0)) ) {
            float secondsFromNow = ([playerPosition distanceToPosition: position]/[playerData speedMax]) + 4.0;
            self.movementExpiration = [NSDate dateWithTimeIntervalSinceNow: secondsFromNow];
            log(LOG_MOVEMENT_CORRECTION, @"Movement expiration in %.2f seconds for %.2f yards.", secondsFromNow, [playerPosition distanceToPosition: position]);
        }
    } else {
        if( [[NSDate date] timeIntervalSinceDate: self.lastDirectionCorrection] > 2.0) {
            [self correctDirection: YES];
        }
    }
}

- (BOOL)useSmoothTurning{
	return ([movementType selectedTag] == MOVE_KEYBOARD);
}

- (BOOL)useClickToMove{
	return ([movementType selectedTag] == MOVE_CTM);	
}

#pragma mark IB Actions

- (IBAction)prefsChanged: (id)sender {
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: self.shouldJump] forKey: @"MovementShouldJump"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
}

#pragma mark Click To Move
// 13.44444444			0x12709FC				9.0
- (void)setClickToMove:(Position*)position andType:(UInt32)type andGUID:(UInt64)guid{
	
	MemoryAccess *memory = [controller wowMemoryAccess];
	if ( !memory ){
		return;
	}
	
	// Set our position!
	if ( position != nil ){
		float pos[3] = {0.0f, 0.0f, 0.0f};
		pos[0] = [position xPosition];
		pos[1] = [position yPosition];
		pos[2] = [position zPosition];
		[memory saveDataForAddress: [offsetController offset:@"CTM_POS"] Buffer: (Byte *)&pos BufLength: sizeof(float)*3];
	}
	
	// Set the GUID of who to interact with!
	if ( guid > 0 ){
		[memory saveDataForAddress: [offsetController offset:@"CTM_GUID"] Buffer: (Byte *)&guid BufLength: sizeof(guid)];
	}
	
	// Set our scale!
	float scale = 13.962634f;
	[memory saveDataForAddress: [offsetController offset:@"CTM_SCALE"] Buffer: (Byte *)&scale BufLength: sizeof(scale)];
	
	// Set our distance to the target until we stop moving
	float distance = 0.5f;	// Default for just move to position
	if ( type == ctmAttackGuid ){
		distance = 3.66f;
	}
	else if ( type == ctmInteractNpc ){
		distance = 2.75f;
	}
	else if ( type == ctmInteractObject ){
		distance = 4.5f;
	}
	[memory saveDataForAddress: [offsetController offset:@"CTM_DISTANCE"] Buffer: (Byte *)&distance BufLength: sizeof(distance)];
	
	/*
	// Set these other randoms!  These are set if the player actually clicks, but sometimes they won't when they login!  Then it won't work :(  /cry
	float unk = 9.0f;
	float unk2 = 14.0f;		// should this be 7.0f?  If only i knew what this was!
	[memory saveDataForAddress: CTM_UNKNOWN Buffer: (Byte *)&unk BufLength: sizeof(unk)];
	[memory saveDataForAddress: CTM_UNKNOWN2 Buffer: (Byte *)&unk2 BufLength: sizeof(unk2)];
	 */
	
	// Lets start moving!
	[memory saveDataForAddress: [offsetController offset:@"CTM_ACTION"] Buffer: (Byte *)&type BufLength: sizeof(type)];
}

- (BOOL)isCTMActive{
	UInt32 value = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: [offsetController offset:@"CTM_ACTION"] Buffer: (Byte*)&value BufLength: sizeof(value)];
    return ((value == ctmWalkTo) || (value == ctmLoot) || (value == ctmInteractNpc) || (value == ctmInteractObject));
}

- (void)followObject: (WoWObject*)unit{
	[self setClickToMove: [unit position] andType:ctmWalkTo andGUID:[unit GUID]];
}

- (BOOL)dismount{
	
	[macroController useMacroOrSendCmd:@"Dismount"];
	return YES;
	
	
	// get memory
	MemoryAccess *memory = [controller wowMemoryAccess];
	if ( !memory )
		return NO;
	
	// do they have a standard mount?
	UInt32 mountID = [[playerData player] mountID];
	
	// check for druids
	if ( mountID == 0 ){
		if ( [auraController unit: [playerData player] hasAuraNamed: @"Swift Flight Form"] )
			mountID = 40120;
		else if ( [auraController unit: [playerData player] hasAuraNamed: @"Swift Flight Form"] )
			mountID = 33943;
	}
	
	// mount found! "use" it!
	if ( mountID > 0 ){
		
		log(LOG_MOVEMENT, @"Dismounting from %d", mountID);
		
		[botController performAction: mountID];
		
		usleep(100000);
		
		return YES;
	}
	
	// just in case people have problems, we'll print something to their log file
	if ( ![playerData isOnGround] ) {
		log(LOG_MOVEMENT, @"Unable to dismount player! In theory we should never be here! Mount ID: %d", mountID);
    }
	
	return NO;	
}

@end
