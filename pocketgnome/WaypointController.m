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

#import "BetterTableView.h"

#import "PTHeader.h"
#import <Growl/GrowlApplicationBridge.h>
#import <ShortcutRecorder/ShortcutRecorder.h>

#define AddWaypointHotkeyIdentifier @"AddWaypoint"
#define AutomatorHotkeyIdentifier @"AutomatorStartStop"

enum AutomatorIntervalType {
    AutomatorIntervalType_Time = 0,
    AutomatorIntervalType_Distance = 1,
};

@interface WaypointController (Internal)
- (void)toggleGlobalHotKey:(id)sender;
- (void)automatorPulse;
@end

@implementation WaypointController

+ (void) initialize {
    NSDictionary *waypointDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"0.5",                       @"RouteAutomatorIntervalValue",
                                      [NSNumber numberWithInt: 0],  @"RouteAutomatorIntervalTypeTag", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults: waypointDefaults];
}

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
                log(LOG_WAYPOINT, @"Updated %d routes to routesets.", [_newRoutes count]);
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
    
    // Automator isn't running!
    self.isAutomatorRunning = NO;
    
    [shortcutRecorder setCanCaptureGlobalHotKeys: YES];
	[automatorRecorder setCanCaptureGlobalHotKeys: YES];
    
    KeyCombo combo = { -1, 0 };
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyCode"])
        combo.code = [[[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyCode"] intValue];
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyFlags"])
        combo.flags = [[[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAdd_HotkeyFlags"] intValue];
    
	KeyCombo combo2 = {NSShiftKeyMask, kSRKeysF14};
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAutomator_HotkeyCode"])
        combo2.code = [[[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAutomator_HotkeyCode"] intValue];
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAutomator_HotkeyFlags"])
        combo2.flags = [[[NSUserDefaults standardUserDefaults] objectForKey: @"WaypointAutomator_HotkeyFlags"] intValue];
	
    [shortcutRecorder setDelegate: nil];
    [shortcutRecorder setKeyCombo: combo];
    [shortcutRecorder setDelegate: self];
	
    [automatorRecorder setDelegate: nil];
    [automatorRecorder setKeyCombo: combo2];
    [automatorRecorder setDelegate: self];
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

@synthesize disableGrowl;
@synthesize validSelection;
@synthesize validWaypointCount;
@synthesize isAutomatorRunning;

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
    if(![routeSet isKindOfClass: [RouteSet class]]) return;
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
    
    log(LOG_WAYPOINT, @"Added route: %@", [routeSet name]);
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
	
	[isFlyingRouteButton setState:[self currentRoute].isFlyingRoute];
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
    
    if(importedRoute) {
        if([importedRoute isKindOfClass: [RouteSet class]]) {
            [self addRoute: importedRoute];
        } else if([importedRoute isKindOfClass: [NSArray class]]) {
            for(RouteSet *route in importedRoute) {
                [self addRoute: route];
            }
        } else {
            importedRoute = nil;
        }
    }
    
    if(!importedRoute) {
        NSRunAlertPanel(@"Route not Valid", [NSString stringWithFormat: @"The file at %@ cannot be imported because it does not contain a valid route or route set.", path], @"Okay", NULL, NULL);
    }
}

- (IBAction)importRoute: (id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	[openPanel setCanChooseDirectories: NO];
	[openPanel setCanCreateDirectories: NO];
	[openPanel setPrompt: @"Import Route"];
	[openPanel setCanChooseFiles: YES];
    [openPanel setAllowsMultipleSelection: YES];
	
	int ret = [openPanel runModalForTypes: [NSArray arrayWithObjects: @"route", @"routeset", nil]];
    
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

- (IBAction)openExportPanel: (id)sender {

	[NSApp beginSheet: exportPanel
	   modalForWindow: [waypointTable window]
		modalDelegate: nil
	   didEndSelector: nil //@selector(sheetDidEnd: returnCode: contextInfo:)
		  contextInfo: nil];
}

- (IBAction)closeExportPanel: (id)sender {
    [NSApp endSheet: exportPanel returnCode: 1];
    [exportPanel orderOut: nil];
}

- (IBAction)exportRoutes: (id)sender {
    if(![sender count]) {
        NSBeep();
        return;
    }

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setCanCreateDirectories: YES];
    [savePanel setTitle: ([sender count] == 1) ? @"Export Route" : @"Export Routes"];
    [savePanel setMessage: ([sender count] == 1) ? @"Please choose a destination for this route." : @"Please choose a destination for these routes."];
    int ret = [savePanel runModalForDirectory: @"~/" file: [[NSString stringWithFormat: @"%d", [sender count]] stringByAppendingPathExtension: ([sender count] == 1) ? @"route" : @"routeset"]];
    
	if(ret == NSFileHandlingPanelOKButton) {
        NSString *saveLocation = [savePanel filename];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject: ([sender count] == 1) ? [sender lastObject] : sender];
        [data writeToFile: saveLocation atomically: YES];
        [self closeExportPanel: nil];
    }
}



#pragma mark -
#pragma mark Waypoint & Other Actions


- (IBAction)closestWaypoint: (id)sender{

	Waypoint *wp = nil;
	Position *playerPosition = [playerData position];
	float minDist = INFINITY, tempDist;
	int closestWaypointRow = -1, i;
	for ( i = 0; i < [[self currentRoute] waypointCount]; i++ ){
		wp = [[self currentRoute] waypointAtIndex: i];
		tempDist = [playerPosition distanceToPosition: [wp position]];
		if( (tempDist < minDist) && (tempDist >= 0.0f)) {
			minDist = tempDist;
			closestWaypointRow = i;
		}
	}
	
	if ( closestWaypointRow > 0 ){
		[waypointTable selectRow:closestWaypointRow byExtendingSelection:NO];
		log(LOG_WAYPOINT, @"Closest waypoint is %0.2f yards away", minDist);
	}
}

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

- (IBAction)optionSelected: (id)sender {
    if(![self currentRoute])        return;
    if(![self.view window])         return;	
	
	[self currentRoute].isFlyingRoute = [isFlyingRouteButton state];
}

- (IBAction)addWaypoint: (id)sender {
    if(![self currentRoute])        return;
    if(![playerData playerIsValid:self]) return;
    if(![self.view window])         return;

    Waypoint *newWP = [Waypoint waypointWithPosition: [playerData position]];
    [[self currentRoute] addWaypoint: newWP];
    [waypointTable reloadData];
    changeWasMade = YES;
    log(LOG_WAYPOINT, @"Added: %@", newWP);
    NSString *readableRoute =  ([routeTypeSegment selectedTag] == 0) ? @"Primary" : @"Corpse Run";
    
    BOOL dontGrowl = (!sender && self.disableGrowl); // sender is nil when this is called by the automator
    if( !dontGrowl && [controller sendGrowlNotifications] && [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
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
		log(LOG_ERROR, @"Error: invalid row (%d), cannot change action.", [waypointTable clickedRow]);
        return;
    }
    
    // get our waypoint
    Waypoint *wp = [[self currentRoute] waypointAtIndex: [waypointTable clickedRow]];
    _editWaypoint = wp;
	wp.action.type = [sender tag];
	
	log(LOG_WAYPOINT, @"Modifying WP %@ to %d", wp, wp.action.type);
    
	int type = 0;
	if(wp.action.type == ActionType_None)
		type = 0;
	else if(wp.action.type == ActionType_Delay)
		type = 1;
	else if (wp.action.type == ActionType_Jump )
		type = 3;
    else
        type = 2;
    
    // we only need to setup the GUI if this is a non-normal type
    if( [wp.action type] != ActionType_None ) {
        // PGLog(@"EDITING FOR %d", [wp.action type]);
        // select the correct tab for our action
        [wpActionTabs selectTabViewItemAtIndex: type];
        [wpActionDelayText setFloatValue: wp.action.delay];
        
        // if we are a spell, item, or macro, set the correct segment
        // otherwise, just set it to spell
		if ( [wp.action type] != ActionType_Jump ){
			if(wp.action.isPerform) {
				[wpActionTypeSegments selectSegmentWithTag: wp.action.type];
			}
			else {
				[wpActionTypeSegments selectSegmentWithTag: ActionType_Spell];
			}
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
        log(LOG_ERROR, @"Error creating menu for type %d, action %d", [sender selectedTag], [wp.action.value unsignedIntValue]);
    }
    
}

- (IBAction)closeWaypointAction: (id)sender {
    [[sender window] makeFirstResponder: [[sender window] contentView]];
    [NSApp endSheet: wpActionPanel returnCode: NSOKButton];
    [wpActionPanel orderOut: nil];
    
    Waypoint *wp = _editWaypoint;
    if(!wp) {
        log(LOG_ERROR, @"Error editing waypoint action; there is no selected row!");
        return;
    }
    
    wp.action.value = [NSNumber numberWithInt: 0];
	
	NSString *selectedTab = [[wpActionTabs selectedTabViewItem] identifier];
    
    if ( [selectedTab isEqualToString: @"Normal"] ){
        wp.action.type = ActionType_None;
    }
	else if ( [selectedTab isEqualToString: @"Delay"] ){
        if([wpActionDelayText floatValue] == 0.0f) {   // if the delay is 0, set back to normal
            wp.action.type = ActionType_None;
        }
		else{
            wp.action.type = ActionType_Delay;
            wp.action.value = [NSNumber numberWithFloat: [wpActionDelayText floatValue]];
        }
	}
	else if ( [selectedTab isEqualToString: @"Jump"] ){
		wp.action.type = ActionType_Jump;
    }
	else{
        wp.action.type = ActionType_None;
        
        // waypoint actions are not currently enabled
        if ( [[wpActionIDPopUp selectedItem] tag] == 0.0f ) {    // if no action specified, set back to normal
            wp.action.type = ActionType_None;
        }
		else {
            wp.action.type = [wpActionTypeSegments selectedTag];
            wp.action.value = [NSNumber numberWithUnsignedInt: [[wpActionIDPopUp selectedItem] tag]];
        }
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
#pragma mark Route Automator
// thanks to Josh for getting this started! I just cleaned up a little :)

- (IBAction)openAutomatorPanel: (id)sender {
    if([[self currentRouteKey] isEqualToString: PrimaryRoute])
        [automatorVizualizer setShouldClosePath: YES];
    else
        [automatorVizualizer setShouldClosePath: NO];
    
    [automatorVizualizer setRoute: [self currentRoute]];
    [automatorVizualizer setPlayerPosition: [playerData position]];
    [automatorVizualizer setNeedsDisplay: YES];
    
    // enable automator hotkey
    BOOL isAutomatorEnabled = ([[PTHotKeyCenter sharedCenter] hotKeyWithIdentifier: AutomatorHotkeyIdentifier]) ? YES : NO;
    if(!isAutomatorEnabled)
        [self toggleGlobalHotKey: automatorRecorder];

	[NSApp beginSheet: automatorPanel
	   modalForWindow: [self.view window]
		modalDelegate: nil
	   didEndSelector: nil //@selector(sheetDidEnd: returnCode: contextInfo:)
		  contextInfo: nil];
}

- (IBAction)closeAutomatorPanel: (id)sender {
    if(self.isAutomatorRunning) {
        [self startStopAutomator: automatorStartStopButton];
    }
    
    // disable automator hotkey
    BOOL isAutomatorEnabled = ([[PTHotKeyCenter sharedCenter] hotKeyWithIdentifier: AutomatorHotkeyIdentifier]) ? YES : NO;
    if(isAutomatorEnabled)
        [self toggleGlobalHotKey: automatorRecorder];
    
    
    [NSApp endSheet: automatorPanel returnCode: 1];
    [automatorPanel orderOut: nil];
    [self saveRoutes];
}

- (IBAction)startStopAutomator: (id)sender {
	// OK stop automator!
	if ( self.isAutomatorRunning ) {
		log(LOG_WAYPOINT, @"Waypoint recording stopped");
		self.isAutomatorRunning = NO;
        [automatorSpinner stopAnimation: nil];
        [automatorStartStopButton setState: NSOffState];
        [automatorStartStopButton setTitle: @"Start Recording"];
        [automatorStartStopButton setImage: [NSImage imageNamed: @"off"]];
	}
	else {
		log(LOG_WAYPOINT, @"Waypoint recording started");
        [automatorPanel makeFirstResponder: [automatorPanel contentView]];
		self.isAutomatorRunning = YES;
        [automatorSpinner startAnimation: nil];
        [automatorStartStopButton setState: NSOnState];
        [automatorStartStopButton setTitle: @"Stop Recording"];
        [automatorStartStopButton setImage: [NSImage imageNamed: @"on"]];
	}
	
	[self automatorPulse];
}

-(void)automatorPulse {
	// Make sure we have valid route/player/window!
	if(!self.isAutomatorRunning)    return;
	if(![self currentRoute])        return;
    if(![self.view window])         return;
    if(![playerData playerIsValid:self]) return;
    
	// figure out how far we've moved
    Position *playerPosition = [playerData position];
	Waypoint *curWP = [Waypoint waypointWithPosition: playerPosition];
	Waypoint *lastWP = [[[self currentRoute] waypoints] lastObject];
    float distance = [curWP.position distanceToPosition: lastWP.position];
    
    // if we haven't moved, we dont care!
    BOOL waypointAdded = NO;
    float pulseTime = 0.1f;
    if(distance != 0.0f) {
        float interval = [[[NSUserDefaults standardUserDefaults] objectForKey: @"RouteAutomatorIntervalValue"] floatValue];
        NSInteger type = [[NSUserDefaults standardUserDefaults] integerForKey: @"RouteAutomatorIntervalTypeTag"]; 
        
        if(type == AutomatorIntervalType_Distance) {
            // record automatically after X yards
            if(distance >= interval) {
                waypointAdded = YES;
                [self addWaypoint: nil];
            }
        } else {
            // if we're recording on an time interval, we know 
            waypointAdded = YES;
            [self addWaypoint: nil];
            pulseTime = interval;
        }
    }
    
    if(waypointAdded) {
        // if we added something, have the visualizer redraw
        [automatorVizualizer setPlayerPosition: playerPosition];
        [automatorVizualizer setNeedsDisplay: YES];
    }
	
	// Check again after the specified delay!
	[self performSelector: @selector(automatorPulse) withObject: nil afterDelay: pulseTime];
}

// called by the X button in the Automator panel
- (IBAction)resetAllWaypoints: (id)sender {
    int ret = NSRunAlertPanel(@"Remove All Waypoints?", [NSString stringWithFormat: @"Are you sure you want to delete all the waypoints in route \"%@\"?  This cannot be undone.", [[self currentRouteSet] name]], @"Delete", @"Cancel", NULL);
    if(ret == NSAlertDefaultReturn) {
        Waypoint *wp = nil;
        Route *route = [self currentRoute];
        while((wp = [route waypointAtIndex: 0])) {
            [route removeWaypointAtIndex: 0];
        }
        [automatorVizualizer setNeedsDisplay: YES];
        changeWasMade = YES;
    }
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
		else
			type = wp.action.type;
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
		if(wp.action.type == ActionType_Interact) {
			return [NSString stringWithFormat: @"Interact: %@", wp.action.value];
		}
		if(wp.action.type == ActionType_Jump) {
			return [NSString stringWithFormat: @"Jump"];
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
        log(LOG_ERROR, @"Error dragging waypoints. Indexes invalid.");
        return NO;
    }

    log(LOG_WAYPOINT, @"Draggin %d rows to above row %d", [rowIndexes count], row);
    
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
    BOOL isAddWaypointEnabled = ([[PTHotKeyCenter sharedCenter] hotKeyWithIdentifier: AddWaypointHotkeyIdentifier]) ? YES : NO;
    
    if( [notification object] == self.view ) {
        if(!isAddWaypointEnabled) {
            [self toggleGlobalHotKey: shortcutRecorder];
        }
    } else {
		// Adding another waypoint
        if(isAddWaypointEnabled) {
            [self toggleGlobalHotKey: shortcutRecorder];
            [self saveRoutes];
        }
    }
}

- (void)toggleGlobalHotKey:(id)sender
{
	// Only if we come from shortcutRecorder!  Can probably combine this into one function but I'm a n00b
	if ( sender == shortcutRecorder )
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
	
	// Automator only pls
	if ( sender == automatorRecorder )
	{
		if (automatorGlobalHotkey != nil) {
			[[PTHotKeyCenter sharedCenter] unregisterHotKey: automatorGlobalHotkey];
			[automatorGlobalHotkey release];
			automatorGlobalHotkey = nil;
		} else {
			KeyCombo keyCombo = [automatorRecorder keyCombo];
			
			if(keyCombo.code >= 0 && keyCombo.flags >= 0) {
				automatorGlobalHotkey = [[PTHotKey alloc] initWithIdentifier: AutomatorHotkeyIdentifier
																	  keyCombo: [PTKeyCombo keyComboWithKeyCode: keyCombo.code
																									  modifiers: [automatorRecorder cocoaToCarbonFlags: keyCombo.flags]]];
				
				[automatorGlobalHotkey setTarget: self];
				[automatorGlobalHotkey setAction: @selector(startStopAutomator:)];
				
				[[PTHotKeyCenter sharedCenter] registerHotKey: automatorGlobalHotkey];
			}
		}
		
	}
}

- (void)shortcutRecorder:(SRRecorderControl *)recorder keyComboDidChange:(KeyCombo)newKeyCombo {
    
	if(recorder == shortcutRecorder) {
		[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.code] forKey: @"WaypointAdd_HotkeyCode"];
		[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.flags] forKey: @"WaypointAdd_HotkeyFlags"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
    
	if(recorder == automatorRecorder) {
		[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.code] forKey: @"WaypointAutomator_HotkeyCode"];
		[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.flags] forKey: @"WaypointAutomator_HotkeyFlags"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
    // register this hotkey globally
    [self toggleGlobalHotKey: recorder];
}

@end
