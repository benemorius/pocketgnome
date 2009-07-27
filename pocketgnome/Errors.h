/*
 *  Errors.h
 *  Pocket Gnome
 *
 *  Created by Josh on 6/9/09.
 *  Copyright 2007 Savory Software, LLC. All rights reserved.
 *
 */

// Return types for performAction
//	More errors here: http://www.wowwiki.com/WoW_Constants/Errors
typedef enum CastError {
    ErrNone = 0,
	ErrNotFound = 1,
    ErrInventoryFull = 2,				// @"Inventory is Full"
    ErrTargetNotInLOS = 3,				// 
	ErrCantMove = 4,				// 
	ErrTargetNotInFrnt = 5,				//
	ErrWrng_Way = 6,                 // 
	ErrSpell_Cooldown  = 7,        // 
	ErrAttack_Stunned  = 8,        //
	ErrSpellNot_Ready  = 9,        // 
	ErrTargetOutRange  = 10,        // 
	ErrTargetOutRange2  = 11,        // 
	ErrSpellNot_Ready2  = 12,        //
} CastError;

#define INV_FULL			@"Inventory is Full"
#define TARGET_LOS			@"Target not in line of sight"
#define CANT_MOVE			@"Can't do that while moving"
#define TARGET_FRNT			@"Target needs to be in front of you."
#define WRNG_WAY			@"You are facing the wrong way!"
#define NOT_YET			    @"You can't do that yet"
#define NOT_RDY			    @"Spell is not ready yet."
#define NOT_RDY2			@"Ability is not ready yet."
#define ATTACK_STUNNED	    @"Can't attack while stunned."
#define TARGET_RNGE			@"Out of range."
#define TARGET_RNGE2		@"You are too far away!"

