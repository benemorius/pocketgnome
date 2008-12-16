//
//  WaypointController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/16/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import "WaypointController.h"
#import "Controller.h"
#import "PlayerDataController.h"
#import "MovementController.h"
#import "MobController.h"
#import "CombatController.h"
#import "SpellController.h"
#import "InventoryController.h"

#import "RouteSet.h"
#import "Route.h"
#import "Waypoint.h"
#import "Action.h"
#import "Mob.h"
#import "ActionMenusController.h"

#import "RouteVisualizationView.h"

#import "PTHeader.h"
#import <Growl/GrowlApplicationBridge.h>
#import <ShortcutRecorder/ShortcutRecorder.h>

#define AddWaypointHotkeyIdentifier @"AddWaypoint"

@interface WaypointController (Internal)
- (void)toggleGlobalHotKey:(id)sender;
@end

@implementation WaypointController

- (id) init
{
    self = [super init];
    if (self != nil) {
        changeWasMade = NO;
        id loadedRoutes = [[NSUserDefaults standardUserDefaults] objectForKey: @"Routes"];
        if(loadedRoutes) {
            _routes = [[NSKeyedUnarchiver unarchiveObjectWithData: loadedRoutes] mutableCopy];
            
            NSMutableArray *_newRoutes = [NSMutableArray array];
            for(id route in _routes) {
                if( [route isKindOfClass: [Route class]] ) {
                    RouteSet *newSet = [RouteSet routeSetWithName: [route name]];
                    [newSet setRoute: route forKey: PrimaryRoute];
                    [_newRoutes addObject: newSet];
                }
            }
            
            if([_newRoutes count]) {
                PGLog(@"Updated %d routes to routesets.", [_newRoutes count]);
                [_routes removeAllObjects];
                [_routes addObjectsFromArray: _newRoutes];
            }
            
        } else
            _routes = [[NSMutableArray array] retain];
        
        
        // listen for notification

        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(applicationWillTerminate:) name: NSApplicationWillTerminateNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(checkHotkeys:) 
                                                     name: DidLoadViewInMainWindowNotification 
                                                   object: nil];
        
        [NSBundle loadNibNamed: @"Routes" owner: self];
    }
    return self;
}

- (void)awakeFromNib {
    self.minSectionSize = [self.view frame].size;
    self.maxSectionSize = NSZeroSize;

    [waypointTable registerForDraggedTypes: [NSArray arrayWithObjects: @"WaypointIndexesType", @"WaypointArrayType", nil]];

    if( !self.currentRoute && [_routes count]) {
        [self setCurrentRouteSet: [_routes objectAtIndex: 0]];
        [waypointTable reloadData];
    }
    
    [shortcutRecorder setCanCaptureGlobalHotKeys: YES];
    
    KeyCombo combo = { -1, 0 };
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyCode"])
        combo.code = [[[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyCode"] intValue];
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyFlags"])
        combo.flags = [[[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyFlags"] intValue];
    
    [shortcutRecorder setDelegate: nil];
    [shortcutRecorder setKeyCombo: combo];
    [shortcutRecorder setDelegate: self];
}

- (void)saveRoutes {
    if(changeWasMade) {
        [[NSUserDefaults standardUserDefaults] setObject: [NSKeyedArchiver archivedDataWithRootObject: _routes] forKey: @"Routes"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        changeWasMade = NO;
    }
}

- (void)validateBindings {
    [self willChangeValueForKey: @"currentRoute"];
    [self didChangeValueForKey: @"currentRoute"];
    
    self.validSelection = [waypointTable numberOfSelectedRows] ? YES : NO;
    self.validWaypointCount = [[self currentRoute] waypointCount] > 1 ? YES : NO;
}

- (void)applicationWillTerminate: (NSNotification*)notification {
    [self saveRoutes];
}

#pragma mark -
#pragma mark Current State

@synthesize view;
@synthesize minSectionSize;
@synthesize maxSectionSize;
@synthesize currentRoute = _currentRoute;
@synthesize currentRouteSet = _currentRouteSet;

@synthesize validSelection;
@synthesize validWaypointCount;

- (NSString*)sectionTitle {
    return @"Routes & Waypoints";
}

- (NSString*)currentRouteKey {
    if( [routeTypeSegment selectedTag] == 0 )
        return PrimaryRoute;
    if( [routeTypeSegment selectedTag] == 1 )
        return CorpseRunRoute;
    return @"";
}

- (NSArray*)routes {
    return [[_routes retain] autorelease];
}

/*- (Route*)currentRoute {
    return [[_route retain] autorelease];
}

- (void)setCurrentRoute: (Route*)route {
    [_route autorelease];
    _route = [route retain];
}*/

- (Route*)currentRoute {
    return [[self currentRouteSet] routeForKey: [self currentRouteKey]];
}

- (void)setCurrentRouteSet: (RouteSet*)routeSet {
    [_currentRouteSet autorelease];
    _currentRouteSet = [routeSet retain];
    
    [routeTypeSegment selectSegmentWithTag: 0];
    [self validateBindings];

}

#pragma mark -
#pragma mark Route Actions


- (void)addRoute: (RouteSet*)routeSet {
    int num = 2;
    BOOL done = NO;
    
    if(![[routeSet name] length]) return;
    
    // check to see if a route exists with this name
    NSString *originalName = [routeSet name];
    while(!done) {
        BOOL conflict = NO;
        for(RouteSet *route in self.routes) {
            if( [[route name] isEqualToString: [routeSet name]]) {
                [routeSet setName: [NSString stringWithFormat: @"%@ %d", originalName, num++]];
                conflict = YES;
                break;
            }
        }
        if(!conflict) done = YES;
    }
    
    // save this route into our array
    [self willChangeValueForKey: @"routes"];
    [_routes addObject: routeSet];
    [self didChangeValueForKey: @"routes"];

    // update the current route
    changeWasMade = YES;
    [self setCurrentRouteSet: routeSet];
    [waypointTable reloadData];
    
    // PGLog(@"Added route: %@", [routeSet name]);
}

- (IBAction)createRoute: (id)sender {
    // make sure we have a valid name
    NSString *routeName = [sender stringValue];
    if( [routeName length] == 0) {
        NSBeep();
        return;
    }
    
    // create a new route
    [self addRoute: [RouteSet routeSetWithName: routeName]];
    [sender setStringValue: @""];
}

- (IBAction)loadRoute: (id)sender {
    [waypointTable reloadData];
}

- (IBAction)setRouteType: (id)sender {
    [waypointTable reloadData];
    [self validateBindings];
}

- (IBAction)removeRoute: (id)sender {
    if([self currentRouteSet]) {
        
        int ret = NSRunAlertPanel(@"Delete Route?", [NSString stringWithFormat: @"Are you sure you want to delete the route \"%@\"?", [[self currentRouteSet] name]], @"Delete", @"Cancel", NULL);
        if(ret == NSAlertDefaultReturn) {
            
            [self willChangeValueForKey: @"routes"];
            [_routes removeObject: [self currentRouteSet]];
            
            if([_routes count])
                [self setCurrentRouteSet: [_routes objectAtIndex: 0]];
            else
                [self setCurrentRouteSet: nil];
                
            [self didChangeValueForKey: @"routes"];
            
            changeWasMade = YES;
            [waypointTable reloadData];
        }
    }
}

- (IBAction)duplicateRoute: (id)sender {
    [self addRoute: [self.currentRouteSet copy]];
}

- (IBAction)renameRoute: (id)sender {
	[NSApp beginSheet: renamePanel
	   modalForWindow: [self.view window]
		modalDelegate: nil
	   didEndSelector: nil //@selector(sheetDidEnd: returnCode: contextInfo:)
		  contextInfo: nil];
}

- (IBAction)closeRename: (id)sender {
    [[sender window] makeFirstResponder: [[sender window] contentView]];
    [NSApp endSheet: renamePanel returnCode: 1];
    [renamePanel orderOut: nil];

    changeWasMade = YES;
}

#pragma mark -

- (void)importRouteAtPath: (NSString*)path {
    id importedRoute;
    NS_DURING {
        importedRoute = [NSKeyedUnarchiver unarchiveObjectWithFile: path];
    } NS_HANDLER {
        importedRoute = nil;
    } NS_ENDHANDLER
    
    if(importedRoute && [importedRoute respondsToSelector: @selector(routeForKey:)]) {
        [self addRoute: importedRoute];
    } else {
        NSRunAlertPanel(@"Route not Valid", [NSString stringWithFormat: @"The file at %@ cannot be imported because it does not contain a valid route.", path], @"Okay", NULL, NULL);
    }
    
}

- (IBAction)importRoute: (id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	[openPanel setCanChooseDirectories: NO];
	[openPanel setCanCreateDirectories: NO];
	[openPanel setPrompt: @"Import Route"];
	[openPanel setCanChooseFiles: YES];
    [openPanel setAllowsMultipleSelection: YES];
	
	int ret = [openPanel runModalForTypes: [NSArray arrayWithObject: @"route"]];
    
	if(ret == NSFileHandlingPanelOKButton) {
        for(NSString *routePath in [openPanel filenames]) {
            [self importRouteAtPath: routePath];
        }
	}
}

- (IBAction)exportRoute: (id)sender {

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setCanCreateDirectories: YES];
    [savePanel setTitle: @"Export Route"];
    [savePanel setMessage: @"Please choose a destination for this route."];
    int ret = [savePanel runModalForDirectory: @"~/" file: [[[self currentRouteSet] name] stringByAppendingPathExtension: @"route"]];
    
	if(ret == NSFileHandlingPanelOKButton) {
        NSString *saveLocation = [savePanel filename];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject: [self currentRouteSet]];
        [data writeToFile: saveLocation atomically: YES];
    }
    
}

#pragma mark -
#pragma mark Waypoint & Other Actions

- (IBAction)visualize: (id)sender {
    if([[self currentRouteKey] isEqualToString: PrimaryRoute])
        [visualizeView setShouldClosePath: YES];
    else
        [visualizeView setShouldClosePath: NO];
    
    [visualizeView setRoute: [self currentRoute]];
    [visualizeView setPlayerPosition: [playerData position]];
    [visualizeView setNeedsDisplay: YES];

	[NSApp beginSheet: visualizePanel
	   modalForWindow: [waypointTable window]
		modalDelegate: nil
	   didEndSelector: nil //@selector(sheetDidEnd: returnCode: contextInfo:)
		  contextInfo: nil];
}

- (IBAction)closeVisualize: (id)sender {
    [NSApp endSheet: visualizePanel returnCode: 1];
    [visualizePanel orderOut: nil];
}

- (IBAction)addWaypoint: (id)sender {
    if(![self currentRoute])        return;
    if(![playerData playerIsValid]) return;
    if(![self.view window])         return;

    Waypoint *newWP = [Waypoint waypointWithPosition: [playerData position]];
    [[self currentRoute] addWaypoint: newWP];
    [waypointTable reloadData];
    changeWasMade = YES;
    PGLog(@"Added: %@", newWP);
    NSString *readableRoute =  ([routeTypeSegment selectedTag] == 0) ? @"Primary" : @"Corpse Run";
    
    if( [controller sendGrowlNotifications] && [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
        // [GrowlApplicationBridge setGrowlDelegate: @""];
        [GrowlApplicationBridge notifyWithTitle: @"Added Waypoint"
                                    description: [NSString stringWithFormat: @"Added waypoint to %@ route of \"%@\"", readableRoute, [[self currentRouteSet] name]]
                               notificationName: @"AddWaypoint"
                                       iconData: [[NSImage imageNamed: @"Ability_Rogue_Sprint"] TIFFRepresentation]
                                       priority: 0
                                       isSticky: NO
                                   clickContext: nil];
    }
}

- (IBAction)removeWaypoint: (id)sender {
    NSIndexSet *rowIndexes = [waypointTable selectedRowIndexes];
    if([rowIndexes count] == 0 || ![self currentRoute]) return;
    
    int row = [rowIndexes lastIndex];
    while(row != NSNotFound) {
        [[self currentRoute] removeWaypointAtIndex: row];
        row = [rowIndexes indexLessThanIndex: row];
    }
    
    [waypointTable selectRow: [rowIndexes firstIndex] byExtendingSelection: NO]; 
    
    [waypointTable reloadData];
    changeWasMade = YES;
}

- (IBAction)editWaypointAction: (id)sender {
    // make sure the clicked row is valid
    if([waypointTable clickedRow] < 0 || [waypointTable clickedRow] >= [[self currentRoute] waypointCount]) {
        NSBeep();
        PGLog(@"Error: invalid row (%d), cannot change action.", [waypointTable clickedRow]);
        return;
    }
    
    // get our waypoint
    Waypoint *wp = [[self currentRoute] waypointAtIndex: [waypointTable clickedRow]];
    _editWaypoint = wp;
    
    // PGLog(@"Modifying WP %@", wp);
    
    int type = 0;
    if(([sender tag] == ActionType_Spell) && wp.action.isPerform) {
        type = 2;
    } else {
        if([sender tag] != wp.action.type) {
            wp.action.value = [NSNumber numberWithInt: 0];
        }
        wp.action.type = type = [sender tag];
        
        if(wp.action.type == ActionType_Delay)
            type = 1;
        if(wp.action.type == ActionType_Spell)
            type = 2;
    }
    
    // we only need to setup the GUI if this is a non-normal type
    if( [wp.action type] != ActionType_None ) {
        // PGLog(@"EDITING FOR %d", [wp.action type]);
        // select the correct tab for our action
        [wpActionTabs selectTabViewItemAtIndex: type];
        [wpActionDelayText setFloatValue: wp.action.delay];
        
        // if we are a spell, item, or macro, set the correct segment
        // otherwise, just set it to spell
        if(wp.action.isPerform) {
            [wpActionTypeSegments selectSegmentWithTag: wp.action.type];
        } else {
            [wpActionTypeSegments selectSegmentWithTag: ActionType_Spell];
        }
        
        // generate the correct menu for the popup
        [self changeWaypointAction: wpActionTypeSegments];
        
        // pop open the editor window
        [NSApp beginSheet: wpActionPanel
           modalForWindow: [self.view window]
            modalDelegate: nil
           didEndSelector: nil //@selector(sheetDidEnd: returnCode: contextInfo:)
              contextInfo: nil];
    } else {
        _editWaypoint = nil;
        [waypointTable reloadData];
    }
    changeWasMade = YES;
}

- (IBAction)changeWaypointAction: (id)sender {
    // PGLog(@"changeAction: %@", sender);
    Waypoint *wp = _editWaypoint;
    sender = (BetterSegmentedControl*)sender;
    
    //PGLog(@"%d vs. %d", [waypointTable clickedRow], [waypointTable selectedRow]);
    //[[waypointTable tableColumnWithIdentifier: @"Type"]
    //return;
    
    if(!wp || !sender) return;
    
    // get appropriate menu
    NSMenu *menu = [[ActionMenusController sharedMenus] menuType: [sender selectedTag] actionID: wp.action.actionID];
    if(menu) {
        [wpActionIDPopUp setMenu: menu];
        [wpActionIDPopUp selectItemWithTag: [wp.action.value unsignedIntValue]];
    } else {
        PGLog(@"Error creating menu for type %d, action %d", [sender selectedTag], [wp.action.value unsignedIntValue]);
    }
    
}

- (IBAction)closeWaypointAction: (id)sender {
    [[sender window] makeFirstResponder: [[sender window] contentView]];
    [NSApp endSheet: wpActionPanel returnCode: NSOKButton];
    [wpActionPanel orderOut: nil];
    
    Waypoint *wp = _editWaypoint;
    if(!wp) {
        PGLog(@"Error editing waypoint action; there is no selected row!");
        return;
    }
    
    wp.action.value = [NSNumber numberWithInt: 0];
    
    if([[[wpActionTabs selectedTabViewItem] identifier] isEqualToString: @"Normal"]) {
        wp.action.type = ActionType_None;
    } else if([[[wpActionTabs selectedTabViewItem] identifier] isEqualToString: @"Delay"]) {
        if([wpActionDelayText floatValue] == 0.0f) {   // if the delay is 0, set back to normal
            wp.action.type = ActionType_None;
        } else {
            wp.action.type = ActionType_Delay;
            wp.action.value = [NSNumber numberWithFloat: [wpActionDelayText floatValue]];
        }
        //PGLog(@"Delay: %@", wp.action.value);
    } else {
        wp.action.type = ActionType_None;
        
        /* waypoint actions are not currently enabled
        if([[wpActionIDPopUp selectedItem] tag] == 0.0f) {    // if no action specified, set back to normal
            wp.action.type = ActionType_None;
        } else {
            wp.action.type = [wpActionTypeSegments selectedTag];
            wp.action.value = [NSNumber numberWithUnsignedInt: [[wpActionIDPopUp selectedItem] tag]];
        }*/
        //PGLog(@"Action: %@", wp.action.value);
    }
    
    _editWaypoint = nil;
    [waypointTable reloadData];
}

- (IBAction)cancelWaypointAction: (id)sender {
    [[sender window] makeFirstResponder: [[sender window] contentView]];
    [NSApp endSheet: wpActionPanel returnCode: NSCancelButton];
    [wpActionPanel orderOut: nil];
}


- (IBAction)moveToWaypoint: (id)sender {
    int row = [[waypointTable selectedRowIndexes] firstIndex];
    if(row == NSNotFound || ![self currentRoute]) return;
    
    Waypoint *waypoint = [[self currentRoute] waypointAtIndex: row];
    
    //[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(movementFinished:) name: @"MovementFinished" object: [waypoint position]];
    [movementController moveToWaypoint: waypoint];
}

- (IBAction)testWaypointSequence: (id)sender {
    if(![self currentRoute] || ![[self currentRoute] waypointCount])    return;
    
    [movementController setPatrolRoute: [self currentRoute]];
    [movementController beginPatrol: 1 andAttack: NO];
}

- (IBAction)stopMovement: (id)sender {
    [movementController setPatrolRoute: nil];
}


#pragma mark -
#pragma mark NSTableView Delesource

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [[self currentRoute] waypointCount];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    if(rowIndex == -1) return nil;
    
    Waypoint *wp = [[self currentRoute] waypointAtIndex: rowIndex];
    if( [[aTableColumn identifier] isEqualToString: @"Step"] ) {
        return [NSNumber numberWithInt: rowIndex+1];
    }
    
    if( [[aTableColumn identifier] isEqualToString: @"Type"] ) {
        int type = 0;
        if((wp.action.type <= ActionType_None) || (wp.action.type >= ActionType_Max))
            type = 0;
        if(wp.action.isPerform) {
            //PGLog(@"%d is PERFORM (%d)", rowIndex, wp.action.type);
            type = 2;
        }
        if(wp.action.type == ActionType_Delay) {
            //PGLog(@"%d is DELAY (%d)", rowIndex, wp.action.type);
            type = 1;
        }
        return [NSNumber numberWithInt: type];
    }
    
    
    if([[aTableColumn identifier] isEqualToString: @"Coordinates"]) {
        if(wp.action.type == ActionType_Delay)
            return [NSString stringWithFormat: @"Delay for %.2f seconds.", [wp.action.value floatValue]];
        if(wp.action.type == ActionType_Spell) {
            if([[[SpellController sharedSpells] spellForID: [NSNumber numberWithUnsignedInt: wp.action.actionID]] fullName])
                return [NSString stringWithFormat: @"Ability: %@", [[[SpellController sharedSpells] spellForID: [NSNumber numberWithUnsignedInt: wp.action.actionID]] fullName]];
            else
                return [NSString stringWithFormat: @"Ability: %@", wp.action.value];
        }
        if(wp.action.type == ActionType_Item) {
            return [NSString stringWithFormat: @"Item: %@", [[InventoryController sharedInventory] nameForID: [NSNumber numberWithUnsignedInt: wp.action.actionID]]];
        }
        if(wp.action.type == ActionType_Macro) {
            return [NSString stringWithFormat: @"Macro: %@", wp.action.value];
        }
        return [NSString stringWithFormat: @"X: %.1f; Y: %.1f; Z: %.1f", [[wp position] xPosition], [[wp position] yPosition], [[wp position] zPosition]];
    }
    
    if([[aTableColumn identifier] isEqualToString: @"Distance"]) {
        Waypoint *prevWP = (rowIndex == 0) ? ([[self currentRoute] waypointAtIndex: [[self currentRoute] waypointCount] - 1]) : ([[self currentRoute] waypointAtIndex: rowIndex-1]);
        float distance = [[wp position] distanceToPosition: [prevWP position]];
        return [NSString stringWithFormat: @"%.2f yards", distance];
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {

}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if([[aTableColumn identifier] isEqualToString: @"Type"] ) {
        return YES;
    }
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    [self validateBindings];
}

- (void)tableView: (NSTableView*)tableView deleteKeyPressedOnRowIndexes: (NSIndexSet*)rowIndexes {
    [self removeWaypoint: nil];
}

- (BOOL)tableViewCopy: (NSTableView*)tableView {
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    if([rowIndexes count] == 0) {
        return NO;
    }
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard declareTypes: [NSArray arrayWithObjects: NSStringPboardType, @"WaypointArrayType", nil] owner: nil];

    // create list of our waypoints
    NSMutableArray *waypointList = [NSMutableArray arrayWithCapacity: [rowIndexes count]];
    int aRow = [rowIndexes firstIndex];
    while (aRow != NSNotFound) {
        [waypointList addObject: [[self currentRoute] waypointAtIndex: aRow]];
        aRow = [rowIndexes indexGreaterThanIndex: aRow];
    }
    [pboard setData: [NSKeyedArchiver archivedDataWithRootObject: waypointList] forType: @"WaypointArrayType"];
    
    NSMutableString *stringVal = [NSMutableString string];
    for(Waypoint *wp in waypointList) {
        [stringVal appendFormat: @"{ %.2f, %.2f, %.2f }\n", wp.position.xPosition, wp.position.yPosition, wp.position.zPosition ];
    }
    [pboard setString: stringVal forType: NSStringPboardType];
    
    return YES;
}

- (BOOL)tableViewPaste: (NSTableView*)tableView {
    NSPasteboard* pboard = [NSPasteboard generalPasteboard];
    NSData *data = [pboard dataForType: @"WaypointArrayType"];
    if(!data) return NO;
    
    NSArray *copiedWaypoints = [NSKeyedUnarchiver unarchiveObjectWithData: data];
    
    if( !copiedWaypoints || ![self currentRoute] ) {
        return NO;
    }
    
    int index = [[tableView selectedRowIndexes] firstIndex];
    if(index == NSNotFound) index = [[self currentRoute] waypointCount];
    
    // insert waypoints in reverse order
    for (Waypoint *wp in [copiedWaypoints reverseObjectEnumerator]) {
        [[self currentRoute] insertWaypoint: wp atIndex: index];
    }
    
    // reload and select the pasted routes
    [tableView reloadData];
    [tableView selectRowIndexes: [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(index, [copiedWaypoints count])] byExtendingSelection: NO];
    
    return YES;
}

- (BOOL)tableViewCut: (NSTableView*)tableView {
    if( [self tableViewCopy: tableView] ) {
        [self removeWaypoint: nil];
        return YES;
    }
    return NO;
}

#pragma mark Table Drag & Drop

// begin drag operation, save row index
- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
    // Copy the row numbers to the pasteboard.
    [pboard declareTypes: [NSArray arrayWithObjects: @"WaypointIndexesType", nil] owner: self];
    [pboard setData: [NSKeyedArchiver archivedDataWithRootObject: rowIndexes] forType: @"WaypointIndexesType"];

    return YES;
}

// validate drag operation
- (NSDragOperation) tableView: (NSTableView*) tableView
                 validateDrop: (id ) info
                  proposedRow: (int) row
        proposedDropOperation: (NSTableViewDropOperation) op
{
    int result = NSDragOperationNone;
    
    if (op == NSTableViewDropAbove) {
        result = NSDragOperationMove;
        
        /*NSPasteboard* pboard = [info draggingPasteboard];
        NSData* rowData = [pboard dataForType: @"WaypointType"];
        NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
        int dragRow = [rowIndexes firstIndex];
        
        if(dragRow == row || dragRow == row-1) {
            result = NSDragOperationNone;
        }*/
    }
    
    return (result);
    
}

// accept the drop
- (BOOL)tableView: (NSTableView *)aTableView 
       acceptDrop: (id <NSDraggingInfo>)info
              row: (int)row 
    dropOperation: (NSTableViewDropOperation)operation {
    
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData *data = [pboard dataForType: @"WaypointIndexesType"];
    if(!data) return NO;
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: data];
    if(!rowIndexes ) {
        PGLog(@"Error dragging waypoints. Indexes invalid.");
        return NO;
    }

    // PGLog(@"Draggin %d rows to above row %d", [rowIndexes count], row);
    
    Waypoint *targetWP = [[self currentRoute] waypointAtIndex: row];
    NSMutableArray *wpToInsert = [NSMutableArray arrayWithCapacity: [rowIndexes count]];
    
    // save and remove all waypoints we are moving.
    // do it in reverse order so as to not mess up earlier indexes
    int aRow = [rowIndexes lastIndex];
    while (aRow != NSNotFound) {
        [wpToInsert addObject: [[self currentRoute] waypointAtIndex: aRow]];
        [[self currentRoute] removeWaypointAtIndex: aRow];
        aRow = [rowIndexes indexLessThanIndex: aRow];
    }
    
    // now, find the current index of the saved waypoint
    int index = [[[self currentRoute] waypoints] indexOfObjectIdenticalTo: targetWP];
    if(index == NSNotFound) index = [[self currentRoute] waypointCount];
    // PGLog(@"Target index: %d", index);

    // don't need to reverseEnum because the order is already reversed
    for (Waypoint *wp in wpToInsert) {
        [[self currentRoute] insertWaypoint: wp atIndex: index];
    }
    
    
    /*
    int numIns = 0;
    int dragRow = [rowIndexes firstIndex];
    if(dragRow < row) { 
        PGLog(@" --> Decrementing row to %d because dragRow (%d) < row (%d)", row-1, dragRow, row);
        row--;
    }
    
    // at this point, "row" is index of the waypoint above where we want to move everything
    
    //while (dragRow != NSNotFound) {
        // Move the specified row to its new location...
        Waypoint *dragWaypoint = [[self currentRoute] waypointAtIndex: dragRow];
        [[self currentRoute] removeWaypointAtIndex: dragRow];
        [[self currentRoute] insertWaypoint: dragWaypoint atIndex: (row + numIns)];
        
        PGLog(@" --> Moving row %d to %d", dragRow, (row + numIns));
        
        numIns++;
        dragRow = [rowIndexes indexGreaterThanIndex: dragRow];
    //}
    */
    
    // reload and select rows
    [aTableView reloadData];
    [aTableView selectRowIndexes: [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(index, [wpToInsert count])] byExtendingSelection: NO];
    
    return YES;
}

#pragma mark ShortcutRecorder Delegate

- (void)checkHotkeys: (NSNotification*)notification {

    BOOL isEnabled = ([[PTHotKeyCenter sharedCenter] hotKeyWithIdentifier: AddWaypointHotkeyIdentifier]) ? YES : NO;

    if( [notification object] == self.view ) {
        if(!isEnabled) {
            [self toggleGlobalHotKey: shortcutRecorder];
        }
    } else {
        if(isEnabled) {
            [self toggleGlobalHotKey: shortcutRecorder];
            [self saveRoutes];
        }
    }
}

- (void)toggleGlobalHotKey:(id)sender
{
	if (addWaypointGlobalHotkey != nil) {
		[[PTHotKeyCenter sharedCenter] unregisterHotKey: addWaypointGlobalHotkey];
		[addWaypointGlobalHotkey release];
		addWaypointGlobalHotkey = nil;
	} else {
        KeyCombo keyCombo = [shortcutRecorder keyCombo];
        
        if(keyCombo.code >= 0 && keyCombo.flags >= 0) {
            addWaypointGlobalHotkey = [[PTHotKey alloc] initWithIdentifier: AddWaypointHotkeyIdentifier
                                                                  keyCombo: [PTKeyCombo keyComboWithKeyCode: keyCombo.code
                                                                                                  modifiers: [shortcutRecorder cocoaToCarbonFlags: keyCombo.flags]]];
            
            [addWaypointGlobalHotkey setTarget: self];
            [addWaypointGlobalHotkey setAction: @selector(addWaypoint:)];
            
            [[PTHotKeyCenter sharedCenter] registerHotKey: addWaypointGlobalHotkey];
        }
    }
}

- (void)shortcutRecorder:(SRRecorderControl *)recorder keyComboDidChange:(KeyCombo)newKeyCombo {
    
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.code] forKey: @"WaypointAdd_HotkeyCode"];
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.flags] forKey: @"WaypointAdd_HotkeyFlags"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // register this hotkey globally
    [self toggleGlobalHotKey: recorder];
    
}


@end
