//
//  WorldObjectController.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/29/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Node.h"

@class PlayerDataController;
@class BlacklistController;

typedef enum {
    AnyNode = 0,
    MiningNode = 1,
    HerbalismNode = 2,
	FishingSchool = 3,
} NodeType;

@interface NodeController : NSObject {
    IBOutlet id controller;
    IBOutlet id botController;
    IBOutlet PlayerDataController *playerController;
    IBOutlet id movementController;
    IBOutlet id memoryViewController;
    IBOutlet BlacklistController *blacklistController;
    
    IBOutlet NSView *view;
    
    IBOutlet id nodeTable;
    
    IBOutlet NSPopUpButton *moveToList;

    NSString *filterString;
    NSMutableArray *_nodeList;
    NSMutableArray *_nodeDataList;
    NSMutableArray *_finishedNodes;
    
    // NSMutableDictionary *_nodeNames;

    NSDictionary *_miningDict;
    NSDictionary *_herbalismDict;
	
    NSTimer *_updateTimer;
    float _updateFrequency;
    NSSize minSectionSize, maxSectionSize;
    int _nodeTypeFilter;
}

@property (readonly) NSView *view;
@property (readonly) NSString *sectionTitle;
@property NSSize minSectionSize;
@property NSSize maxSectionSize;
@property float updateFrequency;

- (void)addAddresses: (NSArray*)addresses;
// - (BOOL)addNode: (Node*)node;
- (unsigned)nodeCount;
- (void)finishedNode: (Node*)node;
- (void)resetAllNodes;
- (BOOL)removeFinishedNode: (Node*)node;

- (NSArray*)nodesOfType:(UInt32)nodeType shouldLock:(BOOL)lock;
- (NSArray*)allMiningNodes;
- (NSArray*)allHerbalismNodes;
- (NSArray*)nodesWithinDistance: (float)distance ofAbsoluteType: (GameObjectType)type;
- (NSArray*)nodesWithinDistance: (float)distance ofType: (NodeType)type maxLevel: (int)level;
- (NSArray*)nodesWithinDistance: (float)nodeDistance NodeIDs: (NSArray*)nodeIDs position:(Position*)position;
- (NSArray*)nodesWithinDistance: (float)nodeDistance EntryID: (int)entryID position:(Position*)position;
- (Node*)closestNode:(UInt32)entryID;
- (Node*)closestNodeForInteraction:(UInt32)entryID;
- (Node*)nodeWithEntryID:(UInt32)entryID;

- (IBAction)filterNodes: (id)sender;
- (IBAction)resetList: (id)sender;
- (IBAction)faceNode: (id)sender;
- (IBAction)targetNode: (id)sender;
- (IBAction)filterList: (id)sender;

- (IBAction)moveToStart: (id)sender;
- (IBAction)moveToStop: (id)sender;

@end
