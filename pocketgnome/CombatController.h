//
//  CombatController.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/18/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Unit;
@class Controller;
@class ChatController;
@class MobController;
@class BotController;
@class MovementController;
@class PlayerDataController;
@class PlayersController;
@class Position;
@class BlacklistController;

@interface CombatController : NSObject {
    IBOutlet Controller				*controller;
    IBOutlet PlayerDataController	*playerData;
	IBOutlet PlayersController		*playersController;
    IBOutlet BotController			*botController;
    IBOutlet MobController			*mobController;
    IBOutlet ChatController			*chatController;
    IBOutlet MovementController		*movementController;
	IBOutlet BlacklistController	*blacklistController;
	
    BOOL _inCombat;
    BOOL _combatEnabled;
    BOOL _technicallyOOC;
    BOOL _attemptingCombat;
    Unit *_attackUnit;
    NSMutableArray *_attackQueue;
	NSMutableArray *_unitsAttackingMe;
}

@property BOOL combatEnabled;
@property BOOL inCombat;
@property (readwrite, retain) Unit *attackUnit;

// combat status
- (BOOL)inCombat;

// combat state
//- (NSArray*)combatUnits;
- (NSArray*)attackQueue;
- (NSArray*)unitsAttackingMe;

// action initiation
- (BOOL)attackBestTarget;
- (void)cancelAllCombat;
- (void)finishUnit: (Unit*)mob;


// get all units we're in combat with!
- (void)doCombatSearch;

// new combat search
- (Unit*)findBestUnitToAttack;
- (UInt32)unitWeight: (Unit*)unit PlayerPosition:(Position*)playerPosition;

// attack queue
- (BOOL)addUnitToAttackQueue: (Unit*)unit;
- (BOOL)removeUnitFromAttackQueue: (Unit*)unit;

//    float vertOffset = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"CombatBlacklistVerticalOffset"] floatValue];
//([[unit position] verticalDistanceToPosition: position] <= vertOffset)  



////// INPUTS //////
// --> playerEnteringCombat	via PlayerData notification
// --> playerLeavingCombat	via PlayerData notification
// --> disposeOfUnit (bot) via findBestUnitToAttack in evaluateSituation (if in combat)
// --> disposeOfUnit (bot) via searching nearby mobs/players in evaluateSituation (if not in combat + need to search around)
// --> disposeOfUnit (bot) as soon as the bot is started a check is done for mobs you're in combat with
////// OUTPUT /////
// <-- playerEnteringCombat
// <-- playerLeavingCombat
// <-- addingUnit
// <-- attackUnit
// <-- finishUnit
///////////////////


@end
