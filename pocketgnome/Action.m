//
//  Action.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 9/6/08.
//  Copyright 2008 Jon Drummond. All rights reserved.
//

#import "Action.h"


@implementation Action

- (id) init
{
    return [self initWithType: ActionType_None value: nil];
}

- (id)initWithType: (ActionType)type value: (NSNumber*)value {
    self = [super init];
    if (self != nil) {
        self.type = type;
        self.value = value;
        //self.delay = delay;
        //self.actionID = actionID;
    }
    return self;
}

+ (id)actionWithType: (ActionType)type value: (NSNumber*)value {
    return [[[[self class] alloc] initWithType: type value: value] autorelease];
}

+ (id)action {
    return [[self class] actionWithType: ActionType_None value: nil];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super init];
	if(self) {
        self.type = [[decoder decodeObjectForKey: @"Type"] unsignedIntValue];
        self.value = ([decoder decodeObjectForKey: @"Value"] ? [decoder decodeObjectForKey: @"Value"] : nil);
	}
	return self;
}

-(void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject: [NSNumber numberWithUnsignedInt: self.type]    forKey: @"Type"];
    if(self.type > ActionType_None) 
        [coder encodeObject: self.value                                 forKey: @"Value"];
}

- (id)copyWithZone:(NSZone *)zone
{
    Action *copy = [[[self class] allocWithZone: zone] initWithType: self.type value: self.value];
    
    return copy;
}

- (void) dealloc
{
    self.value = nil;
    [super dealloc];
}


@synthesize type = _type;
@synthesize value = _value;

- (void)setType: (ActionType)type {
    if(type < ActionType_None || (type >= ActionType_Max)) {
        type = ActionType_None;
    }
    
    _type = type;
}

- (BOOL)isPerform {
    if((self.type >= ActionType_Spell) && (self.type <= ActionType_Macro))
        return YES;
	if(self.type == ActionType_Interact)
		return YES;
    return NO;
}

- (float)delay {
    if(self.type == ActionType_Delay) {
        return [self.value floatValue];
    }
    return 0.0f;
}

- (UInt32)actionID {
    if(self.type == ActionType_Spell || self.type == ActionType_Item || self.type == ActionType_Macro) {
        return [self.value unsignedIntValue];
    }
    return 0;
}

/*- (void)setDelay: (float)delay {
    if((delay < 0.0f) || (delay == INFINITY) || (delay == NAN))
        delay = 0.0f;
    
    _delay = delay;
}

- (void)setActionID: (UInt32)actionID {
    if(actionID < 0)
        actionID = 0;
    
    _actionID = actionID;
}*/

@end
