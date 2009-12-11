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
#import "BotController.h"
#import "NodeController.h"
#import "OffsetController.h"
#import "MobController.h"

#import "Spell.h"
#import "Player.h"
#import "Position.h"

#import "ImageAndTextCell.h"

#import <Growl/GrowlApplicationBridge.h>

#define StrandGateOfTheBlueSapphire		190724
#define StrandGateOfTheGreenEmerald		190722

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
           
		_combatDataList = [[NSMutableArray array] retain];
		
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
	
	[combatTable setDoubleAction: @selector(combatTableDoubleClick:)];
    
    float freq = [[NSUserDefaults standardUserDefaults] floatForKey: @"PlayerUpdateFrequency"];
    if(freq <= 0.0f) freq = 0.35;
    self.updateFrequency = freq;
	
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
    [imageAndTextCell setEditable: NO];
    [[combatTable tableColumnWithIdentifier: @"Class"] setDataCell: imageAndTextCell];
    [[combatTable tableColumnWithIdentifier: @"Race"] setDataCell: imageAndTextCell];
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
    if( [self playerIsValid:self]  ) {
		unsigned long offset = [offsetController offset:@"PLAYER_NAME_STATIC"];
        // get the player name if we can
        NSString *playerName = nil;
        if( offset ) {
            char name[13];
            name[12] = 0;
            if([[controller wowMemoryAccess] loadDataForObject: self atAddress: offset Buffer: (Byte *)&name BufLength: sizeof(name)-1]) {
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
	unsigned long offset = [offsetController offset:@"LAST_RED_ERROR_MESSAGE"];
    if( offset ) {
        char str[100];
        str[99] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: offset Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
            NSString *string = [NSString stringWithUTF8String: str];
            if([string length]) {
                return string;
            }
        }
    }
    return @"";
}

- (NSString*)playerName {
	unsigned long offset = [offsetController offset:@"PLAYER_NAME_STATIC"];
    if( offset ) {
        char str[13];
        str[12] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: offset Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
            NSString *string = [NSString stringWithUTF8String: str];
            if([string length]) {
                return string;
            }
        }
    }
    return @"";
}

- (NSString*)accountName {
	unsigned long offset = [offsetController offset:@"ACCOUNT_NAME_STATIC"];
    if( offset ) {
        char str[33];
        str[32] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: offset Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
            NSString *string = [NSString stringWithUTF8String: str];
            if([string length]) {
                return string;
            }
        }
    }
    return @"";
}

- (NSString*)serverName {
	unsigned long offset = [offsetController offset:@"SERVER_NAME_STATIC"];
    if( offset ) {
        char str[33];
        str[32] = 0;
        if([[controller wowMemoryAccess] loadDataForObject: self atAddress: offset Buffer: (Byte *)&str BufLength: sizeof(str)-1]) {
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

- (BOOL)playerIsValid{
	//PGLog(@"UI UI UI");
	return [self playerIsValid:nil];	
}
// 4 reads
//  could take this down to 3 if we store the global GUID somewhere + ONLY reset when player is invalid
- (BOOL)playerIsValid: (id)sender {
    // check that our so-called player struct has the correct signature
    MemoryAccess *memory = [controller wowMemoryAccess];
    
    // load the following:
    //  global GUID
    //  our GUID
    //  previous pointer
    // then compare GUIDs and validate previous pointer is valid
    
    UInt32 selfGUID = 0, previousPtr = 0, objectType = 0;
	UInt64 globalGUID = 0;
    [memory loadDataForObject: self atAddress: [offsetController offset:@"PLAYER_GUID_STATIC"] Buffer: (Byte*)&globalGUID BufLength: sizeof(globalGUID)];
    [memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_GUID_LOW32) Buffer: (Byte*)&selfGUID BufLength: sizeof(selfGUID)];
	[memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_STRUCT3_POINTER) Buffer: (Byte*)&previousPtr BufLength: sizeof(previousPtr)];
	[memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_TYPE_ID) Buffer: (Byte*)&objectType BufLength: sizeof(objectType)];
	
	// is the player still valid?
    if ( GUID_LOW32(globalGUID) == selfGUID && objectType == TYPEID_PLAYER && previousPtr > 0x0 ) {
		if ( !_lastState ) {
			PGLog(@"[Player] Player is valid. %@", [sender class]);
			[self loadState];
		}
		return YES;
	}

    if ( _lastState ) {
        PGLog(@"[Player] Player is invalid. %@", [sender class]);
        [self resetState];
    }
    return NO;
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
	
	//[[NSNotificationCenter defaultCenter] postNotificationName: PlayerIsInvalidNotification object: nil];		// moved this to in controller.m when we CANNOT find a player - doesn't belong here!
}

// before we get here we've made the following comparisons:
//	playerIsValid:
//		GUID > 0
//		guid == playerGUID
//		PreviousPtr > 0
//		object type == TYPEID_PLAYER
//	setStructureAddress (from [controller sortObjects])
//		GUID > 0
//		guid == playerGUID
// so lets ONLY compare the type! (since it wasn't done in playerIsValid, but WAS done in sortObjects)
// 2 reads
- (void)loadState {
    // load player info: info sub-struct, signature, and playerID
    MemoryAccess *memory = [controller wowMemoryAccess];
    UInt32 objectType = 0, playerAddress = 0;
    if(memory && _baselineAddress && [self baselineAddress]) {
        [memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_TYPE_ID) Buffer: (Byte*)&objectType BufLength: sizeof(objectType)];
        [memory loadDataForObject: self atAddress: ([self baselineAddress] + OBJECT_FIELDS_PTR) Buffer: (Byte*)&playerAddress BufLength: sizeof(playerAddress)];
		PGLog(@"[PlayerData] Type: %d Address: 0x%X  BaselineAddress: 0x%X", objectType, playerAddress, [self baselineAddress]);
    }
	
	PGLog(@"loading state...");
    
    // if we got a ~~~~
    // 1) valid player address
    // 2) the player signature is correct
    // 3) we have a real baseline address
    // 4) and a real player ID
    // ... then we're good to go.
    if(playerAddress && (objectType == TYPEID_PLAYER)) {
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
        
		PGLog(@"[PlayerData] Sending player is valid notification!");
        [[NSNotificationCenter defaultCenter] postNotificationName: PlayerIsValidNotification object: nil];
        
        // and start the update process
        [self performSelector: @selector(refreshPlayerData) withObject: nil afterDelay: _updateFrequency];
        return;
    }
    
    PGLog(@"Error: Attemping to load invalid player; bailing. Address: 0x%X Type: %d", playerAddress, objectType);
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

- (UInt32)lowGUID {
    UInt32 value = 0;
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
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([offsetController offset:@"COMBO_POINTS_STATIC"]) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
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
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([offsetController offset:@"PLAYER_IN_BUILDING_STATIC"]) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
        return (value == 1);
    }
    return NO;
}

- (BOOL)isOutdoors {
    return ![self isIndoors];
}

- (BOOL)isOnGround {
	
	// Player is in the air!
	if ( ( [self movementFlags] & 0x3000000) == 0x3000000 || ( [self movementFlags] & 0x1000) == 0x1000 ){
		return NO;
	}
	
	return YES;
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

- (void)setMovementFlags:(UInt32)movementFlags {
    [[controller wowMemoryAccess] saveDataForAddress: ([self baselineAddress] + BaseField_MovementFlags) Buffer: (Byte*)&movementFlags BufLength: sizeof(movementFlags)];
}

// 1 read
- (UInt32)movementFlags {
    UInt32 value = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self baselineAddress] + BaseField_MovementFlags) Buffer: (Byte*)&value BufLength: sizeof(value)];
    return value;
}

// 1 read
- (UInt64)movementFlags64 {
    UInt64 value = 0;
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

// 1 read
- (UInt32)copper {
	UInt32 value = 0;
	[[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self infoAddress] + PlayerField_Coinage) Buffer: (Byte*)&value BufLength: sizeof(value)];
	return value;
}

// 1 read
- (UInt32)honor {
	UInt32 value = 0;
	[[controller wowMemoryAccess] loadDataForObject: self atAddress: ([self infoAddress] + PlayerField_Coinage) Buffer: (Byte*)&value BufLength: sizeof(value)];
	return value;
}

// 1 read, 2 writes
- (void)faceToward: (Position*)position {
    if([self playerIsValid:self]) {
        Position *ourPosition = [self position];
        [self setHorizontalDirectionFacing: [ourPosition angleTo: position]];
        [self setVerticalDirectionFacing: [ourPosition verticalAngleTo: position]];
    }
}

// 1 write
- (void)trackResources: (int)resource{
	MemoryAccess *memory = [controller wowMemoryAccess];
	[memory saveDataForAddress: ([self infoAddress] + PlayerField_TrackResources) Buffer: (Byte *)&resource BufLength: sizeof(resource)];
}

#pragma mark Player Targeting

- (BOOL)setTarget: (UInt64)targetID{
	
	
	MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory && [self playerIsValid]) {
        BOOL ret1, ret3;
        // save this value to the target table
        ret1 = [memory saveDataForAddress: ([offsetController offset:@"TARGET_TABLE_STATIC"] + TARGET_CURRENT) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)];
        //ret2 = [[self wowMemory] saveDataForAddress: self atAddress: ([offsetController offset:@"TARGET_TABLE_STATIC"] + TARGET_MOUSEOVER) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)];
        
        // and to the player table
        ret3 = [memory saveDataForAddress: ([self infoAddress] + UnitField_Target) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)];
		
        if(ret1 && ret3)    
            return YES;
        else
            return NO;
    }
    return NO;
	
}

- (BOOL)setPrimaryTarget: (WoWObject*)target {
	
	// is target valid
	if ( !target || ![target isValid] ){
		PGLog(@"[Player] Unable to target %@", target);
		[mobController clearTargets];
		return [self setTarget:0];
	}
	
	// need to make sure we hit the mob selection variable as well!
	if ( [target isNPC] ){
		Mob *mob = (Mob*)target;
		[mob select];			
	}
	
	return [self setTarget:[target GUID]];
}


- (BOOL)setMouseoverTarget: (UInt64)targetID {
    if([self playerIsValid:self]) {
        // save this value to the target table
        if([[controller wowMemoryAccess] saveDataForAddress: ([offsetController offset:@"TARGET_TABLE_STATIC"] + TARGET_MOUSEOVER) Buffer: (Byte *)&targetID BufLength: sizeof(targetID)])
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
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([offsetController offset:@"TARGET_TABLE_STATIC"] + TARGET_INTERACT) Buffer: (Byte*)&value BufLength: sizeof(value)] && value) {
        return value;
    }
    return 0;
}

- (UInt64)focusGUID {
    UInt64 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([offsetController offset:@"TARGET_TABLE_STATIC"] + TARGET_FOCUS) Buffer: (Byte*)&value BufLength: sizeof(value)] && value) {
        return value;
    }
    return 0;
}

- (UInt64)mouseoverID {
    UInt64 value = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: ([offsetController offset:@"TARGET_TABLE_STATIC"] + TARGET_MOUSEOVER) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (UInt64)comboPointUID {
    UInt64 value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: ([offsetController offset:@"COMBO_POINTS_STATIC"] + COMBO_POINT_TARGET_UID) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
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

- (int)haste {
    MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory) {
        UInt32 value = 0;
        if([memory loadDataForObject: self atAddress: [self baselineAddress] + PlayerField_Haste Buffer: (Byte *)&value BufLength: sizeof(value)] && value)
            return value;
    }
    return 0;
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
    if([self playerIsValid:self]) {
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

- (IBAction)showCooldownWindow: (id)sender {
	[spellController showCooldownPanel];
}

#pragma mark -


- (void)refreshPlayerData {
    
    MemoryAccess *memory = [controller wowMemoryAccess];
    if( memory && [self playerIsValid:self] ) {  // ([botController isBotting] || [[self view] superview]) && 
        
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
            PGLog(@"[PlayerData] ------ Player Entering Combat ------");
            [[NSNotificationCenter defaultCenter] postNotificationName: PlayerEnteringCombatNotification object: nil];
        }
        if( _lastCombatState && !combatState) {
            // we were in combat, now we are not
			PGLog(@"[PlayerData] ------ Player Leaving Combat ------");
            [[NSNotificationCenter defaultCenter] postNotificationName: PlayerLeavingCombatNotification object: nil];
        }
        _lastCombatState = combatState;
		
		// Lets see which mobs are attacking us!
		if ( combatState ){
			[combatController doCombatSearch];
		}
		
		[_combatDataList removeAllObjects];
		
		// only resort and display the table if the window is visible
		if( [[combatTable window] isVisible]) {
			
			NSArray *units = [combatController unitsAttackingMe];
			NSArray *attackQueue = [combatController attackQueue];
			NSMutableArray *allUnits = [NSMutableArray array];
			[allUnits addObjectsFromArray:units];

			// Only add new units!
			for(Unit *unit in attackQueue){
				if ( ![allUnits containsObject:unit] ){
					[allUnits addObject:unit];
				}
			}
			
			for(Unit *unit in allUnits) {
				if( ![unit isValid] )
					continue;
				
				float distance = [[self position] distanceToPosition: [unit position]];
				unsigned level = [unit level];
				if(level > 100) level = 0;
				int weight = [combatController unitWeight: unit PlayerPosition:[self position]];
				
				[_combatDataList addObject: [NSDictionary dictionaryWithObjectsAndKeys: 
											 unit,                                                                @"Player",
											 [NSString stringWithFormat: @"0x%X", [unit lowGUID]],                @"ID",
											 [NSString stringWithFormat: @"%@%@", [unit isPet] ? @"[Pet] " : @"", [Unit stringForClass: [unit unitClass]]],                             @"Class",
											 [Unit stringForRace: [unit race]],                                   @"Race",
											 [NSString stringWithFormat: @"%d%%", [unit percentHealth]],          @"Health",
											 [NSNumber numberWithUnsignedInt: level],                             @"Level",
											 [NSNumber numberWithFloat: distance],                                @"Distance", 
											 [NSNumber numberWithInt:weight],									  @"Weight",
											 nil]];
			}
			
			// Update our combat table!
			[_combatDataList sortUsingDescriptors: [combatTable sortDescriptors]];
			[combatTable reloadData];
			
			
			// Update healing info!
			NSArray *unitsToHeal = [botController availableUnitsToHeal];
			for(Unit *unit in unitsToHeal) {
				if( ![unit isValid] )
					continue;
				
				float distance = [[self position] distanceToPosition: [unit position]];
				[_healingDataList addObject: [NSDictionary dictionaryWithObjectsAndKeys: 
											 unit,                                                                @"Player",
											 [NSString stringWithFormat: @"0x%X", [unit lowGUID]],                @"ID",
											 [NSString stringWithFormat: @"%@%@", [unit isPet] ? @"[Pet] " : @"", [Unit stringForClass: [unit unitClass]]],                             @"Class",
											 [Unit stringForRace: [unit race]],                                   @"Race",
											 [Unit stringForGender: [unit gender]],                               @"Gender",
											 [NSString stringWithFormat: @"%d%%", [unit percentHealth]],          @"Health",
											 [NSNumber numberWithUnsignedInt: [unit level]],                      @"Level",
											 [NSNumber numberWithFloat: distance],                                @"Distance", 
											 nil]];
			}
			
			// Update our combat table!
			[_healingDataList sortUsingDescriptors: [healingTable sortDescriptors]];
			[healingTable reloadData];
			
			// Update our CD info!
			[spellController reloadCooldownInfo];
		}
		
		// Update our bot timer!
		[botController updateRunningTimer];
    }
    [self performSelector: @selector(refreshPlayerData) withObject: nil afterDelay: _updateFrequency];
}

-(Position*)corpsePosition{
	 MemoryAccess *memory = [controller wowMemoryAccess];
	
	float pos[3] = {-1.0f, -1.0f, -1.0f };
	if([memory loadDataForObject: self atAddress: [offsetController offset:@"CORPSE_POSITION_STATIC"] Buffer: (Byte *)&pos BufLength: sizeof(float)*3])
		return [Position positionWithX: pos[0] Y: pos[1] Z: pos[2]];
	return nil;
}

- (UInt32)zone{
	UInt32 zone = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: [offsetController offset:@"PLAYER_CURRENT_ZONE"] Buffer: (Byte *)&zone BufLength: sizeof(zone)];
	return zone;
}

- (int)battlegroundStatus{
	UInt32 status = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: [offsetController offset:@"BATTLEGROUND_STATUS"] + BG_STATUS Buffer: (Byte *)&status BufLength: sizeof(status)];
	
	if ( status < BGNone || status > BGActive )
		return -1;
	
	return status;	
}

- (BOOL)isInBG:(int)zone{
	switch(zone){
		case 4384:	// Strand of the Ancients
		case 3358:	// Arathi Basin
		case 3277:	// Warsong Gulch
		case 2597:	// Alterac Valley
		case 3820:	// Eye of the Storm
		case 4710:	// Isle of Conquest
			return YES;
		default:
			return NO;
	}
	return NO;
}

// the graceful maiden - right boat
// the frostbreaker - left boat
#define StrandPrivateerZierhut			32658		// right boat
#define StrandPrivateerStonemantle		32657		// left boat
- (BOOL)isOnRightBoatInStrand{
	
	// not on a boat
	if ( ![self isOnBoatInStrand] )
		return NO;
	
	if ( [[mobController mobsWithinDistance:50.0f	// actual value is around 35.0f
									MobIDs:[NSArray arrayWithObject:[NSNumber numberWithInt:StrandPrivateerZierhut]]
								  position: [[self player] position]
								 aliveOnly:NO] count] ){
		return YES;
	}
	
	return NO;
	
}

- (BOOL)isOnLeftBoatInStrand{
	
	// not on a boat
	if ( ![self isOnBoatInStrand] )
		return NO;
	
	if ( [[mobController mobsWithinDistance:50.0f 
									 MobIDs:[NSArray arrayWithObject:[NSNumber numberWithInt:StrandPrivateerStonemantle]]
								   position: [[self player] position]
								  aliveOnly:NO] count]){
		return YES;
	}
	
	return NO;	
}

- (BOOL)isOnBoatInStrand{
	Position *playerPos = [self position];
	
	// Verify x
	if ( playerPos.xPosition > -20.0f && playerPos.xPosition < 20.0f ){				// Really -16 < x < 16		when on the ramp:	6
		if ( playerPos.yPosition > -15.0f && playerPos.yPosition < 15.0f ){			// Really -9 < y < 9							14
			if ( playerPos.zPosition > -15.0f && playerPos.zPosition < 15.0f ){		// Really -10 < z < 10							5
				return YES;
			}
		}
	}
	
	return NO;
}

#pragma mark -
#pragma mark TableView Delegate & Datasource

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
	[aTableView reloadData];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	if ( aTableView == combatTable ){
		return [_combatDataList count];
	}
	
	return [[botController availableUnitsToHeal] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	if ( aTableView == combatTable ){
		if(rowIndex == -1 || rowIndex >= [_combatDataList count]) return nil;
		
		if([[aTableColumn identifier] isEqualToString: @"Distance"])
			return [NSString stringWithFormat: @"%.2f", [[[_combatDataList objectAtIndex: rowIndex] objectForKey: @"Distance"] floatValue]];
		
		if([[aTableColumn identifier] isEqualToString: @"Status"]) {
			NSString *status = [[_combatDataList objectAtIndex: rowIndex] objectForKey: @"Status"];
			if([status isEqualToString: @"1"])  status = @"Combat";
			if([status isEqualToString: @"2"])  status = @"Hostile";
			if([status isEqualToString: @"3"])  status = @"Dead";
			if([status isEqualToString: @"4"])  status = @"Neutral";
			if([status isEqualToString: @"5"])  status = @"Friendly";
			return [NSImage imageNamed: status];
		}
		
		return [[_combatDataList objectAtIndex: rowIndex] objectForKey: [aTableColumn identifier]];
	}
	else if ( aTableView == healingTable ){
		if(rowIndex == -1 || rowIndex >= [_healingDataList count]) return nil;
		
		if([[aTableColumn identifier] isEqualToString: @"Distance"])
			return [NSString stringWithFormat: @"%.2f", [[[_healingDataList objectAtIndex: rowIndex] objectForKey: @"Distance"] floatValue]];
		
		return [[_healingDataList objectAtIndex: rowIndex] objectForKey: [aTableColumn identifier]];
	}
	
	return nil;
}

- (void)tableView: (NSTableView *)aTableView willDisplayCell: (id)aCell forTableColumn: (NSTableColumn *)aTableColumn row: (int)aRowIndex{
	
	if ( aTableView == combatTable ){
		if( aRowIndex == -1 || aRowIndex >= [_combatDataList count]) return;
		
		if ([[aTableColumn identifier] isEqualToString: @"Race"]) {
			[(ImageAndTextCell*)aCell setImage: [[_combatDataList objectAtIndex: aRowIndex] objectForKey: @"RaceIcon"]];
		}
		if ([[aTableColumn identifier] isEqualToString: @"Class"]) {
			[(ImageAndTextCell*)aCell setImage: [[_combatDataList objectAtIndex: aRowIndex] objectForKey: @"ClassIcon"]];
		}
		
		// do text color
		if( ![aCell respondsToSelector: @selector(setTextColor:)] ){
			PGLog(@"can't do color :(");
			return;
		}
		
		if ( [[_combatDataList objectAtIndex: aRowIndex] objectForKey: @"Player"] == [combatController attackUnit] ){
			[aCell setTextColor: [NSColor redColor]];
			return;
		}
		
		[aCell setTextColor: [NSColor darkGrayColor]];
	}
	else if ( aTableView == healingTable ){
		// do text color
		if( ![aCell respondsToSelector: @selector(setTextColor:)] ){
			PGLog(@"can't do color :(");
			return;
		}
		
		if ( [[_combatDataList objectAtIndex: aRowIndex] objectForKey: @"Player"] == [combatController attackUnit] ){
			[aCell setTextColor: [NSColor greenColor]];
			return;
		}
		
		[aCell setTextColor: [NSColor darkGrayColor]];
	}
	
	return;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return NO;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectTableColumn:(NSTableColumn *)aTableColumn {
    if( [[aTableColumn identifier] isEqualToString: @"RaceIcon"])
        return NO;
    if( [[aTableColumn identifier] isEqualToString: @"ClassIcon"])
        return NO;
    return YES;
}

- (void)combatTableDoubleClick: (id)sender {
    //if( [sender clickedRow] == -1 || [sender clickedRow] >= [[combatController unitsAttackingMe] count] ) return;
	
	//PGLog(@"[Bot] Doublie clicked!");
    
    //[memoryViewController showObjectMemory: [[[combatController combatUnits] objectAtIndex: [sender clickedRow]] objectForKey: @"Player"]];
    //[controller showMemoryView];
}

/*
 [StructLayout(LayoutKind.Sequential)]
 public struct ClickToMoveInfoStruct
 {
 public float Unknown1F;
 public float TurnScale;
 public float Unknown2F;
 
 /// <summary>
 /// This can be left alone. There is no need to write to it!!
 /// </summary>
 public float InteractionDistance;
 
 public float Unknown3F;
 public float Unknown4F;
 public uint Unknown5U;
 
 /// <summary>
 /// As per the ClickToMoveAction enum members.
 /// </summary>
 public uint ActionType;
 
 public ulong InteractGuid;
 
 /// <summary>
 /// Check == 2 (This might be some sort of flag?)
 /// Always 2 when using some form of CTM action. 0 otherwise.
 /// </summary>
 public uint IsClickToMoving;
 
 [MarshalAs(UnmanagedType.ByValArray, SizeConst = 21)]
 public uint[] Unknown6U;
 
 /// <summary>
 /// This will change in memory as WoW figures out where exactly we're going to stop. (Also the actual end location)
 /// </summary>
 public Point Dest;
 
 /// <summary>
 /// This is wherever we actually 'clicked' in game.
 /// </summary>
 public Point Click;
 
 /// <summary>
 /// Returns the fully qualified type name of this instance.
 /// </summary>
 /// <returns>
 /// A <see cref="T:System.String"/> containing a fully qualified type name.
 /// </returns>
 /// <filterpriority>2</filterpriority>
 public override string ToString()
 {
 string tmp = "";
 for (int i = 0; i < Unknown6U.Length; i++)
 {
 tmp += "Unknown6U_" + i + ": " + Unknown6U[i].ToString("X") + ", ";
 }
 return
 string.Format(
 "TurnScale: {0}, InteractionDistance: {1}, ActionType: {2}, InteractGuid: {3}, IsClickToMoving: {4}, ClickX: {5}, ClickY: {6}, ClickZ: {7}, DestX: {8}, DestY: {9}, DestZ: {10}, Unk4f: {12}, UNK: {11}",
 TurnScale, InteractionDistance, (ClickToMoveType) ActionType, InteractGuid.ToString("X"),
 IsClickToMoving == 2, Click.X, Click.Y, Click.Z, Dest.X, Dest.Y, Dest.Z, tmp, Unknown4F);
 }
 }
*/ 
@end
