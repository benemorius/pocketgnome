//
//  CombatController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/18/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import "CombatController.h"
#import "PlayerDataController.h"
#import "MovementController.h"
#import "Controller.h"
#import "BotController.h"
#import "MobController.h"
#import "ChatController.h"
#import "BlacklistController.h"
#import "PlayersController.h"

#import "Unit.h"
#import "Mob.h"
#import "Player.h"
#import "CombatProfile.h"

@interface CombatController (Internal)
- (void)verifyCombatUnits: (BOOL)purgeCombat;
- (BOOL)attackBestTarget;

//- (BOOL)addUnitToCombatList: (Unit*)unit;
//- (BOOL)removeUnitFromCombatList: (Unit*)unit;

- (Unit*)findBestUnitToAttack;
- (BOOL)addUnitToAttackingMe: (Unit*)unit;
- (BOOL)removeUnitFromAttackingMe: (Unit*)unit;
@end

@implementation CombatController

- (id) init
{
    self = [super init];
    if (self != nil) {
        _inCombat = NO;
        _combatEnabled = NO;
        _technicallyOOC = YES;
        _attemptingCombat = NO;
        //_combatUnits = [[NSMutableArray array] retain];
        _attackQueue = [[NSMutableArray array] retain];
		_unitsAttackingMe = [[NSMutableArray array] retain];
        
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerEnteringCombat:) name: PlayerEnteringCombatNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerLeavingCombat:) name: PlayerLeavingCombatNotification object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(invalidTarget:) name: ErrorInvalidTarget object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outOfRange:) name: ErrorOutOfRange object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(targetNotInFront:) name: ErrorTargetNotInFront object: nil];
    }
    return self;
}

@synthesize inCombat = _inCombat;
@synthesize attackUnit = _attackUnit;
@synthesize combatEnabled = _combatEnabled;

#pragma mark from PlayerData Controller
- (void)concludeCombat {
	log(LOG_COMBAT, @"------ Player Leaving Combat ------ (conclude combat)");
	
    // lets stop everything and tell the botController
    self.inCombat = NO;
    self.attackUnit = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    [botController playerLeavingCombat];
}

#pragma mark State

/*- (NSArray*)combatUnits {
 return [[_combatUnits retain] autorelease];
 }*/
- (NSArray*)attackQueue {
    return [[_attackQueue retain] autorelease];
}

- (NSArray*)unitsAttackingMe {
    return [[_unitsAttackingMe retain] autorelease];
}


#pragma mark (Internal) State Maintenence

// The sole purpose of verifyCombatUnits is to validate the units currently being tracked for combat purposes
// this includes the complete list of combat units, as well as the attack queue
- (void)verifyCombatUnits: (BOOL)purgeCombat {
    NSMutableArray *unitsToRemove = [NSMutableArray array];
    
    // We want to remove:
    // * Blacklisted
    // * Dead
    // * Not in combat
    // * Invalid
    // * Evading
    // * Tapped by others
    
    for(Unit* unit in _attackQueue) {
        // remove the unit if it's invalid, blacklisted, dead, evading or no longer in combat
        if( ![unit isValid] || [unit isDead] || [unit isEvading]){ // || [unit isTappedByOther]) {// || ![unit isInCombat] ) {
            log(LOG_TARGET, @"[A] Removing %@  NotValid?(%d) Dead?(%d) Evading?(%d) TappedByOther?(%d) NotInCombat?(%d)", unit, ![unit isValid], [unit isDead], [unit isEvading], [unit isTappedByOther], ![unit isInCombat]);
			[unitsToRemove addObject: unit];
        }
    }
    
    for(Unit* unit in unitsToRemove) {
        // this removes the unit from the attack queue as well
        //[self finishUnit: unit];
        [self removeUnitFromAttackQueue:unit];
    }
    
    if([unitsToRemove count])
    { 
		//log(LOG_TARGET, @"%d attacking me; %d in attack queue.", [_unitsAttackingMe count], [_attackQueue count]);
		if(![self inCombat] && ([_unitsAttackingMe count] == 0))
			[self concludeCombat];
    }
}

#pragma mark Internal

- (void)combatCheck: (Unit*)unit {
    if ( !unit ) {
		log(LOG_COMBAT, @"No unit %@ to attack!", unit);
		return;
	}
    
    // cancel any other pending checks for this unit
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(combatCheck:) object: unit];
    
	if ( [unit isDead] ){
		log(LOG_COMBAT, @"Unit %@ dead, cancelling combatCheck", unit);
		return;
	}
	
    // if the unit is either not in combat, or is evading
    if( ![unit isInCombat] || [unit isEvading] || ![unit isAttackable] ) { 
        log(LOG_COMBAT, @"-XX- Unit %@ not in combat (%d), evading (%d), or not attackable(%d), blacklisting.", unit, ![unit isInCombat], [unit isEvading], ![unit isAttackable] );
        [blacklistController blacklistObject: unit forSeconds:20];
        return;
    }
	
	// we should be checking other things here
	//	has the unit's health not dropped?
	//	check vertical distance?
    
    /*float currentDistance = [[playerData position] distanceToPosition2D: [unit position]];
    if( botController.theCombatProfile.attackRange < currentDistance ) {
		PGLog(@"[Combat] -XX- Unit %@ distance (%.2f) is greater than the attack distance (%.2f).", unit, currentDistance, botController.theCombatProfile.attackRange);

        return;
    }*/
    
    // keep pulsing the combat check every second
    [self performSelector: @selector(combatCheck:)
               withObject: unit
               afterDelay: 1.0f];
}

- (void)attackTheUnit: (Unit*)unit {
    
}

#pragma mark Notifications

- (void)playerEnteringCombat: (NSNotification*)notification {
	if(![botController isBotting])
		return;
    log(LOG_COMBAT, @"------ Player Entering Combat ------");
    self.inCombat = YES;
    _technicallyOOC = NO;
    
    // find who we are in combat with
    if([self combatEnabled] && ([[self unitsAttackingMe] count] == 0)) {
        log(LOG_COMBAT, @"Rescan targets because we are in combat, but have no known targets.");
		[self doCombatSearch];
    }
	
    if(![_attackQueue count])
	{
        [botController playerEnteringCombat];
    }
	else
	{
        [self attackBestTarget];
    }
}

- (void)playerLeavingCombat: (NSNotification*)notification {
    log(LOG_COMBAT, @"------ Technically (real) OOC ------");
    _technicallyOOC = YES;
    
    // get rid of any unit still classified as in combat
    [self verifyCombatUnits: YES];
    
    // dump everything
    [_unitsAttackingMe removeAllObjects];
    [_attackQueue removeAllObjects];
	
    [self concludeCombat];
}

// invalid target
- (void)invalidTarget: (NSNotification*)notification {
	
	// is there a unit we should be attacking
	if ( self.attackUnit && [playerData targetID] == [self.attackUnit GUID] ){
		log(LOG_TARGET, @"Target not valid, blacklisting %@", self.attackUnit);
		[blacklistController blacklistObject: self.attackUnit forSeconds:20];
		//[self finishUnit:self.attackUnit];
	}
}

// target is out of range
- (void)outOfRange: (NSNotification*)notification {
	
	// We should blacklist this guy?
	if ( self.attackUnit ){

		// is this who we are currently attacking?
		if ( [playerData targetID] == [self.attackUnit GUID] ){
			//log(LOG_TARGET, @"Out of range, blacklisting %@", self.attackUnit);
			//[blacklistController blacklistObject: self.attackUnit];
			//[self finishUnit:self.attackUnit];
            [movementController moveToObject:self.attackUnit andNotify: YES];
		}
	}
}

- (void)targetNotInFront: (NSNotification*)notification {
	log(LOG_COMBAT, @"Target not in front!");
	[movementController backEstablishPosition];
}

#pragma mark from BotController

- (void)cancelAllCombat {
    log(LOG_COMBAT, @"Clearing all combat state.");
    self.attackUnit = nil;
    [_attackQueue removeAllObjects];
	[_unitsAttackingMe removeAllObjects];
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
}

#pragma mark Attack


- (BOOL)attackBestTarget
{
    if(!self.combatEnabled || ![botController isBotting]) return NO;
    
	Unit *bestUnit = [self findBestUnitToAttack];
	if (bestUnit)
	{
		log(LOG_COMBAT, @"Attacking: %@", bestUnit);
		[botController attackUnit:bestUnit];
		return YES;
	}
	log(LOG_COMBAT, @"Nothing to attack");
	return NO;
}


- (void)finishUnit: (Unit*)unit {
    if ( unit == nil ) {
		log(LOG_COMBAT, @"Unable to finish a nil unit!");
		return;
	}
    
    if([self.attackUnit isEqualToObject: unit]) {
        self.attackUnit = nil;
		log(LOG_COMBAT, @"Finishing our current target %@", unit);
    }
    
    // make sure the unit sticks around until we're done with it
    [[unit retain] autorelease];
    
    // unregister callbacks to this controller
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(attackTheUnit:) object: unit];
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(combatCheck:) object: unit];
    
    // remove from the attack queue & combat list
    BOOL wasInAttackQueue = [_attackQueue containsObject: unit];
    [self removeUnitFromAttackQueue: unit];
    
    // tell the bot controller
    [botController finishUnit: unit wasInAttackQueue: wasInAttackQueue];
}

#pragma mark Data Structure Access

// units will ONLY be added to the attack queue from botController
- (BOOL)addUnitToAttackQueue: (Unit*)unit {
    if( ![_attackQueue containsObject: unit] )
	{
		if(![unit isValid]) { // if we were sent a bad unit
			log(LOG_TARGET, @"Unit to attack is not valid!");
			return NO;
		} else {
			if([[blacklistController blacklistedUnits] containsObject:unit]) {
				log(LOG_TARGET, @"Blacklisted unit %@ will not be fought.", unit);
				return NO;
			}
			
			if( [unit isDead]) {
				log(LOG_TARGET, @"Cannot attack a dead unit %@.", unit);
				[blacklistController blacklistObject: unit forSeconds:20];
				return NO;
			}
			
			if( [unit isEvading]) {
				log(LOG_TARGET, @"%@ appears to be evading...", unit);
				[blacklistController blacklistObject: unit forSeconds:20];
				return NO;
			}
		}
        [_attackQueue addObject: unit];
        float dist = [[playerData position] distanceToPosition2D: [unit position]];
        log(LOG_TARGET, @"Adding %@ to attack queue at %.2f yards.", unit, dist);
		return YES;
    }
	else
	{
		//log(LOG_TARGET, @"Unit %@ already exists in the attack queue", unit);
        return NO;
    }
}

- (BOOL)removeUnitFromAttackQueue: (Unit*)unit {
    if([_attackQueue containsObject:unit]) {
        log(LOG_TARGET, @"Removing %@ from attack queue.", unit);
        [_attackQueue removeObject: unit];
        return YES;
    }
    return NO;
}

int DistanceFromPositionCmp(id <UnitPosition> unit1, id <UnitPosition> unit2, void *context) {
    
    //PlayerDataController *playerData = (PlayerDataController*)context; [playerData position];
    Position *position = (Position*)context; 
	
    float d1 = [position distanceToPosition: [unit1 position]];
    float d2 = [position distanceToPosition: [unit2 position]];
    if (d1 < d2)
        return NSOrderedAscending;
    else if (d1 > d2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

- (UInt32)unitWeight: (Unit*)unit PlayerPosition:(Position*)playerPosition{
	float attackRange = botController.theCombatProfile.attackRange;
	float distanceToTarget = [playerPosition distanceToPosition:[unit position]];
	
	// begin weight calculation
	int weight = 0;
	
	// always return 100 weight if weight system disabled
	if (!botController.theCombatProfile.enemyWeightEnabled)
		return 100;
	
	// player or pet?
	if ([unit isPlayer])
		weight += botController.theCombatProfile.enemyWeightPlayer;
	else if ([unit isPet])
		weight += botController.theCombatProfile.enemyWeightPet;
	else if ([unit isNPC] && [playerData isHostileWithFaction:[unit factionTemplate]])
		weight += botController.theCombatProfile.enemyWeightHostileNPC;
    else if ([unit isNPC] && ![playerData isFriendlyWithFaction:[unit factionTemplate]])
        weight += botController.theCombatProfile.enemyWeightNeutralNPC;
	
	// current target
	if ( [playerData targetID] == [unit GUID] )
		weight += botController.theCombatProfile.enemyWeightTarget;
    
    if([unit isElite])
       weight += botController.theCombatProfile.enemyWeightElite;
    
    if([unit targetID] == [playerData GUID])
        weight += botController.theCombatProfile.enemyWeightAttackingMe;
    
    weight += ([unit level] - [playerData level]) * botController.theCombatProfile.enemyWeightLevel;
	
    // health left
	weight += (100.0f - [unit percentHealth]) * (botController.theCombatProfile.enemyWeightHealth / 100.0f);
	
	// distance to target
	if ( attackRange > 0 )
		weight += ( 100.0f * ((attackRange-distanceToTarget)/attackRange)) * (botController.theCombatProfile.enemyWeightDistance / 100.0f);
	
	return weight;	
}

- (Unit*)findBestUnitToAttack{
	if ( ![botController isBotting] )	return nil;
	if ( ![self combatEnabled] )		return nil;
	
	// grab all units we're in combat with
	NSMutableArray *units = [NSMutableArray array];
	[units addObjectsFromArray:_unitsAttackingMe];
	// add new mobs which are in the attack queue
	for ( Unit *unit in _attackQueue ){
		if ( ![units containsObject:unit] ){
			[units addObject:unit];
		}
	}
	
	// sort units by position
	Position *playerPosition = [playerData position];
	[units sortUsingFunction: DistanceFromPositionCmp context: playerPosition];
	log(LOG_COMBAT, @"Units in queue or attacking me: %d (Queue:%d) (Me:%d)", [units count], [_attackQueue count], [_unitsAttackingMe count]);
	
	// lets find the best target
	if ( [units count] ){
		float distanceToTarget = 0.0f;
		int highestWeight = -65535;
		Unit *bestUnit = nil;
		
		for ( Unit *unit in units ){
			distanceToTarget = [playerPosition distanceToPosition:[unit position]];
			
			// only check targets that are close enough //no, check that before queueing it
			//if ( distanceToTarget > attackRange ){
			//	continue;
			//}
			
			// ignore blacklisted units
			if ( [blacklistController isBlacklisted:unit] ){
				continue;
			}
			
			// ignore dead/evading/not valid units
			if ( [unit isDead] || [unit isEvading] || ![unit isValid] ){
				continue;
			}
			
			// begin weight calculation
			int weight = [self unitWeight:unit PlayerPosition:playerPosition];
			//log(LOG_COMBAT, @"Valid target %@ found %0.2f yards away with weight %d", unit, distanceToTarget, weight);
			
			// best weight
			if ( weight > highestWeight ){
				highestWeight = weight;
				bestUnit = unit;
			}
		}
		log(LOG_COMBAT, @"Best unit out of %d: %@ weighs: %d", [units count], bestUnit, highestWeight);
		// make sure the unit sticks around until we're done with it
		[[bestUnit retain] autorelease];
		return bestUnit;
	}
	
	// no targets found
	return nil;	
}

// find all units we are in combat with
- (void)doCombatSearch{
	//if(![botController isBotting])
	//	return;

	NSArray *mobs = [mobController allMobs];
	NSArray *players = [playersController allPlayers];
	
	BOOL playerHasPet = [[playerData player] hasPet];
	
	for(Mob *mob in mobs)
	{
		if([mob isValid])
        {
            if([botController isUnitValidToAttack:mob fromPosition:[[playerData player] position] ignoreDistance:NO ignoreProfile:NO])
				[self addUnitToAttackQueue:mob];
            if([botController isUnitValidToAttack:mob fromPosition:[[playerData player] position] ignoreDistance:NO ignoreProfile:YES])
            {
                if([mob targetID] == [[playerData player] GUID] || (playerHasPet && [mob targetID] == [[playerData player] petGUID]) || [mob isFleeing])
                    [self addUnitToAttackingMe: (Unit*)mob];
            }
            else
                [self removeUnitFromAttackingMe:(Unit*)mob];
		}
	}
	
	for(Player *player in players)
    {
		if([player isValid])
        {
            if([botController isUnitValidToAttack:player fromPosition:[[playerData player] position] ignoreDistance:NO ignoreProfile:NO])
				[self addUnitToAttackQueue:player];
            if([botController isUnitValidToAttack:player fromPosition:[[playerData player] position] ignoreDistance:NO ignoreProfile:YES])
            {
                if([player targetID] == [[playerData player] GUID] || (playerHasPet && [player targetID] == [[playerData player] petGUID]) || [player isFleeing])
                    [self addUnitToAttackingMe:player];
            }
            else
                [self removeUnitFromAttackingMe:player];
        }
	}
	
	// verify units we're in combat with!
	[self verifyCombatUnits: NO];
	
	//log(LOG_TARGET, @"In combat with %d units; %d in attack queue", [_unitsAttackingMe count], [_attackQueue count]);
}

- (BOOL)addUnitToAttackingMe: (Unit*)unit{
	if(![_unitsAttackingMe containsObject: unit])
    {
		[_unitsAttackingMe addObject:unit];
		// should we remove the unit from the blacklist?
		log(LOG_TARGET, @"Adding %@ to units attacking me (%d total)", unit, [_unitsAttackingMe count]);
        
        if( [controller sendGrowlNotifications] && [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
			NSString *unitName = ([unit name]) ? [unit name] : nil;
			[GrowlApplicationBridge notifyWithTitle: [NSString stringWithFormat: @"%@ Attacking", [unit isPlayer] ? @"Player" : @"Mob"]
										description: ( unitName ? [NSString stringWithFormat: @"[%d] %@ at %d%%", [unit level], unitName, [unit percentHealth]] : ([unit isPlayer]) ? [NSString stringWithFormat: @"[%d] %@ %@, %d%%", [unit level], [Unit stringForRace: [unit race]], [Unit stringForClass: [unit unitClass]], [unit percentHealth]] : [NSString stringWithFormat: @"[%d] %@, %d%%", [unit level], [Unit stringForClass: [unit unitClass]], [unit percentHealth]])
								   notificationName: @"AddingUnit"
										   iconData: [[unit iconForClass: [unit unitClass]] TIFFRepresentation]
										   priority: 0
										   isSticky: NO
									   clickContext: nil];             
		}
		return YES;
	}
	return NO;
}

- (BOOL)removeUnitFromAttackingMe: (Unit*)unit{
	if ([_unitsAttackingMe containsObject: unit]){
		[_unitsAttackingMe removeObject: unit];
		log(LOG_TARGET, @"Removing %@ from units attacking me (%d remaining)", unit, [_unitsAttackingMe count]);
		return YES;		
	}
	return NO;			 
}

@end
