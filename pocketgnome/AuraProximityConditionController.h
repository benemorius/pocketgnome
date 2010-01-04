//
//  AuraProximityCondition.h
//  Pocket Gnome
//
//  Created by System Administrator on 1/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ConditionController.h"

@class BetterSegmentedControl;

@interface AuraProximityConditionController : ConditionController
{
    IBOutlet BetterSegmentedControl *targetCountComparator;
    IBOutlet NSTextField *targetCountText;
    IBOutlet NSTextField *targetRange;
    IBOutlet BetterSegmentedControl *unitSelect;
    IBOutlet NSPopUpButton *auraStatusComparator;
    IBOutlet NSTextField *auraText;
}

@end
