//
//  Controller.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/15/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MemoryAccess.h"
#import <Growl/GrowlApplicationBridge.h>

@class Position;
@class BotController;
@class MobController;
@class NodeController;
@class SpellController;
@class ChatLogController;
@class PlayersController;
@class WaypointController;
@class InventoryController;
@class ProcedureController;
@class MemoryViewController;
@class PlayerDataController;
@class CorpseController;
@class FishController;
@class OffsetController;
@class StatisticsController;

#define MemoryAccessValidNotification       @"MemoryAccessValidNotification"
#define MemoryAccessInvalidNotification     @"MemoryAccessInvalidNotification"
#define DidLoadViewInMainWindowNotification @"DidLoadViewInMainWindowNotification"

BOOL Ascii2Virtual(char pcar, BOOL *pshift, BOOL *palt, char *pkeycode);


@interface Controller : NSObject <GrowlApplicationBridgeDelegate> {
    IBOutlet PlayerDataController	*playerData;
    IBOutlet MemoryViewController	*memoryViewController;
    IBOutlet BotController			*botController;
    IBOutlet MobController			*mobController;
    IBOutlet NodeController			*nodeController;
    IBOutlet PlayersController		*playersController;
    IBOutlet InventoryController	*itemController;
    IBOutlet SpellController		*spellController;
    IBOutlet WaypointController		*routeController;
    IBOutlet ProcedureController	*behaviorController;
    IBOutlet ChatLogController		*chatLogController;
	IBOutlet CorpseController		*corpseController;
	IBOutlet OffsetController		*offsetController;
	IBOutlet StatisticsController	*statisticsController;
	
    IBOutlet id mainWindow;
    IBOutlet NSToolbar *mainToolbar;
    IBOutlet NSToolbarItem *botToolbarItem, *playerToolbarItem, *itemsToolbarItem, *spellsToolbarItem;
    IBOutlet NSToolbarItem *playersToolbarItem, *mobsToolbarItem, *nodesToolbarItem, *routesToolbarItem, *behavsToolbarItem;
    IBOutlet NSToolbarItem *memoryToolbarItem, *prefsToolbarItem, *chatLogToolbarItem, *statisticsToolbarItem;
	
	IBOutlet NSPopUpButton *wowInstancePopUpButton;
	int _selectedPID;
	int _lastAttachedPID;
    
    IBOutlet NSView *aboutView, *settingsView;
    IBOutlet NSImageView *aboutValidImage;
    IBOutlet NSTextField *versionInfoText;
	IBOutlet NSTextField *compileInfoText;
    
    IBOutlet id mainBackgroundBox;
    IBOutlet id memoryAccessLight;
    IBOutlet id memoryAccessValidText;
    IBOutlet id currentStatusText;
    
    // security stuff
    IBOutlet NSButton *disableGUIScriptCheckbox, *matchExistingCheckbox;
    IBOutlet NSTextField *newNameField, *newIdentifierField, *newSignatureField;
    NSString *_matchExistingApp;
    
    NSMutableArray *_items, *_mobs, *_players, *_gameObjects, *_dynamicObjects, *_corpses;
	
	// new scan
	NSMutableArray *_objectAddresses;
	UInt32 _currentObjectManager;
	int _totalObjects;
	UInt32 _currentAddress;
	BOOL _validObjectListManager;
	
    MemoryAccess *_wowMemoryAccess;
    NSString *_savedStatus;
    BOOL _appFinishedLaunching;
    int _currentState;
    BOOL _isRegistered;
	UInt64 _globalGUID;
	BOOL _invalidPlayerNotificationSent;
	
	NSTimer *_updateNameListTimer;
	NSMutableDictionary *_nameListAddresses;
	int _nameListSavedRead;

    NSDictionary *factionTemplate;
}

+ (Controller *)sharedController;

@property BOOL isRegistered;
@property (readonly) UInt64 globalGUID;

- (IBAction)showAbout: (id)sender;
- (IBAction)showSettings: (id)sender;
- (IBAction)launchWebsite:(id)sender;
- (IBAction)toolbarItemSelected: (id)sender;
- (IBAction)pidSelected: (id)sender;

- (void)revertStatus;
- (NSString*)currentStatus;
- (void)setCurrentStatus: (NSString*)statusMsg;

- (NSString*)appName;
- (NSString*)appSignature;
- (NSString*)appIdentifier;
- (BOOL)sendGrowlNotifications;

// new scan
- (NSArray*)allObjectAddresses;
- (BOOL)isObjectManagerValid;

// WoW information
- (BOOL)isWoWOpen;
- (BOOL)isWoWFront;
- (BOOL)isWoWHidden;
- (BOOL)isWoWChatBoxOpen;
- (BOOL)isWoWVersionValid;
- (BOOL)makeWoWFront;
- (NSString*)wowPath;
- (NSString*)wtfAccountPath;
- (NSString*)wtfCharacterPath;
- (int)getWOWWindowID;
- (CGRect)wowWindowRect;
- (unsigned)refreshDelay;
- (unsigned)refreshDelayReal;
- (Position*)cameraPosition;
- (NSString*)wowVersionShort;
- (NSString*)wowVersionLong;
- (MemoryAccess*)wowMemoryAccess;
- (ProcessSerialNumber)getWoWProcessSerialNumber;
- (CGPoint)screenPointForGamePosition: (Position*)gamePosition;

- (void)showMemoryView;

- (void)killWOW;

// factions stuff
- (NSDictionary*)factionDict;
- (UInt32)reactMaskForFaction: (UInt32)faction;
- (UInt32)friendMaskForFaction: (UInt32)faction;
- (UInt32)enemyMaskForFaction: (UInt32)faction;

// security routines
- (IBAction)toggleGUIScripting: (id)sender;
- (IBAction)toggleSecurePrefs: (id)sender;
- (IBAction)confirmAppRename: (id)sender;
- (IBAction)renameUseExisting: (id)sender;
- (IBAction)renameShowHelp: (id)sender;

- (IBAction)testFront: (id)sender;

- (void)traverseNameList;
@end

@interface NSObject (MemoryViewControllerExtras)
- (NSString*)infoForOffset: (unsigned)offset;
@end
