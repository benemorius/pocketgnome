//
//  AuraStackConditionController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 7/1/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import "AuraProximityConditionController.h"


@implementation AuraProximityConditionController

- (id) init {
    self = [super init];
    if (self != nil) {
        if(![NSBundle loadNibNamed: @"AuraProximityCondition" owner: self]) {
            log(LOG_ERROR, @"Error loading AuraProximityCondition nib.");
            
            [self release];
            self = nil;
        }
    }
    return self;
}

- (IBAction)validateState: (id)sender {
    
}

- (Condition*)condition {
    [self validateState: nil];
    
    Condition *condition = [Condition conditionWithVariety: VarietyAuraProximity 
                                                      unit: [unitSelect selectedTag]
                                                   quality: [auraStatusComparator selectedTag]
                                                comparator: [targetCountComparator selectedTag]
                                                     state: [targetCountText intValue]
                                                      type: [targetRange intValue]
                                                     value: [auraText stringValue]];
    [condition setEnabled: self.enabled];
    
    return condition;
}

- (void)setStateFromCondition: (Condition*)condition {
    [super setStateFromCondition: condition];

    [targetRange setStringValue:[NSString stringWithFormat:@"%d", [condition type]]];
    [targetCountText setStringValue: [NSString stringWithFormat: @"%d", [condition state]]];
    [auraText setStringValue: [NSString stringWithFormat: @"%@", [condition value]]];
    
    [auraStatusComparator selectItemWithTag:[condition quality]];
    [targetCountComparator selectSegmentWithTag:[condition comparator]];
    [unitSelect selectSegmentWithTag:[condition unit]];
    
    [self validateState: nil];

}

@end
