//
//  IgnoreProfile.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 7/19/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import "CombatProfile.h"
#import "Unit.h"
#import "Mob.h"
#import "IgnoreEntry.h"

#import "PlayerDataController.h"
#import "PlayersController.h"


@implementation CombatProfile

- (id) init
{
    self = [super init];
    if (self != nil) {
        self.name = nil;
        self.entries = [NSArray array];
        self.combatEnabled = YES;
        self.onlyRespond = NO;
        self.attackNeutralNPCs = YES;
        self.attackHostileNPCs = YES;
        self.attackPlayers = NO;
        self.attackPets = NO;
        self.attackAnyLevel = YES;
        self.ignoreElite = YES;
        self.ignoreLevelOne = YES;
		
		// Healing
		self.healingEnabled = NO;
		self.autoFollowTarget = NO;
		self.yardsBehindTarget = 10.0f;
		self.healingRange = 40.0f;
		self.followMountEnabled = NO;
		self.selectedTankGUID = 0x0;
		self.healthThreshold = 95;
        
        self.followRange = 40;
        self.attackOnlyTankedMobs = YES;
		self.followCombatDisabled = NO;
		self.followHealDisabled = NO;
		self.followLootDisabled = NO;
		self.followGatherDisabled = NO;
		

        self.attackRange = 20.0f;
        self.attackLevelMin = 2;
        self.attackLevelMax = 70;
		
		self.enemyWeightEnabled = YES;
		self.enemyWeightPlayer = 100;
		self.enemyWeightPet = 0;
		self.enemyWeightHostileNPC = 75;
        self.enemyWeightNeutralNPC = 50;
		self.enemyWeightHealth = 20;
		self.enemyWeightTarget = 10;
		self.enemyWeightDistance = 30;
        self.enemyWeightElite = 20;
        self.enemyWeightLevel = 10;
        self.enemyWeightAttackingMe = 0;
    }
	log(LOG_COMBAT, @"CombatProfile created with name %@", self.name);
    return self;
}

- (id)initWithName: (NSString*)name {
    self = [self init];
    if (self != nil) {
        self.name = name;
    }
    return self;
}

+ (id)combatProfile {
    return [[[CombatProfile alloc] init] autorelease];
}

+ (id)combatProfileWithName: (NSString*)name {
    return [[[CombatProfile alloc] initWithName: name] autorelease];
}

- (id)copyWithZone:(NSZone *)zone
{
    CombatProfile *copy = [[[self class] allocWithZone: zone] initWithName: self.name];
    
    copy.entries = self.entries;
    copy.combatEnabled = self.combatEnabled;
    copy.onlyRespond = self.onlyRespond;
    copy.attackNeutralNPCs = self.attackNeutralNPCs;
    copy.attackHostileNPCs = self.attackHostileNPCs;
    copy.attackPlayers = self.attackPlayers;
    copy.attackPets = self.attackPets;
    copy.attackAnyLevel = self.attackAnyLevel;
    copy.ignoreElite = self.ignoreElite;
    copy.ignoreLevelOne = self.ignoreLevelOne;
	
	copy.healingEnabled = self.healingEnabled;
    copy.autoFollowTarget = self.autoFollowTarget;
    copy.yardsBehindTarget = self.yardsBehindTarget;
	copy.healingRange = self.healingRange;
	copy.followMountEnabled = self.followMountEnabled;
	copy.selectedTankGUID = self.selectedTankGUID;
	copy.healthThreshold = self.healthThreshold;
    
    copy.followRange = self.followRange;
    copy.attackOnlyTankedMobs = self.attackOnlyTankedMobs;
	copy.followCombatDisabled = self.followCombatDisabled;
	copy.followHealDisabled = self.followHealDisabled;
	copy.followLootDisabled = self.followLootDisabled;
	copy.followGatherDisabled = self.followGatherDisabled;
	
    copy.attackRange = self.attackRange;
    copy.attackLevelMin = self.attackLevelMin;
    copy.attackLevelMax = self.attackLevelMax;
	
	copy.enemyWeightEnabled = self.enemyWeightEnabled;
	copy.enemyWeightPlayer = self.enemyWeightPlayer;
	copy.enemyWeightPet = self.enemyWeightPet;
	copy.enemyWeightHostileNPC = self.enemyWeightHostileNPC;
    copy.enemyWeightNeutralNPC = self.enemyWeightNeutralNPC;
	copy.enemyWeightHealth = self.enemyWeightHealth;
	copy.enemyWeightTarget = self.enemyWeightTarget;
	copy.enemyWeightDistance = self.enemyWeightDistance;
    copy.enemyWeightElite = self.enemyWeightElite;
    copy.enemyWeightLevel = self.enemyWeightLevel;
    copy.enemyWeightAttackingMe = self.enemyWeightAttackingMe;

    
    return copy;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [self init];
	if(self) {
        self.entries = [decoder decodeObjectForKey: @"IgnoreList"] ? [decoder decodeObjectForKey: @"IgnoreList"] : [NSArray array];

        self.name = [decoder decodeObjectForKey: @"Name"];
        self.combatEnabled = [[decoder decodeObjectForKey: @"CombatEnabled"] boolValue];
        self.onlyRespond = [[decoder decodeObjectForKey: @"OnlyRespond"] boolValue];
        self.attackNeutralNPCs = [[decoder decodeObjectForKey: @"AttackNeutralNPCs"] boolValue];
        self.attackHostileNPCs = [[decoder decodeObjectForKey: @"AttackHostileNPCs"] boolValue];
        self.attackPlayers = [[decoder decodeObjectForKey: @"AttackPlayers"] boolValue];
        self.attackPets = [[decoder decodeObjectForKey: @"AttackPets"] boolValue];
        self.attackAnyLevel = [[decoder decodeObjectForKey: @"AttackAnyLevel"] boolValue];
        self.ignoreElite = [[decoder decodeObjectForKey: @"IgnoreElite"] boolValue];
        self.ignoreLevelOne = [[decoder decodeObjectForKey: @"IgnoreLevelOne"] boolValue];

		self.healingEnabled = [[decoder decodeObjectForKey: @"HealingEnabled"] boolValue];
        self.autoFollowTarget = [[decoder decodeObjectForKey: @"AutoFollowTarget"] boolValue];
		self.yardsBehindTarget = [[decoder decodeObjectForKey: @"YardsBehindTarget"] floatValue];
		self.healingRange = [[decoder decodeObjectForKey: @"HealingRange"] floatValue];
		self.followMountEnabled = [[decoder decodeObjectForKey: @"FollowMountEnabled"] boolValue];
		self.selectedTankGUID = [[decoder decodeObjectForKey: @"selectedTankGUID"] unsignedLongLongValue];
		self.healthThreshold = [[decoder decodeObjectForKey: @"HealthThreshold"] intValue];
        
        self.followRange = [[decoder decodeObjectForKey: @"FollowRange"] floatValue];
        self.attackOnlyTankedMobs = [[decoder decodeObjectForKey: @"AttackOnlyTankedMobs"] boolValue];
		self.followCombatDisabled = [[decoder decodeObjectForKey: @"FollowCombatDisabled"] boolValue];
		self.followHealDisabled = [[decoder decodeObjectForKey: @"FollowHealDisabled"] boolValue];
		self.followLootDisabled = [[decoder decodeObjectForKey: @"FollowLootDisabled"] boolValue];
		self.followGatherDisabled = [[decoder decodeObjectForKey: @"FollowGatherDisabled"] boolValue];
		
        self.attackRange = [[decoder decodeObjectForKey: @"AttackRange"] floatValue];
        self.attackLevelMin = [[decoder decodeObjectForKey: @"AttackLevelMin"] intValue];
        self.attackLevelMax = [[decoder decodeObjectForKey: @"AttackLevelMax"] intValue];
		
		self.enemyWeightEnabled = [[decoder decodeObjectForKey: @"EnemyWeightEnabled"] boolValue];
		self.enemyWeightPlayer = [[decoder decodeObjectForKey: @"EnemyWeightPlayer"] intValue];
		self.enemyWeightPet = [[decoder decodeObjectForKey: @"EnemyWeightPet"] intValue];
		self.enemyWeightHostileNPC = [[decoder decodeObjectForKey: @"EnemyWeightHostileNPC"] intValue];
        self.enemyWeightNeutralNPC = [[decoder decodeObjectForKey: @"EnemyWeightNeutralNPC"] intValue];
		self.enemyWeightTarget = [[decoder decodeObjectForKey: @"EnemyWeightTarget"] intValue];
		self.enemyWeightHealth = [[decoder decodeObjectForKey: @"EnemyWeightHealth"] intValue];
		self.enemyWeightDistance = [[decoder decodeObjectForKey: @"EnemyWeightDistance"] intValue];
		self.enemyWeightElite = [[decoder decodeObjectForKey: @"EnemyWeightElite"] intValue];
		self.enemyWeightLevel = [[decoder decodeObjectForKey: @"EnemyWeightLevel"] intValue];
		self.enemyWeightAttackingMe = [[decoder decodeObjectForKey: @"EnemyWeightAttackingMe"] intValue];

	}
	return self;
}

-(void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject: self.name forKey: @"Name"];
    [coder encodeObject: [NSNumber numberWithBool: self.combatEnabled] forKey: @"CombatEnabled"];
    [coder encodeObject: [NSNumber numberWithBool: self.onlyRespond] forKey: @"OnlyRespond"];
    [coder encodeObject: [NSNumber numberWithBool: self.attackNeutralNPCs] forKey: @"AttackNeutralNPCs"];
    [coder encodeObject: [NSNumber numberWithBool: self.attackHostileNPCs] forKey: @"AttackHostileNPCs"];
    [coder encodeObject: [NSNumber numberWithBool: self.attackPlayers] forKey: @"AttackPlayers"];
    [coder encodeObject: [NSNumber numberWithBool: self.attackPets] forKey: @"AttackPets"];
    [coder encodeObject: [NSNumber numberWithBool: self.attackAnyLevel] forKey: @"AttackAnyLevel"];
    [coder encodeObject: [NSNumber numberWithBool: self.ignoreElite] forKey: @"IgnoreElite"];
    [coder encodeObject: [NSNumber numberWithBool: self.ignoreLevelOne] forKey: @"IgnoreLevelOne"];

	[coder encodeObject: [NSNumber numberWithBool: self.healingEnabled] forKey: @"HealingEnabled"];
    [coder encodeObject: [NSNumber numberWithBool: self.autoFollowTarget] forKey: @"AutoFollowTarget"];
    [coder encodeObject: [NSNumber numberWithFloat: self.yardsBehindTarget] forKey: @"YardsBehindTarget"];
	[coder encodeObject: [NSNumber numberWithFloat: self.healingRange] forKey: @"HealingRange"];
	[coder encodeObject: [NSNumber numberWithBool: self.followMountEnabled] forKey: @"FollowMountEnabled"];
	[coder encodeObject: [NSNumber numberWithUnsignedLongLong: self.selectedTankGUID]forKey: @"selectedTankGUID"];
	[coder encodeObject: [NSNumber numberWithInt: self.healthThreshold] forKey: @"HealthThreshold"];
    
    [coder encodeObject: [NSNumber numberWithFloat: self.followRange] forKey: @"FollowRange"];
	[coder encodeObject: [NSNumber numberWithBool: self.attackOnlyTankedMobs] forKey: @"AttackOnlyTankedMobs"];
    [coder encodeObject: [NSNumber numberWithBool: self.followCombatDisabled] forKey: @"FollowCombatDisabled"];
	[coder encodeObject: [NSNumber numberWithBool: self.followHealDisabled] forKey: @"FollowHealDisabled"];
    [coder encodeObject: [NSNumber numberWithBool: self.followLootDisabled] forKey: @"FollowLootDisabled"];
    [coder encodeObject: [NSNumber numberWithBool: self.followGatherDisabled] forKey: @"FollowGatherDisabled"];

	
    [coder encodeObject: [NSNumber numberWithFloat: self.attackRange] forKey: @"AttackRange"];
    [coder encodeObject: [NSNumber numberWithInt: self.attackLevelMin] forKey: @"AttackLevelMin"];
    [coder encodeObject: [NSNumber numberWithInt: self.attackLevelMax] forKey: @"AttackLevelMax"];

    [coder encodeObject: self.entries forKey: @"IgnoreList"];
	
	[coder encodeObject: [NSNumber numberWithBool: self.enemyWeightEnabled] forKey: @"EnemyWeightEnabled"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightPlayer] forKey: @"EnemyWeightPlayer"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightPet] forKey: @"EnemyWeightPet"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightHostileNPC] forKey: @"EnemyWeightHostileNPC"];
    [coder encodeObject: [NSNumber numberWithInt: self.enemyWeightNeutralNPC] forKey: @"EnemyWeightNeutralNPC"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightTarget] forKey: @"EnemyWeightTarget"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightHealth] forKey: @"EnemyWeightHealth"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightDistance] forKey: @"EnemyWeightDistance"];
    [coder encodeObject: [NSNumber numberWithInt: self.enemyWeightElite] forKey: @"EnemyWeightElite"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightLevel] forKey: @"EnemyWeightLevel"];
	[coder encodeObject: [NSNumber numberWithInt: self.enemyWeightAttackingMe] forKey: @"EnemyWeightAttackingMe"];

}

- (void) dealloc
{
    self.name = nil;
    self.entries = nil;
    [super dealloc];
}

@synthesize name = _name;
@synthesize entries = _combatEntries;
@synthesize combatEnabled;
@synthesize onlyRespond;
@synthesize attackNeutralNPCs;
@synthesize attackHostileNPCs;
@synthesize attackPlayers;
@synthesize attackPets;
@synthesize attackAnyLevel;
@synthesize ignoreElite;
@synthesize ignoreLevelOne;

@synthesize healingEnabled;
@synthesize autoFollowTarget;
@synthesize yardsBehindTarget;
@synthesize healingRange;
@synthesize followMountEnabled;
@synthesize selectedTankGUID;
@synthesize healthThreshold;

@synthesize followRange;
@synthesize attackOnlyTankedMobs;
@synthesize followCombatDisabled;
@synthesize followHealDisabled;
@synthesize followLootDisabled;
@synthesize followGatherDisabled;

@synthesize attackRange;
@synthesize attackLevelMin;
@synthesize attackLevelMax;

@synthesize enemyWeightEnabled;
@synthesize enemyWeightPlayer;
@synthesize enemyWeightPet;
@synthesize enemyWeightHostileNPC;
@synthesize enemyWeightNeutralNPC;
@synthesize enemyWeightTarget;
@synthesize enemyWeightHealth;
@synthesize enemyWeightDistance;
@synthesize enemyWeightElite;
@synthesize enemyWeightLevel;
@synthesize enemyWeightAttackingMe;


- (BOOL)unitFitsProfile: (Unit*)unit ignoreDistance: (BOOL)ignoreDistance {
    // if combat is disabled
    // or we are only responding, then NO.
    if(!self.combatEnabled || self.onlyRespond)
        return NO;
    
    // check our internal blacklist
    for(IgnoreEntry *entry in [self entries]) {
        if( [entry type] == IgnoreType_EntryID) {
            if( [[entry ignoreValue] intValue] == [unit entryID])
                return NO;
        }
        if( [entry type] == IgnoreType_Name) {
            if(![entry ignoreValue] || ![[entry ignoreValue] length] || ![unit name])
                continue;

            NSRange range = [[unit name] rangeOfString: [entry ignoreValue] 
                                               options: NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
            if(range.location != NSNotFound) {
                return NO;
            }
        }
    }
    PlayerDataController *playerData = [PlayerDataController sharedController];
    PlayersController *playersController = [[PlayersController alloc] init];
    Player *tank = [playersController playerWithGUID:[self selectedTankGUID]];

    if([unit isTappedByOther] && (([unit targetID] != [self selectedTankGUID]) || ([unit targetID] != [playerData focusGUID])))
        return NO;
    if([self attackOnlyTankedMobs] && [tank isValid] && !([unit targetID] == [tank GUID]))
        return NO;


    // get faction data
    int faction = [unit factionTemplate];
    BOOL isFriendly = [playerData isFriendlyWithFaction: faction];
    if(isFriendly) return NO;   // bail if friendly
    BOOL isHostile = [playerData isHostileWithFaction: faction];
    
    // check players
    if([unit isPlayer]) {
        if(!self.attackPlayers)
            return NO;
        if(self.attackPlayers && !isHostile)
            return NO;
    }
    
    // check NPCs
    if([unit isNPC]) {
        if( !((self.attackNeutralNPCs && !isHostile && !isFriendly) || (self.attackHostileNPCs && isHostile)))
            return NO;
    }
    
    // ignore elite?
    if(self.ignoreElite && [unit isElite])
        return NO;
    
    // within level range?
    if(!self.attackAnyLevel) {
        int level = [unit level];
        if(level < self.attackLevelMin || level > self.attackLevelMax)
            return NO;
    } else {
        if(self.ignoreLevelOne && ([unit level] == 1))
            return NO;
    }
    
    // ignore pets?
    if(!self.attackPets && [unit isPet]) {
        return NO;
    }
    
    // check range
    if(!ignoreDistance) {   // ignore range if specified
        float distance = [[playerData position] distanceToPosition: [unit position]];
        if((distance == INFINITY) || (distance < 0.0f) || (distance > self.attackRange)) {
            return NO;
        }
    }
    
    return YES;
}

- (void)setEntries: (NSArray*)newEntries {
    [self willChangeValueForKey: @"entries"];
    [_combatEntries autorelease];
    if(newEntries) {
        _combatEntries = [[NSMutableArray alloc] initWithArray: newEntries copyItems: YES];
    } else {
        _combatEntries = nil;
    }
    [self didChangeValueForKey: @"entries"];
}

- (unsigned)entryCount {
    return [self.entries count];
}

- (IgnoreEntry*)entryAtIndex: (unsigned)index {
    if(index >= 0 && index < [self entryCount])
        return [[[_combatEntries objectAtIndex: index] retain] autorelease];
    return nil;
}

- (void)addEntry: (IgnoreEntry*)entry {
    if(entry != nil)
        [_combatEntries addObject: entry];
}

- (void)removeEntry: (IgnoreEntry*)entry {
    if(entry == nil) return;
    [_combatEntries removeObject: entry];
}

- (void)removeEntryAtIndex: (unsigned)index; {
    if(index >= 0 && index < [self entryCount])
        [_combatEntries removeObjectAtIndex: index];
}

@end
