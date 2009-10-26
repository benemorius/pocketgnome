//
//  SpellController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/20/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>

#import "SpellController.h"
#import "Controller.h"
#import "Offsets.h"
#import "Spell.h"
#import "PlayerDataController.h"
#import "OffsetController.h"

#pragma mark Note: LastSpellCast/Timer Disabled
#pragma mark -

/*
 #define CD_NEXT_ADDRESS	0x4
 #define CD_SPELLID		0x8
 #define CD_COOLDOWN		0x14
 #define CD_COOLDOWN2	0x20
 #define CD_ENABLED		0x24
 #define CD_STARTTIME	0x1C	// Also 0x10
 #define CD_GCD			0x2C	// Also 0x2C
 */
typedef struct WoWCooldown {
	UInt32 unk;					// 0x0
	UInt32 nextObjectAddress;	// 0x4
	UInt32 spellID;				// 0x8
	UInt32 unk3;				// 0xC (always 0 when the spell is a player spell)
	UInt32 startTime;			// 0x10 (start time of the spell, stored in milliseconds)
	long cooldown;				// 0x14
	UInt32 unk4;				// 0x18
	UInt32 startNotUsed;		// 0x1C	(the same as 0x10 always I believe?)
	long cooldown2;				// 0x20
	UInt32 enabled;				// 0x24 (0 if spell is enabled, 1 if it's not)
	UInt32 unk5;				// 0x28
	UInt32 gcd;					// 0x2C
} WoWCooldown;

@interface SpellController (Internal)
- (BOOL)isSpellListValid;
- (void)buildSpellMenu;
- (void)synchronizeSpells;
- (NSArray*)mountsBySpeed: (int)speed;

@end

@implementation SpellController

static SpellController *sharedSpells = nil;

+ (SpellController *)sharedSpells {
	if (sharedSpells == nil)
		sharedSpells = [[[self class] alloc] init];
	return sharedSpells;
}

- (id) init {
    self = [super init];
	if(sharedSpells) {
		[self release];
		self = sharedSpells;
	} else if(self != nil) {
        
		sharedSpells = self;
        
        //_knownSpells = [[NSMutableArray array] retain];
        _playerSpells = [[NSMutableArray array] retain];
		_playerCooldowns = [[NSMutableArray array] retain];
        _cooldowns = [[NSMutableDictionary dictionary] retain];
    
        
        NSData *spellBook = [[NSUserDefaults standardUserDefaults] objectForKey: @"SpellBook"];
        if(spellBook) {
            _spellBook = [[NSKeyedUnarchiver unarchiveObjectWithData: spellBook] mutableCopy];
        } else
            _spellBook = [[NSMutableDictionary dictionary] retain];
        
        // populate known spells array
        //for(Spell *spell in [_spellBook allValues]) {
        //    [_knownSpells addObject: spell];
        //}
        
        // register notifications
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(applicationWillTerminate:) 
                                                     name: NSApplicationWillTerminateNotification 
                                                   object: nil];
                                                   
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(playerIsValid:) 
                                                     name: PlayerIsValidNotification 
                                                   object: nil];
        
        [NSBundle loadNibNamed: @"Spells" owner: self];
    }
    return self;
}

- (void)awakeFromNib {
    self.minSectionSize = [self.view frame].size;
    self.maxSectionSize = [self.view frame].size;
    
}

@synthesize view;
@synthesize selectedSpell;
@synthesize minSectionSize;
@synthesize maxSectionSize;

- (NSString*)sectionTitle {
    return @"Spells";
}

- (void)playerIsValid: (NSNotification*)notification {
    [self reloadPlayerSpells];
    
    int numLoaded = 0;
    for(Spell *spell in [self playerSpells]) {
        if( ![spell name] || ![[spell name] length] || [[spell name] isEqualToString: @"[Unknown]"]) {
            numLoaded++;
            [spell reloadSpellData];
        }
    }
    
    if(numLoaded > 0) {
        // PGLog(@"[Spells] Loading %d unknown spells from wowhead.", numLoaded);
    }
}


- (void)applicationWillTerminate: (NSNotification*)notification {
    [self synchronizeSpells];
}


#pragma mark -
#pragma mark Internal

- (BOOL)isSpellListValid {
    uint32_t value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: [offsetController offset:@"KNOWN_SPELLS_STATIC"] Buffer: (Byte *)&value BufLength: sizeof(value)] && value) {
        return ( (value > 0) && (value < 100000) );
    }
    return NO;
}

- (void)synchronizeSpells {
    [[NSUserDefaults standardUserDefaults] setObject: [NSKeyedArchiver archivedDataWithRootObject: _spellBook] forKey: @"SpellBook"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)reloadPlayerSpells {
    [_playerSpells removeAllObjects];
    MemoryAccess *memory = [controller wowMemoryAccess];
    if( !memory ) return;
    
    int i;
    uint32_t value = 0;

    // scan the list of known spells
    NSMutableArray *playerSpells = [NSMutableArray array];
    if( [playerController playerIsValid:self] && [self isSpellListValid] ) {
        for(i=0; ; i++) {
            // load all known spells into a temp array
            if([memory loadDataForObject: self atAddress: [offsetController offset:@"KNOWN_SPELLS_STATIC"] + (i*4) Buffer: (Byte *)&value BufLength: sizeof(value)] && value) {
                Spell *spell = [self spellForID: [NSNumber numberWithUnsignedInt: value]];
                if( !spell ) {
                    // create a new spell if necessary
                    spell = [Spell spellWithID: [NSNumber numberWithUnsignedInt: value]];
                    [self addSpellAsRecognized: spell];
                }
                [playerSpells addObject: spell];
            } else {
                break;
            }
        }
    }
	
	// scan the list of mounts!
	NSMutableArray *playerMounts = [NSMutableArray array];
	if( [playerController playerIsValid:self] ){
		UInt32 mountAddress = 0;
		
		// grab the pointer to the list
		if([memory loadDataForObject: self atAddress: [offsetController offset:@"MOUNT_LIST_POINTER"] Buffer: (Byte *)&mountAddress BufLength: sizeof(mountAddress)] && mountAddress) {
			
			for(i=0; ; i++) {
				// load all known spells into a temp array
				if([memory loadDataForObject: self atAddress: mountAddress + (i*0x4) Buffer: (Byte *)&value BufLength: sizeof(value)] && value < 100000 && value > 0) {
					Spell *spell = [self spellForID: [NSNumber numberWithUnsignedInt: value]];
					if( !spell ) {
						// create a new spell if necessary
						spell = [Spell spellWithID: [NSNumber numberWithUnsignedInt: value]];
						if ( !spell ){
							PGLog(@"[Spell] Mount %d not found!", value );
							continue;
						}
						[self addSpellAsRecognized: spell];
					}
					[playerMounts addObject: spell];
				} else {
					break;
				}
			}
			
		}
	}
    
    // update list of known spells
    [_playerSpells addObjectsFromArray: playerSpells];
	if ( [playerMounts count] > 0 )
		[_playerSpells addObjectsFromArray: playerMounts];
    [self buildSpellMenu];
}

- (void)buildSpellMenu {
    
    NSMenu *spellMenu = [[[NSMenu alloc] initWithTitle: @"Spells"] autorelease];
    
    // load the player spells into arrays by spell school
    NSMutableDictionary *organizedSpells = [NSMutableDictionary dictionary];
    for(Spell *spell in _playerSpells) {
		
		if ( [spell isMount] ){
			if( ![organizedSpells objectForKey: @"Mount"] )
                [organizedSpells setObject: [NSMutableArray array] forKey: @"Mount"];
            [[organizedSpells objectForKey: @"Mount"] addObject: spell];
		}
        else if([spell school]) {
            if( ![organizedSpells objectForKey: [spell school]] )
                [organizedSpells setObject: [NSMutableArray array] forKey: [spell school]];
            [[organizedSpells objectForKey: [spell school]] addObject: spell];
        } 
		else {
            if( ![organizedSpells objectForKey: @"Unknown"] )
                [organizedSpells setObject: [NSMutableArray array] forKey: @"Unknown"];
            [[organizedSpells objectForKey: @"Unknown"] addObject: spell];
        }
    }
    
    NSMenuItem *spellItem;
    NSSortDescriptor *nameDesc = [[[NSSortDescriptor alloc] initWithKey: @"name" ascending: YES] autorelease];
    for(NSString *key in [organizedSpells allKeys]) {
        // create menu header for spell school name
        spellItem = [[[NSMenuItem alloc] initWithTitle: key action: nil keyEquivalent: @""] autorelease];
        [spellItem setAttributedTitle: [[[NSAttributedString alloc] initWithString: key 
                                                                        attributes: [NSDictionary dictionaryWithObjectsAndKeys: [NSFont boldSystemFontOfSize: 0], NSFontAttributeName, nil]] autorelease]];
        [spellItem setTag: 0];
        [spellMenu addItem: spellItem];
        
        // then, sort the array so its in alphabetical order
        NSMutableArray *schoolArray = [organizedSpells objectForKey: key];
        [schoolArray sortUsingDescriptors: [NSArray arrayWithObject: nameDesc]];
        
        // loop over the array and add in all the spells
        for(Spell *spell in schoolArray) {
            if( [spell name]) {
                spellItem = [[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: @"%@ - %@", [spell fullName], [spell ID] ] action: nil keyEquivalent: @""];
            } else {
                spellItem = [[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: @"%@", [spell ID]] action: nil keyEquivalent: @""];
            }
            [spellItem setTag: [[spell ID] unsignedIntValue]];
            [spellItem setRepresentedObject: spell];
            [spellItem setIndentationLevel: 1];
            [spellMenu addItem: [spellItem autorelease]];
        }
        [spellMenu addItem: [NSMenuItem separatorItem]];
    }
    
    int tagToSelect = 0;
    if( [_playerSpells count] == 0) {
        //for(NSMenuItem *item in [spellMenu itemArray]) {
       //     [spellMenu removeItem: item];
        //}
        spellItem = [[NSMenuItem alloc] initWithTitle: @"There are no available spells." action: nil keyEquivalent: @""];
        [spellItem setTag: 0];
        [spellMenu addItem: [spellItem autorelease]];
    } else {
        tagToSelect = [[spellDropDown selectedItem] tag];
    }
    
    [spellDropDown setMenu: spellMenu];
    [spellDropDown selectItemWithTag: tagToSelect];
}

#pragma mark -

- (Spell*)spellForName: (NSString*)name {
    if(!name || ![name length]) return nil;
    // PGLog(@"Searching for spell \"%@\"", name);
    for(Spell *spell in [_spellBook allValues]) {
        if([spell name]) {
            NSRange range = [[spell name] rangeOfString: name 
                                                options: NSCaseInsensitiveSearch | NSAnchoredSearch | NSDiacriticInsensitiveSearch];
            if(range.location != NSNotFound)
                return spell;
        }
    }
    return nil;
}

- (Spell*)spellForID: (NSNumber*)spellID {
    return [_spellBook objectForKey: spellID];
}

- (Spell*)highestRankOfSpell: (Spell*)incSpell {
    if(!incSpell) return nil;
    
    Spell *highestRankSpell = incSpell;
    for(Spell *spell in [_spellBook allValues]) {
        // if the spell names match
        if([spell name] && [spell rank] && [[spell name] isEqualToString: [incSpell name]]) {
            // see which one has the higher rank
            if( [[spell rank] intValue] > [[highestRankSpell rank] intValue])
                highestRankSpell = spell;
        }
    }
    
    return highestRankSpell;
}

- (Spell*)playerSpellForName: (NSString*)spellName{
	if(!spellName) return nil;

    for(Spell *spell in [self playerSpells]) {
        // if the spell names match
        if([spell name] && [[spell name] isEqualToString: spellName]) {
			return spell;
        }
    }
	
	return nil;	
}

// I really don't like how ugly this function is, if only it was elegant :(
- (Spell*)mountSpell: (int)type andFast:(BOOL)isFast{
	
	NSMutableArray *mounts = [NSMutableArray array];
	if ( type == MOUNT_GROUND ){
		
		// Add fast mounts!
		if ( isFast ){
			[mounts addObjectsFromArray:[self mountsBySpeed:100]];
		}
		
		// We either have no fast mounts, or we didn't even want them!
		if ( [mounts count] == 0 ){
			[mounts addObjectsFromArray:[self mountsBySpeed:60]];	
		}
	}
	else if ( type == MOUNT_AIR ){
		if ( isFast ){
			[mounts addObjectsFromArray:[self mountsBySpeed:310]];
			
			// For most we will be here
			if ( [mounts count] == 0 ){
				[mounts addObjectsFromArray:[self mountsBySpeed:280]];
			}
		}
		
		// We either have no fast mounts, or we didn't even want them!
		if ( [mounts count] == 0 ){
			[mounts addObjectsFromArray:[self mountsBySpeed:150]];	
		}
	}
	
	// Randomly select one from the array!
	if ( [mounts count] > 0 ){
		int randomMount = SSRandomIntBetween(0, [mounts count]-1);
		
		return [mounts objectAtIndex:randomMount];
	}
	
	return nil;
}

- (NSArray*)mountsBySpeed: (int)speed{
	NSMutableArray *mounts = [NSMutableArray array];
	for(Spell *spell in _playerSpells) {
		int s = [[spell speed] intValue];
		if ( s == speed ){
			[mounts addObject:spell];
		}
	}
	
	return mounts;	
}

- (BOOL)addSpellAsRecognized: (Spell*)spell {
    if(![spell ID]) return NO;
    if([[spell ID] unsignedIntValue] > 1000000) return NO;
    if( ![self spellForID: [spell ID]] ) {
        // PGLog(@"Adding spell %@ as recognized.", spell);
        [_spellBook setObject: spell forKey: [spell ID]];
        [self synchronizeSpells];
        return YES;
    }
    return NO;
}

#pragma mark -

- (BOOL)isPlayerSpell: (Spell*)aSpell {
    for(Spell *spell in [self playerSpells]) {
        if([spell isEqualToSpell: aSpell])
            return YES;
    }
    return NO;
}

- (NSArray*)playerSpells {
    return [[_playerSpells retain] autorelease];
}

- (NSMenu*)playerSpellsMenu {
    [self reloadPlayerSpells];
    return [[[spellDropDown menu] copy] autorelease];
}

- (UInt32)lastAttemptedActionID {
    UInt32 value = 0;
    [[controller wowMemoryAccess] loadDataForObject: self atAddress: [offsetController offset:@"LAST_SPELL_THAT_DIDNT_CAST_STATIC"] Buffer: (Byte*)&value BufLength: sizeof(value)];
    return value;
}

#pragma mark -
#pragma mark IBActions

- (IBAction)reloadMenu: (id)sender {
    [self reloadPlayerSpells];
}

- (IBAction)spellLoadAllData:(id)sender {
    
    // make sure our state is valid
    MemoryAccess *memory = [controller wowMemoryAccess];
    if( !memory || ![self isSpellListValid] )  {
        NSBeep();
        return;
    }

    [self reloadPlayerSpells];

    if([_playerSpells count]) {
        [spellLoadingProgress setHidden: NO];
        [spellLoadingProgress setMaxValue: [_playerSpells count]];
        [spellLoadingProgress setDoubleValue: 0];
        [spellLoadingProgress setUsesThreadedAnimation: YES];
    } else {
        return;
    }
    
    for(Spell *spell in _playerSpells) {
        [spell reloadSpellData];
        [spellLoadingProgress incrementBy: 1.0];
        [spellLoadingProgress displayIfNeeded];
    }
    
    // finish up
    [spellLoadingProgress setHidden: YES];
    [self synchronizeSpells];
    [self reloadPlayerSpells];
}

- (void)showCooldownPanel{
	[cooldownPanel makeKeyAndOrderFront: self];
}

// Pull in latest CD info
- (void)reloadCooldownInfo{
	// Why are we updating the table if we can't see it??
	if ( ![[cooldownPanelTable window] isVisible] ){
		return;
	}
	
	[_playerCooldowns removeAllObjects];
	
	MemoryAccess *memory = [controller wowMemoryAccess];
	
	UInt32 objectListPtr = 0, lastObjectPtr=0, row=0;
	UInt32 offset = [offsetController offset:@"CD_LIST_STATIC"];
	[memory loadDataForObject:self atAddress:offset + 0x4 Buffer:(Byte *)&lastObjectPtr BufLength:sizeof(lastObjectPtr)];
	[memory loadDataForObject:self atAddress:offset + 0x8 Buffer:(Byte *)&objectListPtr BufLength:sizeof(objectListPtr)];
	BOOL reachedEnd = NO;
	
	WoWCooldown cd;
	while ((objectListPtr != 0)  && ((objectListPtr & 1) == 0) ) {
		row++;
		[memory loadDataForObject: self atAddress: (objectListPtr) Buffer:(Byte*)&cd BufLength: sizeof(cd)];
		
		long realCD = cd.cooldown;
		if (  cd.cooldown2 > cd.cooldown )
			realCD =  cd.cooldown2;
		
		long realStartTime = cd.startTime;
		if ( cd.startNotUsed > cd.startTime )
			realStartTime = cd.startNotUsed;
		
		// Save it!
		[_playerCooldowns addObject: [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt: row],							@"ID",
									  [NSNumber numberWithInt: cd.spellID],						@"SpellID",
									  [NSNumber numberWithInt: realStartTime],					@"StartTime",
									  [NSNumber numberWithInt: realCD],                         @"Cooldown",
									  [NSNumber numberWithInt: cd.gcd],							@"GCD",
									  nil]];

		if ( reachedEnd )
			break;
		
		objectListPtr = cd.nextObjectAddress;

		if ( objectListPtr == lastObjectPtr )
			reachedEnd = YES;
	}
	
	[cooldownPanelTable reloadData];
}



#pragma mark -
#pragma mark Auras Delesource


- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
   return [_playerCooldowns count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
   if(rowIndex == -1 || rowIndex >= [_playerCooldowns count]) return nil;
    	
	if([[aTableColumn identifier] isEqualToString: @"Cooldown"]) {
        float secRemaining = [[[_playerCooldowns objectAtIndex: rowIndex] objectForKey: [aTableColumn identifier]] floatValue]/1000.0f;
        if(secRemaining < 60.0f) {
            return [NSString stringWithFormat: @"%.0f sec", secRemaining];
        } else if(secRemaining < 3600.0f) {
            return [NSString stringWithFormat: @"%.0f min", secRemaining/60.0f];
        } else if(secRemaining < 86400.0f) {
            return [NSString stringWithFormat: @"%.0f hour", secRemaining/3600.0f];
		}
	}
	
	if([[aTableColumn identifier] isEqualToString: @"TimeRemaining"]) {
        float cd = [[[_playerCooldowns objectAtIndex: rowIndex] objectForKey: @"Cooldown"] floatValue];
		float currentTime = (float) [playerController currentTime];
		float startTime = [[[_playerCooldowns objectAtIndex: rowIndex] objectForKey: @"StartTime"] floatValue];
		float secRemaining = ((startTime + cd)-currentTime)/1000.0f;
		
		//if ( secRemaining < 0.0f ) secRemaining = 0.0f;
		
		if(secRemaining < 60.0f) {
            return [NSString stringWithFormat: @"%.0f sec", secRemaining];
        } else if(secRemaining < 3600.0f) {
            return [NSString stringWithFormat: @"%.0f min", secRemaining/60.0f];
        } else if(secRemaining < 86400.0f) {
            return [NSString stringWithFormat: @"%.0f hour", secRemaining/3600.0f];
		}
	}
		
	if ([[aTableColumn identifier] isEqualToString:@"Address"]){
		return [NSString stringWithFormat:@"0x%X", [[[_playerCooldowns objectAtIndex: rowIndex] objectForKey: [aTableColumn identifier]] intValue]]; 
	}
	
	if ([[aTableColumn identifier] isEqualToString:@"SpellName"]){
		int spellID = [[[_playerCooldowns objectAtIndex: rowIndex] objectForKey: @"SpellID"] intValue];
		Spell *spell = [self spellForID:[NSNumber numberWithInt:spellID]];
		// need to add it!
		if ( !spell ){
			spell = [Spell spellWithID: [NSNumber numberWithUnsignedInt: spellID]];
			[spell reloadSpellData];
			[self addSpellAsRecognized: spell];
		}
		return [spell name];
	}
    
    return [[_playerCooldowns objectAtIndex: rowIndex] objectForKey: [aTableColumn identifier]];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return NO;
}

- (void)tableView:(NSTableView *)aTableView  sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    //[_playerAuras sortUsingDescriptors: [aurasPanelTable sortDescriptors]];
    [cooldownPanelTable reloadData];
}

#pragma mark Cooldowns
// Contribution by Monder - thank you!

-(BOOL)isGCDActive {
	MemoryAccess *memory = [controller wowMemoryAccess];
	UInt32 currentTime = [playerController currentTime];
	UInt32 objectListPtr = 0, lastObjectPtr=0;
	UInt32 offset = [offsetController offset:@"CD_LIST_STATIC"];
	BOOL reachedEnd = NO;
	WoWCooldown cd;
	
	// load start/end object ptrs
	[memory loadDataForObject:self atAddress:offset + 0x4 Buffer:(Byte *)&lastObjectPtr BufLength:sizeof(lastObjectPtr)];
	[memory loadDataForObject:self atAddress:offset + 0x8 Buffer:(Byte *)&objectListPtr BufLength:sizeof(objectListPtr)];

	while ((objectListPtr != 0)  && ((objectListPtr & 1) == 0) ) {
		[memory loadDataForObject: self atAddress: (objectListPtr) Buffer:(Byte*)&cd BufLength: sizeof(cd)];
		
		long realStartTime = cd.startTime;
		if ( cd.startNotUsed > cd.startTime )
			realStartTime = cd.startNotUsed;
			
		// is gcd active?
		if ( realStartTime + cd.gcd > currentTime ){
			return YES;
		}
		
		if ( reachedEnd )
			break;
		
		objectListPtr = cd.nextObjectAddress;
		
		if ( objectListPtr == lastObjectPtr )
			reachedEnd = YES;
	}
	
	return NO;     
}
-(BOOL)isSpellOnCooldown:(UInt32)spell {
	if( [self cooldownLeftForSpellID:spell] == 0)
		return NO;
	return YES;
}

// this could be more elegant (i.e. storing cooldown info and only updating it every 0.25 seconds or when a performAction on a spell is done)
-(UInt32)cooldownLeftForSpellID:(UInt32)spell {
	
	MemoryAccess *memory = [controller wowMemoryAccess];
	
	UInt32 currentTime = [playerController currentTime];
	UInt32 objectListPtr = 0, lastObjectPtr=0;
	UInt32 offset = [offsetController offset:@"CD_LIST_STATIC"];
	[memory loadDataForObject:self atAddress:offset + 0x4 Buffer:(Byte *)&lastObjectPtr BufLength:sizeof(lastObjectPtr)];
	[memory loadDataForObject:self atAddress:offset + 0x8 Buffer:(Byte *)&objectListPtr BufLength:sizeof(objectListPtr)];
	BOOL reachedEnd = NO;
	
	WoWCooldown cd;
	while ((objectListPtr != 0)  && ((objectListPtr & 1) == 0) ) {
		[memory loadDataForObject: self atAddress: (objectListPtr) Buffer:(Byte*)&cd BufLength: sizeof(cd)];
		
		if ( cd.spellID == spell ){
			
			long realCD = cd.cooldown;
			if (  cd.cooldown2 > cd.cooldown )
				realCD =  cd.cooldown2;
			
			long realStartTime = cd.startTime;
			if ( cd.startNotUsed > cd.startTime )
				realStartTime = cd.startNotUsed;
			
			// are we on cooldown?
			if ( realStartTime + realCD > currentTime )
				return realStartTime + realCD - currentTime;
		}
		
		if ( reachedEnd )
			break;
		
		objectListPtr = cd.nextObjectAddress;
		
		if ( objectListPtr == lastObjectPtr )
			reachedEnd = YES;
	}
	
	// if we get here we made it through the list, the spell isn't on cooldown!
	return 0;
}


@end
