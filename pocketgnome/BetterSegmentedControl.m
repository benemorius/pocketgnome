//
//  BetterSegmentedControl.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 1/3/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import "BetterSegmentedControl.h"


@implementation BetterSegmentedControl

- (int)selectedTag {
    if([self selectedSegment] == -1) return 0;
    
    return [[self cell] tagForSegment: [self selectedSegment]];
}


// **** sizing infoz ****
//
// size of the SegControl is: [sum of segment widths] + (5 + 1*[number of segments])
// 
// float width = 5;
// for(each segment) {
//    width += ([segment width] + 1);
// }
//

// float widthPerSegment = ([[self parentView] availableWidth] - (5 + [self segmentCount])) / ([self segmentCount]*1.0);


@end
