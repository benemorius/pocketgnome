//
//  PlayerDataController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/15/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import "PlayerDataController.h"
#import "Offsets.h"
#import "MemoryAccess.h"

#import "AuraController.h"
#import "Controller.h"
#import "MobController.h"
#import "SpellController.h"
#import "CombatController.h"
#import "MemoryViewController.h"

#import "Spell.h"
#import "Player.h"
#import "Position.h"

#import <Growl/GrowlApplicationBridge.h>

@interface PlayerDataController ()
@property (readwrite, retain) Position *deathPosition;
@property float xPosition;
@property float yPosition;
@property float zPosition;
@property BOOL wasDead;
@end

@interface PlayerDataController (Internal)
- (void)resetState;
- (void)loadState;

- (UInt32)factionTemplate;

- (void)setHorizontalDirectionFacing: (float)direction; // [0, 2pi]
- (void)setVerticalDirectionFacing: (float)direction;   // [-pi/2, pi/2]
@end

@implementation PlayerDataController

+ (void)initialize {
    /*[self exposeBinding: @"mana"];
    [self exposeBinding: @"maxMana"];
    [self exposeBinding: @"health"];
    [self exposeBinding: @"maxHealth"];
    [self exposeBinding: @"percentHealth"];
     [self exposeBinding: @"percentMana"];*/
    [self exposeBinding: @"playerIsValid"];
}

static PlayerDataController* sharedController = nil;

+ (PlayerDataController *)sharedController {
	if (sharedController == nil)
		sharedController = [[[self class] alloc] init];
	return sharedController;
}

- (id) init {
    self = [super init];
	if(sharedController) {
		[self release];
		self = sharedController;
	} else if(self != nil) {
        sharedController = self;

        _baselineAddress = nil;
        _playerAddress = nil;
        _lastState = NO;
        _lastCombatState = NO;
        self.deathPosition = nil;
        _lastTargetID = 0;
        savedLevel = 0;
        self.wasDead = NO;
           
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(applicationWillTerminate:) 
                                                     name: NSApplicationWillTerminateNotification 
                                                   object: nil];
                                                   
                                                   
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(viewLoaded:) 
                                                     name: DidLoadViewInMainWindowNotification 
                                                   object: nil];
        
        [NSBundle loadNibNamed: @"Player" owner: self];
    }
    return self;
}

- (void)viewLoaded: (NSNotification*)notification {
    //if( [notification object] == self.view ) {
    //    PGLog(@"loaded");
    //    [[AuraController sharedController] aurasForUnit: [self player]];
    //} 
}

- (void)awakeFromNib {
    
    self.minSectionSize = [self.view frame].size;
    self.maxSectionSize = [self.view frame].size;
    
    float freq = [[NSUserDefaults standardUserDefaults] floatForKey: @"PlayerUpdateFrequency"];
    if(freq <= 0.0f) freq = 0.35;
    self.updateFrequency = freq;
}

- (void)applicationWillTerminate: (NSNotification*)notification {
    [[NSUserDefaults standardUserDefaults] setFloat: self.updateFrequency forKey: @"PlayerUpdateFrequency"];
}

@synthesize view;
@synthesize deathPosition = _deathPosition;
@synthesize xPosition = _xPosition;
@synthesize yPosition = _yPosition;
@synthesize zPosition = _zPosition;
@synthesize updateFrequency = _updateFrequency;
@synthesize minSectionSize;
@synthesize maxSectionSize;
@synthesize wasDead = _wasDead;
@synthesize pet = _pet;

- (NSString*)playerHeader {
    if( [self playerIsValid]  ) {
        // get the player name if we can
        NSString *playerName = nil;
        if( PLAYER_NAME_STATIC ) {
            char name[13];
            name[12] = 0;
            if([[controller wowMemoryAccess] loadDataForObject: self atAddress: PLAYER_NAME_STATIC Buffer: (Byte *)&name BufLength: sizeof(name)-1]) {
                NSString *newName = [NSString stringWithUTF8String: name];
                if([newName length]) {
                    playerName = newName;
                }
            }
        }
        
        Player *thisPlayer = [self player];
        
        if(playerName) {
            return [NSString stringWithFormat: @"%@, level %d %@ %@", playerName, [thisPlayer level], [Unit stringForRace: [thisPlayer race]], [Unit stringForClass: [thisPlayer unitClass]]];
        }
        return [NSString stringWithFormat: @"Level %d %@ %@", [thisPlayer level], [Unit stringForRace: [thisPlayer race]], [Unit stringForClass: [thisPlayer unitClass]]];
        
    } else {
        return @"No valid player detected.";
    }
}


- (NSString*)lastErrorMessage {
    if( LAST_RED_ERROR_MESSAGE ) {
        char str[100];
        str[99] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: LAST_RED_ERROR_MESSAGE Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
            NSString *string = [NSString stringWithUTF8String: str];
            if([string length]) {
                return string;
            }
        }
    }
    return @"";
}

- (NSString*)playerName {
    if( PLAYER_NAME_STATIC ) {
        char str[13];
        str[12] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: PLAYER_NAME_STATIC Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
            NSString *string = [NSString stringWithUTF8String: str];
            if([string length]) {
                return string;
            }
        }
    }
    return @"";
}

- (NSString*)accountName {
    if( ACCOUNT_NAME_STATIC ) {
        char str[33];
        str[32] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ACCOUNT_NAME_STATIC Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
            NSString *string = [NSString stringWithUTF8String: str];
            if([string length]) {
                return string;
            }
        }
    }
    return @"";
}

- (NSString*)serverName {
    if( SERVER_NAME_STATIC ) {
        char str[33];
        str[32] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: SERVER_NAME_STATIC Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
            NSString *string = [NSString stringWithUTF8String: str];
            if([string length]) {
                return string;
            }
        }
    }
    return @"";
}

- (NSString*)sectionTitle {
    return @"Player";
}

#pragma mark -

- (BOOL)playerIsValid {
    // check that our so-called player struct has the correct signature
    MemoryAccess *memory = [controller wowMemoryAccess];
    
    // load the following:
    //  global GUID
    //  our GUID
    //  our object type
    // then compare GUIDs and validate object type
    
    UInt32 globalGUID = 0, selfGUID = 0, objType = 0;
    [memory loadDataForObject: self atAddress: PLAYER_GUID_STATIC Buffer: (Byte*)&globalGUID BufLength: sizeof(globalGUID)];
    [memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_GUID_LOW32) Buffer: (Byte*)&selfGUID BufLength: sizeof(selfGUID)];
    if(globalGUID && selfGUID && [memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_TYPE_ID) Buffer: (Byte*)&objType BufLength: sizeof(objType)] && (objType == TYPEID_PLAYER)) {
        if(globalGUID == selfGUID) {
            if(!_lastState) {   // update binding
                PGLog(@"[Player] Player is valid.");
                [self loadState];
            }
            return YES;
        }
    }
    
    if(_lastState) {
        PGLog(@"[Player] Player is invalid.");
        [self resetState];
    }
    return NO;
    
    
    /*
    // the following is the validation function for pre-3.0
    // it no longer works because Blizzard removed the global PLAYER_STRUCT_PTR_STATIC
    
    UInt32 value = 0, value2 = 0;
    if([memory loadDataForObject: self atAddress: PLAYER_STRUCT_PTR_STATIC Buffer: (Byte*)&value BufLength: sizeof(value)] && (value == [self baselineAddress])) {
        if([memory loadDataForObject: self atAddress: (value + OBJECT_TYPE_ID) Buffer: (Byte*)&value2 BufLength: sizeof(value2)] && (value2 == TYPEID_PLAYER)) {
            if(!_lastState) {   // update binding
                PGLog(@"[Player] Player is valid.");
                [self loadState];
            }
            return YES;
        }
    }
    if(_lastState) {
        PGLog(@"[Player] Player is invalid.");
        [self resetState];
    }
    return NO; */
}

- (void)resetState {
    [self willChangeValueForKey: @"playerHeader"];
    [self willChangeValueForKey: @"playerIsValid"];
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    
    _lastState = NO;
    [_playerAddress release];   _playerAddress = nil;
    self.pet = nil;
    savedLevel = 0;
    
    [self didChangeValueForKey: @"playerIsValid"];
    [self didChangeValueForKey: @"playerHeader"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName: PlayerIsInvalidNotification object: nil];
}

- (void)loadState {
    // load player info: info sub-struct, signature, and playerID
    GUID playerGUID = 0;
    MemoryAccess *memory = [controller wowMemoryAccess];
    UInt32 objectType = 0, playerAddress = 0;
    if(memory && _baselineAddress && [self baselineAddress]) {
        [memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_TYPE_ID) Buffer: (Byte*)&objectType BufLength: sizeof(objectType)];
        [memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_FIELDS_PTR) Buffer: (Byte*)&playerAddress BufLength: sizeof(playerAddress)];
        [memory loadDataForObject: self atAddress: (playerAddress) Buffer: (Byte*)&playerGUID BufLength: sizeof(playerGUID)];
    }
    
    // if we got a ~~~~
    // 1) valid player address
    // 2) the player signature is correct
    // 3) we have a real baseline address
    // 4) and a real player ID
    // ... then we're good to go.
    if(playerAddress && (objectType == TYPEID_PLAYER) && (playerGUID > 0) ) {
        [_playerAddress release];
        _playerAddress = [[NSNumber numberWithUnsignedInt: playerAddress] retain];
        [self willChangeValueForKey: @"playerHeader"];
        [self willChangeValueForKey: @"playerIsValid"];
        _lastState = YES;
        [self didChangeValueForKey: @"playerIsValid"];
        [self didChangeValueForKey: @"playerHeader"];
        
        // reset internal state info variables
        self.wasDead = [self isDead];
        savedLevel = 0;
        
        [[NSNotificationCenter defaultCenter] postNotificationName: PlayerIsValidNotification object: nil];
        
        // and start the update process
        [self performSelector: @selector(refreshPlayerData) withObject: nil afterDelay: _updateFrequency];
        return;
    }
    
    PGLog(@"Error: Attemping to load invalid player; bailing.");
    [self resetState];
}


//- (void)wowMemoryAccessIsValid: (NSNotification*)notification {
//    if(_baselineAddress)
//        [self loadState];
//}
//
//- (void)wowMemoryAccessIsNotValid: (NSNotification*)notification {
//    [self resetState];
//}

- (void)setStructureAddress: (NSNumber*)address {
    
    // save new address
    [_baselineAddress release];
    _baselineAddress = [address retain];

    // reset any previous state
    [self resetState];
    
    // try and load player state
    [self loadState];
}

- (UInt32)baselineAddress {
    return [_baselineAddress unsignedIntValue];
}

- (NSNumber*)structureAddress {
    return [[_baselineAddress retain] autorelease];
}

- (UInt32)infoAddress {
    return [_playerAddress unsignedIntValue];
}

- (Player*)player {
    return [Player playerWithAddress: [self structureAddress] inMemory: [controller wowMemoryAccess]];
}

#pragma mark Generic Player Info

- (UInt64)GUID {
    UInt64 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: [self infoAddress] Buffer: (Byte*)&value BufLength: sizeof(value)] && value)
        return value;
    return 0;
}



#pragma mark Player Health & Mana

- (BOOL)isDead {
    // if we have no health, we're dead
    if( [self health] == 0) return YES;
    
    // or, if we're a ghost
    return [self isGhost];
}

- (BOOL)isGhost {
    NSArray *auras = [[AuraController sharedController] aurasForUnit: [self player] idsOnly: YES];
    // 8326 - regular dead
    // 20584 - night elf wisp form
    return ([auras containsObject: [NSNumber numberWithUnsignedInt: 8326]] || [auras containsObject: [NSNumber numberWithUnsignedInt: 20584]]);
}

- (UInt32)percentHealth {
    if([self maxHealth] == 0) return 0;
    return (UInt32)(((1.0)*[self health])/[self maxHealth] * 100);
}

- (UInt32)percentMana {
    if([self maxMana] == 0) return 0;
    return (UInt32)(((1.0)*[self mana])/[self maxMana] * 100);
}

- (void)setHealth: (UInt32)value {
    if(_playerHealth != value) {
        [self willChangeValueForKey: @"health"];
        [self willChangeValueForKey: @"percentHealth"];
        _playerHealth = value;
        [self didChangeValueForKey: @"health"];
        [self didChangeValueForKey: @"percentHealth"];
    }
}

- (UInt32)health {
    return _playerHealth;
}

- (void)setMaxHealth: (UInt32)value {
    if(_playerMaxHealth != value) {
        [self willChangeValueForKey: @"maxHealth"];
        [self willChangeValueForKey: @"percentHealth"];
        _playerMaxHealth = value;
        [self didChangeValueForKey: @"maxHealth"];
        [self didChangeValueForKey: @"percentHealth"];
    }
}
- (UInt32)maxHealth {
    return _playerMaxHealth;
}

- (void)setMana: (UInt32)playerMana {
    if(_playerMana != playerMana) {
        [self willChangeValueForKey: @"mana"];
        [self willChangeValueForKey: @"percentMana"];
        _playerMana = playerMana;
        [self didChangeValueForKey: @"mana"];
        [self didChangeValueForKey: @"percentMana"];
    }
}

- (UInt32)mana {
    return _playerMana;
}

- (void)setMaxMana: (UInt32)value {
    if(_playerMaxMana != value) {
        [self willChangeValueForKey: @"maxMana"];
        [self willChangeValueForKey: @"percentMana"];
        _playerMaxMana = value;
        [self didChangeValueForKey: @"maxMana"];
        [self didChangeValueForKey: @"percentMana"];
    }
}
- (UInt32)maxMana {
    return _playerMaxMana;
}

- (UInt32)comboPoints {
    UInt32 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: (COMBO_POINTS_STATIC) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
        return value;
    }
    return 0;
}

#pragma mark Player Bearings

- (Position*)position {
    float pos[3] = {-1.0f, -1.0f, -1.0f };
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self baselineAddress] + BaseField_XLocation) Buffer: (Byte *)&pos BufLength: sizeof(float)*3])
        return [Position positionWithX: pos[0] Y: pos[1] Z: pos[2]];
    return nil;
}

- (BOOL)isIndoors {
    UInt32 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: (PLAYER_ON_BUILDING_STATIC) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
        return (value == 1);
    }
    return NO;
}

- (BOOL)isOutdoors {
    return ![self isIndoors];
}

// 1 write
- (void)setHorizontalDirectionFacing: (float)direction {
    // player must be valid
    if(direction >= 0.0f) {
        [[controller wowMemoryAccess] saveDataForAddress: ([self baselineAddress] + BaseField_Facing_Horizontal) Buffer: (Byte *)&direction BufLength: sizeof(direction)];
        //[[controller wowMemoryAccess] saveDataForAddress: ([self baselineAddress] + 0xC24) Buffer: (Byte *)&direction BufLength: sizeof(direction)];
        //[[controller wowMemoryAccess] saveDataForAddress: ([self baselineAddress] + 0xF18) Buffer: (Byte *)&direction BufLength: sizeof(direction)];
        //[[controller wowMemoryAccess] saveDataForAddress: (0x24362bbc) Buffer: (Byte *)&direction BufLength: sizeof(direction)];
    }
}

// 1 write
- (void)setVerticalDirectionFacing: (float)direction {
    [[controller wowMemoryAccess] saveDataForAddress: ([self baselineAddress] + BaseField_Facing_Vertical) Buffer: (Byte *)&direction BufLength: sizeof(direction)];
}

// 1 read
- (float)directionFacing {
    float floatValue = -1.0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self baselineAddress] + BaseField_Facing_Horizontal) Buffer: (Byte*)&floatValue BufLength: sizeof(floatValue)];
    return floatValue;
}

- (void)setDirectionFacing: (float)direction {
    if(direction < 0) return;
    [[controller wowMemoryAccess] saveDataForAddress: ([self baselineAddress] + BaseField_Facing_Horizontal) Buffer: (Byte*)&direction BufLength: sizeof(direction)];
}

// 1 read
- (UInt32)movementFlags {
    UInt32 value = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self baselineAddress] + BaseField_MovementFlags) Buffer: (Byte*)&value BufLength: sizeof(value)];
    return value;
}

// 1 read
- (float)speed {
    float floatValue = 0.0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self baselineAddress] + BaseField_RunSpeed_Current) Buffer: (Byte*)&floatValue BufLength: sizeof(floatValue)];
    return [[NSString stringWithFormat: @"%.2f", floatValue] floatValue];
}

// 2 reads
- (float)speedMax {
    float groundSpeed = [self maxGroundSpeed], airSpeed = [self maxAirSpeed];
    return (airSpeed > groundSpeed) ? airSpeed : groundSpeed;
}

// 1 read
- (float)maxGroundSpeed {
    float floatValue = 0.0f;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self baselineAddress] + BaseField_RunSpeed_Max) Buffer: (Byte*)&floatValue BufLength: sizeof(floatValue)];
    return floatValue;
}

// 1 read
- (float)maxAirSpeed {
    float floatValue = 0.0f;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self baselineAddress] + BaseField_AirSpeed_Max) Buffer: (Byte*)&floatValue BufLength: sizeof(floatValue)];
    return floatValue;
}

// 1 read, 2 writes
- (void)faceToward: (Position*)position {
    if([self playerIsValid]) {
        Position *ourPosition = [self position];
        [self setHorizontalDirectionFacing: [ourPosition angleTo: position]];
        [self setVerticalDirectionFacing: [ourPosition verticalAngleTo: position]];
    }
}

#pragma mark Player Targeting

- (BOOL)setPrimaryTarget: (UInt64)targetID {
    MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory && [self playerIsValid]) {
        BOOL ret1, ret3;
        // save this value to the target table
        ret1 = [memory saveDataForAddress: (TARGET_TABLE_STATIC + TARGET_CURRENT) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)];
        //ret2 = [[self wowMemory] saveDataForAddress: (TARGET_TABLE_STATIC + TARGET_MOUSEOVER) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)];
        
        // and to the player table
        ret3 = [memory saveDataForAddress: ([self infoAddress] + UnitField_Target) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)];
        
        if(ret1 && ret3)    
            return YES;
        else
            return NO;
    }
    return NO;
}

- (BOOL)setMouseoverTarget: (UInt64)targetID {
    if([self playerIsValid]) {
        // save this value to the target table
        if([[controller wowMemoryAccess] saveDataForAddress: (TARGET_TABLE_STATIC + TARGET_MOUSEOVER) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)])
            return YES;
        else
            return NO;
    }
    return NO;
}

- (UInt64)targetID {
    UInt64 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self infoAddress] + UnitField_Target) Buffer: (Byte*)&value BufLength: sizeof(value)] && value) {
        return value;
    }
    return 0;
}

- (UInt64)interactGUID {
    UInt64 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: (TARGET_TABLE_STATIC + TARGET_INTERACT) Buffer: (Byte*)&value BufLength: sizeof(value)] && value) {
        return value;
    }
    return 0;
}

- (UInt64)mouseoverID {
    UInt64 value = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: (TARGET_TABLE_STATIC + TARGET_MOUSEOVER) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (UInt64)comboPointUID {
    UInt64 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: (COMBO_POINTS_TABLE_STATIC + COMBO_POINT_TARGET_UID) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
        return value;
    }
    return 0;
}

#pragma mark PLayer Status

- (UInt32)stateFlags {
    UInt32 value = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: [self infoAddress] + UnitField_StatusFlags Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
    
    // polymorph sets bits 22 and 29
    
    // bit 1  - not attackable
    // bit 4  - evading
    // bit 10 - looting
    // bit 11 - combat (for mob)
    // but 18 - stunned
    // bit 19 - combat (for player)
    // bit 23 - running away
    // bit 25 - invisible/not selectable
    // bit 26 - skinnable
    // bit 29 - feign death
}

- (BOOL)isInCombat {
    if( ([self stateFlags] & (1 << 19)) == (1 << 19))
        return YES;
    return NO;
}

- (BOOL)isLooting {
    if( ([self stateFlags] & (1 << 10)) == (1 << 10))
        return YES;
    return NO;
}

- (BOOL)isSitting {
    return [[self player] isSitting];
}

    
    
- (BOOL)isHostileWithFaction: (UInt32)otherFaction {
    UInt32 playerFaction = [self factionTemplate];
    if( !playerFaction || !otherFaction) return YES;
    
    NSDictionary *playerFactionTemplate = [[controller factionDict] objectForKey: [NSString stringWithFormat: @"%d", playerFaction]];
    NSDictionary *otherFactionTemplate  = [[controller factionDict] objectForKey: [NSString stringWithFormat: @"%d", otherFaction]];
    
    if(!playerFactionTemplate || !otherFactionTemplate) return YES;
    
    // check enemy list
    if([[playerFactionTemplate objectForKey: @"EnemyFactions"] containsObject: [NSNumber numberWithUnsignedInt: otherFaction]])
        return YES;
        
    return ( [[playerFactionTemplate objectForKey: @"EnemyMask"] unsignedIntValue] & [[otherFactionTemplate objectForKey: @"ReactMask"] unsignedIntValue] );
}

- (BOOL)isFriendlyWithFaction: (UInt32)otherFaction {
    UInt32 playerFaction = [self factionTemplate];
    if( !playerFaction || !otherFaction) return NO;
    
    NSDictionary *playerFactionTemplate = [[controller factionDict] objectForKey: [NSString stringWithFormat: @"%d", playerFaction]];
    NSDictionary *otherFactionTemplate  = [[controller factionDict] objectForKey: [NSString stringWithFormat: @"%d", otherFaction]];
    
    if(!playerFactionTemplate || !otherFactionTemplate) return NO;
    
    // check friend list
    if([[playerFactionTemplate objectForKey: @"FriendFactions"] containsObject: [NSNumber numberWithUnsignedInt: otherFaction]])
        return YES;
        
    return ( [[playerFactionTemplate objectForKey: @"FriendMask"] unsignedIntValue] & [[otherFactionTemplate objectForKey: @"ReactMask"] unsignedIntValue] );
}

#pragma mark Player Casting

- (BOOL)isCasting {
    MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory) {
        UInt32 toCastID = 0, castID = 0, channelID = 0;
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_Casting Buffer: (Byte *)&castID BufLength: sizeof(castID)];
        if(castID > 0) return YES;
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_ToCast Buffer: (Byte *)&toCastID BufLength: sizeof(toCastID)];
        if(toCastID > 0) return YES;
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_Channeling Buffer: (Byte *)&channelID BufLength: sizeof(channelID)];
        if(channelID > 0) return YES;
        
        /*
        if( (toCastID > 0) || (castID > 0) || (channelID > 0) ) { // (value == 0x500) || (value == 0x80500)
            // 500 means we might be casting or within the GCD
            // 500 is also returned under other circumstances, but let's not go there (/lie)
            // sometimes it's simply 0x500, moreoften 0x80500
            // 0x90500 seems to be the default state, but often isn't (wtf)
            // 0x--100 on a gryphon
            PGLog(@"toCast = %d, castID = %d, channelID = %d", toCastID, castID, channelID);
            return YES;
        }*/
    }
    return NO;
    
    // below is the old way I did it using the static casting table
    /* 0xC8E5A0 (BASE ADDRESS)
     0x00 - playerID (64bits)
     0x08 - playerID if casting/targeting, 0 otherwise (64bit)
     0x0C - ^^ also while waiting server response
     0x10 - last/current spell cast
     0x14 - spell type
        0x00 instant, none
        0x20000 single target,
        0x40000 targeted AOE
        0x8000000 gathering?    (spellID 2366 is gathering)
        evocation does nothing
     0x18 - targetID (64bit)
     0x1C - (same)
     ...
     0x3C - xLoc of targeted AOE
     0x40 - yLoc
     0x44 - zLoc */
    
}

- (BOOL)isChanneling {
    MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory) {
        UInt32 value = 0;
        if([memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_Channeling Buffer: (Byte *)&value BufLength: sizeof(value)] && value)
            return YES;
    }
    return NO;
}

- (UInt32)spellCasting {
    MemoryAccess *memory = [controller wowMemoryAccess];
    if([self isCasting] && memory) {
        UInt32 value = 0;
        // we have started to cast a spell, but are awaiting server response
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_ToCast Buffer: (Byte *)&value BufLength: sizeof(value)];
        if(value)   return value;
        
        // we are actually casting a spell
        value = 0;
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_Casting Buffer: (Byte *)&value BufLength: sizeof(value)];
        if(value) return value;
        
        // we are chanelling a spell
        value = 0;
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_Channeling Buffer: (Byte *)&value BufLength: sizeof(value)];
        if(value) return value;
    }
    return 0;
}

- (float)castTime {
    
    MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory && [self isCasting]) {
        UInt32 timeEnd = 0, timeStart = 0;
        if( [self isChanneling] ) {
            [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_ChannelTimeEnd Buffer: (Byte *)&timeEnd BufLength: sizeof(timeEnd)];
            [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_ChannelTimeStart Buffer: (Byte *)&timeStart BufLength: sizeof(timeStart)];
        } else {
            [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_TimeEnd Buffer: (Byte *)&timeEnd BufLength: sizeof(timeEnd)];
            [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_TimeStart Buffer: (Byte *)&timeStart BufLength: sizeof(timeStart)];
        }
        float time = (timeEnd - timeStart) / 1000.0f;
        return time;
    }
    return 0.0f;
}

- (float)castTimeRemaining {
    MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory && [self isCasting]) {
        // get the current time, according to the game
        UInt32 currentTime = [self currentTime];
        
        // check to see if we're casting
        UInt32 endTime = 0;
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_TimeEnd Buffer: (Byte *)&endTime BufLength: sizeof(endTime)];
        if(endTime) { // we are casting and it has a designated end time
            //PGLog(@"[cast] %d vs. %d", endTime, currentTime);
            if(endTime >= currentTime) {
                //PGLog(@"[cast] %f", ((endTime - currentTime) / 1000.0f));
                return ((endTime - currentTime) / 1000.0f);
            }
        }
        
        // check to see if we're chaneling
        endTime = 0;
        [memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Spell_ChannelTimeEnd Buffer: (Byte *)&endTime BufLength: sizeof(endTime)];
        if(endTime) { // we are chanelling and it has a designated end time
            if(endTime >= currentTime)
                return ((endTime - currentTime) / 1000.0f);
        }
    }
    // PGLog(@"nothing from castTimeRemaining");
    return 0;
}

- (UInt32)currentTime {
    UInt32 currentTime = 0;
    MemoryAccess *memory = [controller wowMemoryAccess];
    if([memory loadDataForObject: self atAddress: [self baselineAddress] + BaseField_Player_CurrentTime Buffer: (Byte *)&currentTime BufLength: sizeof(currentTime)] && currentTime) {
        return currentTime;
    }
    return 0;
}

- (UInt32)level {
    UInt32 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self infoAddress] + UnitField_Level) Buffer: (Byte *)&value BufLength: sizeof(value)] && value) {
        return value;
    }
    return 0;
}

- (UInt32)factionTemplate {
    UInt32 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self infoAddress] + UnitField_FactionTemplate) Buffer: (Byte *)&value BufLength: sizeof(value)] && value) {
        return value;
    }
    return 0;
}

#pragma mark -

- (IBAction)setPlayerDirectionInMemory: (id)sender {
    if([self playerIsValid]) {
        [self setHorizontalDirectionFacing: 6.28319f - [sender floatValue]];
    }
}

- (IBAction)showPlayerStructure: (id)sender {
    
    //PGLog(@"%@", NSStringFromPoint(NSPointFromCGPoint([controller screenPointForGamePosition: [self position]])));
    
    [memoryViewController showObjectMemory: [self player]];
    [controller showMemoryView];
    /*
     NSNumber *structAddr = [self structureAddress];
    UInt32 structStart = [structAddr unsignedIntValue], structEnd = 0;
    
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: (structStart + OBJECT_FIELDS_END_PTR) Buffer: (Byte*)&structEnd BufLength: sizeof(structEnd)] && structEnd && (structEnd > structStart) ) {
        [memoryViewController setBaseAddress: structAddr withCount: (structEnd - structStart)/4];
        [memoryViewController setCallback: self];
        [controller showMemoryView];
    } else {
        NSBeep();
    }*/
}

- (IBAction)showAuraWindow: (id)sender {
    [[AuraController sharedController] showAurasPanel];
}

#pragma mark -


- (void)refreshPlayerData {
    
    MemoryAccess *memory = [controller wowMemoryAccess];
    if( memory && [self playerIsValid] ) {  // ([botController isBotting] || [[self view] superview]) && 
        
        Player *player = [self player];
        
        // the stance value doesn't seem to exist in 3.0.8
        /*UInt32 stance = [player currentStance];
        if(stance) {
            Spell *stanceSpell = [[SpellController sharedSpells] spellForID: [NSNumber numberWithUnsignedInt: stance]];
            if(stanceSpell.name) {
                [stanceText setStringValue: [NSString stringWithFormat: @"%@ (%d)", stanceSpell.name, stance]];
            } else {
                [stanceText setStringValue: [NSString stringWithFormat: @"%d", stance]];
            }
        } else {
            [stanceText setStringValue: @"No stance detected."];
        }*/
        
        // load health
        [self setHealth: [player currentHealth]];
        [self setMaxHealth: [player maxHealth]];
        
        // load mana
        [self setMana: [player currentPower]];
        [self setMaxMana: [player maxPower]];
        
        switch([player powerType]) {
            case UnitPower_Mana:        [powerNameText setStringValue: @"Mana:"];   break;
            case UnitPower_Rage:        [powerNameText setStringValue: @"Rage:"];   break;
            case UnitPower_Focus:       [powerNameText setStringValue: @"Focus:"];  break;
            case UnitPower_Energy:      [powerNameText setStringValue: @"Energy:"]; break;
            case UnitPower_Happiness:   [powerNameText setStringValue: @"Happiness:"]; break;
            case UnitPower_RunicPower:  [powerNameText setStringValue: @"Runic Power:"]; break;
            default:                    [powerNameText setStringValue: @"Power:"];  break;
        }
        
        // check pet
        if( self.pet && (![self.pet isValid] || ([player petGUID] == 0))) {
            self.pet = nil;
            PGLog(@"[Player] Pet is no longer valid.");
        }
        
        // player has a pet, but we don't know which mob it is
        if( !self.pet && [player hasPet]) {
            GUID playerGUID = [player GUID];
            Mob *pet = [[MobController sharedController] mobWithGUID: [player petGUID]];
            
            // this mob is really our pet, right?
            if( [pet isValid] && ((playerGUID == [pet summonedBy]) || (playerGUID == [pet createdBy]) || (playerGUID == [pet charmedBy]))) {
                self.pet = pet;
                PGLog(@"[Player] Found pet: %@", pet);
            } else {
                // [[MobController sharedController] enumerateAllMobs];
            }
        }
        
        int level = [self level];
        if(savedLevel == 0) {
            savedLevel = level;
        } else {
            if(level == (savedLevel+1)) {
                PGLog(@"[Player] Level up! You have reached level %d", level);
                savedLevel = level;
                
                if( [controller sendGrowlNotifications] && [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
                    // [GrowlApplicationBridge setGrowlDelegate: @""];
                    [GrowlApplicationBridge notifyWithTitle: @"Level up!"
                                                description: [NSString stringWithFormat: @"You have reached level %d.", level]
                                           notificationName: @"PlayerLevelUp"
                                                   iconData: [[NSImage imageNamed: @"Ability_Warrior_Revenge"] TIFFRepresentation]
                                                   priority: 0
                                                   isSticky: NO
                                               clickContext: nil];             
                }
                
                [self willChangeValueForKey: @"playerHeader"];
                [self didChangeValueForKey: @"playerHeader"];
            }
        }
        
        
        // check to see if we recently died
        if( !self.wasDead && [self isDead]) {
            [self willChangeValueForKey: @"isDead"];
            if([self health] == 0) {
                self.deathPosition = [self position];
            } else {
                self.deathPosition = nil;
            }
            self.wasDead = YES;
            [self didChangeValueForKey: @"isDead"];
            // NSLog(@"Player has died.");
            [[NSNotificationCenter defaultCenter] postNotificationName: PlayerHasDiedNotification object: nil];
        }
        
        if( self.wasDead && ![self isDead]) {
            [self willChangeValueForKey: @"isDead"];
            self.deathPosition = nil;
            [self didChangeValueForKey: @"isDead"];
            self.wasDead = NO;
            
            // NSLog(@"Player has revived.");
            [[NSNotificationCenter defaultCenter] postNotificationName: PlayerHasRevivedNotification object: nil];
        }
        
        // position X
        Position *position = [self position];
        if(position) {
            self.xPosition = [position xPosition];
            self.yPosition = [position yPosition];
            self.zPosition = [position zPosition];
        }
        
        // player speed
        [self willChangeValueForKey: @"speed"];
        [self didChangeValueForKey: @"speed"];
        
        // player speed max
        [self willChangeValueForKey: @"speedMax"];
        [self didChangeValueForKey: @"speedMax"];
        
        // player direction
        [self willChangeValueForKey: @"directionFacing"];
        [self didChangeValueForKey: @"directionFacing"];
        
        // get target ID
        UInt64 targetID = [self targetID];
        if(_lastTargetID != targetID) {
            [self willChangeValueForKey: @"targetID"];
            [self didChangeValueForKey: @"targetID"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName: PlayerChangedTargetNotification object: nil];
            _lastTargetID = targetID;
        }
        
        // update casting binds
        [self willChangeValueForKey: @"castTime"];
        [self didChangeValueForKey: @"castTime"];
        
        [self willChangeValueForKey: @"castTimeRemaining"];
        [self didChangeValueForKey: @"castTimeRemaining"];
        
        [self willChangeValueForKey: @"spellCasting"];
        [self didChangeValueForKey: @"spellCasting"];
        
        // check combat flags
        BOOL combatState = [self isInCombat];
        if( !_lastCombatState && combatState) {
            // we were not in combat, now we are
            //PGLog(@"------ Player Entering Combat ------");
            //[[NSNotificationCenter defaultCenter] postNotificationName: PlayerEnteringCombatNotification object: nil];
            [combatController playerEnteringCombat];
        }
        if( _lastCombatState && !combatState) {
            // we were in combat, now we are not
            //[[NSNotificationCenter defaultCenter] postNotificationName: PlayerLeavingCombatNotification object: nil];
            [combatController playerLeavingCombat];
        }
        _lastCombatState = combatState;
        
        
    }
    [self performSelector: @selector(refreshPlayerData) withObject: nil afterDelay: _updateFrequency];
}



@end
