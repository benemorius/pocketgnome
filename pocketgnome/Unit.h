//
//  Unit.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 5/26/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "WoWObject.h"

enum eUnitBaseFields {
    BaseField_XLocation                 = 0x790,  // 3.0.9: 0x7C4
    BaseField_YLocation                 = 0x794,  // 3.0.9: 0x7C8
    BaseField_ZLocation                 = 0x798,  // 3.0.9: 0x7CC
    BaseField_Facing_Horizontal         = 0x79C,  // 3.0.9: 0x7D0  // [0, 2pi]
    BaseField_Facing_Vertical           = 0x7A0,  // 3.0.9: 0x7D0  // [-pi/2, pi/2]
    
    BaseField_MovementFlags             = 0x7C0,  // 3.0.9: 0x7F0
    // 0x80000001 - move forward
    // 0x80000002 - move backward
    // 0x80000004 - strafe left
    // 0x80000008 - strafe right
    
    // 0x80000010 - turn left
    // 0x80000020 - turn left
    
    // 0x80001000 - jumping
    
    // 0x80200000 - swimming
    
    // 0x81000000 - air mounted, on the ground
    // 0x83000400 - air mounted, in the air
    // 0x83400400 - air mounted, going up (spacebar)
    // 0x83800400 - air mounted, going down (sit key)
    // among others...
	
	
	// 0x1			- moving forward
	// 0x2			- moving backward
	// 0x4			- strafe left
	// 0x8			- strafe right
	// 0x1000		- in air, not mounted
	
	// 0x3400000	- moving up, on air mount
	// 0x3800000	- moving down, on air mount
	
	
	// 0x1000000 - air mounted, on ground
	// 0x3000000 - air mounted, in the air
	/*from Ascent Emulator,
	 enum MovementFlags
	 {
	 // Byte 1 (Resets on Movement Key Press)
	 MOVEFLAG_MOVE_STOP                  = 0x00,            //verified
	 MOVEFLAG_MOVE_FORWARD                = 0x01,            //verified
	 MOVEFLAG_MOVE_BACKWARD                = 0x02,            //verified
	 MOVEFLAG_STRAFE_LEFT                = 0x04,            //verified
	 MOVEFLAG_STRAFE_RIGHT                = 0x08,            //verified
	 MOVEFLAG_TURN_LEFT                    = 0x10,            //verified
	 MOVEFLAG_TURN_RIGHT                    = 0x20,            //verified
	 MOVEFLAG_PITCH_DOWN                    = 0x40,            //Unconfirmed
	 MOVEFLAG_PITCH_UP                    = 0x80,            //Unconfirmed
	 
	 // Byte 2 (Resets on Situation Change)
	 MOVEFLAG_WALK                        = 0x100,        //verified
	 MOVEFLAG_TAXI                        = 0x200,        
	 MOVEFLAG_NO_COLLISION                = 0x400,
	 MOVEFLAG_FLYING                        = 0x800,        //verified
	 MOVEFLAG_REDIRECTED                    = 0x1000,        //Unconfirmed
	 MOVEFLAG_FALLING                    = 0x2000,       //verified
	 MOVEFLAG_FALLING_FAR                = 0x4000,        //verified
	 MOVEFLAG_FREE_FALLING                = 0x8000,        //half verified
	 
	 // Byte 3 (Set by server. TB = Third Byte. Completely unconfirmed.)
	 MOVEFLAG_TB_PENDING_STOP            = 0x10000,        // (MOVEFLAG_PENDING_STOP)
	 MOVEFLAG_TB_PENDING_UNSTRAFE        = 0x20000,        // (MOVEFLAG_PENDING_UNSTRAFE)
	 MOVEFLAG_TB_PENDING_FALL            = 0x40000,        // (MOVEFLAG_PENDING_FALL)
	 MOVEFLAG_TB_PENDING_FORWARD            = 0x80000,        // (MOVEFLAG_PENDING_FORWARD)
	 MOVEFLAG_TB_PENDING_BACKWARD        = 0x100000,        // (MOVEFLAG_PENDING_BACKWARD)
	 MOVEFLAG_SWIMMING                      = 0x200000,        //  verified
	 MOVEFLAG_FLYING_PITCH_UP            = 0x400000,        // (half confirmed)(MOVEFLAG_PENDING_STR_RGHT)
	 MOVEFLAG_TB_MOVED                    = 0x800000,        // (half confirmed) gets called when landing (MOVEFLAG_MOVED)
	 
	 // Byte 4 (Script Based Flags. Never reset, only turned on or off.)
	 MOVEFLAG_AIR_SUSPENSION                    = 0x1000000,    // confirmed allow body air suspension(good name? lol).
	 MOVEFLAG_AIR_SWIMMING                = 0x2000000,    // confirmed while flying.
	 MOVEFLAG_SPLINE_MOVER                = 0x4000000,    // Unconfirmed
	 MOVEFLAG_IMMOBILIZED                = 0x8000000,
	 MOVEFLAG_WATER_WALK                    = 0x10000000,
	 MOVEFLAG_FEATHER_FALL                = 0x20000000,    // Does not negate fall damage.
	 MOVEFLAG_LEVITATE                    = 0x40000000,
	 MOVEFLAG_LOCAL                        = 0x80000000,    // This flag defaults to on. (Assumption)
	 
	 // Masks
	 MOVEFLAG_MOVING_MASK                = 0x03,
	 MOVEFLAG_STRAFING_MASK                = 0x0C,
	 MOVEFLAG_TURNING_MASK                = 0x30,
	 MOVEFLAG_FALLING_MASK                = 0x6000,
	 MOVEFLAG_MOTION_MASK                = 0xE00F,        // Forwards, Backwards, Strafing, Falling
	 MOVEFLAG_PENDING_MASK                = 0x7F0000,
	 MOVEFLAG_PENDING_STRAFE_MASK        = 0x600000,
	 MOVEFLAG_PENDING_MOVE_MASK            = 0x180000,
	 MOVEFLAG_FULL_FALLING_MASK            = 0xE000,
	 };
*/	 

    
    BaseField_RunSpeed_Current          = 0x808,	// 3.0.9: 0x838
    BaseField_RunSpeed_Walk             = 0x80C,	// (you sure this is runspeed walk? - i noticed it was 2.5, yet current speed when walking was 7.0) 3.0.9: 0x83C
    BaseField_RunSpeed_Max              = 0x810,	// 3.0.9: 0x840
    BaseField_RunSpeed_Back             = 0x814,	// 3.0.9: 0x844
    BaseField_AirSpeed_Max              = 0x820,	// 3.0.9: 0x850
    

    BaseField_Spell_ToCast              = 0xA4C,	// 3.0.9: 0xA28
    BaseField_Spell_Casting             = 0xA5C,	// 3.0.9: 0xA2C
    BaseField_Spell_TargetGUID_Low      = 0xA60,	// 3.0.9: 0xA30  (not sure how to verify if 3.1.0 offset is correct)
    BaseField_Spell_TargetGUID_High     = 0xA64,	// 3.0.9: 0xA34  (not sure how to verify if 3.1.0 offset is correct)
    BaseField_Spell_TimeStart           = 0xA68,	// 3.0.9: 0xA38
    BaseField_Spell_TimeEnd             = 0xA6C,	// 3.0.9: 0xA3C
    
    BaseField_Spell_Channeling          = 0xA70,	// 3.0.9: 0xA40
    BaseField_Spell_ChannelTimeStart    = 0xA74,	// 3.0.9: 0xA44
    BaseField_Spell_ChannelTimeEnd      = 0xA78,	// 3.0.9: 0xA48
    
    BaseField_SelectionFlags            = 0xA80,	// (1 << 12) when a unit is selected, (1 << 13) when it is focused
    
    BaseField_Player_CurrentTime        = 0xAAC,
    
    // BaseField_CurrentStance          = 0xB40, // this seems to have dissapeared in 3.0.8
    
    BaseField_Auras_ValidCount          = 0xDB4,
    BaseField_Auras_Start               = 0xC34,
    
    // I'm not entirely sure what the story is behind these pointers
    // but it seems that once the player hits > 16 buffs/debuffs (17 or more)
    // the Aura fields in the player struct is abandoned and moves elsewhere
    BaseField_Auras_OverflowValidCount  = 0xC38,
    BaseField_Auras_OverflowPtr1        = 0xC3C,    // 3.0.8-9: i could not verify overflow 2, 3, 4
    // BaseField_Auras_OverflowPtr2        = 0xEA4, // but since they aren't actually used, I don't think it matters.
    // BaseField_Auras_OverflowPtr3        = 0xF3C,
    // BaseField_Auras_OverflowPtr4        = 0xF94,
};

enum eUnitFields {
	UnitField_Charm                     = 0x18,
	UnitField_Summon                    = 0x20,
	UnitField_Critter                   = 0x28,
	UnitField_CharmedBy                 = 0x30,
	UnitField_SummonedBy                = 0x38,
	UnitField_CreatedBy                 = 0x40,
	UnitField_Target                    = 0x48,
	//UnitField_Persuaded                 = 0x48,
	UnitField_Channel_Object            = 0x50,
    
    UnitField_Bytes0                    = 0x58,
    
	UnitField_Health                    = 0x5C,
	UnitField_Power1                    = 0x60, // Mana
	UnitField_Power2                    = 0x64, // Rage
	UnitField_Power3                    = 0x68, // Focus
	UnitField_Power4                    = 0x6C, // Energy
	UnitField_Power5                    = 0x70, // Happiness
	UnitField_Power6                    = 0x74, // unknown
	UnitField_Power7                    = 0x78, // Runic Power
	UnitField_MaxHealth                 = 0x7C,
	UnitField_MaxPower1                 = 0x80,
	UnitField_MaxPower2                 = 0x84,
	UnitField_MaxPower3                 = 0x88,
	UnitField_MaxPower4                 = 0x8C,
	UnitField_MaxPower5                 = 0x90,
	UnitField_MaxPower6                 = 0x94,
	UnitField_MaxPower7                 = 0x98,

    UnitField_PowerRegen_FlatMod        = 0x9C,
    // 0xA0 - 0xB4 are not known
    UnitField_PowerRegen_Interrupted_FlatMod = 0xB8,


	UnitField_Level                     = 0xD4,
	UnitField_FactionTemplate           = 0xD8,
    // UNIT_VIRTUAL_ITEM_SLOT_ID
    
    UnitField_StatusFlags               = 0xE8,
    UnitField_StatusFlags2              = 0xEC,
    
    UnitField_MainhandSpeed             = 0xF4, // these speeds are in milliseconds, eg 2000 = 2.0sec
    UnitField_OffhandSpeed              = 0xF8,
    UnitField_RangedSpeed               = 0xFC,

    UnitField_BoundingRadius            = 0x100,
    UnitField_CombatReach               = 0x104,

    UnitField_DisplayID                 = 0x108,
    UnitField_NativeDisplayID           = 0x10C,
    UnitField_MountDisplayID            = 0x110,

	UnitField_Bytes_1                   = 0x124,    // sit, lie, kneel and so on (stealth = 0x20000)
    
    UnitField_PetNumber                 = 0x128,    // not the same as entry ID
	UnitField_PetNameTimestamp          = 0x12C,
	UnitField_PetExperience             = 0x130,
	UnitField_PetNextLevelExp           = 0x134,

	UnitField_DynamicFlags              = 0x138,    // tracking, tapped
	UnitField_ChannelSpell              = 0x13C,
	UnitField_ModCastSpeed              = 0x140,
	UnitField_UnitCreatedBySpell        = 0x144,
	UnitField_NPCFlags                  = 0x148,    // repairer, auctioneer, etc
	UnitField_NPCEmoteState             = 0x14C,
    
    // 5x stats
    // 5x +states
    // 5x -stats
    // 7x resistances
    // 7x resistances mod positive
    // 7x resistances mod negative
    
	UnitField_BaseMana                  = 0x1E0,
	UnitField_BaseHealth                = 0x1E4,
    UnitField_Bytes_2                   = 0x1E8,    // 0x1001 for most mobs. 0x2801 for totems?

    UnitField_AttackPower               = 0x1EC,
    UnitField_AttackPower_Mod           = 0x1F0,
    UnitField_AttackPower_Mult          = 0x1F4,
    UnitField_Ranged_AttackPower        = 0x1F8,
    UnitField_Ranged_AttackPower_Mod    = 0x1FC,
    UnitField_Ranged_AttackPower_Mult   = 0x200,
    UnitField_Ranged_MinDamage          = 0x204,
    UnitField_Ranged_MaxDamage          = 0x208,
    UnitField_PowerCost_Mod             = 0x20C,
    // 7 total fields ^^
    UnitField_PowerCost_Mult            = 0x228,
    // 7 total fields ^^
    
    UnitField_MaxHealth_Modifier        = 0x244,
    UnitField_HoverHeight               = 0x248,
    // padding
	
    UnitField_TotalUnitFields           = 0x59,
    
};

// Added from: http://www.mmowned.com/forums/wow-memory-editing/257771-wow-constant-data-enums-structs-etc.html
typedef enum{
	UnitField_None = 0,
	UnitField_Lootable = 0x1,
	UnitField_TrackUnit = 0x2,
	UnitField_TaggedByOther = 0x4,
	UnitField_TaggedByMe = 0x8,
	UnitField_SpecialInfo = 0x10,
	UnitField_Dead = 0x20,
	UnitField_ReferAFriendLinked = 0x40,
	UnitField_IsTappedByAllThreatList = 0x80,
} UnitDynamicFlags;

/*
// Value masks for UNIT_FIELD_FLAGS (UnitField_StatusFlags)
enum UnitFlags
{
    UNIT_FLAG_UNKNOWN7       = 0x00000001,
    UNIT_FLAG_NON_ATTACKABLE = 0x00000002,                  // not attackable
    UNIT_FLAG_DISABLE_MOVE   = 0x00000004,
    UNIT_FLAG_UNKNOWN1       = 0x00000008,                  // for all units, make unit attackable even it's friendly in some cases...
    UNIT_FLAG_RENAME         = 0x00000010,
    UNIT_FLAG_RESTING        = 0x00000020,
    UNIT_FLAG_UNKNOWN9       = 0x00000040,
    UNIT_FLAG_UNKNOWN10      = 0x00000080,
    UNIT_FLAG_UNKNOWN2       = 0x00000100,                  // 2.0.8
    UNIT_FLAG_UNKNOWN11      = 0x00000200,
    UNIT_FLAG_UNKNOWN12      = 0x00000400,                  // loot animation
    UNIT_FLAG_PET_IN_COMBAT  = 0x00000800,                  // in combat?, 2.0.8
    UNIT_FLAG_PVP            = 0x00001000,                  // ok
    UNIT_FLAG_SILENCED       = 0x00002000,                  // silenced, 2.1.1
    UNIT_FLAG_UNKNOWN4       = 0x00004000,                  // 2.0.8
    UNIT_FLAG_UNKNOWN13      = 0x00008000,
    UNIT_FLAG_UNKNOWN14      = 0x00010000,
    UNIT_FLAG_PACIFIED       = 0x00020000,
    UNIT_FLAG_DISABLE_ROTATE = 0x00040000,                  // stunned, 2.1.1
    UNIT_FLAG_IN_COMBAT      = 0x00080000,
    UNIT_FLAG_UNKNOWN15      = 0x00100000,                  // mounted? 2.1.3, probably used with 0x4 flag
    UNIT_FLAG_DISARMED       = 0x00200000,                  // disable melee spells casting..., "Required melee weapon" added to melee spells tooltip.
    UNIT_FLAG_CONFUSED       = 0x00400000,
    UNIT_FLAG_FLEEING        = 0x00800000,
    UNIT_FLAG_UNKNOWN5       = 0x01000000,                  // used in spell Eyes of the Beast for pet...
    UNIT_FLAG_NOT_SELECTABLE = 0x02000000,                  // ok
    UNIT_FLAG_SKINNABLE      = 0x04000000,
    UNIT_FLAG_MOUNT          = 0x08000000,                  // the client seems to handle it perfectly
    UNIT_FLAG_UNKNOWN17      = 0x10000000,
    UNIT_FLAG_UNKNOWN6       = 0x20000000,                  // used in Feing Death spell
    UNIT_FLAG_SHEATHE        = 0x40000000
};
 
 private enum UnitFlags : uint
 {
 None = 0,
 Sitting = 0x1,
 //SelectableNotAttackable_1 = 0x2,
 Influenced = 0x4, // Stops movement packets
 PlayerControlled = 0x8, // 2.4.2
 Totem = 0x10,
 Preparation = 0x20, // 3.0.3
 PlusMob = 0x40, // 3.0.2
 //SelectableNotAttackable_2 = 0x80,
 NotAttackable = 0x100,
 //Flag_0x200 = 0x200,
 Looting = 0x400,
 PetInCombat = 0x800, // 3.0.2
 PvPFlagged = 0x1000,
 Silenced = 0x2000, //3.0.3
 //Flag_14_0x4000 = 0x4000,
 //Flag_15_0x8000 = 0x8000,
 //SelectableNotAttackable_3 = 0x10000,
 Pacified = 0x20000, //3.0.3
 Stunned = 0x40000,
 CanPerformAction_Mask1 = 0x60000,
 Combat = 0x80000, // 3.1.1
 TaxiFlight = 0x100000, // 3.1.1
 Disarmed = 0x200000, // 3.1.1
 Confused = 0x400000, //  3.0.3
 Fleeing = 0x800000,
 Possessed = 0x1000000, // 3.1.1
 NotSelectable = 0x2000000,
 Skinnable = 0x4000000,
 Mounted = 0x8000000,
 //Flag_28_0x10000000 = 0x10000000,
 Dazed = 0x20000000,
 Sheathe = 0x40000000,
 //Flag_31_0x80000000 = 0x80000000,
 }
 
*/
   // polymorph sets bits 22 and 29
    
    // bit 1  - not attackable
    // bit 4  - evading
    // bit 10 - looting
    // bit 11 - combat (for mob)
    // but 18 - stunned
    // bit 19 - combat (for player)
    // bit 23 - running away
    // bit 25 - invisible/not selectable
    // bit 26 - skinnable
    // bit 29 - feign death
    
typedef enum {
    UnitStatus_Unknown0         = 0,
    UnitStatus_NotAttackable    = 1,
    UnitStatus_Disablemove      = 2,
    UnitStatus_Unknown3,
    UnitStatus_Evading          = 4,
    UnitStatus_Resting          = 5,
    UnitStatus_Elite            = 6,
    UnitStatus_Unknown7,
    UnitStatus_Unknown8,
    UnitStatus_Unknown9,                // most NPCs in IF have this
    UnitStatus_Looting          = 10,   // loot animation
    UnitStatus_NPC_Combat       = 11,   // not really sure
    UnitStatus_PVP              = 12,
    UnitStatus_Silenced         = 13,
    UnitStatus_Unknown14,
    UnitStatus_Unknown15,               // guards in IF all have this
    UnitStatus_Unknown16,
    UnitStatus_Pacified         = 17,
    UnitStatus_Stunned          = 18,
    UnitStatus_InCombat         = 19,
    UnitStatus_Unknown20,
    UnitStatus_Disarmed         = 21,
    UnitStatus_Confused         = 22, // used in polymorph
    UnitStatus_Fleeing          = 23,
    UnitStatus_MindControl      = 24, // used in eyes of the beast...
    UnitStatus_NotSelectable    = 25,
    UnitStatus_Skinnable        = 26,
    UnitStatus_Mounted          = 27,
    UnitStatus_Unknown28        = 28,
    UnitStatus_FeignDeath       = 29,
    UnitStatus_Sheathe          = 30,
} UnitStatusBits;


typedef enum {
    UnitPower_Mana          = 0,
    UnitPower_Rage          = 1,
    UnitPower_Focus         = 2,
    UnitPower_Energy        = 3,
    UnitPower_Happiness     = 4,
    UnitPower_RunicPower    = 6,
    UnitPower_Max           = 7,
} UnitPower;

typedef enum {
    UnitGender_Male         = 0,
    UnitGender_Female       = 1,
    UnitGender_Unknown      = 2,
} UnitGender;

// UnitClass must be replicated in TargetClassCondition
typedef enum {
    UnitClass_Unknown       = 0,
    UnitClass_Warrior       = 1,
    UnitClass_Paladin       = 2,
    UnitClass_Hunter        = 3,
    UnitClass_Rogue         = 4,
    UnitClass_Priest        = 5,
    UnitClass_DeathKnight   = 6,
    UnitClass_Shaman        = 7,
    UnitClass_Mage          = 8,
    UnitClass_Warlock       = 9,
    UnitClass_Druid         = 11,
} UnitClass;

typedef enum {
    UnitRace_Human          = 1,
    UnitRace_Orc,
    UnitRace_Dwarf,
    UnitRace_NightElf,
    UnitRace_Undead,
    UnitRace_Tauren,
    UnitRace_Gnome,
    UnitRace_Troll,
    UnitRace_Goblin,
    UnitRace_BloodElf,
    UnitRace_Draenei,
    UnitRace_FelOrc,
    UnitRace_Naga,
    UnitRace_Broken,
    UnitRace_Skeleton       = 15,
} UnitRace;

// CreatureType must be replicated in TargetClassCondition
typedef enum CreatureType
{
    CreatureType_Unknown          = 0,
    CreatureType_Beast            = 1,  // CREATURE_TYPE_BEAST
    CreatureType_Dragon           = 2,
    CreatureType_Demon            = 3,
    CreatureType_Elemental        = 4,
    CreatureType_Giant            = 5,
    CreatureType_Undead           = 6,
    CreatureType_Humanoid         = 7,
    CreatureType_Critter          = 8,
    CreatureType_Mechanical       = 9,
    CreatureType_NotSpecified     = 10,
    CreatureType_Totem            = 11,
    CreatureType_Non_Combat_Pet   = 12,
    CreatureType_Gas_Cloud        = 13,
    
    CreatureType_Max,
} CreatureType;

typedef enum MovementFlag {
    // some of these may be named poorly (names were my best guess)
    MovementFlag_None               = 0,            // 0x00000000
    MovementFlag_Forward            = (1 << 0),     // 0x00000001
    MovementFlag_Backward           = (1 << 1),     // 0x00000002
    MovementFlag_StrafeLeft         = (1 << 2),     // 0x00000004
    MovementFlag_StrafeRight        = (1 << 3),     // 0x00000008
    MovementFlag_Left               = (1 << 4),     // 0x00000010
    MovementFlag_Right              = (1 << 5),     // 0x00000020
    MovementFlag_PitchUp            = (1 << 6),     // 0x00000040
    MovementFlag_PitchDown          = (1 << 7),     // 0x00000080
    MovementFlag_WalkMode           = (1 << 8),     // 0x00000100
    MovementFlag_OnTransport        = (1 << 9),     // 0x00000200
    MovementFlag_Levitating         = (1 << 10),    // 0x00000400
    MovementFlag_FlyUnknown11       = (1 << 11),    // 0x00000800
    MovementFlag_Jumping            = (1 << 12),    // 0x00001000
    MovementFlag_Unknown13          = (1 << 13),    // 0x00002000
    MovementFlag_Falling            = (1 << 14),    // 0x00004000
    // 0x8000, 0x10000, 0x20000, 0x40000, 0x80000, 0x100000
    MovementFlag_Swimming           = (1 << 21),    // 0x00200000 - can appear with Fly flag?
    MovementFlag_FlyUp              = (1 << 22),    // 0x00400000
    MovementFlag_CanFly             = (1 << 23),    // 0x00800000
    MovementFlag_Flying1            = (1 << 24),    // 0x01000000 - flying, but not in the air 
    MovementFlag_Flying2            = (1 << 25),    // 0x02000000 - actually in the air
    MovementFlag_Spline1            = (1 << 26),    // 0x04000000 - used for flight paths
    MovementFlag_Spline2            = (1 << 27),    // 0x08000000 - used for flight paths
    MovementFlag_WaterWalking       = (1 << 28),    // 0x10000000 - don't fall through water
    MovementFlag_SafeFall           = (1 << 29),    // 0x20000000 - active rogue safe fall spell (passive)?
    MovementFlag_Unknown30          = (1 << 30),    // 0x40000000
    // the last bit (31) is sometimes on, sometimes not.
    // i think it's fair to say that it is not used and shouldn't matter.
    
    MovementFlag_Max                = (1 << 31),
} MovementFlag;

@interface Unit : WoWObject <UnitPosition> {
}

+ (id)unitWithAddress: (NSNumber*)address inMemory: (MemoryAccess*)memory;

// global
- (Position*)position;
- (float)directionFacing;

- (GUID)petGUID;

- (GUID)charm;
- (GUID)summon;
- (GUID)targetID;
- (GUID)createdBy;
- (GUID)charmedBy;
- (GUID)summonedBy;

// info
- (UInt32)level;
- (UInt32)maxPower;
- (UInt32)maxHealth;
- (UInt32)currentPower;
- (UInt32)percentPower;
- (UInt32)currentHealth;
- (UInt32)percentHealth;
- (UInt32)factionTemplate;

- (UInt32)currentStance; // only works for the current player

- (UInt32)maxPowerOfType: (UnitPower)powerType;
- (UInt32)currentPowerOfType: (UnitPower)powerType;
- (UInt32)percentPowerOfType: (UnitPower)powerType;

// unit type
- (UnitRace)race;
- (UnitGender)gender;
- (UnitClass)unitClass;
- (UnitPower)powerType;

- (CreatureType)creatureType;

// unit type translation
+ (NSString*)stringForClass: (UnitClass)unitClass;
+ (NSString*)stringForRace: (UnitRace)unitRace;
+ (NSString*)stringForGender: (UnitGender) underGender;
- (NSImage*)iconForClass: (UnitClass)unitClass;
- (NSImage*)iconForRace: (UnitRace)unitRace gender: (UnitGender)unitGender;

// status
- (BOOL)isPet;
- (BOOL)hasPet;
- (BOOL)isTotem;
- (BOOL)isElite;
- (BOOL)isCasting;
- (BOOL)isMounted;

- (UInt32)stateFlags;
- (BOOL)isPVP;
- (BOOL)isDead;
- (BOOL)isFleeing;
- (BOOL)isEvading;
- (BOOL)isInCombat;
- (BOOL)isSkinnable;
- (BOOL)isFeignDeath;
- (BOOL)isSelectable;
- (BOOL)isAttackable;

- (UInt32)dynamicFlags;
- (UInt32)npcFlags;
- (BOOL)isLootable;         // always NO (implement in subclass)
- (BOOL)isTappedByOther;    // always NO (implement in subclass)

- (void)trackUnit;
- (void)untrackUnit;

- (UInt32)petNumber;
- (UInt32)petNameTimestamp;

- (UInt32)createdBySpell;

- (UInt32)unitBytes1;
- (UInt32)unitBytes2;

- (BOOL)isSitting;

@end
