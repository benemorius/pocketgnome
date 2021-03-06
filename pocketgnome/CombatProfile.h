//
//  IgnoreProfile.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 7/19/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IgnoreEntry.h"

@class Unit;
@class Player;

@interface CombatProfile : NSObject <NSCoding, NSCopying> {
    NSString *_name;
    NSMutableArray *_combatEntries;
    
    BOOL combatEnabled, onlyRespond, attackNeutralNPCs, attackHostileNPCs, attackPlayers, attackPets;
    BOOL attackAnyLevel, ignoreElite, ignoreLevelOne;
	
	// Healing
	BOOL healingEnabled, autoFollowTarget, followMountEnabled;
	float yardsBehindTarget, healingRange;
	int healthThreshold;
	UInt64 selectedTankGUID;
    
    BOOL attackOnlyTankedMobs;
    float followRange;
	BOOL followCombatDisabled;
	BOOL followHealDisabled;
	BOOL followLootDisabled;
	BOOL followGatherDisabled;
	
	
	BOOL enemyWeightEnabled;
	int enemyWeightPlayer;
	int enemyWeightPet;
	int enemyWeightHostileNPC;
    int enemyWeightNeutralNPC;
	int enemyWeightHealth;
	int enemyWeightTarget;
	int enemyWeightDistance;
    int enemyWeightElite;
    int enemyWeightLevel;
    int enemyWeightAttackingMe;
    
    float attackRange;
    int attackLevelMin, attackLevelMax;
}

+ (id)combatProfile;
+ (id)combatProfileWithName: (NSString*)name;

- (BOOL)unitFitsProfile: (Unit*)unit ignoreDistance: (BOOL)ignoreDistance;

- (unsigned)entryCount;
- (IgnoreEntry*)entryAtIndex: (unsigned)index;

- (void)addEntry: (IgnoreEntry*)entry;
- (void)removeEntry: (IgnoreEntry*)entry;
- (void)removeEntryAtIndex: (unsigned)index;

@property (readwrite, retain) NSArray *entries;
@property (readwrite, copy) NSString *name;
@property (readwrite, assign) UInt64 selectedTankGUID;
@property (readwrite, assign) BOOL combatEnabled;
@property (readwrite, assign) BOOL onlyRespond;
@property (readwrite, assign) BOOL attackNeutralNPCs;
@property (readwrite, assign) BOOL attackHostileNPCs;
@property (readwrite, assign) BOOL attackPlayers;
@property (readwrite, assign) BOOL attackPets;
@property (readwrite, assign) BOOL attackAnyLevel;
@property (readwrite, assign) BOOL ignoreElite;
@property (readwrite, assign) BOOL ignoreLevelOne;

@property (readwrite, assign) BOOL healingEnabled;
@property (readwrite, assign) BOOL autoFollowTarget;
@property (readwrite, assign) float yardsBehindTarget;
@property (readwrite, assign) float healingRange;
@property (readwrite, assign) BOOL followMountEnabled;
@property (readwrite, assign) int healthThreshold;

@property (readwrite, assign) BOOL attackOnlyTankedMobs;
@property (readwrite, assign) float followRange;
@property (readwrite, assign) BOOL followCombatDisabled;
@property (readwrite, assign) BOOL followHealDisabled;
@property (readwrite, assign) BOOL followLootDisabled;
@property (readwrite, assign) BOOL followGatherDisabled;


@property (readwrite, assign) float attackRange;
@property (readwrite, assign) int attackLevelMin;
@property (readwrite, assign) int attackLevelMax;

@property (readwrite, assign) BOOL enemyWeightEnabled;
@property (readwrite, assign) int enemyWeightPlayer;
@property (readwrite, assign) int enemyWeightPet;
@property (readwrite, assign) int enemyWeightHostileNPC;
@property (readwrite, assign) int enemyWeightNeutralNPC;
@property (readwrite, assign) int enemyWeightHealth;
@property (readwrite, assign) int enemyWeightTarget;
@property (readwrite, assign) int enemyWeightDistance;
@property (readwrite, assign) int enemyWeightElite;
@property (readwrite, assign) int enemyWeightLevel;
@property (readwrite, assign) int enemyWeightAttackingMe;


@end
