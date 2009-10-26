//
//  Controller.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/15/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//
// NEW

#import "Controller.h"
#import "NoAccessApplication.h"
#import "BotController.h"
#import "MobController.h"
#import "NodeController.h"
#import "SpellController.h"
#import "InventoryController.h"
#import "WaypointController.h"
#import "ProcedureController.h"
#import "PlayerDataController.h"
#import "MemoryViewController.h"
#import "PlayersController.h"
#import "CorpseController.h"
#import "FishController.h"
#import "OffsetController.h"

#import "CGSPrivate.h"

#import "MemoryAccess.h"
#import "Offsets.h"
#import "NSNumberToHexString.h"
#import "NSString+URLEncode.h"
#import "NSString+Extras.h"
#import "Mob.h"
#import "Item.h"
#import "Node.h"
#import "Player.h"
#import "PTHeader.h"
#import "Position.h"

#import <Foundation/foundation.h>
#import <SecurityFoundation/SFAuthorization.h>
#import <Security/AuthorizationTags.h>

typedef enum {
    wowNotOpenState =       0,
    memoryInvalidState =    1,
    memoryValidState =      2,
    playerValidState =      3,
} memoryState;

#define MainWindowMinWidth  740
#define MainWindowMinHeight 200

@interface Controller ()
@property int currentState;
@property (readwrite, retain) NSString* matchExistingApp;
@end

@interface Controller (Internal)
- (void)finalizeUserDefaults;

- (void)scanObjectGraph;
- (BOOL)locatePlayerStructure;
- (void)loadView: (NSView*)newView withTitle: (NSString*)title;
- (void)populateWowInstances;
- (void)foundObjectListAddress: (NSNumber*)address;

// new structure scanning
- (BOOL)isValidAddress: (UInt32)address;
- (UInt32)getNextObjectAddress:(MemoryAccess*)memory;
- (void)sortObjects: (MemoryAccess*)memory;
@end

@implementation Controller

+ (void)initialize {

    // initialize our value transformer
    NSNumberToHexString *hexTransformer = [[[NSNumberToHexString alloc] init] autorelease];
    [NSValueTransformer setValueTransformer: hexTransformer forName: @"NSNumberToHexString"];
    
    NSDictionary *defaultValues = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithFloat: 7.0],     @"CombatBlacklistDelay",
                                   [NSNumber numberWithFloat: 10.0],    @"CombatBlacklistVerticalOffset",
                                   [NSNumber numberWithBool: YES],      @"MovementUseSmoothTurning",
                                   [NSNumber numberWithFloat: 2.0],     @"MovementMinJumpTime",
                                   [NSNumber numberWithFloat: 6.0],     @"MovementMaxJumpTime",
                                   [NSNumber numberWithBool: YES],      @"GlobalSendGrowlNotifications",
                                   [NSNumber numberWithBool: YES],      @"SUCheckAtStartup",
                                   [NSNumber numberWithBool: YES],      @"SecurityDisableGUIScripting",
                                   [NSNumber numberWithBool: NO],       @"SecurityUseBlankWindowTitles",
                                   [NSNumber numberWithBool: NO],       @"SecurityPreferencesUnreadable",
                                   [NSNumber numberWithBool: NO],       @"SecurityShowRenameSettings",
                                   [NSNumber numberWithBool: NO],       @"SecurityDisableLogging",
                                   
                                   nil];
    // NSLog(@"%d, %d", getuid(), geteuid());
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultValues];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues: defaultValues];
    
    [[NSUserDefaults standardUserDefaults] setObject: @"http://www.savorydeviate.com/pocketgnome/appcast.xml" forKey: @"SUFeedURL"];
}

static Controller* sharedController = nil;

+ (Controller *)sharedController {
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
        _items = [[NSMutableArray array] retain];
        _mobs = [[NSMutableArray array] retain];
        _players = [[NSMutableArray array] retain];
        _corpses = [[NSMutableArray array] retain];
        _gameObjects = [[NSMutableArray array] retain];
        _dynamicObjects = [[NSMutableArray array] retain];

        _wowMemoryAccess = nil;
        _appFinishedLaunching = NO;
		_invalidPlayerNotificationSent = NO;
		
		_lastAttachedPID = 0;
		selectedPID = [NSNumber numberWithInt:0];
		_globalGUID = 0;
		
		// new search
		_objectAddresses = [[NSMutableArray array] retain];		// stores the start address for all objects
		_currentAddress = 0;
		_totalObjects = 0;
		_currentObjectManager = 0;
        
        [SecureUserDefaults secureUserDefaults];
        
        // load in our faction dictionary
        factionTemplate = [[NSDictionary dictionaryWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"FactionTemplate" ofType: @"plist"]] retain];
    }
    
    return self;
}

- (void)checkWoWVersion {
    
    NSString *appVers = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleShortVersionString"];
    
    if([self isWoWVersionValid]) {
        [aboutValidImage setImage: [NSImage imageNamed: @"good"]];
        [versionInfoText setStringValue: [NSString stringWithFormat: @"%@ (v%@) is up to date with WoW %@.", [self appName], appVers, [self wowVersionShort]]];
    } else {
        [aboutValidImage setImage: [NSImage imageNamed: @"bad"]];
        [versionInfoText setStringValue: [NSString stringWithFormat: @"%@ (v%@) requires WoW %@.", [self appName], appVers, VALID_WOW_VERSION]];
    }
}

- (void)awakeFromNib {
    // [mainWindow setBackgroundColor: [NSColor windowFrameColor]];
    
    [self showAbout: nil];
    [self checkWoWVersion];
    
    [GrowlApplicationBridge setGrowlDelegate: self];
    [GrowlApplicationBridge setWillRegisterWhenGrowlIsReady: YES];
    /*if( [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
        PGLog(@"Growl running.");
        [GrowlApplicationBridge notifyWithTitle: @"RUNNING"
                                    description: [NSString stringWithFormat: @"You have reached level %d.", 1]
                               notificationName: @"PlayerLevelUp"
                                       iconData: [[NSImage imageNamed: @"Ability_Warrior_Revenge"] TIFFRepresentation]
                                       priority: 0
                                       isSticky: NO
                                   clickContext: nil];             
    } else {
        PGLog(@"Growl not running.");
    }*/
    
    // insert the new ChatLog toolbar item if it hasn't been done before and it's not there
    if(![[NSUserDefaults standardUserDefaults] boolForKey: @"AddedChatLogToolbarItem"]) {
        BOOL foundChatLog = NO;
        for(NSToolbarItem *item in [mainToolbar items]) {
            if([[item itemIdentifier] isEqualToString: [chatLogToolbarItem itemIdentifier]]) {
                foundChatLog = YES;
            }
        }
        if(!foundChatLog) {
            PGLog(@"Inserting Chat Log toolbar item.");
            [mainToolbar insertItemWithItemIdentifier: [chatLogToolbarItem itemIdentifier] atIndex: 1];
        }
        [[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"AddedChatLogToolbarItem"];
    }
	
    // insert the new Fishing toolbar item if it hasn't been done before and it's not there
    if(![[NSUserDefaults standardUserDefaults] boolForKey: @"AddedFishingToolbarItem"]) {
        BOOL foundFishing = NO;
        for(NSToolbarItem *item in [mainToolbar items]) {
            if([[item itemIdentifier] isEqualToString: [fishingToolbarItem itemIdentifier]]) {
                foundFishing = YES;
            }
        }
        if(!foundFishing) {
            PGLog(@"Inserting Fishing toolbar item.");
            [mainToolbar insertItemWithItemIdentifier: [fishingToolbarItem itemIdentifier] atIndex: 1];
        }
        [[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"AddedFishingToolbarItem"];
    }
    
    //UInt32 bleh = 3250009464u;
    //float bleh2;
    //memcpy(&bleh2, &bleh, 4);
    //PGLog(@"%f", bleh2);
}

- (void)finalizeUserDefaults {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"SUFeedURL"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // no more license checking; clean up old registration
    self.isRegistered = YES;
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    [settings removeObjectForKey: @"LicenseData"];
    [settings removeObjectForKey: @"LicenseName"];
    [settings removeObjectForKey: @"LicenseEmail"];
    [settings removeObjectForKey: @"LicenseHash"];
    [settings removeObjectForKey: @"LicenseID"];
    [settings synchronize];
    
    [self toggleGUIScripting: nil];
    
    // make us the front process
	if ( ![self isWoWFront] ){
		ProcessSerialNumber psn = { 0, kCurrentProcess };
		SetFrontProcess( &psn );
		[mainWindow makeKeyAndOrderFront: nil];
	}
    _appFinishedLaunching = YES;
    
    // validate game version
    //if(![self isWoWVersionValid]) {
    //    NSRunCriticalAlertPanel(@"No valid version of WoW detected!", @"You have version %@ of WoW installed, and this program requires version %@.  There is no gaurantee that this program will work with your version of World of Warcraft.  Please check for an updated version.", @"Okay", nil, nil, [self wowVersionShort], VALID_WOW_VERSION);
    //}
    
    [self performSelector: @selector(scanObjectGraph) withObject: nil afterDelay: 0.5];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self finalizeUserDefaults];
    
    [[SecureUserDefaults secureUserDefaults] updatePermissions];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification {
    if(![mainWindow isVisible]) {
        [mainWindow makeKeyAndOrderFront: nil];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    if(!flag) {
        [mainWindow makeKeyAndOrderFront: nil];
    }
    return NO;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    
    if([[filename pathExtension] isEqualToString: @"route"]) {
        [routeController importRouteAtPath: filename];
        [self toolbarItemSelected: routesToolbarItem];
        [mainToolbar setSelectedItemIdentifier: [routesToolbarItem itemIdentifier]];
        return YES;
    } else if([[filename pathExtension] isEqualToString: @"behavior"]) {
        [behaviorController importBehaviorAtPath: filename];
        [self toolbarItemSelected: behavsToolbarItem];
        [mainToolbar setSelectedItemIdentifier: [behavsToolbarItem itemIdentifier]];
        return YES;
    }
    
    return NO;
}

#pragma mark NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response { return; }

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data { return; }

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // PGLog(@"Registration connection error.");
    [connection autorelease];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // PGLog(@"Registration connection done.");
    [connection autorelease];
}

#pragma mark -
#pragma mark WoW Structure Scanning

// Special thanks to EmilyStrange @ http://www.mmowned.com/forums/wow-memory-editing/261575-c-memory-enumerator-walking-objects.html
- (void)scanObjectList:(MemoryAccess*)memory{
	
	// clear crap from our last scan
	[_objectAddresses removeAllObjects];
	_currentAddress = 0;
	
	// find all object addresses
	UInt32 objectAddress = 0;
	while ( (objectAddress = [self getNextObjectAddress:memory]) && [self isValidAddress:objectAddress] ){
		_currentAddress = objectAddress;
		
		// save the object addresses
		[_objectAddresses addObject:[NSNumber numberWithInt:objectAddress]];
	}
	
	// we have the addresses now, lets add them to our respective controllers
	[self sortObjects:memory];
	_totalObjects = [_objectAddresses count];
}

- (BOOL)isValidAddress: (UInt32)address{
	if ( address == 0x0 )
		return NO;
	
	if ( (address & 1) != 0 )
		return NO;
	
	if ( address == _currentAddress )
		return NO;
	
	return YES;
}


- (UInt32)getNextObjectAddress:(MemoryAccess*)memory{
	if ( _currentAddress == 0 ){
		UInt32 objectManager = 0;
		if([memory loadDataForObject: self atAddress: [offsetController offset:@"OBJECT_LIST_LL_PTR"] Buffer: (Byte*)&objectManager BufLength: sizeof(objectManager)] && objectManager) {
			_validObjectListManager = YES;
			UInt32 firstObjectPtr = 0;
			if([memory loadDataForObject: self atAddress: objectManager + 0xAC Buffer: (Byte*)&firstObjectPtr BufLength: sizeof(firstObjectPtr)] && firstObjectPtr) {
				return firstObjectPtr;
			}
		}
	}
	
	UInt32 nextObjectAddress = 0;
	if([memory loadDataForObject: self atAddress: _currentAddress + 0x34 Buffer: (Byte*)&nextObjectAddress BufLength: sizeof(nextObjectAddress)] && nextObjectAddress) {
		return nextObjectAddress;
	}
	
	return 0;
}

- (void)sortObjects: (MemoryAccess*)memory{
	
	UInt32 objectAddress = 0;
	for ( NSNumber *objAddress in _objectAddresses ){
		objectAddress = [objAddress intValue];
		
		int objectType = TYPEID_UNKNOWN;
		if ( [memory loadDataForObject: self atAddress: (objectAddress + OBJECT_TYPE_ID) Buffer: (Byte*)&objectType BufLength: sizeof(objectType)] ) {
			
			// item
			if ( objectType == TYPEID_ITEM || objectType == TYPEID_CONTAINER ) {
				[_items addObject: objAddress];
				continue;
			}
			
			// mob
			if ( objectType == TYPEID_UNIT ) {
				[_mobs addObject: objAddress];
				continue;
			}
			
			// player
			if ( objectType == TYPEID_PLAYER ) {
				
				// read player GUID
				UInt32 guid = 0;
				if ( [memory loadDataForObject: self atAddress: (objectAddress + OBJECT_GUID_LOW32) Buffer: (Byte*)&guid BufLength: sizeof(guid)] && guid == _globalGUID ){
					if ( objectAddress != [playerData baselineAddress] ){
						
						PGLog(@"[Controller] Player base address 0x%X changed to 0x%X, verifying change...", [playerData baselineAddress], objectAddress);
						
						// reset mobs, nodes, and inventory for the new player address
						[mobController resetAllMobs];
						[nodeController resetAllNodes];
						[itemController resetInventory];
						[playersController resetAllPlayers];
						
						// tell our player controller its new address
						[playerData setStructureAddress: objAddress];
						Player *player = [playerData player];
						PGLog(@"[Player] Level %d %@ %@", [player level], [Unit stringForRace: [player race]], [Unit stringForClass: [player unitClass]]);
						
						[self setCurrentState: playerValidState];
					}			
				}
				
				[_players addObject: objAddress];
				continue;
			}
			
			if(objectType == TYPEID_GAMEOBJECT) {
				[_gameObjects addObject: objAddress];
				continue;
			}
			
			if(objectType == TYPEID_DYNAMICOBJECT) {
				[_dynamicObjects addObject: objAddress];
				continue;
			}
			
			if(objectType == TYPEID_CORPSE) {
				[_corpses addObject: objAddress];
				continue;
			}
		}
	}
}


// [[OBJECT_MANAGER] + 0xC] ==[[OBJECT_MANAGER] + 0xAC] = First object in object list
// [[OBJECT_MANAGER] + 0x1C] = Object list (not in order)
- (UInt32)objectManager:(MemoryAccess*)memory{
	UInt32 objectManager = 0;
	if([memory loadDataForObject: self atAddress: [offsetController offset:@"OBJECT_LIST_LL_PTR"] Buffer: (Byte*)&objectManager BufLength: sizeof(objectManager)] && objectManager) {
		return objectManager;
	}
	
	return 0;	
}

// this gets our objects
- (void)scanObjectGraph {
	
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    
	// populate wow process list
	[self populateWowInstances];
	
	// grab memory
    MemoryAccess *memory = [self wowMemoryAccess];
	
	// grab our global GUID
	[memory loadDataForObject: self atAddress: [offsetController offset:@"PLAYER_GUID_STATIC"] Buffer: (Byte*)&_globalGUID BufLength: sizeof(_globalGUID)];
	
	// object manager
	if ( memory ){
		
		UInt32 objectManager = [self objectManager:memory];
		// we have a valid object list
		if ( objectManager > 0x0 ){
			
			// our object manager has changed (wonder if this happens often?)
			if ( _currentObjectManager > 0x0 && _currentObjectManager != objectManager ){
				
				PGLog(@"OBJECT MANAGER HAS CHANGED 0x%X != 0x%X", _currentObjectManager, objectManager);
				_validObjectListManager = NO;
			}
			
			_currentObjectManager = objectManager;
			_invalidPlayerNotificationSent = NO;
		}
		// no valid list, player not logged in or loading screen
		else if ( objectManager == 0x0 || _globalGUID == 0x0 ){
			if ( !_invalidPlayerNotificationSent ){
				_invalidPlayerNotificationSent = YES;
				[[NSNotificationCenter defaultCenter] postNotificationName: PlayerIsInvalidNotification object: nil];
				PGLog(@"Invalid notification sent...");
			}
			
			// memory is valid, but no player :(
			[self setCurrentState: memoryValidState];
		}
	}
	
	// we only need memory to try our scan!
    if ( memory ) {
        [_items removeAllObjects];
        [_mobs removeAllObjects];
        [_players removeAllObjects];
        [_gameObjects removeAllObjects];
        [_dynamicObjects removeAllObjects];
        [_corpses removeAllObjects];
        
        //NSDate *date = [NSDate date];
		[memory resetLoadCount];
		[self scanObjectList:memory];
		//PGLog(@"[Controller] Found %d objects in game with %d memory operations", _totalObjects, [memory loadCount]);
		//PGLog(@"New name scan took %.2f seconds and %d memory operations.", [date timeIntervalSinceNow]*-1.0, [memory loadCount]);
		
        //PGLog(@"Memory scan took %.4f sec for %d total objects.", [date timeIntervalSinceNow]*-1.0f, [_mobs count] + [_items count] + [_gameObjects count] + [_players count]);
        //date = [NSDate date];
        
        [mobController addAddresses: _mobs];
        [itemController addAddresses: _items];
        [nodeController addAddresses: _gameObjects];
        [playersController addAddresses: _players];
		[corpseController addAddresses: _corpses];
		
        //PGLog(@"Controller adding took %.4f sec", [date timeIntervalSinceNow]*-1.0f);
        //date = [NSDate date];
		
        // clean-up; we don't need this crap sitting around
        [_items removeAllObjects];
        [_mobs removeAllObjects];
        [_players removeAllObjects];
        [_gameObjects removeAllObjects];
        [_dynamicObjects removeAllObjects];
        [_corpses removeAllObjects];
		
		// is our player invalid?
		if ( ![playerData playerIsValid:self] ){
			[self setCurrentState: memoryValidState];
		}
		else{
			[self setCurrentState: playerValidState];
		}
        
        //PGLog(@"Total scan took %.4f sec", [start timeIntervalSinceNow]*-1.0f);
        //PGLog(@"-----------------");
    }
    
    // run this every second
    [self performSelector: @selector(scanObjectGraph) withObject: nil afterDelay: 1.0];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)showAbout: (id)sender {
    [self checkWoWVersion];
    [self loadView: aboutView withTitle: [self appName]];
    [mainToolbar setSelectedItemIdentifier: nil];

    NSSize theSize = [aboutView frame].size; theSize.height += 20;
    [mainWindow setContentMinSize: theSize];
    [mainWindow setContentMaxSize: theSize];
    [mainWindow setShowsResizeIndicator: NO];
}

- (IBAction)showSettings: (id)sender {
    [self loadView: settingsView withTitle: @"Settings"];
    [mainToolbar setSelectedItemIdentifier: [prefsToolbarItem itemIdentifier]];
    
    NSSize theSize = [settingsView frame].size; theSize.height += 20;
    [mainWindow setContentMinSize: theSize];
    [mainWindow setContentMaxSize: theSize];
    [mainWindow setShowsResizeIndicator: NO];
    
    // setup security stuff
    self.matchExistingApp = nil;
    [matchExistingCheckbox setState: NSOffState];
    [newNameField setStringValue: [self appName]];
    [newSignatureField setStringValue: [self appSignature]];
    [newIdentifierField setStringValue: [self appIdentifier]];
}

- (IBAction)launchWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://www.savorydeviate.com/pocketgnome"]];
}

- (void)loadView: (NSView*)newView withTitle: (NSString*)title {
    if(!newView || (newView == [mainBackgroundBox contentView]) ) return;
	
    // set the view to blank
    NSView *tempView = [[NSView alloc] initWithFrame: [[mainWindow contentView] frame]];
    [mainBackgroundBox setContentView: tempView];
    [tempView release];
    
    NSRect newFrame = [mainWindow frame];
    newFrame.size.height =	[newView frame].size.height + ([mainWindow frame].size.height - [[mainWindow contentView] frame].size.height) + 20; // Compensates for toolbar
    newFrame.size.width =	[newView frame].size.width < MainWindowMinWidth ? MainWindowMinWidth : [newView frame].size.width;
    newFrame.origin.y +=	([[mainWindow contentView] frame].size.height - [newView frame].size.height - 20); // Origin moves by difference in two views
    newFrame.origin.x +=	([[mainWindow contentView] frame].size.width - newFrame.size.width)/2; // Origin moves by difference in two views, halved to keep center alignment
    
    /* // resolution independent resizing
     float vdiff = ([newView frame].size.height - [[mainWindow contentView] frame].size.height) * [mainWindow userSpaceScaleFactor];
     newFrame.origin.y -= vdiff;
     newFrame.size.height += vdiff;
     float hdiff = ([newView frame].size.width - [[mainWindow contentView] frame].size.width) * [mainWindow userSpaceScaleFactor];
     newFrame.size.width += hdiff;*/
    
    [mainWindow setFrame: newFrame display: YES animate: YES];
    [mainBackgroundBox setContentView: newView];
    
    if( [[[NSUserDefaults standardUserDefaults] objectForKey: @"SecurityUseBlankWindowTitles"] boolValue] ) {
        [mainWindow setTitle: @""];
    } else {
        [mainWindow setTitle: title];
    }
        
    [[NSNotificationCenter defaultCenter] postNotificationName: DidLoadViewInMainWindowNotification object: newView];
}

- (IBAction)toolbarItemSelected: (id)sender {
    NSView *newView = nil;
    NSString *addToTitle = nil;
    NSSize minSize = NSZeroSize, maxSize = NSZeroSize;
    if( [sender tag] == 1) {
        newView = [botController view];
        addToTitle = [botController sectionTitle];
        minSize = [botController minSectionSize];
        maxSize = [botController maxSectionSize];
    }
    if( [sender tag] == 2) {
        newView = [playerData view];
        addToTitle = [playerData sectionTitle];
        minSize = [playerData minSectionSize];
        maxSize = [playerData maxSectionSize];
    }
    if( [sender tag] == 3) {
        newView = [spellController view];
        addToTitle = [spellController sectionTitle];
        minSize = [spellController minSectionSize];
        maxSize = [spellController maxSectionSize];
    }
    if( [sender tag] == 4) {
        newView = [mobController view];
        addToTitle = [mobController sectionTitle];
        minSize = [mobController minSectionSize];
        maxSize = [mobController maxSectionSize];
    }
    if( [sender tag] == 5) {
        newView = [nodeController view];
        addToTitle = [nodeController sectionTitle];
        minSize = [nodeController minSectionSize];
        maxSize = [nodeController maxSectionSize];
    }
    if( [sender tag] == 6) {
        newView = [routeController view];
        addToTitle = [routeController sectionTitle];
        minSize = [routeController minSectionSize];
        maxSize = [routeController maxSectionSize];
    }
    if( [sender tag] == 7) {
        newView = [behaviorController view];
        addToTitle = [behaviorController sectionTitle];
        minSize = [behaviorController minSectionSize];
        maxSize = [behaviorController maxSectionSize];
    }
    if( [sender tag] == 8) {
        newView = [itemController view];
        addToTitle = [itemController sectionTitle];
        minSize = [itemController minSectionSize];
        maxSize = [itemController maxSectionSize];
    }
    //if( [sender tag] == 9) {
    //    newView = settingsView;
    //    addToTitle = @"Settings";
    //}
    if( [sender tag] == 10) {
        newView = [memoryViewController view];
        addToTitle = [memoryViewController sectionTitle];
        minSize = [memoryViewController minSectionSize];
        maxSize = [memoryViewController maxSectionSize];
    }
    if( [sender tag] == 11) {
        newView = [playersController view];
        addToTitle = [playersController sectionTitle];
        minSize = [playersController minSectionSize];
        maxSize = [playersController maxSectionSize];
    }
    if( [sender tag] == 12) {
        newView = [chatLogController view];
        addToTitle = [chatLogController sectionTitle];
        minSize = [chatLogController minSectionSize];
        maxSize = [chatLogController maxSectionSize];
    }
    if( [sender tag] == 13) {
        newView = [fishController view];
        addToTitle = [fishController sectionTitle];
        minSize = [fishController minSectionSize];
        maxSize = [fishController maxSectionSize];
    }
    
    if(newView) {
        [self loadView: newView withTitle: addToTitle];
    }
    
    // correct the minSize
    if(NSEqualSizes(minSize, NSZeroSize)) {
        minSize = NSMakeSize(MainWindowMinWidth, MainWindowMinHeight);
    } else {
        minSize.height += 20;
    }
    
    // correct the maxSize
    if(NSEqualSizes(maxSize, NSZeroSize)) {
        maxSize = NSMakeSize(20000, 20000);
    } else {
        maxSize.height += 20;
    }
    
    // set constraints
    if(minSize.width < MainWindowMinWidth) minSize.width = MainWindowMinWidth;
    if(maxSize.width < MainWindowMinWidth) maxSize.width = MainWindowMinWidth;
    if(minSize.height < MainWindowMinHeight) minSize.height = MainWindowMinHeight;
    if(maxSize.height < MainWindowMinHeight) maxSize.height = MainWindowMinHeight;
    
    if((minSize.width == maxSize.width) && (minSize.height == maxSize.height)) {
        [mainWindow setShowsResizeIndicator: NO];
    } else {
        [mainWindow setShowsResizeIndicator: YES];
    }
    
    [mainWindow setContentMinSize: minSize];
    [mainWindow setContentMaxSize: maxSize];
}

#pragma mark -
#pragma mark State & Status

- (void)revertStatus {
    [self setCurrentStatus: _savedStatus];
}

- (NSString*)currentStatus {
    return [currentStatusText stringValue];
}

- (void)setCurrentStatus: (NSString*)statusMsg {
    NSString *currentText = [[currentStatusText stringValue] retain];
    [currentStatusText setStringValue: statusMsg];

    [_savedStatus release];
    _savedStatus = currentText;
}

- (BOOL)isObjectManagerValid{
	return _validObjectListManager;
}

- (NSArray*)allObjectAddresses{
	return [[_objectAddresses copy] autorelease];
}

@synthesize currentState = _currentState;
@synthesize isRegistered = _isRegistered;   // too many bindings rely on this property, keep it
@synthesize matchExistingApp = _matchExistingApp;
@synthesize selectedPID;
@synthesize globalGUID = _globalGUID;

- (void)setCurrentState: (int)state {
    if(_currentState == state) return;
    
    [self willChangeValueForKey: @"stateImage"];
    [self willChangeValueForKey: @"stateString"];
    _currentState = state;
    [self didChangeValueForKey: @"stateImage"];
    [self didChangeValueForKey: @"stateString"];
}

- (NSImage*)stateImage {
    if(self.currentState == memoryValidState)
        return [NSImage imageNamed: @"mixed"];
    if(self.currentState == playerValidState)
        return [NSImage imageNamed: @"on"];
    return [NSImage imageNamed: @"off"];
}

- (NSString*)stateString {
    if(self.currentState == wowNotOpenState)
        return @"WoW is not open";
    if(self.currentState == memoryInvalidState)
        return @"Memory access denied";
    if(self.currentState == memoryValidState)
        return @"Player not found";
    if(self.currentState == playerValidState)
        return @"Player is Valid";
    return @"Unknown State";
}

- (NSString*)appName {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"];
}

- (NSString*)appSignature {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleSignature"];
}

- (NSString*)appIdentifier {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleIdentifier"];
}

- (BOOL)sendGrowlNotifications {
    return [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"GlobalSendGrowlNotifications"] boolValue];
}

#pragma mark -
#pragma mark WoW Accessors


- (MemoryAccess*)wowMemoryAccess {
    // dont do anything until the app finishes launching
    if(!_appFinishedLaunching) {
        //PGLog(@"App still launching; nil");
        return nil;
    }

    // if we have a good memory access, return it
    if(_wowMemoryAccess && [_wowMemoryAccess isValid]) {
        return [[_wowMemoryAccess retain] autorelease];
    }
    
    // we have a memory access, but it is no longer valid
    if(_wowMemoryAccess && ![_wowMemoryAccess isValid]) {
        [self willChangeValueForKey: @"wowMemoryAccess"];

        // send notification of invalidity
        PGLog(@"Memory access is invalid.");
        [self setCurrentState: memoryInvalidState];

        [_wowMemoryAccess release];
        _wowMemoryAccess = nil;
        
        [self didChangeValueForKey: @"wowMemoryAccess"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName: MemoryAccessInvalidNotification object: nil];
        
        return nil;
    }
    
    if(_wowMemoryAccess == nil) {
        if([self isWoWOpen]) {
            // PGLog(@"Initializing memory access.");
            // otherwise, create one if possible
            pid_t wowPID = 0;
            ProcessSerialNumber wowPSN = [self getWoWProcessSerialNumber];
            OSStatus err = GetProcessPID(&wowPSN, &wowPID);
            
            //PGLog(@"Got PID: %d", wowPID);
            
            // make sure the old one is disposed of, just incase
            [_wowMemoryAccess release];
            _wowMemoryAccess = nil;
            
            if(err == noErr && wowPID > 0) {
                // now we have a valid memory access
                [self willChangeValueForKey: @"wowMemoryAccess"];
                _wowMemoryAccess = [[MemoryAccess alloc] initWithPID: wowPID];
                [self didChangeValueForKey: @"wowMemoryAccess"];
                
                // send notification of validity
                if(_wowMemoryAccess && [_wowMemoryAccess isValid]) {
                    PGLog(@"Memory access is valid for PID %d.", wowPID);
                    [self setCurrentState: memoryValidState];
                    [[NSNotificationCenter defaultCenter] postNotificationName: MemoryAccessValidNotification object: nil];
                    return [[_wowMemoryAccess retain] autorelease];
                } else {
                    PGLog(@"Even after re-creation, memory access is nil (wowPID = %d).", wowPID);
                    return nil;
                }
            } else {
                PGLog(@"Error %d while retrieving WoW's PID.", err);
            }
        } else {
            [self setCurrentState: wowNotOpenState];
        }
    }
    
    //PGLog(@"Unable to get a handle on WoW's memory.");
    return nil;
}

- (BOOL)isWoWFront {
	NSDictionary *frontProcess;
	if( (frontProcess = [[NSWorkspace sharedWorkspace] activeApplication]) ) {
		NSString *bundleID = [frontProcess objectForKey: @"NSApplicationBundleIdentifier"];
		if( [bundleID isEqualToString: @"com.blizzard.worldofwarcraft"] ) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)isWoWHidden {
    ProcessSerialNumber wowPSN = [self getWoWProcessSerialNumber];
    NSDictionary *infoDict = (NSDictionary*)ProcessInformationCopyDictionary(&wowPSN, kProcessDictionaryIncludeAllInformationMask);
    [infoDict autorelease];
    return [[infoDict objectForKey: @"IsHiddenAttr"] boolValue];
}

- (BOOL)isWoWOpen {
    for(NSDictionary *processDict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
		NSString *bundleID = [processDict objectForKey: @"NSApplicationBundleIdentifier"];
		if( [bundleID isEqualToString: @"com.blizzard.worldofwarcraft"] ) {
			return YES;
		}
	}
	return NO;
}

- (NSString*)wowPath {
    for(NSDictionary *processDict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
		NSString *bundleID = [processDict objectForKey: @"NSApplicationBundleIdentifier"];
		if( [bundleID isEqualToString: @"com.blizzard.worldofwarcraft"] ) {
			return [processDict objectForKey: @"NSApplicationPath"];
		}
	}
	return @"";
}

- (NSString*)wtfAccountPath {
    if([[self wowMemoryAccess] isValid]) {
        NSString *fullPath = [self wowPath];
        fullPath = [fullPath stringByDeletingLastPathComponent];
        fullPath = [fullPath stringByAppendingPathComponent: @"WTF"];
        fullPath = [fullPath stringByAppendingPathComponent: @"Account"];
        fullPath = [fullPath stringByAppendingPathComponent: [playerData accountName]];
        
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath: fullPath isDirectory: &isDir] && isDir) {
            //PGLog(@"Got full path: %@", fullPath);
            return fullPath;
        }
        //PGLog(@"Unable to get path (%@)", fullPath);
    }
    return @"";
}

- (NSString*)wtfCharacterPath {
    if([[self wowMemoryAccess] isValid]) {
        // create the path
        NSString *path = [self wtfAccountPath];
        if([path length]) {
            path = [path stringByAppendingPathComponent: [playerData serverName]];
            path = [path stringByAppendingPathComponent: [playerData playerName]];
        }
        
        // see if it exists
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &isDir] && isDir) {
            return path;
        }
    }
    return @"";
}

- (BOOL)isWoWVersionValid {
    if( [VALID_WOW_VERSION isEqualToString: [self wowVersionShort]])
        return YES;
    return NO;
}

- (BOOL)makeWoWFront {
    if([self isWoWOpen]) {
        ProcessSerialNumber psn = [self getWoWProcessSerialNumber];
        SetFrontProcess( &psn );
        usleep(50000);
        return YES;
    }
    return NO;
}

- (NSString*)wowVersionShort {
    NSBundle *wowBundle = nil;
    if([self isWoWOpen]) {
        for(NSDictionary *processDict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
            NSString *bundleID = [processDict objectForKey: @"NSApplicationBundleIdentifier"];
            if( [bundleID isEqualToString: @"com.blizzard.worldofwarcraft"] ) {
                wowBundle = [NSBundle bundleWithPath: [processDict objectForKey: @"NSApplicationPath"]];
            }
        }
    } else {
        wowBundle = [NSBundle bundleWithPath: [[NSWorkspace sharedWorkspace] fullPathForApplication: @"World of Warcraft"]];
    }
    return [[wowBundle infoDictionary] objectForKey: @"CFBundleVersion"];
}

- (NSString*)wowVersionLong {
    NSBundle *wowBundle = nil;
    if([self isWoWOpen]) {
        for(NSDictionary *processDict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
            NSString *bundleID = [processDict objectForKey: @"NSApplicationBundleIdentifier"];
            if( [bundleID isEqualToString: @"com.blizzard.worldofwarcraft"] ) {
                wowBundle = [NSBundle bundleWithPath: [processDict objectForKey: @"NSApplicationPath"]];
            }
        }
    } else {
        wowBundle = [NSBundle bundleWithPath: [[NSWorkspace sharedWorkspace] fullPathForApplication: @"World of Warcraft"]];
    }
    return [[wowBundle infoDictionary] objectForKey: @"BlizzardFileVersion"];
}

- (ProcessSerialNumber)getWoWProcessSerialNumber {
	ProcessSerialNumber pSN = {kNoProcess, kNoProcess};
	pid_t wowPID = 0;
    for(NSDictionary *processDict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
		if( [[processDict objectForKey: @"NSApplicationBundleIdentifier"] isEqualToString: @"com.blizzard.worldofwarcraft"] ) {
			pSN.highLongOfPSN = [[processDict objectForKey: @"NSApplicationProcessSerialNumberHigh"] longValue];
			pSN.lowLongOfPSN  = [[processDict objectForKey: @"NSApplicationProcessSerialNumberLow"] longValue];
			
			OSStatus err = GetProcessPID(&pSN, &wowPID);
			_lastAttachedPID = wowPID;
			if( err == noErr && wowPID > 0 && wowPID == [selectedPID intValue]) {
				return pSN;
			}
		}
	}

	// This is ONLY the case when we load PG!
	if ( wowPID != [selectedPID intValue] ){
		selectedPID = [NSNumber numberWithInt:wowPID];
		
		// Now rebuild menu!
		[self populateWowInstances];
	}

	return pSN;
}

- (IBAction)pidSelected: (id)sender{
	// Only switch if the user chose a new one!
	if ( [selectedPID intValue] != _lastAttachedPID ){
		_wowMemoryAccess = nil;
		[self wowMemoryAccess];
	}
}

- (void)populateWowInstances{
	NSMutableArray *PIDs = [[NSMutableArray array] retain];
	
	// Lets find all available processes!
	ProcessSerialNumber pSN = {kNoProcess, kNoProcess};
    for(NSDictionary *processDict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
		if( [[processDict objectForKey: @"NSApplicationBundleIdentifier"] isEqualToString: @"com.blizzard.worldofwarcraft"] ) {
			pSN.highLongOfPSN = [[processDict objectForKey: @"NSApplicationProcessSerialNumberHigh"] longValue];
			pSN.lowLongOfPSN  = [[processDict objectForKey: @"NSApplicationProcessSerialNumberLow"] longValue];
			
			pid_t wowPID = 0;
			OSStatus err = GetProcessPID(&pSN, &wowPID);
			
			if((err == noErr) && (wowPID > 0)) {
				[PIDs addObject:[NSNumber numberWithInt:wowPID]];
			}
		}
	}
	
	// Build our menu! I'm sure I could use bindings to do this another way, but I'm a n00b :(
	NSMenu *wowInstanceMenu = [[[NSMenu alloc] initWithTitle: @"Instances"] autorelease];
	NSMenuItem *wowInstanceItem;
	int tagToSelect = 0;
    
	// WoW isn't open then :(
	if ( [PIDs count] == 0 ){
		wowInstanceItem = [[NSMenuItem alloc] initWithTitle: @"WoW is not open" action: nil keyEquivalent: @""];
		[wowInstanceItem setTag: 0];
		[wowInstanceItem setRepresentedObject: 0];
		[wowInstanceItem setIndentationLevel: 0];
		[wowInstanceMenu addItem: [wowInstanceItem autorelease]];
	}
	// We have some instances running!
	else{
		// Add all of them to the menu!
		for ( NSNumber *pid in PIDs ){
			wowInstanceItem = [[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: @"%@", pid] action: nil keyEquivalent: @""];
			[wowInstanceItem setTag: [pid intValue]];
			[wowInstanceItem setRepresentedObject: pid];
			[wowInstanceItem setIndentationLevel: 0];
			[wowInstanceMenu addItem: [wowInstanceItem autorelease]];
		}
		
		if ( [selectedPID intValue] != 0 ){
			tagToSelect = [selectedPID intValue];
		}
		else{
			tagToSelect = [[PIDs objectAtIndex:0] intValue];;
		}
	}

    [wowInstancePopUpButton setMenu: wowInstanceMenu];
    [wowInstancePopUpButton selectItemWithTag: tagToSelect];
	
	[PIDs release];
}

-(int)getWOWWindowID  {
	CGError err = 0;
	int count = 0;
    ProcessSerialNumber pSN = [self getWoWProcessSerialNumber];
	CGSConnection connectionID = 0;
	CGSConnection myConnectionID = _CGSDefaultConnection();
	
    err = CGSGetConnectionIDForPSN(0, &pSN, &connectionID);
    if( err == noErr ) {
	
        //err = CGSGetOnScreenWindowCount(myConnectionID, connectionID, &count);
		err = CGSGetWindowCount(myConnectionID, connectionID, &count);
        if( (err == noErr) && (count > 0) ) {
        
            int i = 0, actualIDs = 0, windowList[count];
			
            //err = CGSGetOnScreenWindowList(myConnectionID, connectionID, count, windowList, &actualIDs);
			err = CGSGetWindowList(myConnectionID, connectionID, count, windowList, &actualIDs);
			
            for(i = 0; i < actualIDs; i++) {
				CGSValue windowTitle;
				CGSWindow window = windowList[i];
				//CFStringRef titleKey = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, "kCGSWindowTitle", kCFStringEncodingUTF8, kCFAllocatorNull); 
				err = CGSGetWindowProperty(myConnectionID, window, (CGSValue)CFSTR("kCGSWindowTitle"), &windowTitle);
                //if(titleKey) CFRelease(titleKey);
				if((err == noErr) && windowTitle) {
                    // PGLog(@"%d: %@", window, windowTitle);
					return window;
				}
            }
        }
    }
	return 0;
}

- (BOOL)isWoWChatBoxOpen {
    unsigned value = 0;
    [[self wowMemoryAccess] loadDataForObject: self atAddress: [offsetController offset:@"CHAT_BOX_OPEN_STATIC"] Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (unsigned)refreshDelayReal {
    UInt32 refreshDelay = 0;
    if([[self wowMemoryAccess] loadDataForObject: self atAddress:( REFRESH_DELAY ) Buffer: (Byte *)&refreshDelay BufLength: sizeof(refreshDelay)]) {
        return refreshDelay;
    }
    return 0;
}

- (unsigned)refreshDelay {
    UInt32 refreshDelay = [self refreshDelayReal];

    if(refreshDelay > 1000000)  refreshDelay = 50000;   // incase we get a bogus number
    if(refreshDelay < 15000)    refreshDelay = 15000;   // incase we get a bogus number

    return refreshDelay*2;
    

    /* // this table was removed from wow in 2.4.3
    int refreshCurrentStep = 0;
    [[self wowMemoryAccess] loadDataForObject: self atAddress: REFRESH_DELAY_STRUCT + REFRESH_CURR_STEP Buffer: (Byte *)&refreshCurrentStep BufLength: sizeof(refreshCurrentStep)];
    
    // 
    if(refreshCurrentStep == 0)
        refreshCurrentStep = REFRESH_ARRAY_SIZE - 1;
    else
        refreshCurrentStep--;
    
    unsigned refreshEntryToLoad = (REFRESH_DELAY_STRUCT + REFRESH_ARRAY_START) + (REFRESH_ARRAY_ENTRY_SIZE * refreshCurrentStep) + REFRESH_ARRAY_ENTRY_DELAY, refreshDelay = 0;
    [[self wowMemoryAccess] loadDataForObject: self atAddress: refreshEntryToLoad Buffer: (Byte *)&refreshDelay BufLength: sizeof(refreshDelay)];
    
    //PGLog(@"Refresh: %d ms, %.2f FPS", refreshDelay, 1000000.0f/refreshDelay);
    
    */

    /* // refresh delay with float avg
    float realRefreshDelay[30];
    [[self wowMemoryAccess] loadDataForObject: self atAddress: CURRENT_REFRESH_DELAY_STATIC Buffer: (Byte *)&realRefreshDelay BufLength: sizeof(realRefreshDelay)];
    int i;
    float count = 0;
    for(i=0; i<30; i++) {
        count += realRefreshDelay[i];
    }
    count = count / 30.0f;
    unsigned realDelay = count*1000000;
    PGLog(@"Real refresh: %d", realDelay); */
}

- (CGRect)wowWindowRect {
    CGRect windowRect;
	int Connection = _CGSDefaultConnection();
	int windowID = [self getWOWWindowID];
	PGLog(@"Connection: %d, Window id: %d", Connection, windowID);
    CGSGetWindowBounds(Connection, windowID, &windowRect);
    windowRect.origin.y += 22;      // cut off the title bar
    windowRect.size.height -= 22;

    return windowRect;
}

- (Position*)cameraPosition {
    if(IS_X86) {
        float pos[3] = { -1, -1, -1 };
        [[self wowMemoryAccess] loadDataForObject: self atAddress: 0xD6B198 Buffer: (Byte *)&pos BufLength: sizeof(pos)];
        return [Position positionWithX: pos[0] Y: pos[1] Z: pos[2]];
        
    }
    return nil;
}

- (float)cameraFacing {
    if(IS_X86) {
        float value = 0;
        [[self wowMemoryAccess] loadDataForObject: self atAddress: 0xD6B1BC Buffer: (Byte *)&value BufLength: sizeof(value)];
        return value;
    }
    return 0;
}

- (float)cameraTilt {
    if(IS_X86) {
        float value = 0;
        [[self wowMemoryAccess] loadDataForObject: self atAddress: 0xD6B1B8 Buffer: (Byte *)&value BufLength: sizeof(value)];
        return asinf(value);
    }
    return 0;
}

- (CGPoint)screenPointForGamePosition: (Position*)gP {
    Position *cP = [self cameraPosition];
    if(!gP || !cP) return CGPointZero;
    
    float ax = -[gP xPosition];
    float ay = -[gP zPosition];
    float az = [gP yPosition];
    
    PGLog(@"Game position: { %.2f, %.2f, %.2f } (%@)", ax, ay, az, gP);
    
    float cx = -[cP xPosition];
    float cy = -[cP zPosition];
    float cz = [cP yPosition];

    PGLog(@"Camera position: { %.2f, %.2f, %.2f } (%@)", cx, cy, cz, cP);
    
    float facing = [self cameraFacing];
    if(facing > M_PI) facing -= 2*M_PI;
    PGLog(@"Facing: %.2f (%.2f), tilt = %.2f", facing, [self cameraFacing], [self cameraTilt]);
    
    float ox = [self cameraTilt];
    float oy = -facing;
    float oz = 0;
    
    PGLog(@"Camera direction: { %.2f, %.2f, %.2f }", ox, oy, oz);

    
    float dx = cosf(oy) * ( sinf(oz) * (ay - cy) + cosf(oz) * (ax - cx)) - sinf(oy) * (az - cz);
    float dy = sinf(ox) * ( cosf(oy) * (az - cz) + sinf(oy) * ( sinf(oz) * (ay - cy) + cosf(oz) * (ax - cx))) + cosf(ox) * ( cosf(oz) * (ay - cy) - sinf(oz) * (ax - cx) );
    float dz = cosf(ox) * ( cosf(oy) * (az - cz) + sinf(oy) * ( sinf(oz) * (ay - cy) + cosf(oz) * (ax - cx))) - sinf(ox) * ( cosf(oz) * (ay - cy) - sinf(oz) * (ax - cx) );
    
    PGLog(@"Calcu position: { %.2f, %.2f, %.2f }", dx, dy, dz);
    
    float bx = (dx - cx) * (cz/dz);
    float by = (dy - cy) * (cz/dz);

    PGLog(@"Projected 2d position: { %.2f, %.2f }", bx, by);
    
    if(dz <= 0) {
        PGLog(@"behind the camera1");
        //return CGPointMake(-1, -1);
    }
    
    CGRect wowSize = [self wowWindowRect];
    CGPoint wowCenter = CGPointMake( wowSize.origin.x+wowSize.size.width/2.0f, wowSize.origin.y+wowSize.size.height/2.0f);
    
    PGLog(@"WowWindowSize: %@", NSStringFromRect(NSRectFromCGRect(wowSize)));
    PGLog(@"WoW Center: %@", NSStringFromPoint(NSPointFromCGPoint(wowCenter)));
    
    float FOV1 = 0.1;
    float FOV2 = 3 /* 7.4 */ * wowSize.size.width;
    int sx = dx * (FOV1 / (dz + FOV1)) * FOV2 + wowCenter.x;
    int sy = dy * (FOV1 / (dz + FOV1)) * FOV2 + wowCenter.y;
    
    // ensure on screen
    if(sx < wowSize.origin.x || sy < wowSize.origin.y || sx >= wowSize.origin.x+wowSize.size.width || sy >= wowSize.origin.y+wowSize.size.height) {
        PGLog(@"behind the camera2");
        //return CGPointMake(-1, -1);
    }
    return CGPointMake(sx, sy);
}

#pragma mark -
#pragma mark Faction Information

    // Keys:
    //  @"ReactMask",       Number
    //  @"FriendMask",      Number
    //  @"EnemyMask",       Number
    //  @"EnemyFactions",   Array
    //  @"FriendFactions"   Array
    
- (NSDictionary*)factionDict {
    return [[factionTemplate retain] autorelease];
}

- (UInt32)reactMaskForFaction: (UInt32)faction {
    NSNumber *mask = [[[self factionDict] objectForKey: [NSString stringWithFormat: @"%d", faction]] objectForKey: @"ReactMask"];
    if(mask)
        return [mask unsignedIntValue];
    return 0;
}

- (UInt32)friendMaskForFaction: (UInt32)faction {
    NSNumber *mask = [[[self factionDict] objectForKey: [NSString stringWithFormat: @"%d", faction]] objectForKey: @"FriendMask"];
    if(mask)
        return [mask unsignedIntValue];
    return 0;
}

- (UInt32)enemyMaskForFaction: (UInt32)faction {
    NSNumber *mask = [[[self factionDict] objectForKey: [NSString stringWithFormat: @"%d", faction]] objectForKey: @"EnemyMask"];
    if(mask)
        return [mask unsignedIntValue];
    return 0;
}


#pragma mark -

- (void)showMemoryView {
    [self performSelector: [memoryToolbarItem action] withObject: memoryToolbarItem];
}

#pragma mark Toolbar Delegate

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return [NSArray arrayWithObjects:
            [botToolbarItem itemIdentifier], 
            [chatLogToolbarItem itemIdentifier],
            NSToolbarSpaceItemIdentifier,
            [playerToolbarItem itemIdentifier], 
            [spellsToolbarItem itemIdentifier],
			[fishingToolbarItem itemIdentifier],
            NSToolbarSpaceItemIdentifier,
            [playersToolbarItem itemIdentifier], 
            [mobsToolbarItem itemIdentifier], 
            [itemsToolbarItem itemIdentifier],
            [nodesToolbarItem itemIdentifier], 
            NSToolbarSpaceItemIdentifier,
            [routesToolbarItem itemIdentifier], 
            [behavsToolbarItem itemIdentifier],
            NSToolbarFlexibleSpaceItemIdentifier,
            [memoryToolbarItem itemIdentifier],
            [prefsToolbarItem itemIdentifier], nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar;
{
    // Optional delegate method: Returns the identifiers of the subset of
    // toolbar items that are selectable. In our case, all of them
    return [NSArray arrayWithObjects:  [botToolbarItem itemIdentifier], 
            [playerToolbarItem itemIdentifier], 
            [itemsToolbarItem itemIdentifier], 
            [spellsToolbarItem itemIdentifier],
			[mobsToolbarItem itemIdentifier], 
            [playersToolbarItem itemIdentifier],
            [nodesToolbarItem itemIdentifier], 
            [routesToolbarItem itemIdentifier], 
            [behavsToolbarItem itemIdentifier],
            [memoryToolbarItem itemIdentifier],
            [prefsToolbarItem itemIdentifier],
            [chatLogToolbarItem itemIdentifier], 
			[fishingToolbarItem itemIdentifier], nil];
}

#pragma mark -
#pragma mark Growl Delegate

/*	 The dictionary should have the required key object pairs:
 *	 key: GROWL_NOTIFICATIONS_ALL		object: <code>NSArray</code> of <code>NSString</code> objects
 *	 key: GROWL_NOTIFICATIONS_DEFAULT	object: <code>NSArray</code> of <code>NSString</code> objects
 */
 
- (NSDictionary *) registrationDictionaryForGrowl {
    NSDictionary * dict = [NSDictionary dictionaryWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"Growl Registration Ticket" ofType: @"growlRegDict"]];
    return dict;
}

- (NSString *) applicationNameForGrowl {
    // NSLog(@"applicationNameForGrowl: %@", [self appName]);
    return [self appName]; //@"Pocket Gnome";
}

- (NSImage *) applicationIconForGrowl {
    //PGLog(@"applicationIconForGrowl");
    return [NSApp applicationIconImage]; // [NSImage imageNamed: @"gnome2"];
}

- (NSData *) applicationIconDataForGrowl {
    //PGLog(@"applicationIconDataForGrowl");
    return [[NSApp applicationIconImage] TIFFRepresentation];
}

#pragma mark -
#pragma mark Security

- (void)doQuickAlertSheetWithTitle: (NSString*)title text: (NSString*)text style: (NSAlertStyle)style {
    NSAlert *alert = [NSAlert alertWithMessageText: title 
                                     defaultButton: @"Okay" 
                                   alternateButton: nil
                                       otherButton: nil 
                         informativeTextWithFormat: text];
    [alert setAlertStyle: style]; 
    [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil];
}

// Sparkle delegate

// Sent when a valid update is found by the update driver.
//- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update {
//    PGLog(@"[Update] didFindValidUpdate: %@", [update fileURL]);
//}

//- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update {
//    PGLog(@"[Update] willInstallUpdate: %@", [update fileURL]);
//}

// If you're using special logic or extensions in your appcast, implement this to use your own logic for finding
// a valid update, if any, in the given appcast.
/*- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)bundle {
    // Find the first update we can actually use.
    NSEnumerator *updateEnumerator = [[appcast items] objectEnumerator];
 do {
 item = [updateEnumerator nextObject];
 } while (item && ![self hostSupportsItem:item]);
 }*/

/*
- (BOOL)updater: (SUUpdater *)updater
shouldPostponeRelaunchForUpdate: (SUAppcastItem *)update
  untilInvoking: (NSInvocation *)invocation
{
    if( ![[self appName] isEqualToString: @"Pocket Gnome"] ) {
       // PGLog(@"[Update] We've been renamed.");
        
        NSAlert *alert = [NSAlert alertWithMessageText: @"SECURITY ALERT: PLEASE BE AWARE" 
                                         defaultButton: @"Understood" 
                                       alternateButton: nil
                                           otherButton: nil 
                             informativeTextWithFormat: @"During the update process, the file name of the downloaded version of Pocket Gnome will be changed to \"%@\".\n\nHowever, the executable, signature, and identifier inside the new version WILL NOT BE CHANGED. In order for rename settings to stay in effect, you must manually reapply them from the \"Security\" panel.", [self appName]];
        [alert setAlertStyle: NSCriticalAlertStyle]; 
        [alert beginSheetModalForWindow: mainWindow 
                          modalDelegate: self 
                         didEndSelector: @selector(updateAlertConfirmed:returnCode:contextInfo:)
                            contextInfo: (void*)[invocation retain]];
        return YES;
    }
    //PGLog(@"[Update] Relaunching as expected.");
    return NO;
}*/

- (void)updateAlertConfirmed:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSInvocation *invocation = (NSInvocation*)contextInfo;
    [invocation invoke];
}

/*
 - (SUUpdateAlertChoice)userChoseAction:(SUUpdateAlertChoice)action forUpdate:(SUAppcastItem *)update toHostBundle:(NSBundle *)bundle {
 if( ![[self appName] isEqualToString: @"Pocket Gnome"] ) {
        if(action == SUInstallUpdateChoice) {
            [[NSWorkspace sharedWorkspace] openURL: [update fileURL]];
            NSBeep();
            [self doQuickAlertSheetWithTitle: @"Downloading New Version"
                                        text: [NSString stringWithFormat: @"Version %@ of Pocket Gnome is currently being downloaded by your web browser.\n\nThis is happening because a name-changed version of Pocket Gnome cannot perform the automatic update process like an unmodified version.\n\nOnce the new version is downloaded, quit this copy of Pocket Gnome (and WoW if it is open), and perform a \"Match Existing Application\" rename operation from the \"Settings > Security\" section of the new version.", [update versionString]] 
                                       style: NSInformationalAlertStyle];
            return SURemindMeLaterChoice;
        }
    }
    
    return action;
}*/

- (IBAction)toggleGUIScripting: (id)sender {
    [NSApp setAllowAccessibility: (self.isRegistered && ![disableGUIScriptCheckbox state])];
}

- (IBAction)toggleSecurePrefs: (id)sender {
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)confirmAppRename: (id)sender {

    // make sure the other app is not open
    if(self.matchExistingApp) {
        for(NSDictionary *dict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
            if([[dict objectForKey: @"NSApplicationPath"] isEqualToString: self.matchExistingApp]) {
                [self doQuickAlertSheetWithTitle: @"Quit Matched Application" text: @"You must quit the application you are matching before performing the renaming process." style: NSInformationalAlertStyle];
                return;
            }
        }
    }
    
    int result = NSRunCriticalAlertPanel(@"Really Rename Application?", 
                                         @"If an error occurs during this process, you may need to redownload the program.\n\nThe application will automatically quit if the renaming process completes successfully.",
                                         @"Rename", @"Cancel", NULL);
    
    if(result != NSAlertDefaultReturn) {
        return;
    }
    
    BOOL madeModifications = NO;
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSString *infoPath = [[appPath stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Info.plist"];
    NSString *pkgInfoPath = [[appPath stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"PkgInfo"];
    NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithContentsOfFile: infoPath];
    
    PGLog(@"AppPath: %@", appPath);
    
    // verify everything is in working order
    if(!infoDict || ![[NSFileManager defaultManager] fileExistsAtPath: appPath] || ![[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
        PGLog(@"[Rename] Error locating correct files."); 
        NSBeep();
        [self doQuickAlertSheetWithTitle: @"Rename Failed"
                                    text: @"The correct files to modify could not be located.  Nothing was changed." 
                                   style: NSCriticalAlertStyle];
        return;
    }
    
    BOOL doMove = NO;
    NSString *execPath = nil, *newExecPath = nil, *newAppPath = nil;
    if([[newNameField stringValue] length] && ![[newNameField stringValue] isEqualToString: [infoDict objectForKey: @"CFBundleName"]]) {
        PGLog(@"[Rename] Setting application name to \"%@\".", [newNameField stringValue]);
        [infoDict setObject: [newNameField stringValue] forKey: @"CFBundleDisplayName"];
        [infoDict setObject: [newNameField stringValue] forKey: @"CFBundleExecutable"];
        [infoDict setObject: [newNameField stringValue] forKey: @"CFBundleName"];
        [infoDict setObject: [NSString stringWithFormat: @"%@ %@", [newNameField stringValue], [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"]] forKey: @"CFBundleGetInfoString"];
        
        execPath = [[NSBundle mainBundle] executablePath];
        newExecPath = [[execPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: [newNameField stringValue]];
        newAppPath = [[[appPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: [newNameField stringValue]] stringByAppendingPathExtension: @"app"];
        
        PGLog(@"newAppPath: %@", newAppPath);
        
        doMove = YES;
        madeModifications = YES;
        
        // sanity check the new paths
        if([[NSFileManager defaultManager] fileExistsAtPath: newAppPath]) {
            if(self.matchExistingApp && [newAppPath moveToTrash]) {
                PGLog(@"[Reaname] Matched application moved to trash.");
            } else {
                NSAlert *alert = [NSAlert alertWithMessageText: @"File Already Exists" 
                                                 defaultButton: @"Okay" 
                                               alternateButton: nil
                                                   otherButton: nil 
                                     informativeTextWithFormat: @"Application could not be renamed to \"%@\" because a file with this name already exists.  Please choose a new name or remove the other file.", [newExecPath lastPathComponent]];
                [alert setAlertStyle: NSCriticalAlertStyle]; 
                [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil];
                return;
            }
        }
    } else {
        PGLog(@"[Rename] No changes to application name.");
    }
    
    // set new signature
    if(![[newSignatureField stringValue] isEqualToString: [infoDict objectForKey: @"CFBundleSignature"]]) {
        NSString *newSig = [[newSignatureField stringValue] stringByPaddingToLength: 4 withString: @"?" startingAtIndex: 0];
        PGLog(@"[Rename] Changing the signature to \"%@\".", newSig);
        [infoDict setObject: newSig forKey: @"CFBundleSignature"];
        
        // write out the new Pkginfo file
        [[NSString stringWithFormat: @"APPL%@", newSig] writeToFile: pkgInfoPath atomically: NO encoding: NSUTF8StringEncoding error: NULL];
        
        madeModifications = YES;
    } else {
        PGLog(@"[Rename] No changes to application signature.");
    }
    
    // set new identifier
    NSString *newIdentifier = [newIdentifierField stringValue];
    NSString *oldIdentifier = [[[infoDict objectForKey: @"CFBundleIdentifier"] retain] autorelease];
    if([newIdentifier length] && ![newIdentifier isEqualToString: oldIdentifier]) {
        PGLog(@"[Rename] Changing app identifier from \"%@\" to \"%@\".", oldIdentifier, newIdentifier);
        [infoDict setObject: newIdentifier forKey: @"CFBundleIdentifier"];
        madeModifications = YES;
    } else {
        oldIdentifier = nil;
        PGLog(@"[Rename] No changes to application identifier.");
    }
    
    // did we even change anything?
    if(!madeModifications) {
        PGLog(@"[Rename] No action necessary.");
        NSAlert *alert = [NSAlert alertWithMessageText: @"No Action Taken" 
                                         defaultButton: @"Okay" 
                                       alternateButton: nil
                                           otherButton: nil 
                             informativeTextWithFormat: @"No changes were necessary."];
        [alert setAlertStyle: NSCriticalAlertStyle]; 
        [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil];
        return;
    }
    
    // remove the old info.plist
    id permissions = [[NSFileManager defaultManager] fileAttributesAtPath: infoPath traverseLink: YES];
    if(![[NSFileManager defaultManager] removeFileAtPath: infoPath handler: nil]) {
        PGLog(@"[Rename] Rename failed.");
        NSAlert *alert = [[[NSAlert alloc] init] autorelease]; 
        [alert addButtonWithTitle: @"Okay"];
        [alert setMessageText: @"Rename Failed"]; 
        [alert setInformativeText: @"There was an unknown error while trying to remove the old Info.plist file.  You may have to re-download the application if it has become corrupted."];
        [alert setAlertStyle: NSCriticalAlertStyle]; 
        [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil]; 
        
        return;
    }
    
    // write out new info dict
    if([infoDict writeToFile: infoPath atomically: YES]) {
        if(permissions) {
            [[NSFileManager defaultManager] changeFileAttributes: permissions atPath: infoPath];
            permissions = nil;
        }
        PGLog(@"[Rename] Wrote out info dict.");
        if(doMove) {
            // rename executable
            PGLog(@"[Rename] Renaming executable to: %@", [newExecPath lastPathComponent]);
            
            permissions = [[NSFileManager defaultManager] fileAttributesAtPath: execPath traverseLink: YES];
            if(![[NSFileManager defaultManager] moveItemAtPath: execPath toPath: newExecPath error: NULL]) {
                PGLog(@"[Rename] Rename failed.");
                NSAlert *alert = [[[NSAlert alloc] init] autorelease]; 
                [alert addButtonWithTitle: @"Okay"];
                [alert setMessageText: @"Rename Failed"]; 
                [alert setInformativeText: @"There was an error while renaming the executable file.  You may have to re-download the application if it has become corrupted."];
                [alert setAlertStyle: NSCriticalAlertStyle]; 
                [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil]; 
                return;
            } else {
                // reset permissions
                if(permissions) {
                    [[NSFileManager defaultManager] changeFileAttributes: permissions atPath: newExecPath];
                    permissions = nil;
                }
            }
            
            // rename application
            PGLog(@"[Rename] Renaming application to: %@", [newAppPath lastPathComponent]);
            permissions = [[NSFileManager defaultManager] fileAttributesAtPath: appPath traverseLink: YES];
            if(![[NSFileManager defaultManager] moveItemAtPath: appPath toPath: newAppPath error: NULL]) {
                PGLog(@"[Rename] Rename failed.");
                NSAlert *alert = [[[NSAlert alloc] init] autorelease]; 
                [alert addButtonWithTitle: @"Okay"];
                [alert setMessageText: @"Rename Failed"]; 
                [alert setInformativeText: @"There was an error while renaming the application.  You may have to re-download the application if it has become corrupted."];
                [alert setAlertStyle: NSCriticalAlertStyle]; 
                [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil]; 
                return;
            } else {
                // reset permissions
                if(permissions) {
                    [[NSFileManager defaultManager] changeFileAttributes: permissions atPath: newAppPath];
                }
            }
        }
        
        // move the old prefs into place if necessary
        if(oldIdentifier && !self.matchExistingApp) {
            // save out our current user defaults
            [self finalizeUserDefaults];

            // generate paths for copying prefs
            NSString *prefFolderPath = [[[@"~/" stringByExpandingTildeInPath] stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Preferences"];
            NSString *prefPath = [[prefFolderPath stringByAppendingPathComponent: oldIdentifier] stringByAppendingPathExtension: @"plist"];
            NSString *newPrefPath = [[prefFolderPath stringByAppendingPathComponent: [infoDict objectForKey: @"CFBundleIdentifier"]] stringByAppendingPathExtension: @"plist"];
            PGLog(@"Copying prefs file at %@ to %@", prefPath, newPrefPath);
            
            // does the preference file exist?
            if([[NSFileManager defaultManager] fileExistsAtPath: prefPath]) {
                // does the destination exist?
                if([[NSFileManager defaultManager] fileExistsAtPath: newPrefPath]) {
                    // move the old one to the trash
                    if([newPrefPath moveToTrash]) {
                        PGLog(@"[Rename] Old preference file moved to the trash.");
                    } else {
                        NSAlert *alert = [NSAlert alertWithMessageText: @"Error Moving Preferences" 
                                                         defaultButton: @"Okay" 
                                                       alternateButton: nil
                                                           otherButton: nil 
                                             informativeTextWithFormat: @"The old preferences file \"%@\" could not be moved to the trash.",
                                          [newPrefPath lastPathComponent]];
                        [alert setAlertStyle: NSCriticalAlertStyle]; 
                        [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil];
                        return;
                    }
                }
                
                // copy the preferences file
                if(![[NSFileManager defaultManager] copyPath: prefPath toPath: newPrefPath handler: NULL]) {
                    PGLog(@"[Rename] Error moving prefs.");
                    NSAlert *alert = [NSAlert alertWithMessageText: @"Error Moving Preferences" 
                                                     defaultButton: @"Okay" 
                                                   alternateButton: nil
                                                       otherButton: nil 
                                         informativeTextWithFormat: @"The preferences file \"%@\" could not be renamed.  You will need to manually rename your preferences file to \"%@\" or you will lose all your settings.",
                                      [prefPath lastPathComponent],
                                      [newPrefPath lastPathComponent]];
                    [alert setAlertStyle: NSCriticalAlertStyle]; 
                    [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil];
                    return;
                } else {
                    // chmod the new prefs to only owner readable
                    [[NSFileManager defaultManager] changeFileAttributes: [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: S_IRWXU] forKey: @"NSFilePosixPermissions"] atPath: newPrefPath];
                }
            } else {
                // could not find prefs
                PGLog(@"[Rename] Can't find old preferences.");
                NSAlert *alert = [[[NSAlert alloc] init] autorelease]; 
                [alert addButtonWithTitle: @"Okay"];
                [alert setMessageText: @"Error Locating Preferences"]; 
                [alert setInformativeText: [NSString stringWithFormat: @"The preference file expected at \"%@\" could not be located.  You will need to manually rename your preference file to \"%@\" or you will lose all your settings.", 
                                            prefPath, 
                                            [newPrefPath lastPathComponent]]];
                [alert setAlertStyle: NSCriticalAlertStyle]; 
                [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil];
                // dont return, since we're otherwise good to go
            }
            
        }
    } else {
        PGLog(@"Error writing new Info.plist.");
        NSAlert *alert = [NSAlert alertWithMessageText: @"Rename Failed" 
                                         defaultButton: @"Okay" 
                                       alternateButton: nil
                                           otherButton: nil 
                             informativeTextWithFormat: @"There was an unknown error while trying to modify the Info.plist file.  You may have to re-download the application if it has become corrupted."];
        [alert setAlertStyle: NSCriticalAlertStyle]; 
        [alert beginSheetModalForWindow: mainWindow modalDelegate: self didEndSelector: nil contextInfo: nil];
        return;
    }
    
    // launch the new copy of the app
    NSURL *url = [NSURL fileURLWithPath: newAppPath];
    LSLaunchURLSpec launchSpec;
    launchSpec.appURL = (CFURLRef)url;
    launchSpec.itemURLs = NULL;
    launchSpec.passThruParams = NULL;
    launchSpec.launchFlags = kLSLaunchDefaults | kLSLaunchNewInstance;
    launchSpec.asyncRefCon = NULL;
    
    LSOpenFromURLSpec(&launchSpec, NULL);
    exit(0);    // and then bail because we're about to crash

}


- (IBAction)renameUseExisting: (id)sender {
    if( [sender state] ) {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        
        [openPanel setTitle: @"Select Another Application"];
        [openPanel setCanChooseDirectories: NO];
        [openPanel setCanCreateDirectories: NO];
        [openPanel setPrompt: @"Match This"];
        [openPanel setCanChooseFiles: YES];
        [openPanel setAllowsMultipleSelection: NO];
        
        int ret = [openPanel runModalForDirectory: @"/Applications/"
                                             file: nil
                                            types: [NSArray arrayWithObject: @"app"]];
        
        if( (ret == NSOKButton) && ([[openPanel filenames] count] == 1)) {
            NSString *appPath = [[openPanel filenames] objectAtIndex: 0];
            NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile: [[appPath stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Info.plist"]];
            
            if(([infoDict objectForKey: @"CFBundleName"] || [infoDict objectForKey: @"CFBundleExecutable"]) && 
               [infoDict objectForKey: @"CFBundleIdentifier"] && 
               [infoDict objectForKey: @"CFBundleSignature"])
            {
                self.matchExistingApp = [[openPanel filenames] objectAtIndex: 0];
                [matchExistingCheckbox setState: NSOnState];
                
                [newNameField setStringValue: ([infoDict objectForKey: @"CFBundleName"] ? [infoDict objectForKey: @"CFBundleName"] : [infoDict objectForKey: @"CFBundleExecutable"])];
                [newSignatureField setStringValue: [infoDict objectForKey: @"CFBundleSignature"]];
                [newIdentifierField setStringValue: [infoDict objectForKey: @"CFBundleIdentifier"]];
                return;
            } else {
                // not valid
                PGLog(@"Selected application does not have the appropriate keys necessary to match.");
                NSBeep();
            }
        }
    }
    
    self.matchExistingApp = nil;
    [matchExistingCheckbox setState: NSOffState];
}

- (IBAction)renameShowHelp: (id)sender {
    [self doQuickAlertSheetWithTitle: @"For Advanced Users" text: @"The Rename Application function will completely rename the Pocket Gnome application such that it will no longer be recognized in process list scans.\n\nIt is an advanced feature, and should only be used by people who know what Signatures and Identifiers are.\n\nBacking up of your preference file before renaming would be a fantastic idea." style: NSInformationalAlertStyle];
}


- (IBAction)testFront: (id)sender {
    ProcessSerialNumber wowProcess = [self getWoWProcessSerialNumber];
    int thisSpace, wowSpace;
    int delay = 10000, timeWaited = 0;
    BOOL wasWoWHidden = [self isWoWHidden];
    int err = 0;
    if(wasWoWHidden) {
        NSLog(@"wow was hidden");
        err = ShowHideProcess( &wowProcess, YES);
        NSLog(@"show/hide err = %d", err);
    } else {
        NSLog(@"wow was NOT hidden");
    }
    CGSConnection cgsConnection = _CGSDefaultConnection();
    CGSGetWorkspace(cgsConnection, &thisSpace);
    NSLog(@"thisSpace: %d", thisSpace);
    while(!IsProcessVisible(&wowProcess) && (timeWaited < 500000)) {
        usleep(delay);
        timeWaited += delay;
        NSLog(@":: not visible");
    }
    CGSGetWindowWorkspace(cgsConnection, [self getWOWWindowID], &wowSpace);
    
    BOOL weMadeWoWFront = NO;
    
    // move wow to the front if necessary
    if(![self isWoWFront]) {
        NSLog(@"not front!!!");
        // move to WoW's workspace
        if(thisSpace != wowSpace) {
            CGSSetWorkspace(cgsConnection, wowSpace);
            usleep(100000);
        }
        
        // and set it as front process
        err = SetFrontProcess(&wowProcess);
        NSLog(@"SetFrontProcess error =%d", err);
        usleep(100000);
        
        weMadeWoWFront = YES;
    } else {
        NSLog(@"front");
    }
}

- (void)killWOW{
	ProcessSerialNumber pSN = [self getWoWProcessSerialNumber];
	if( pSN.lowLongOfPSN == kNoProcess) return;
	NSLog(@"Quitting WoW");
	
	// send Quit apple event
	OSStatus status;
	AEDesc targetProcess = {typeNull, NULL};
	AppleEvent theEvent = {typeNull, NULL};
	AppleEvent eventReply = {typeNull, NULL}; 
	
	status = AECreateDesc(typeProcessSerialNumber, &pSN, sizeof(pSN), &targetProcess);
	require_noerr(status, AECreateDesc);
	
	status = AECreateAppleEvent(kCoreEventClass, kAEQuitApplication, &targetProcess, kAutoGenerateReturnID, kAnyTransactionID, &theEvent);
	require_noerr(status, AECreateAppleEvent);
	
	status = AESend(&theEvent, &eventReply, kAENoReply + kAEAlwaysInteract, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
	require_noerr(status, AESend);
	
AESend:;
AECreateAppleEvent:;
AECreateDesc:;
	
	AEDisposeDesc(&eventReply); 
	AEDisposeDesc(&theEvent);
AEDisposeDesc(&targetProcess);
}

@end
