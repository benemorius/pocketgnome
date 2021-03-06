//
//  CombatProfileEditor.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 7/19/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CombatProfile.h"

@class PlayersController;
@class Player;

@interface CombatProfileEditor : NSObject {
    IBOutlet NSPanel			*editorPanel;
    IBOutlet NSPanel			*renamePanel;
    IBOutlet NSTableView		*ignoreTable;
	IBOutlet NSPopUpButton		*playerList;
	
	IBOutlet PlayersController	*playersController;
	
    NSMutableArray				*_combatProfiles;
    CombatProfile				*_currentCombatProfile;
}

@property (readonly) NSArray *combatProfiles;

+ (CombatProfileEditor *)sharedEditor;
- (void)showEditorOnWindow: (NSWindow*)window forProfileNamed: (NSString*)profile;

- (NSArray*)combatProfiles;
- (IBAction)createCombatProfile: (id)sender;
- (IBAction)loadCombatProfile: (id)sender;

- (IBAction)renameCombatProfile: (id)sender;
- (IBAction)closeRename: (id)sender;
- (IBAction)duplicateCombatProfile: (id)sender;
- (IBAction)deleteCombatProfile: (id)sender;

- (void)importCombatProfileAtPath: (NSString*)path;
- (IBAction)importCombatProfile: (id)sender;
- (IBAction)exportCombatProfile: (id)sender;

- (IBAction)addIgnoreEntry: (id)sender;
- (IBAction)addIgnoreFromTarget: (id)sender;
- (IBAction)deleteIgnoreEntry: (id)sender;

- (IBAction)closeEditor: (id)sender;

- (IBAction)playerList: (id)sender;

- (IBAction)tankSelected: (id)sender;

@end
