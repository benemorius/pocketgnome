//
//  Player.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 5/25/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Unit.h"


enum ePlayerFields {
	PlayerField_Flags                           = 0x3B0, // 3.1: need to verify this!

    PlayerField_VisibleItem_Head                = 0x560,
    PlayerField_VisibleItem_Neck                = 0x5A0,
    // all the other slots in here at 0x40 intervals
    PlayerField_VisibleItem_Weapon1             = 0x920,
    PlayerField_VisibleItem_Weapon2             = 0x960,
    
    PlayerField_CharacterSlot                   = 0x4A8, // used by itemGUIDinSlot: for temporary weapon enchant condition
    
    // PlayerField_PackSlot_1                   = 0xAE0, // 3.1 unknown

    // PlayerField_FarSight                     = 0xE68, // 3.1 unknown
    // PlayerField_ComboPoint_Target            = 0xE70, // 3.1 unknown

	PlayerField_Experience                      = 0x980,
	PlayerField_NextLevel_Experience            = 0x984,

    PlayerField_RestState_Experience            = 0x11DC, // rest experience remaining
    PlayerField_Coinage                         = 0x11E0, // in copper
    
    // 3.1 unknown
    // PlayerField_ManaRegen                       = 0x1870, // (float, per second)
    // PlayerField_ManaRegen_Combat                = 0x1874, // (float, per second)
    PlayerField_MaxLevel                        = 0x1380,
	
	PlayerField_QuestStart						= 0x1A30,	// Every 0x10 is another quest ID.. Keep going til you hit 0, that is the full quest list
	
	PlayerField_Haste							= 0x2B00,
};

enum ePlayer_VisibleItem_Fields {
    VisibleItem_CreatorGUID                     = 0x0,
    VisibleItem_EntryID                         = 0x8,
    VisibleItem_Enchant                         = 0x10,
    // other unknown properties follow
    
    VisibleItem_Size                            = 0x40,
};

typedef enum eCharacterSlot { 
    SLOT_HEAD = 0,
    SLOT_NECK = 1,
    SLOT_SHOULDERS = 2,
    SLOT_SHIRT = 3, 
    SLOT_CHEST = 4, 
    SLOT_WAIST = 5,
    SLOT_LEGS = 6,
    SLOT_FEET = 7, 
    SLOT_WRISTS = 8,
    SLOT_HANDS = 9,
    SLOT_FINGER1 = 10, 
    SLOT_FINGER2 = 11, 
    SLOT_TRINKET1 = 12,
    SLOT_TRINKET2 = 13,
    SLOT_BACK = 14,
    SLOT_MAIN_HAND = 15, 
    SLOT_OFF_HAND = 16, 
    SLOT_RANGED = 17,
    SLOT_TABARD = 18,
    SLOT_EMPTY = 19,
    SLOT_MAX,
} CharacterSlot;

//typedef enum {
//    UnitBloc_Alliance       = 3,
//    UnitBloc_Horde          = 5,
//} UnitBloc;

@interface Player : Unit {
    UInt32 _nameEntryID;
}

+ (id)playerWithAddress: (NSNumber*)address inMemory: (MemoryAccess*)memory;

// status
- (BOOL)isGM;

- (GUID)itemGUIDinSlot: (CharacterSlot)slot;    // invalid for other players
@end
