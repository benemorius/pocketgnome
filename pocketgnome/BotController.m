//
//  BotController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 1/14/08.
//  Copyright 2008 Savory Software, LLC. All rights reserved.
//

#import "BotController.h"

#import "Controller.h"
#import "ChatController.h"
#import "PlayerDataController.h"
#import "MobController.h"
#import "SpellController.h"
#import "NodeController.h"
#import "CombatController.h"
#import "MovementController.h"
#import "AuraController.h"
#import "WaypointController.h"
#import "ProcedureController.h"
#import "InventoryController.h"
#import "PlayersController.h"
#import "QuestController.h"
#import "CorpseController.h"
#import "LootController.h"
#import "ChatLogController.h"
#import "FishController.h"
#import "MacroController.h"
#import "OffsetController.h"
#import "MemoryViewController.h"
#import "CombatProfileEditor.h"
#import "EventController.h"
#import "BlacklistController.h"

#import "ChatLogEntry.h"
#import "BetterSegmentedControl.h"
#import "Behavior.h"
#import "RouteSet.h"
#import "Condition.h"
#import "Mob.h"
#import "Unit.h"
#import "Player.h"
#import "Item.h"
#import "Offsets.h"
#import "PTHeader.h"
#import "CGSPrivate.h"
#import "Macro.h"
#import "CombatProfileEditor.h"
#import "CombatProfile.h"
#import "Errors.h"

#import "ScanGridView.h"
#import "TransparentWindow.h"

#import <Growl/GrowlApplicationBridge.h>
#import <ShortcutRecorder/ShortcutRecorder.h>
#import <ScreenSaver/ScreenSaver.h>

#define DeserterSpellID         26013
#define HonorlessTargetSpellID  2479 
#define HonorlessTarget2SpellID 46705
#define IdleSpellID             43680
#define InactiveSpellID         43681
#define PreparationSpellID      44521
#define WaitingToRezSpellID     2584
#define HearthstoneItemID		6948
#define HearthStoneSpellID		8690

#define RefreshmentTableID		193061	// "Refreshment Table"
#define SoulwellID				193169	// "Soulwell"


// For strand of the ancients
#define StrandFlagpole					191311
#define StrandAllianceBanner			191310
#define StrandAllianceBannerAura		180100
#define StrandHordeBanner				191307
#define StrandeHordeBannerAura			180101
#define StrandAntipersonnelCannon		27894
#define StrandBattlegroundDemolisher	28781
#define StrandPrivateerZierhut			32658		// right boat
#define StrandPrivateerStonemantle		32657		// left boat

@interface BotController ()

@property (readwrite, retain) RouteSet *theRoute;
@property (readwrite, retain) Behavior *theBehavior;
@property (readwrite, retain) CombatProfile *theCombatProfile;
@property (readwrite, retain) NSDate *lootStartTime;
@property (readwrite, retain) NSDate *skinStartTime;
    
@property (readwrite, retain) NSDate *startDate;
@property (readwrite, retain) Mob *mobToSkin;
@property (readwrite, retain) WoWObject *unitToLoot;
@property (readwrite, retain) WoWObject *lastAttemptedUnitToLoot;
@property (readwrite, retain) Unit *preCombatUnit;

// pvp
@property (readwrite, assign) BOOL isPvPing;
@property (readwrite, assign) BOOL pvpPlayWarning;
@property (readwrite, assign) BOOL pvpLeaveInactive;
@property (readwrite, assign) int pvpCheckCount;

@property (readwrite, assign) BOOL doLooting;
@property (readwrite, assign) float gatherDistance;

@end

@interface BotController (Internal)

- (void)timeUp: (id)sender;
- (void)noAFK;

- (void)preRegen;
- (void)evaluateRegen: (NSDictionary*)regenDict;

- (BOOL)isUnitValidToAttack: (Unit*)unit fromPosition: (Position*)position ignoreDistance: (BOOL)ignoreDistance;

- (BOOL)evaluateRule: (Rule*)rule withTarget: (Unit*)target asTest: (BOOL)test;
- (void)performProcedureWithState: (NSDictionary*)state;
- (void)playerHasDied: (NSNotification*)noti;

// pvp
- (void)pvpStop;
- (void)pvpStart;
- (void)pvpCheck;
- (void)pvpGetBGInfo;

- (void)rePop: (NSNumber *)count;
- (void)startBotForPvP;

- (void)skinMob: (Mob*)mob;
- (void)skinOrFinish;
- (BOOL)unitValidToHeal: (Unit*)unit;
- (void)lootNode: (WoWObject*) unit;

- (BOOL)mountNow;

- (BOOL)scaryUnitsNearNode: (WoWObject*)node doMob:(BOOL)doMobCheck doFriendy:(BOOL)doFriendlyCheck doHostile:(BOOL)doHostileCheck;

@end


@implementation BotController

+ (void)initialize {
    
    NSDictionary *defaultValues = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool: NO],      @"IgnoreRoute",
                                   [NSNumber numberWithBool: YES],      @"AttackAnyLevel",
                                   [NSNumber numberWithFloat: 50.0],    @"GatheringDistance",
                                   [NSNumber numberWithInt: NSOnState], @"PvPAddonAutoJoin",
                                   [NSNumber numberWithInt: NSOnState], @"PvPAddonAutoQueue",
                                   [NSNumber numberWithInt: NSOnState], @"PvPAddonAutoRelease",
                                   [NSNumber numberWithInt: NSOnState], @"PvPPlayWarningSound",
                                   [NSNumber numberWithInt: NSOnState], @"PvPLeaveWhenInactive",
								   [NSNumber numberWithInt:0],			@"MovementType",
								   [NSNumber numberWithInt: NSOffState],@"DoLogOutCheck",
								   [NSNumber numberWithInt:20],		    @"LogOutOnBrokenItemsPercentage",
                                   nil];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultValues];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues: defaultValues];
}

- (id) init
{
    self = [super init];
    if (self != nil) {
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerHasDied:) name: PlayerHasDiedNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerHasRevived:) name: PlayerHasRevivedNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(playerIsInvalid:) 
                                                     name: PlayerIsInvalidNotification 
                                                   object: nil];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(auraGain:) 
                                                     name: BuffGainNotification 
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(auraFade:) 
                                                     name: BuffFadeNotification 
                                                   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(itemsLooted:) 
                                                     name: AllItemsLootedNotification 
                                                   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(whisperReceived:) 
                                                     name: WhisperReceived 
                                                   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(eventZoneChanged:) 
                                                     name: EventZoneChanged 
                                                   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(eventBattlegroundStatusChange:) 
                                                     name: EventBattlegroundStatusChange 
                                                   object: nil];
		
        _procedureInProgress = nil;
        self.didPreCombatProcedure = NO;
		_lastSpellCastGameTime = 0;
		self.startDate = nil;
		_unitToLoot = nil;
		_mobToSkin = nil;
		_shouldFollow = YES;
		_lastUnitAttemptedToHealed = nil;
		_pvpIsInBG = NO;
		self.lootStartTime = nil;
		self.skinStartTime = nil;
		_lootAttempt = 0;
		_zoneBeforeHearth = -1;
		_attackingInStrand = NO;
		_strandDelay = NO;
		_jumpAttempt = 0;
        
        _mobsToLoot = [[NSMutableArray array] retain];
        
        // wipe pvp options
        self.isPvPing = NO;
        self.pvpLeaveInactive = NO;
        self.pvpPlayWarning = NO;
		
		// anti afk
		_lastPressedWasForward = NO;
		_afkTimerCounter = 0;
		
		// wg stuff
		_lastNumWGMarks = 0;
		_dateWGEnded = nil;
		
		_logOutTimer = nil;
		
		// Every 15 seconds we'll want to send clicks!
		_wgTimer = [NSTimer scheduledTimerWithTimeInterval: 15.0f target: self selector: @selector(wgTimer:) userInfo: nil repeats: YES];
		
		// Every 30 seconds for an anti-afk
		_afkTimer = [NSTimer scheduledTimerWithTimeInterval: 30.0f target: self selector: @selector(afkTimer:) userInfo: nil repeats: YES];
	
		
        [NSBundle loadNibNamed: @"Bot" owner: self];
    } 
    return self;
}

- (void)awakeFromNib {
    self.minSectionSize = [self.view frame].size;
    self.maxSectionSize = [self.view frame].size;
    
    [shortcutRecorder setCanCaptureGlobalHotKeys: YES];
    [startstopRecorder setCanCaptureGlobalHotKeys: YES];
    [petAttackRecorder setCanCaptureGlobalHotKeys: YES];
	[mouseOverRecorder setCanCaptureGlobalHotKeys: YES];
    
    KeyCombo combo1 = { NSShiftKeyMask, kSRKeysF13 };
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"HotkeyCode"])
        combo1.code = [[[NSUserDefaults standardUserDefaults] objectForKey: @"HotkeyCode"] intValue];
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"HotkeyFlags"])
        combo1.flags = [[[NSUserDefaults standardUserDefaults] objectForKey: @"HotkeyFlags"] intValue];

    KeyCombo combo2 = { NSCommandKeyMask, kSRKeysEscape };
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"StartstopCode"])
        combo2.code = [[[NSUserDefaults standardUserDefaults] objectForKey: @"StartstopCode"] intValue];
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"StartstopFlags"])
        combo2.flags = [[[NSUserDefaults standardUserDefaults] objectForKey: @"StartstopFlags"] intValue];
    
    KeyCombo combo3 = { NSShiftKeyMask, kVK_ANSI_T };
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"PetAttackCode"])
        combo3.code = [[[NSUserDefaults standardUserDefaults] objectForKey: @"PetAttackCode"] intValue];
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"PetAttackFlags"])
        combo3.flags = [[[NSUserDefaults standardUserDefaults] objectForKey: @"PetAttackFlags"] intValue];
        
    KeyCombo combo4 = { 0, -1 };
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"MouseOverTargetCode"])
        combo4.code = [[[NSUserDefaults standardUserDefaults] objectForKey: @"MouseOverTargetCode"] intValue];
    if([[NSUserDefaults standardUserDefaults] objectForKey: @"MouseOverTargetFlags"])
        combo4.flags = [[[NSUserDefaults standardUserDefaults] objectForKey: @"MouseOverTargetFlags"] intValue];
	
    [shortcutRecorder setDelegate: nil];
    [startstopRecorder setDelegate: self];
    [petAttackRecorder setDelegate: nil];
	[mouseOverRecorder setDelegate: nil];

    [shortcutRecorder setKeyCombo: combo1];
    [startstopRecorder setKeyCombo: combo2];
    [petAttackRecorder setKeyCombo: combo3];
	[mouseOverRecorder setKeyCombo: combo4];
    
    [shortcutRecorder setDelegate: self];
    [petAttackRecorder setDelegate: self];
	[mouseOverRecorder setDelegate: self];
	
    // set up overlay window
    [overlayWindow setLevel: NSFloatingWindowLevel];
    if([overlayWindow respondsToSelector: @selector(setCollectionBehavior:)]) {
        [overlayWindow setCollectionBehavior: NSWindowCollectionBehaviorMoveToActiveSpace];
    }
    
    [self updateStatus: nil];
}

@synthesize theRoute;
@synthesize theBehavior;
@synthesize theCombatProfile;
@synthesize lootStartTime;
@synthesize skinStartTime;

@synthesize logOutAfterStuckCheckbox;
@synthesize view;
@synthesize isBotting = _isBotting;
@synthesize didPreCombatProcedure = _didPreCombatProcedure;
@synthesize procedureInProgress = _procedureInProgress;
@synthesize mobToSkin = _mobToSkin;
@synthesize unitToLoot = _unitToLoot;
@synthesize lastAttemptedUnitToLoot = _lastAttemptedUnitToLoot;
@synthesize minSectionSize;
@synthesize maxSectionSize;
@synthesize preCombatUnit;
@synthesize isPvPing = _isPvPing;
@synthesize pvpPlayWarning = _pvpPlayWarning;
@synthesize pvpLeaveInactive = _pvpLeaveInactive;
@synthesize pvpCheckCount = _pvpCheckCount;

@synthesize startDate;
@synthesize doLooting       = _doLooting;
@synthesize gatherDistance  = _gatherDist;
@synthesize nodeDescend     = _nodeDescend;

- (NSString*)sectionTitle {
    return @"Start/Stop Bot";
}

- (CombatProfileEditor*)combatProfileEditor {
    return [CombatProfileEditor sharedEditor];
}

#pragma mark -

int DistanceFromPositionCompare(id <UnitPosition> unit1, id <UnitPosition> unit2, void *context) {
    
    //PlayerDataController *playerData = (PlayerDataController*)context; [playerData position];
    Position *position = (Position*)context; 

    float d1 = [position distanceToPosition: [unit1 position]];
    float d2 = [position distanceToPosition: [unit2 position]];
    if (d1 < d2)
        return NSOrderedAscending;
    else if (d1 > d2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}


#pragma mark -

- (void)testRule: (Rule*)rule {
	log(LOG_FUNCTION, @"entering function");
    Unit *unit = [mobController playerTarget];
    if(!unit) unit = [playersController playerTarget];

    log(LOG_RULE, @"Testing rule with target: %@", unit);
    BOOL result = [self evaluateRule: rule withTarget: unit asTest: YES];
    NSRunAlertPanel(TRUE_FALSE(result), [NSString stringWithFormat: @"%@", rule], @"Okay", NULL, NULL);
}

- (BOOL)evaluateRule: (Rule*)rule withTarget: (Unit*)target asTest: (BOOL)test {
	log(LOG_FUNCTION, @"entering function");
    log(LOG_RULE, @"Checking rule %@.", rule);
    //BOOL eval = [rule isMatchAll] ? YES : NO;

    int numMatched = 0, needToMatch = 0;
    if([rule isMatchAll]) {
        for(Condition *condition in [rule conditions]) {
            if( [condition enabled]) needToMatch++;
        }
    }
    
    if(needToMatch == 0) needToMatch = 1;
    
    Player *thePlayer = [playerController player];
    
    log(LOG_CONDITION, @"Need to match: %d", needToMatch);
    
    for(Condition *condition in [rule conditions]) {
        log(LOG_CONDITION, @"Checking condition: %@", condition);
        
        if(![condition enabled]) continue;  // skip disabled conditions
        
        BOOL conditionEval = NO;
        if([condition unit] == UnitNone && [condition variety] != VarietySpellCooldown) goto loopEnd;
        if([condition unit] == UnitTarget && !target) goto loopEnd;
		if([condition unit] == UnitFriend && !target) goto loopEnd;
        
        switch([condition variety]) {
            case VarietyNone:;
                log(LOG_CONDITION, @"Error: %@ in %@ is of an unknown type.", condition, rule);
                break;
            case VarietyHealth:;
                /* ******************************** */
                /* Health / Power Condition         */
                /* ******************************** */
                int qualityValue = 0;
                if( [condition unit] == UnitPlayer ) {
                    log(LOG_CONDITION, @"Checking player... type %d", [condition type]);
                    if( ![playerController playerIsValid:self] || ![thePlayer isValid]) goto loopEnd;
                    if( [condition quality] == QualityHealth ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentHealth] : [thePlayer percentHealth];
                    } else if ([condition quality] == QualityPower ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentPower] : [thePlayer percentPower];
                    } else if ([condition quality] == QualityMana ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentPowerOfType: UnitPower_Mana] : [thePlayer percentPowerOfType: UnitPower_Mana];
                    } else if ([condition quality] == QualityRage ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentPowerOfType: UnitPower_Rage] : [thePlayer percentPowerOfType: UnitPower_Rage];
                    } else if ([condition quality] == QualityEnergy ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentPowerOfType: UnitPower_Energy] : [thePlayer percentPowerOfType: UnitPower_Energy];
                    } else if ([condition quality] == QualityHappiness ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentPowerOfType: UnitPower_Happiness] : [thePlayer percentPowerOfType: UnitPower_Happiness];
                    } else if ([condition quality] == QualityFocus ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentPowerOfType: UnitPower_Focus] : [thePlayer percentPowerOfType: UnitPower_Focus];
                    } else if ([condition quality] == QualityRunicPower ) {
                        qualityValue = ([condition type] == TypeValue) ? [thePlayer currentPowerOfType: UnitPower_RunicPower] : [thePlayer percentPowerOfType: UnitPower_RunicPower];
                    } else goto loopEnd;
                } else {
                    // get unit as either target or player's pet or friend
                    Unit *aUnit = ([condition unit] == UnitTarget || [condition unit] == UnitFriend) ? target : [playerController pet];
                    if( ![aUnit isValid]) goto loopEnd;
                    if( [condition quality] == QualityHealth ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentHealth] : [aUnit percentHealth];
                    } else if ([condition quality] == QualityPower ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentPower] : [aUnit percentPower];
                    } else if ([condition quality] == QualityMana ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentPowerOfType: UnitPower_Mana] : [aUnit percentPowerOfType: UnitPower_Mana];
                    } else if ([condition quality] == QualityRage ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentPowerOfType: UnitPower_Rage] : [aUnit percentPowerOfType: UnitPower_Rage];
                    } else if ([condition quality] == QualityEnergy ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentPowerOfType: UnitPower_Energy] : [aUnit percentPowerOfType: UnitPower_Energy];
                    } else if ([condition quality] == QualityHappiness ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentPowerOfType: UnitPower_Happiness] : [aUnit percentPowerOfType: UnitPower_Happiness];
                    } else if ([condition quality] == QualityFocus ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentPowerOfType: UnitPower_Focus] : [aUnit percentPowerOfType: UnitPower_Focus];
                    } else if ([condition quality] == QualityRunicPower ) {
                        qualityValue = ([condition type] == TypeValue) ? [aUnit currentPowerOfType: UnitPower_RunicPower] : [aUnit percentPowerOfType: UnitPower_RunicPower];
                    } else goto loopEnd;
                }
                
                // now we have the value of the quality
                if( [condition comparator] == CompareMore) {
                    conditionEval = ( qualityValue > [[condition value] unsignedIntValue] ) ? YES : NO;
                    log(LOG_CONDITION, @"  %d > %@ is %d", qualityValue, [condition value], conditionEval);
                } else if([condition comparator] == CompareEqual) {
                    conditionEval = ( qualityValue == [[condition value] unsignedIntValue] ) ? YES : NO;
                    log(LOG_CONDITION, @"  %d = %@ is %d", qualityValue, [condition value], conditionEval);
                } else if([condition comparator] == CompareLess) {
                    conditionEval = ( qualityValue < [[condition value] unsignedIntValue] ) ? YES : NO;
                    log(LOG_CONDITION, @"  %d > %@ is %d", qualityValue, [condition value], conditionEval);
                } else goto loopEnd;
                
                break;
                
                /* ******************************** */
                /* Status Condition                 */
                /* ******************************** */
            case VarietyStatus:; 
                //PGLog(@"-- Checking status condition --");
                
                // check alive status
                if( [condition state] == StateAlive ) {
                    if( [condition unit] == UnitPlayer)
                        conditionEval = ( [condition comparator] == CompareIs ) ? ![playerController isDead] : ![playerController isDead];
                    else if( [condition unit] == UnitTarget || [condition unit] == UnitFriend )
                        conditionEval = ( [condition comparator] == CompareIs ) ? ![target isDead] : [target isDead];
                    else if( [condition unit] == UnitPlayerPet) {
                        if(playerController.pet == nil) {
                            conditionEval = ([condition comparator] == CompareIs) ? NO : YES;
                        } else
                            conditionEval = ( [condition comparator] == CompareIs ) ? ![playerController.pet isDead] : [playerController.pet isDead];
                    } else goto loopEnd;
                    log(LOG_CONDITION, @"Alive? %d", conditionEval);
                }
                
                // check combat status
                if( [condition state] == StateCombat ) {
                    if( [condition unit] == UnitPlayer)
                        conditionEval = ( [condition comparator] == CompareIs ) ? [combatController inCombat] : ![combatController inCombat];
                    else if( [condition unit] == UnitTarget || [condition unit] == UnitFriend )
                        conditionEval = ( [condition comparator] == CompareIs ) ? [target isInCombat] : ![target isInCombat];
                    else if( [condition unit] == UnitPlayerPet)
                        conditionEval = ( [condition comparator] == CompareIs ) ? [playerController.pet isInCombat] : ![playerController.pet isInCombat];
                    else goto loopEnd;
					log(LOG_CONDITION, @"Combat? %d", conditionEval);
                }
                
                // check casting status
                if( [condition state] == StateCasting ) {
                    if( [condition unit] == UnitPlayer)
                        conditionEval = ( [condition comparator] == CompareIs ) ? [playerController isCasting] : ![playerController isCasting];
                    else if( [condition unit] == UnitTarget || [condition unit] == UnitFriend )
                        conditionEval = ( [condition comparator] == CompareIs ) ? [target isCasting] : ![target isCasting];
                    else if( [condition unit] == UnitPlayerPet)
                        conditionEval = ( [condition comparator] == CompareIs ) ? [playerController.pet isCasting] : ![playerController.pet isCasting];
                    goto loopEnd;
                    log(LOG_CONDITION, @"Casting? %d", conditionEval);
                }
                
                // IS THE UNIT MOUNTED?
                if( [condition state] == StateMounted ) {
                    log(LOG_CONDITION, @"Doing State IsMounted condition...");
                    Unit *aUnit = nil;
                    if( [condition unit] == UnitPlayer)         aUnit = thePlayer;
                    else if( [condition unit] == UnitTarget || [condition unit] == UnitFriend )    aUnit = target;
                    else if( [condition unit] == UnitPlayerPet) aUnit = playerController.pet;
                    log(LOG_CONDITION, @" --> Testing unit %@", aUnit);
                    
                    if([aUnit isValid]) {
                        conditionEval = ( [condition comparator] == CompareIs ) ? [aUnit isMounted] : ![aUnit isMounted];
                        log(LOG_CONDITION, @" --> Unit is mounted? %@", YES_NO(conditionEval));
                    } else {
                        log(LOG_CONDITION, @" --> Unit is invalid.");
                    }
                }
                
                // IS THE PLAYER INDOORS?
                if( [condition state] == StateIndoors ) {
                    log(LOG_CONDITION, @"Doing State 'Indoors' condition...");
                    conditionEval = ( [condition comparator] == CompareIs ) ? [playerController isIndoors] : [playerController isOutdoors];
                    if(test) {
                        if([condition comparator] == CompareIs) {
                            if(conditionEval){
								log(LOG_CONDITION, @" --> (%@) Unit is indoors.", TRUE_FALSE(conditionEval));
							}
                            else{
								log(LOG_CONDITION, @" --> (%@) Unit is not indoors.", TRUE_FALSE(conditionEval));
							}
                        } else {
                            if(conditionEval){
								log(LOG_CONDITION, @" --> (%@) Unit is not indoors.", TRUE_FALSE(conditionEval));
							}
                            else{
								log(LOG_CONDITION, @" --> (%@) Unit is indoors.", TRUE_FALSE(conditionEval));
							}
                        }
                    }
                }
                
                break;
                
                /* ******************************** */
                /* Aura Condition                   */
                /* ******************************** */
            case VarietyAura:;
                log(LOG_CONDITION, @"-- Checking aura condition --");
                
                unsigned spellID = 0;
                NSString *dispelType = nil;
                BOOL doDispelCheck = ([condition quality] == QualityBuffType) || ([condition quality] == QualityDebuffType);
                
                // sanity checks
                if(!doDispelCheck) {
                    if( [condition type] == TypeValue)
                        spellID = [[condition value] unsignedIntValue];
                    
                    if( ([condition type] == TypeValue) && !spellID) {
                        // invalid spell ID
                        goto loopEnd;
                    } else if( [condition type] == TypeString && (![condition value] || ![[condition value] length])) {
                        // invalid spell name
                        goto loopEnd;
                    }
                } else {
                    if( ([condition state] < StateMagic) || ([condition state] > StatePoison)) {
                        // invalid dispel type
                        goto loopEnd;
                    } else {
                        if([condition state] == StateMagic)     dispelType = DispelTypeMagic;
                        if([condition state] == StateCurse)     dispelType = DispelTypeCurse;
                        if([condition state] == StatePoison)    dispelType = DispelTypePoison;
                        if([condition state] == StateDisease)   dispelType = DispelTypeDisease;
                    }
                }
                
                //PGLog(@"  Searching for spell '%@'", [condition value]);
                
                Unit *aUnit = nil;
                if( [condition unit] == UnitPlayer ) {
                    if( ![playerController playerIsValid:self]) goto loopEnd;
                    aUnit = thePlayer;
                } else {
                    aUnit = ([condition unit] == UnitTarget || [condition unit] == UnitFriend) ? target : [playerController pet];
                }
                
                if( [aUnit isValid]) {
                    if( [condition quality] == QualityBuff ) {
                        if([condition type] == TypeValue)
                            conditionEval = ([condition comparator] == CompareExists) ? [auraController unit: aUnit hasBuff: spellID] : ![auraController unit: aUnit hasBuff: spellID];
                        if([condition type] == TypeString)
                            conditionEval = ([condition comparator] == CompareExists) ? [auraController unit: aUnit hasBuffNamed: [condition value]] : ![auraController unit: aUnit hasBuffNamed: [condition value]];
                    } else if([condition quality] == QualityDebuff) {
                        if([condition type] == TypeValue)
                            conditionEval = ([condition comparator] == CompareExists) ? [auraController unit: aUnit hasDebuff: spellID] : ![auraController unit: aUnit hasDebuff: spellID];
                        if([condition type] == TypeString)
                            conditionEval = ([condition comparator] == CompareExists) ? [auraController unit: aUnit hasDebuffNamed: [condition value]] : ![auraController unit: aUnit hasDebuffNamed: [condition value]];
                    } else if([condition quality] == QualityBuffType) {
                        conditionEval = ([condition comparator] == CompareExists) ? [auraController unit: aUnit hasBuffType: dispelType] : ![auraController unit: aUnit hasBuffType: dispelType];
                    } else if([condition quality] == QualityDebuffType) {
                        conditionEval = ([condition comparator] == CompareExists) ? [auraController unit: aUnit hasDebuffType: dispelType] : ![auraController unit: aUnit hasDebuffType: dispelType];
                    }
                } else goto loopEnd;
                
                break;
                
                
                /* ******************************** */
                /* Aura Stack Condition             */
                /* ******************************** */
            case VarietyAuraStack:;
                
                spellID = 0;
                dispelType = nil;
                
                log(LOG_CONDITION, @"Doing Aura Stack condition...");
                
                // sanity checks
                if(([condition type] != TypeValue) && ([condition type] != TypeString)) {
                    log(LOG_CONDITION, @" --> Invalid condition type.");
                    goto loopEnd;
                }
                if( [condition type] == TypeValue) {
                    spellID = [[condition value] unsignedIntValue];
                    if(spellID == 0) { // invalid spell ID
                        log(LOG_CONDITION, @" --> Invalid spell number");
                        goto loopEnd;
                    } else {
                        log(LOG_CONDITION, @" --> Scanning for aura %u", spellID);
                    }
                }
                if( [condition type] == TypeString) {
                    if( ![[condition value] isKindOfClass: [NSString class]] || ![[condition value] length] ) {
                        log(LOG_CONDITION, @" --> Invalid or blank Spell name.");
                        goto loopEnd;
                    } else {
                        log(LOG_CONDITION, @" --> Scanning for aura \"%@\"", [condition value]);
                    }
                }
                
                aUnit = nil;
                if( [condition unit] == UnitPlayer ) {
                    if( ![playerController playerIsValid:self]) goto loopEnd;
                    aUnit = thePlayer;
                } else {
                    aUnit = ([condition unit] == UnitTarget || [condition unit] == UnitFriend) ? target : [playerController pet];
                }
                
                if( [aUnit isValid]) {
                    log(LOG_CONDITION, @"Testing unit %@ for %d", aUnit, spellID);
                    int stackCount = 0;
                    if( [condition quality] == QualityBuff ) {
                        if([condition type] == TypeValue)   stackCount = [auraController unit: aUnit hasBuff: spellID];
                        if([condition type] == TypeString)  stackCount = [auraController unit: aUnit hasBuffNamed: [condition value]];
                    } else if([condition quality] == QualityDebuff) {
                        if([condition type] == TypeValue)   stackCount = [auraController unit: aUnit hasDebuff: spellID];
                        if([condition type] == TypeString)  stackCount = [auraController unit: aUnit hasDebuffNamed: [condition value]];
                    }
                    
                    if([condition comparator] == CompareMore) {
                        conditionEval = (stackCount > [condition state]);
                    }
                    if([condition comparator] == CompareEqual) {
                        conditionEval = (stackCount == [condition state]);
                    }
                    if([condition comparator] == CompareLess) {
                        conditionEval = (stackCount < [condition state]);
                    }
                    log(LOG_CONDITION, @" --> Found %d stacks for result %@", stackCount, (conditionEval ? @"TRUE" : @"FALSE"));
                    // conditionEval = ([condition comparator] == CompareMore) ? (stackCount > [condition state]) : (([condition comparator] == CompareEqual) ? (stackCount == [condition state]) : (stackCount < [condition state]));
                } else goto loopEnd;
                
                break;
                
                
                /* ******************************** */
                /* Distance Condition               */
                /* ******************************** */
            case VarietyDistance:;
                
                if( [condition unit] == UnitTarget && [condition quality] == QualityDistance && target) {
                    float distanceToTarget = [[(PlayerDataController*)playerController position] distanceToPosition: [target position]];
                    log(LOG_CONDITION, @"-- Checking distance condition --");
                    
                    if( [condition comparator] == CompareMore) {
                        conditionEval = ( distanceToTarget > [[condition value] floatValue] ) ? YES : NO;
                        log(LOG_CONDITION, @"  %f > %@ is %d", distanceToTarget, [condition value], conditionEval);
                    } else if([condition comparator] == CompareEqual) {
                        conditionEval = ( distanceToTarget == [[condition value] floatValue] ) ? YES : NO;
                        log(LOG_CONDITION, @"  %f = %@ is %d", distanceToTarget, [condition value], conditionEval);
                    } else if([condition comparator] == CompareLess) {
                        conditionEval = ( distanceToTarget < [[condition value] floatValue] ) ? YES : NO;
                        log(LOG_CONDITION, @"  %f < %@ is %d", distanceToTarget, [condition value], conditionEval);
                    } else goto loopEnd;
                }
                
                break;
                
                
                /* ******************************** */
                /* Inventory Condition              */
                /* ******************************** */
            case VarietyInventory:;
                if( [condition unit] == UnitPlayer && [condition quality] == QualityInventory) {
                    log(LOG_CONDITION, @"-- Checking inventory condition --");
                    Item *item = ([condition type] == TypeValue) ? [itemController itemForID: [condition value]] : [itemController itemForName: [condition value]];
                    
                    int totalCount = [itemController collectiveCountForItemInBags: item];
                    if( [condition comparator] == CompareMore) {
                        conditionEval = (totalCount > [condition state]) ? YES : NO;
                    }
                    
                    if( [condition comparator] == CompareEqual) {
                        conditionEval = (totalCount == [condition state]) ? YES : NO;
                    }
                    
                    if( [condition comparator] == CompareLess) {
                        conditionEval = (totalCount < [condition state]) ? YES : NO;
                    }
                }
                break;
                
                /* ******************************** */
                /* Combo Points Condition           */
                /* ******************************** */
            case VarietyComboPoints:;
                
                log(LOG_CONDITION, @"Doing Combo Points condition...");
                
                UInt32 class = [thePlayer unitClass];
                if( (class != UnitClass_Rogue) && (class != UnitClass_Druid) ) {
                    log(LOG_CONDITION, @" --> You are not a rogue or druid, noob.");
                    goto loopEnd;
                }
                
                if( ([condition unit] == UnitPlayer) && ([condition quality] == QualityComboPoints) && target) {
                    
                    // either we have no CP target, or our CP target matched our current target
                    UInt64 cpUID = [playerController comboPointUID];
                    if( (cpUID == 0) || ([target GUID] == cpUID)) {
                        int comboPoints = [playerController comboPoints];
                        log(LOG_CONDITION, @" --> Found %d combo points.", comboPoints);
                        
                        if( [condition comparator] == CompareMore) {
                            conditionEval = ( comboPoints > [[condition value] intValue] ) ? YES : NO;
                            log(LOG_CONDITION, @" --> %d > %@ is %@.", comboPoints, [condition value], TRUE_FALSE(conditionEval));
                        } else if([condition comparator] == CompareEqual) {
                            conditionEval = ( comboPoints == [[condition value] intValue] ) ? YES : NO;
                            log(LOG_CONDITION, @" --> %d = %@ is %@.", comboPoints, [condition value], TRUE_FALSE(conditionEval));
                        } else if([condition comparator] == CompareLess) {
                            conditionEval = ( comboPoints < [[condition value] intValue] ) ? YES : NO;
                            log(LOG_CONDITION, @" --> %d < %@ is %@.", comboPoints, [condition value], TRUE_FALSE(conditionEval));
                        } else goto loopEnd;
                    }
                }
                
                break;
                
                /* ******************************** */
                /* Totem Condition                  */
                /* ******************************** */
            case VarietyTotem:;
                
                log(LOG_CONDITION, @"Doing Totem condition...");
                
                if( ![condition value] || ![[condition value] length] || ![[condition value] isKindOfClass: [NSString class]] ) {
                    log(LOG_CONDITION, @" --> Invalid totem name.");
                    goto loopEnd;
                }
                if( ([condition unit] != UnitPlayer) || ([condition quality] != QualityTotem)) {
                    log(LOG_CONDITION, @" --> Invalid condition parameters.");
                    goto loopEnd;
                }
                if( [thePlayer unitClass] != UnitClass_Shaman ) {
                    log(LOG_CONDITION, @" --> You are not a shaman, noob.");
                    goto loopEnd;
                }
                
                // we need to rescan the mob list before we check for active totems
                // [mobController enumerateAllMobs];
                
                BOOL foundTotem = NO;
                for(Mob* mob in [mobController allMobs]) {
                    if( [mob isTotem] && ([mob createdBy] == [playerController GUID]) ) {
                        NSRange range = [[mob name] rangeOfString: [condition value]
                                                          options: NSCaseInsensitiveSearch | NSAnchoredSearch | NSDiacriticInsensitiveSearch];
                        if(range.location != NSNotFound) {
                            foundTotem = YES;
                            log(LOG_CONDITION, @" --> Found totem %@ matching \"%@\".", mob, [condition value]);
                            break;
                        }
                    }
                }
                
                if(!foundTotem && test) {
                    log(LOG_CONDITION, @" --> No totem found with name \"%@\"", [condition value]);
                }
                
                conditionEval = ([condition comparator] == CompareExists) ? foundTotem : !foundTotem;
                
                break;
                
                
                /* ******************************** */
                /* Temp. Enchant Condition          */
                /* ******************************** */
            case VarietyTempEnchant:;
                
                log(LOG_CONDITION, @"Doing Temp Enchant condition...");
                
                Item *item = [itemController itemForGUID: [thePlayer itemGUIDinSlot: ([condition quality] == QualityMainhand) ? SLOT_MAIN_HAND : SLOT_OFF_HAND]];
                log(LOG_CONDITION, @" --> Got item %@.", item);
                BOOL hadEnchant = [item hasTempEnchantment];
                conditionEval = ([condition comparator] == CompareExists) ? hadEnchant : !hadEnchant;
                log(LOG_CONDITION, @" --> Had enchant? %@. Result is %@.", YES_NO(hadEnchant), TRUE_FALSE(conditionEval));
				
                break;
                
                
                /* ******************************** */
                /* Target Type Condition          */
                /* ******************************** */
            case VarietyTargetType:;
                
                log(LOG_CONDITION, @"Doing Target Type condition...");
                
                if([condition quality] == QualityNPC) {
                    conditionEval = [target isNPC];
                    log(LOG_CONDITION, @" --> Is NPC? %@", YES_NO(conditionEval));
                }
                if([condition quality] == QualityPlayer) {
                    conditionEval = [target isPlayer];
                    log(LOG_CONDITION, @" --> Is Player? %@", YES_NO(conditionEval));
                }
                break;
                
                /* ******************************** */
                /* Target Class Condition           */
                /* ******************************** */
            case VarietyTargetClass:;
                
                log(LOG_CONDITION, @"Doing Target Class condition...");
                
                if([condition quality] == QualityNPC) {
                    conditionEval = ([target creatureType] == [condition state]);
                    log(LOG_CONDITION, @" --> Unit Creature Type %d == %d? %@", [condition state], [target creatureType], YES_NO(conditionEval));
                }
                if([condition quality] == QualityPlayer) {
                    conditionEval = ([target unitClass] == [condition state]);
                    log(LOG_CONDITION, @" --> Unit Class %d == %d? %@", [condition state], [target unitClass], YES_NO(conditionEval));
                }
                break;
                
                
                /* ******************************** */
                /* Combat Count Condition           */
                /* ******************************** */
            case VarietyCombatCount:;
                
                log(LOG_CONDITION, @"Doing Combat Count condition...");
                
                int unitsAttackingMe = [[combatController unitsAttackingMe] count];
                log(LOG_CONDITION, @" --> Found %d units attacking me.", unitsAttackingMe);
                
                if( [condition comparator] == CompareMore) {
                    conditionEval = ( unitsAttackingMe > [condition state] ) ? YES : NO;
                    log(LOG_CONDITION, @" --> %d > %d is %@.", unitsAttackingMe, [condition state], TRUE_FALSE(conditionEval));
                } else if([condition comparator] == CompareEqual) {
                    conditionEval = ( unitsAttackingMe == [condition state] ) ? YES : NO;
                    log(LOG_CONDITION, @" --> %d = %d is %@.", unitsAttackingMe, [condition state], TRUE_FALSE(conditionEval));
                } else if([condition comparator] == CompareLess) {
                    conditionEval = ( unitsAttackingMe < [condition state] ) ? YES : NO;
                    log(LOG_CONDITION, @" --> %d < %d is %@.", unitsAttackingMe, [condition state], TRUE_FALSE(conditionEval));
                } else goto loopEnd;
                break;
                
                
                /* ******************************** */
                /* Proximity Count Condition        */
                /* ******************************** */
            case VarietyProximityCount:;
                log(LOG_CONDITION, @"Doing Proximity Count condition...");

                float distance = [[condition value] floatValue];
                
                Position *playerPosition = [thePlayer position];
                Position *basePosition = ([condition unit] == UnitTarget) ? [target position] : playerPosition;
                
                // get list of all possible targets
                NSMutableArray *allTargets = [NSMutableArray array], *validTargets = [NSMutableArray array];
                if(test || self.theCombatProfile.attackNeutralNPCs || self.theCombatProfile.attackHostileNPCs) {
                    [allTargets addObjectsFromArray: [mobController allMobs]];
                }
                if(test || self.theCombatProfile.attackPlayers) {
                    [allTargets addObjectsFromArray: [playersController allPlayers]];
                }
                log(LOG_CONDITION, @" --> Found %d total units.", [allTargets count]);
                
                // extract valid targets from all targets
                for(Unit *unit in allTargets) {
                    if( test || [self isUnitValidToAttack: unit fromPosition: playerPosition ignoreDistance: YES]) {
                        [validTargets addObject: unit];
                    }
                }
                
                if(test) {
                    log(LOG_CONDITION, @" --> Test mode checks all units; normal mode will validate units against your combat profile.");
                    if([condition unit] == UnitPlayer) log(LOG_CONDITION, @" --> Checking %.2fy around player...", distance);
                    if([condition unit] == UnitTarget) log(LOG_CONDITION, @" --> Checking %.2fy around target...", distance); 
                }
                
                // count the units in range
                int inRangeCount = 0;
                for(Unit *unit in validTargets) {
                    float range = [basePosition distanceToPosition: [unit position]];
                    if(range <= distance) {
                        log(LOG_CONDITION, @" ----> In Range (%.2fy): %@", range, unit);
                        inRangeCount++;
                    }
                }
                
                // compare with specified number of units
                if( [condition comparator] == CompareMore) {
                    conditionEval = ( inRangeCount > [condition state] ) ? YES : NO;
                    log(LOG_CONDITION, @" --> %d > %d is %@.", inRangeCount, [condition state], TRUE_FALSE(conditionEval));
                } else if([condition comparator] == CompareEqual) {
                    conditionEval = ( inRangeCount == [condition state] ) ? YES : NO;
                    log(LOG_CONDITION, @" --> %d = %d is %@.", inRangeCount, [condition state], TRUE_FALSE(conditionEval));
                } else if([condition comparator] == CompareLess) {
                    conditionEval = ( inRangeCount < [condition state] ) ? YES : NO;
                    log(LOG_CONDITION, @" --> %d < %d is %@.", inRangeCount, [condition state], TRUE_FALSE(conditionEval));
                } else goto loopEnd;
                
                break;
				
				/* ******************************** */
                /* Spell Cooldown Condition        */
                /* ******************************** */
            case VarietySpellCooldown:;
                log(LOG_CONDITION, @"Doing Spell Cooldown condition...");
				
				// checking by spell ID
				if ( [condition type] == TypeValue ){
					
					unsigned spellID = [[condition value] unsignedIntValue];
					if ( !spellID )
						goto loopEnd;
					
					// check
					conditionEval = [spellController isSpellOnCooldown:spellID];
					log(LOG_CONDITION, @"Spell %d is on cooldown? %d", spellID, conditionEval);
				}
				
				// checking by spell ID
				else if ( [condition type] == TypeString ){
					
					// sanity check
					if ( ![condition value] || ![[condition value] length] )
						goto loopEnd;
					
					Spell *spell = [spellController spellForName:[condition value]];
					if ( spell && [spell ID] ){
						conditionEval = [spellController isSpellOnCooldown:[[spell ID] unsignedIntValue]];
						log(LOG_CONDITION, @"Spell %@ is on cooldown? %d", spell, conditionEval);
					}
				}
				
				break;
				
            default:;
                break;
        }
        
    loopEnd:
        if(conditionEval)   {
            numMatched++;
            //if(test) NSRunAlertPanel(@"Condition True", [NSString stringWithFormat: @"%@ is true.", condition], @"Okay", NULL, NULL);
        } else {
            //if(test) NSRunAlertPanel(@"Condition False", [NSString stringWithFormat: @"%@ is false.", condition], @"Okay", NULL, NULL);
        }
        
        // shortcut bail if we can
        if([rule isMatchAll]) {
            if(!conditionEval) return NO;
        } else {
            if(conditionEval) return YES;
        }
    }
    
    // match all requires as many Yes and there are conditions
    //if([rule isMatchAll] && (numMatched >= needToMatch ))
    //    return YES;
    //if(![rule isMatchAll] && (numMatched > 0))
    //    return YES;
    log(LOG_CONDITION, @"    Matched %d of %d", numMatched, needToMatch);

    if(numMatched >= needToMatch)
        return YES;
    return NO;
}

#define RULE_EVAL_DELAY_SHORT   0.25f
#define RULE_EVAL_DELAY_NORMAL  0.5f
#define RULE_EVAL_DELAY_LONG    0.5f

- (void)cancelCurrentProcedure {
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    [self setProcedureInProgress: nil];
}

- (void)finishCurrentProcedure: (NSDictionary*)state {
	log(LOG_FUNCTION, @"entering function");
	
	log(LOG_BEHAVIOR, @"Finishing Procedure: %@", [state objectForKey: @"Procedure"]);
    
    // make sure we're done casting before we end the procedure
    if( [playerController isCasting] ) {
        float timeLeft = [playerController castTimeRemaining];
        if( timeLeft <= 0 ) {
            [self performSelector: _cmd withObject: state afterDelay: 0.1];
        } else {
            log(LOG_BEHAVIOR, @"Still casting (%.2f remains): Delaying procedure end.", timeLeft);
            [self performSelector: _cmd withObject: state afterDelay: timeLeft];
            return;
        }
        return;
    }
    
    //if( ![[state objectForKey: @"Procedure"] isEqualToString: CombatProcedure])
    log(LOG_BEHAVIOR, @"--- All done with procedure: %@.", [state objectForKey: @"Procedure"]);
    [self cancelCurrentProcedure];
    
    // when we finish PreCombat, re-evaluate the situation
    if([[state objectForKey: @"Procedure"] isEqualToString: PreCombatProcedure]) {
        [self evaluateSituation];
        return;
    }
    
    // when we finish PostCombat, run regen
    if([[state objectForKey: @"Procedure"] isEqualToString: PostCombatProcedure]) {
        float regenDelay = 0.0f;
        if( [[state objectForKey: @"ActionsPerformed"] intValue] > 0 ) {
            regenDelay = 1.5f;
        }
        [self performSelector: @selector(performProcedureWithState:) 
                   withObject: [NSDictionary dictionaryWithObjectsAndKeys: 
                                RegenProcedure,                   @"Procedure",
                                [NSNumber numberWithInt: 0],      @"CompletedRules", nil] 
                   afterDelay: regenDelay];
        return;
    }
    
    // if we did any regen, wait 30 seconds before re-evaluating the situation
    if([[state objectForKey: @"Procedure"] isEqualToString: RegenProcedure]) {
        if( [[state objectForKey: @"ActionsPerformed"] intValue] > 0 ) {
            [self performSelector: @selector(preRegen) withObject: nil afterDelay: 2.0];
        } else {
            // or if we didn't regen, go back to evaluate
            [self evaluateSituation];
        }
    }
    
    // if we did the Patrolling procdure, go back to evaluate
    if([[state objectForKey: @"Procedure"] isEqualToString: PatrollingProcedure]) {
        [self evaluateSituation];
    }
	
	// if we did the Healing procdure, go back to evaluate
    if([[state objectForKey: @"Procedure"] isEqualToString: HealingProcedure]) {
		 [self performSelector: @selector(evaluateSituation) withObject: nil afterDelay: 0.1];
	}
	// do it for combat too
    if([[state objectForKey: @"Procedure"] isEqualToString: CombatProcedure]) {
		[self evaluateSituation];
	}
}

- (void)performProcedureWithState: (NSDictionary*)state {
	log(LOG_FUNCTION, @"entering function");
	
    // if there's another procedure running, we gotta stop it
    if( self.procedureInProgress && ![self.procedureInProgress isEqualToString: [state objectForKey: @"Procedure"]]) {
        [self cancelCurrentProcedure];
        log(LOG_BEHAVIOR, @"Cancelling a previous procedure to begin %@.", [state objectForKey: @"Procedure"]);
    }
    
    if(![self procedureInProgress]) {
        [self setProcedureInProgress: [state objectForKey: @"Procedure"]];
        log(LOG_BEHAVIOR, @"Setting current procedure: %@", self.procedureInProgress);
        
        if ( [[self procedureInProgress] isEqualToString: CombatProcedure]) {
			NSArray *attackQueue = [combatController attackQueue];
			NSMutableArray *allUnits = [NSMutableArray array];
			[allUnits addObjectsFromArray:[combatController unitsAttackingMe]];
			for(Unit *unit in attackQueue){
				if ( ![allUnits containsObject:unit] ){
					[allUnits addObject:unit];
				}
			}
			
            int count =		[allUnits count];
            if(count == 1)  [controller setCurrentStatus: [NSString stringWithFormat: @"Bot: Player in Combat (%d unit)", count]];
            else            [controller setCurrentStatus: [NSString stringWithFormat: @"Bot: Player in Combat (%d units)", count]];
			
			log(LOG_BEHAVIOR, @"In Combat: (%d:%d)", [playerController isInCombat], [combatController inCombat]);
        } else {
            if( [[self procedureInProgress] isEqualToString: PreCombatProcedure])
                [controller setCurrentStatus: @"Bot: Pre-Combat Phase"];
            else if( [[self procedureInProgress] isEqualToString: PostCombatProcedure])
                [controller setCurrentStatus: @"Bot: Post-Combat Phase"];
            else if( [[self procedureInProgress] isEqualToString: RegenProcedure])
                [controller setCurrentStatus: @"Bot: Regen Phase"];
        }
    }
    
    Procedure *procedure = [self.theBehavior procedureForKey: [state objectForKey: @"Procedure"]];
    Unit *target = [state objectForKey: @"Target"];
    int completed = [[state objectForKey: @"CompletedRules"] intValue];
    int attempts = [[state objectForKey: @"RuleAttempts"] intValue];
    int actions = [[state objectForKey: @"ActionsPerformed"] intValue];
    
	// if we're healing - is our target still valid?
	if( [[self procedureInProgress] isEqualToString: HealingProcedure] && ![self unitValidToHeal:target] ){
		[self finishCurrentProcedure: state];
		return; 
	}
	
    // send your pet to attack
    if( [self.theBehavior usePet] && [playerController pet] && ![[playerController pet] isDead]) {
        if( [[self procedureInProgress] isEqualToString: PreCombatProcedure] || [[self procedureInProgress] isEqualToString: CombatProcedure] ) {
            if(![controller isWoWChatBoxOpen] && (_currentPetAttackHotkey >= 0)) {
                [chatController pressHotkey: _currentPetAttackHotkey withModifier: _currentPetAttackHotkeyModifier];
            }
        }
    }
    
    // have we completed all the rules?
    int ruleCount = [procedure ruleCount];
    if( !procedure || (completed >= ruleCount) ) {
        [self finishCurrentProcedure: state];
        return;
    }
    
    // delay our next rule until we can cast
    if( [playerController isCasting] ) {
        // try to be smart about how long we wait
        float delayTime = [playerController castTimeRemaining]/2.0f;
        if(delayTime < RULE_EVAL_DELAY_SHORT) delayTime = RULE_EVAL_DELAY_SHORT;
        log(LOG_COMBAT, @"Player casting. Waiting %.2f to perform next rule.", delayTime);
        
        [self performSelector: _cmd
                   withObject: state 
                   afterDelay: delayTime];
        return;
    }
	
	// We don't want to cast if our GCD is active!
	if ( [spellController isGCDActive] ){
        log(LOG_COMBAT, @"Waiting for global cooldown.");
		[self performSelector: _cmd
                   withObject: state 
                   afterDelay: 0.1];
		return;
	}

    // have we exceeded our maximum attempts on this rule?
    if(attempts > 3) {
        log(LOG_CONDITION, @"Exceeded maximum (3) attempts on action %d (%@). Skipping.", [[procedure ruleAtIndex: completed] actionID], [[spellController spellForID:[NSNumber numberWithInt:[[procedure ruleAtIndex: completed] actionID]]] name]);
        [self performSelector: _cmd
                   withObject: [NSDictionary dictionaryWithObjectsAndKeys: 
                                [state objectForKey: @"Procedure"],             @"Procedure",
                                [NSNumber numberWithInt: completed+1],          @"CompletedRules",
                                target,                                         @"Target",  nil] 
                   afterDelay: RULE_EVAL_DELAY_SHORT];
        return;
    }

    int i;
    for(i = completed; i< ruleCount; i++) {
		if(![self isBotting])
		{
			[self finishCurrentProcedure: state];
			return;
		}
        Rule *rule = [procedure ruleAtIndex: i];
		
		if( [[self procedureInProgress] isEqualToString: HealingProcedure])
		{
			if(![self unitValidToHeal:target])
			{
				[self finishCurrentProcedure: state];
				return; 
			}
		}
		if( [[self procedureInProgress] isEqualToString: CombatProcedure])
		{
			if(![target isValid] || [target isDead] || [target isEvading] || [blacklistController isBlacklisted:target])
			{
				log(LOG_COMBAT, @"STOP ATTACK: Invalid? (%d)  Dead? (%d)  Evading? (%d)  Blacklisted? (%d)", ![target isValid], [target isDead], [target isEvading], [blacklistController isBlacklisted:target]);
				[combatController finishUnit:target];
                [self finishCurrentProcedure: state];
				return;
			}
		}
		
		// if we're in a combat procedure, we may need to change our target!
		if ( [[self procedureInProgress] isEqualToString: CombatProcedure] ){
			
			// do something special? Search for an add to CC?
			if ( [rule target] == TargetAdd ){
				log(LOG_TARGET, @"Time to do something to an add! CC?");
			}
			
			// find someone to heal?
			else if ( [rule target] == TargetFriend ){
				log(LOG_TARGET, @"Lets heal someone! Maybe?");
				
			}
			/* wtf is this for?
			// set the attack unit assuming we shouldn't be doing something to ourself!
			else if ( [rule target] != TargetSelf && target != [playerController player] ){
				
				if ( target != [combatController attackUnit] )
					log(LOG_TARGET, @"Switching from target %@ to %@  (count: %d)", target, [combatController attackUnit], [target retainCount]);
				
				target = [combatController attackUnit];
				[[target retain] autorelease];
			}
			*/
			
		}

		log(LOG_RULE, @"Using target %@ for rule %@ RC:%d", target, rule, [target retainCount]);
		
        if( [self evaluateRule: rule withTarget: target asTest: NO] ) {
            if( [rule resultType] > 0) {
                int32_t actionID = [rule actionID];
                if(actionID > 0)
				{
                    BOOL canPerformAction = YES;
                    // if we are using an item or macro, apply a mask to the item number
                    switch([rule resultType]) {
                        case ActionType_Item: 
                            actionID = (USE_ITEM_MASK + actionID);
                            break;
                        case ActionType_Macro:
                            actionID = (USE_MACRO_MASK + actionID);
                            break;
                        case ActionType_Spell:
                            canPerformAction = ![spellController isSpellOnCooldown: actionID];
                            break;
                        default:
                            break;
                    }
                    int actionResult = 0;
                    // if we can cast the spell, do so
                    if(canPerformAction) {
                        
						if ( [rule target] == TargetSelf ){
							[playerController setPrimaryTarget: [playerController player]];
							log(LOG_TARGET, @"SELECTING %@ self for rule %@", [playerController player], rule);
						}
						else if ( target != nil ){
							[playerController setPrimaryTarget: target];
							log(LOG_TARGET, @"SELECTING %@ for rule %@", target, rule);
						}
						
						// Let the target change set in (generally this shouldn't be needed, but I've noticed sometimes the target doesn't switch)
						usleep([controller refreshDelay]);
						
						actionResult = [self performAction:actionID];
						if ( [rule resultType] == ActionType_Spell )
						{
							log(LOG_COMBAT, @"Cast %@", [[spellController spellForID:[NSNumber numberWithInt:actionID]] name]);
							//[spellController cooldownLeftForSpellID:actionID];
						}
						if ( actionResult == ErrSpellNotReady ){
							attempts = 3;
							log(LOG_COMBAT, @"Spell %@ isn't ready! Skipping any further attempts", [[spellController spellForID:[NSNumber numberWithInt:actionID]] name]);
						}
						else if ( actionResult == ErrInvalidTarget || actionResult == ErrTargetOutRange || actionResult == ErrTargetNotInLOS ){
							// Cancel, I don't want to keep attacking this target!
							log(LOG_COMBAT, @"Spell %@ didn't cast on target %@, !(blacklisting and moving on!)", [[spellController spellForID:[NSNumber numberWithInt:actionID]] name], target);
		
							//[self finishCurrentProcedure: state];
							//return;
						}
						else {
							//log(LOG_COMBAT, @"Spell %@ didn't cast on target %@ (%i)", [[spellController spellForID:[NSNumber numberWithInt:actionID]] name], target, actionResult);
						}
						if(actionResult != ErrNotFound && actionResult != ErrSpellNotReady && actionResult != ErrSpellNot_Ready)
						{
							//more multitasking //the world probably isn't ready for this much yet
							//log(LOG_COMBAT, @"Succesfully cast %@ on %@. Ending procedure", [[spellController spellForID:[NSNumber numberWithInt:actionID]] name], target);
							//[self finishCurrentProcedure: state]; //but I am
						}
                    }
	
                    //if( ([rule resultType] == ActionType_Item) || ([rule resultType] == ActionType_Macro) || ([spellController lastAttemptedActionID] == 0) || !canPerformAction )
					if(!actionResult)
					{
						attempts = 0;
                        if([rule resultType] == ActionType_Spell)
						{
                            if(canPerformAction)
							{
                                
                                // special rule for Vanish
                                if(([[self procedureInProgress] isEqualToString: CombatProcedure]) && 
                                   ([rule resultType] == ActionType_Spell) &&
                                   ([[[spellController spellForID: [NSNumber numberWithUnsignedInt: actionID]] name] isEqualToString: @"Vanish"]))
                                {
                                    log(LOG_BEHAVIOR, @"VANISH! Attemping to exit combat (cross your fingers).");
                                    [combatController cancelAllCombat];
                                    return; // bail out of here
                                }
                                
                                log(LOG_COMBAT, @"%@ cast after %d attempts.", [spellController spellForID: [NSNumber numberWithUnsignedInt: actionID]], attempts);

                            }
							else
							{
                                log(LOG_COMBAT, @"  %@ skipped for cooldown.", [spellController spellForID: [NSNumber numberWithUnsignedInt: actionID]] );
                            }
                        }
						else if([rule resultType] == ActionType_Item)
						{
                            log(LOG_COMBAT, @"Using %@.", [itemController itemForID: [NSNumber numberWithInt: [rule actionID]]]);
                        }
						else if([rule resultType] == ActionType_Macro)
						{
                            log(LOG_COMBAT, @"Running macro %d.", [rule actionID]);
                        }
						
                        
                        NSDictionary *newState = [NSDictionary dictionaryWithObjectsAndKeys: 
                                                  [state objectForKey: @"Procedure"],     @"Procedure",
                                                  [NSNumber numberWithInt: i+1],          @"CompletedRules",    // increment
                                                  [NSNumber numberWithInt: actions+1],    @"ActionsPerformed",  // increment
                                                  target,                                 @"Target",  nil];
                        
                        // shortcut end to skip the rule eval delay
                        //if( i+1 >= ruleCount) { [self finishCurrentProcedure: newState]; return; }
                        
						if([rule breakOnSuccess])
						{
							log(LOG_COMBAT, @"Succesfully cast %@ on %@ for %@. Ending procedure", [[spellController spellForID:[NSNumber numberWithInt:actionID]] name], target, rule);
							[self finishCurrentProcedure: state];
							return;
						}
						else
						{
							log(LOG_COMBAT, @"Succesfully cast %@ on %@ for %@. Continuing procedure", [[spellController spellForID:[NSNumber numberWithInt:actionID]] name], target, rule);
						}
                        [self performSelector: _cmd
                                   withObject: newState
                                   afterDelay: RULE_EVAL_DELAY_NORMAL];
					}
                }
            }
        }
		else
		{
            log(LOG_RULE, @"Rule %@ is FALSE.", rule);
        }
    }
    
    // we're done
    [self finishCurrentProcedure: state];
}

#pragma mark -
#pragma mark Loot Helpers

- (void)lootNode: (WoWObject*) unit{
	log(LOG_FUNCTION, @"entering function");
	
	// Loot if we're on the ground!
	if ( [playerController isOnGround] || [auraController unit:[playerController player] hasAura:40120]) //swift flight form
    {
        log(LOG_NODE, @"Looting node %@", unit);
		[self performSelector: @selector(lootUnit:) withObject: unit afterDelay:0.5f];	
	}
	
	// Try again shortly
	else {
        log(LOG_NODE, @"Can't loot %@ because we aren't on the ground. Retrying.", unit);
        [movementController dismount];
		[self performSelector: @selector(lootNode:) withObject: unit afterDelay:0.1f];	
	}
	
	// We should do a check to see if the player is casting after an attempted loot! if they're not we could keep trying!??
}


- (void)lootUnit: (WoWObject*) unit{
	log(LOG_FUNCTION, @"entering function");
    BOOL isNode = [unit isKindOfClass: [Node class]];
	
    if ( self.doLooting || isNode ) {
        Position *playerPosition = [playerController position];
        float distanceToUnit = [playerController isOnGround] ? [playerPosition distanceToPosition2D: [unit position]] : [playerPosition distanceToPosition: [unit position]];
		[movementController pauseMovement];
        [movementController turnTowardObject: unit];
		
		self.lastAttemptedUnitToLoot = unit;
		
        if([unit isValid] && (distanceToUnit <= 5.0)) { //  && (unitIsMob ? [(Mob*)unit isLootable] : YES)
            
			[controller setCurrentStatus: @"Bot: Looting"];
			log(LOG_LOOT, @"Looting : %@", unit);
			
			self.lootStartTime = [NSDate date];
			self.unitToLoot = unit;
			self.mobToSkin = (Mob*)unit;
			_lootAttempt++;
			
			// Lets do this instead of the loot hotkey!
			[self interactWithMouseoverGUID: [unit GUID]];
			
			// In the off chance that no items are actually looted
			[self performSelector: @selector(verifyLootSuccess) withObject: nil afterDelay: (isNode) ? 6.5f : 2.5f];
        } 
		else {
			log(LOG_LOOT, @"Unit not within 5 yards (%d) or is invalid (%d), unable to loot - removing %@ from list", [unit isValid], distanceToUnit <= 5.0, unit );
			
			// This will ensure we won't try to loot this node again - /cry
			if ( [self.unitToLoot isKindOfClass: [Node class]] ){
				[nodeController finishedNode: (Node*)self.unitToLoot];
			}
			else{
				[_mobsToLoot removeObject: self.unitToLoot];
			}
			
			// Not 100% sure why we need this, but it seems important?
			[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(reachedUnit:) object: self.unitToLoot];
			
			[self performSelector: @selector(evaluateSituation) withObject: nil afterDelay: 0.1f];	
        }
    }
}

// Sometimes there isn't an item to loot!  So we'll use this to fire off the notification
- (void)verifyLootSuccess{
	log(LOG_FUNCTION, @"entering function");
	
	// Check if the player is casting still (herbalism/mining/skinning)
	if ( [playerController isCasting] ){
		[self performSelector: @selector(verifyLootSuccess) withObject: nil afterDelay: 1.0f];
		
		return;
	}
	
	// Is the loot window stuck being open?
	if ( [lootController isLootWindowOpen] ){
		log(LOG_LOOT, @"Loot window open? ZOMG lets close it!");
		
		[lootController acceptLoot];
		[self performSelector: @selector(verifyLootSuccess) withObject: nil afterDelay: 1.0f];
		
		return;
	}
	
	// Check for loot window open?
	
	// Just fire off the notification that never went off!
	log(LOG_LOOT, @"Firing off itemsLooted");
	[[NSNotificationCenter defaultCenter] postNotificationName: AllItemsLootedNotification object: [NSNumber numberWithInt:0]];
}

// This is called when all items have actually been looted (the loot window will NOT be open at this point)
- (void)itemsLooted: (NSNotification*)notification {
	log(LOG_FUNCTION, @"entering function");
	
	if ( !self.isBotting )
		return;
	
	// If this event fired, we don't need to verifyLootSuccess! We ONLY need verifyLootSuccess when a body has nothing to loot!
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(verifyLootSuccess) object: nil];
	
	// This lets us know that the LAST loot was just from us looting a corpse (vs. via skinning or herbalism)
	if ( self.unitToLoot ){
		NSDate *currentTime = [NSDate date];
		
		// Unit was looted, remove from list!
		if ([self.unitToLoot isKindOfClass: [Node class]])
		{
			[nodeController finishedNode: (Node*)self.unitToLoot];
			self.mobToSkin = nil;
			log(LOG_LOOT, @"Node looted in %0.2f seconds after %d attempt%@", [currentTime timeIntervalSinceDate: self.lootStartTime], _lootAttempt, _lootAttempt == 1 ? @"" : @"s");
		}
		else
		{
			[_mobsToLoot removeObject: self.unitToLoot];
			log(LOG_LOOT, @"Mob looted in %0.2f seconds after %d attempt%@. %d mobs to loot remain", [currentTime timeIntervalSinceDate: self.lootStartTime], _lootAttempt, _lootAttempt == 1 ? @"" : @"s", [_mobsToLoot count]);
		}
		_lootAttempt = 0;
		// Not 100% sure why we need this, but it seems important?
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(reachedUnit:) object: self.unitToLoot];
	}
	// Here from skinning!
	else if ( self.mobToSkin ){
		NSDate *currentTime = [NSDate date];
		log(LOG_LOOT, @"Skinning completed in %0.2f seconds", [currentTime timeIntervalSinceDate: self.skinStartTime]);
		self.mobToSkin = nil;
	}
	
	// Lets skin the mob, or we're done!
	[self skinOrFinish];
	
	// No longer need this unit!
	[blacklistController blacklistObject:self.unitToLoot];
	[_mobsToLoot removeObject:self.unitToLoot];
	self.unitToLoot = nil;
}

- (void)skinOrFinish{
	log(LOG_FUNCTION, @"entering function");
	
	if ( [fishController isFishing] )
		return;
	
	BOOL canSkin = NO;
	BOOL unitIsMob = ([self.mobToSkin isKindOfClass: [Mob class]] && [self.mobToSkin isNPC]);
	
	// Should we be skinning?
	if ( ( _doSkinning || _doHerbalism ) && self.mobToSkin && unitIsMob ){
		
		// Up to skinning 100, you can find out the highest level mob you can skin by: ((Skinning skill)/10)+10.
		// From skinning level 100 and up the formula is simply: (Skinning skill)/5.
		int canSkinUpToLevel = 0;
		if(_skinLevel <= 100) {
			canSkinUpToLevel = (_skinLevel/10)+10;
		} else {
			canSkinUpToLevel = (_skinLevel/5);
		}
		
		if ( _doSkinning || _doHerbalism ) {
			if ( canSkinUpToLevel >= [self.mobToSkin level] ) {
				
				_skinAttempt = 0;
				
				[self skinMob:self.mobToSkin];
				
				canSkin = YES;
			} 
			else {
				log(LOG_LOOT, @"The mob is above your max %@ level (%d).", ((_doSkinning) ? @"skinning" : @"herbalism"), canSkinUpToLevel);
			}
		}
	}
	
	// We're done looting+skinning!
	if ( !canSkin ){
		NSDate *currentTime = [NSDate date];
		log(LOG_LOOT, @"All looting completed in %0.2f seconds", [currentTime timeIntervalSinceDate: self.lootStartTime]);
		
		// Reset our attempt variables!
		_lootAttempt = 0;
		self.lastAttemptedUnitToLoot = nil;
		
		// Mount?  Or just evaluate
		//[self performSelector: @selector(evaluateSituation) withObject: nil afterDelay: (([self mountNow]) ? 2.0f : 0.1f)];
		[self evaluateSituation];
	}
}

// It actually takes 1.2 - 2.0 seconds for [mob isSkinnable] to change to the correct status, this makes me very sad as a human, seconds wasted!
- (void)skinMob: (Mob*)mob {
	log(LOG_FUNCTION, @"entering function");
    float distanceToUnit = [[playerController position] distanceToPosition2D: [mob position]];
	 
	// We tried for 2.0 seconds, lets bail
	if ( _skinAttempt++ > 20 ){
		log(LOG_LOOT, @"Mob is not valid (%d), not skinnable (%d) or is too far away (%d)", ![mob isValid], ![mob isSkinnable], distanceToUnit > 5.0f );
		self.mobToSkin = nil;
		//[movementController finishMovingToObject: (Unit*)mob];
		
		[self performSelector: @selector(evaluateSituation) withObject: nil afterDelay: 0.1];
		
		return;
	}
	
	// Set to null so our loot notifier realizes we shouldn't try to skin again :P
	self.mobToSkin = nil;
	self.skinStartTime = [NSDate date];
	
	// Not able to skin :/
	if( ![mob isValid] || ![mob isSkinnable] || distanceToUnit > 5.0f ) {
		
		[self performSelector: @selector(skinMob:) withObject:mob afterDelay:0.1f];
        return;
    } 
	
	[controller setCurrentStatus: @"Bot: Skinning"];
	
	log(LOG_LOOT, @"Skinning!");
	
	// Lets interact w/the mob!
	[self interactWithMouseoverGUID: [mob GUID]];
	[self performSelector: @selector(verifyLootSuccess) withObject: nil afterDelay: 4.0f];
}

#pragma mark -
#pragma mark [Input] CombatController

// This method is pure notification.  It's up to EvaluateSituation or an incomming AddingUnit to initiate any attacking.
- (void)playerEnteringCombat {
	log(LOG_FUNCTION, @"entering function");
    // if we're not even botting, bail
    if(![self isBotting]) return;
    
    [controller setCurrentStatus: @"Bot: Player in Combat"];
    
    [self evaluateSituation];
}

- (void)playerLeavingCombat {
	log(LOG_FUNCTION, @"entering function");
    // if we're not even botting, bail
    if(![self isBotting]) return;

    self.didPreCombatProcedure = NO;
	usleep(100000);
	log(LOG_BEHAVIOR, @"Player is dead:%d  Real in combat:%d", [playerController isDead], [playerController isInCombat]);
	
    if ( ![playerController isDead] ) {
        
        if( ![[combatController attackQueue] count] ) {
			
            // we're probably still in the middle of a combat procedure
            if(self.procedureInProgress)        // so let's cancel it
                [self cancelCurrentProcedure];
			
            if(self.theRoute) [movementController pauseMovement];
			[movementController resetUnit];
			//[movementController resumeMovement];	// If we call this we will trigger eval situation, we don't want to yet!
            
            BOOL vanished = [auraController unit: [playerController player] hasBuffNamed: @"Vanish"];
            
            // start post-combat after specified delay
            [self performSelector: @selector(performProcedureWithState:) 
                       withObject: [NSDictionary dictionaryWithObjectsAndKeys: 
                                    PostCombatProcedure,              @"Procedure",
                                    [NSNumber numberWithInt: 0],      @"CompletedRules", nil] 
                       afterDelay: (vanished ? 5.0 : 0.1)];
            return;
        } else {
			log(LOG_BEHAVIOR, @"We are out of combat, but there are more units in the attack queue:%d", [[combatController attackQueue] count]);
            [self evaluateSituation];
        }
    }
}

#pragma mark Healing

- (BOOL)unitValidToHeal: (Unit*)unit{
	log(LOG_FUNCTION, @"entering function");
	Position *playerPosition = [playerController position];
	
	if ( [playerPosition distanceToPosition: [unit position]] < [theCombatProfile healingRange] && ![unit isDead] && [unit currentHealth] != 1 && [playerController isFriendlyWithFaction: [unit factionTemplate]] && [unit percentHealth] < [theCombatProfile healthThreshold]){
		return YES;
	}
	
	return NO;
}

- (void)healUnit: (Unit*)unit{
	log(LOG_FUNCTION, @"entering function");
	if(![self isBotting]) return;
    
    if( ![[self procedureInProgress] isEqualToString: HealingProcedure] ) {
		log(LOG_HEAL, @"Healing %@ %d", unit, [unit lowGUID]);
		
        // stop other procedures
        [self cancelCurrentProcedure];
		[combatController setAttackUnit:unit];
        // start the healing procedure
        [self performProcedureWithState: [NSDictionary dictionaryWithObjectsAndKeys: 
                                          HealingProcedure,                 @"Procedure",
                                          [NSNumber numberWithInt: 0],      @"CompletedRules",
                                          unit,                             @"Target", nil]];
	}
}

- (NSArray*)availableUnitsToHeal{
	log(LOG_FUNCTION, @"entering function");
	
	// get list of all targets
    NSMutableArray *targetsWithinRange = [NSMutableArray array];
	NSMutableArray *targetsToHeal = [NSMutableArray array];
	[targetsWithinRange addObject: [playerController player]];
	[targetsWithinRange addObjectsFromArray: [playersController allPlayers]];
	
	// sort by range
    Position *playerPosition = [playerController position];
    [targetsWithinRange sortUsingFunction: DistanceFromPositionCompare context: playerPosition];
	
    if ( [targetsWithinRange count] ) {
        for ( Unit *unit in targetsWithinRange ) {
			//log(LOG_HEAL, @"Checking %@", unit);
			if ( [self unitValidToHeal:unit] ){
				//log(LOG_HEAL, @"Valid: %@ %d %d", unit, [unit percentHealth], [theCombatProfile healthThreshold] );
				if ( [unit percentHealth] < [theCombatProfile healthThreshold] ){
					log(LOG_HEAL, @"Need to heal: %@ (%d%% < %d%%)", unit, [unit percentHealth], [theCombatProfile healthThreshold] );
					[targetsToHeal addObject: unit];
				}
			}
        }
    }
	
	return targetsToHeal;
}

- (Unit*)unitToHeal{
	log(LOG_FUNCTION, @"entering function");
	// Find one nearby to heal (lowest health target)!
	Unit *lowestHealthTarget = nil;
	UInt32 lowestHealth = 10000000;
        for ( Unit *unit in [self availableUnitsToHeal] ) {
			if ( [self unitValidToHeal:unit] ){
				if ( [unit percentHealth] < [theCombatProfile healthThreshold] && [unit currentHealth] < lowestHealth ){
					
					// TO DO: Check to see if the last spell cast failed on the below target we are returning (LOS?)  _lastUnitAttemptedToHealed
					lowestHealthTarget = unit;
					lowestHealth = [unit currentHealth];
				}
			}
        }
    
    return lowestHealthTarget;
}

#pragma mark Combat

- (void)attackUnit: (Unit*)unit {
	log(LOG_FUNCTION, @"entering function");
    if(![self isBotting]) return;
	
	if ( [blacklistController isBlacklisted:unit] ){
		log(LOG_ERROR, @"Attempted to attack a blacklisted unit. Aborting.");
        return;
	}
	
	if(![unit isValid] || [unit isDead] || [unit isEvading] || [blacklistController isBlacklisted:unit])
	{
		log(LOG_COMBAT, @"STOP ATTACK: Invalid? (%d)  Dead? (%d)  Evading? (%d)  Blacklisted? (%d)", ![unit isValid], [unit isDead], [unit isEvading], [blacklistController isBlacklisted:unit]);
		[combatController finishUnit:unit];
		return;
	}
	if ([playerController isDead])
	{
		log(LOG_COMBAT, @"You died, stopping attack.");
		return;
	}
    
    BOOL isCasting = [playerController isCasting];
    
    // check player facing vs. unit position
    float playerDirection = [playerController directionFacing];
    float theAngle = [[playerController position] angleTo: [unit position]];
    
    // compensate for the 2pi --> 0 crossover
    if(fabsf(theAngle - playerDirection) > M_PI) {
        if(theAngle < playerDirection)  theAngle        += (M_PI*2);
        else                            playerDirection += (M_PI*2);
    }
    
    // find the difference between the angles
    float angleTo = fabsf(theAngle - playerDirection);
    
    // if the difference is more than 90 degrees (pi/2) M_PI_2, reposition
    if( (angleTo > 0.261f) ) {  // changed to be ~15 degrees
        log(LOG_COMBAT, @"Unit is behind us (%.2f). Repositioning.", angleTo);
        
        // set player facing and establish position
        BOOL useSmooth = [movementController useSmoothTurning];
        
        if(!isCasting) [movementController pauseMovement];
        [movementController turnTowardObject: unit];
        if(!isCasting && !useSmooth) {
            [movementController backEstablishPosition];
        }
    }
	
    if( !isCasting ) {
        // ensure unit is our target
        UInt64 unitUID = [unit GUID];
        if ( ( [playerController targetID] != unitUID) || [unit isFeignDeath] ) {
			Position *playerPosition = [playerController position];
			log(LOG_COMBAT, @"SELECTING %@  Weight: %d", unit, [combatController unitWeight:unit PlayerPosition:playerPosition] );
            
            [playerController setPrimaryTarget: unit];
            usleep([controller refreshDelay]);
        }
    }
	
    if( ![[self procedureInProgress] isEqualToString: CombatProcedure] )
	{
		if(!self.didPreCombatProcedure)
		{
			log(LOG_COMBAT, @"Starting precombat procedure (current: %@) for target %@", [self procedureInProgress], unit);
			self.didPreCombatProcedure = YES;
			[self performProcedureWithState: [NSDictionary dictionaryWithObjectsAndKeys: 
											  PreCombatProcedure,               @"Procedure",
											  [NSNumber numberWithInt: 0],      @"CompletedRules",
											  unit,                     @"Target",  nil]];
			
			return;
		}
        log(LOG_COMBAT, @"Starting combat procedure (current: %@) for target %@", [self procedureInProgress], unit);
        // stop and attack
        [self cancelCurrentProcedure];
        
        // check to see if we are supposed to be in melee range
        if( self.theBehavior.meleeCombat) {
			//log(LOG_MOVEMENT, @"Should be in melee range!");
			
            // see if we are moving to this unit already
            if( ![[movementController moveToObject] isEqualToObject: unit]) {
                float distance = [[playerController position] distanceToPosition2D: [unit position]];
                
                if( distance > 5.0f) {
                    // if we are more than 5 yards away, move to this unit
                    log(LOG_MOVEMENT, @"Melee range required; moving to %@ at %.2f yards", unit, distance);
                    [movementController moveToObject: unit andNotify: YES];
                } else  {
                    // if we are in melee range, stop
					log(LOG_MOVEMENT, @"In melee range!");
                    [movementController pauseMovement];
                }
            } else {
                log(LOG_MOVEMENT, @"Already moving to %@", unit);
                // if we are already moving to the unit, make sure we keep going
                [movementController resumeMovement];
            }
        } else {
			//log(LOG_MOVEMENT, @"Don't need to be in melee!");
            // if we don't need to be in melee, pause
            [movementController pauseMovement];
        }
        
        // start the combat procedure
		[combatController setAttackUnit:unit];

        [self performProcedureWithState: [NSDictionary dictionaryWithObjectsAndKeys: 
                                          CombatProcedure,                  @"Procedure",
                                          [NSNumber numberWithInt: 0],      @"CompletedRules",
                                          unit,                             @"Target", nil]];
    } else {
        // we are currently executing the combat routine;
        // do nothing
		
		//PGLog(@"[Bot] could we be moving toward the target here?");
    }
}

- (void)addLootMob: (Unit*)unit {
	if(([(Mob*)unit isSkinnable] || [(Mob*)unit isLootable]) && [[[playerController player] position] distanceToPosition: [unit position]] <= [theCombatProfile attackRange]) {
		if ([_mobsToLoot containsObject: unit])
		{
			[_mobsToLoot removeObject:unit];
			[_mobsToLoot addObject:unit];
		}
		else
		{
			log(LOG_LOOT, @"Adding discovered mob %@ to loot queue.", unit);
			[_mobsToLoot addObject:unit];
		}
	}
	else{
		//PGLog(@"[Loot] Discovered mob %@ isn't lootable, ignoring", unit);
	}
}

- (void)finishUnit: (Unit*)unit wasInAttackQueue: (BOOL)wasInQueue {
	log(LOG_FUNCTION, @"entering function");
	[self evaluateSituation];
	return;
	/*
    // we only need to loot this if it's a mob and if was one we were directed to attack
    if( [unit isNPC] ) {
        if(wasInQueue) {
            if([movementController moveToObject] == unit) {
                log(LOG_MOVEMENT, @"finishUnit says stop moving to this unit.");
                [movementController finishMovingToObject: unit];
            }
            
            if([unit isDead]) {
                if(self.doLooting) {
                    // make sure this mob is even lootable
                    // sometimes the mob isn't marked as 'lootable' yet because it hasn't fully died (death animation or whatever)
                    usleep(500000);
                    if([(Mob*)unit isTappedByMe] || [(Mob*)unit isLootable]) {
                        if ([_mobsToLoot containsObject: unit]) {
                            log(LOG_LOOT, @"%@ was already in the loot list, removing first", unit);
                            [_mobsToLoot removeObject: unit];
                        }
                        log(LOG_LOOT, @"Adding %@ to loot list.", unit);
                        [_mobsToLoot addObject: (Mob*)unit];
                    }
					else{
						log(LOG_LOOT, @"Mob %@ isn't lootable, ignoring", unit);
					}
                }
            }
			else
			{
				log(LOG_LOOT, @"Unit %@ finished, but not dead! Health: %d", unit, [unit currentHealth]);
				[self evaluateSituation];
			}
            
            // if we're in the middle of a combat procedure, end it
            if([[self procedureInProgress] isEqualToString: CombatProcedure])
                [self cancelCurrentProcedure];
        }
        return;
    }
    
    if( [unit isPlayer] ) {
        [self evaluateSituation];
    }
    */
    // if we are not in combat, then an attack attempt went bust
    // --> this is disabled because the OOC notification is now being used to trigger the next action
    //if(![[combatController attackQueue] count]) {
    //    [self evaluateSituation];
    //}
}

/*
- (void)lootNodeWhenOnGround: (WoWObject*)unit{
	
	PGLog(@"[Bot] Movement flags 0x%x %d", [playerController movementFlags], [playerController movementFlags] & 0x0);
	
	// Is our player on the ground?
	if ( ( [playerController movementFlags] & 0x0 ) == 0x0 ){
		[self lootUnit: unit];
		return;
	}
	
	// Wait for fall time!
	[self performSelector: @selector(lootNodeWhenOnGround:) withObject: unit afterDelay:0.1f];
}*/

#pragma mark -
#pragma mark [Input] MovementController

- (void)reachedUnit: (WoWObject*)unit {
	log(LOG_FUNCTION, @"entering function");
    
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: _cmd object: unit];
    [movementController pauseMovement];
	
    // if it's a player, or a non-dead NPC, we must be doing melee combat
    if( [unit isPlayer] || ([unit isNPC] && ![(Unit*)unit isDead])) {
        log(LOG_MOVEMENT, @"Reached melee range with %@", unit);
        return;
    }
	
	// If it's a node, we'll need to dismount (in case we are flying) - then we need to have a delay (for fall time)
	if ( [unit isKindOfClass: [Node class]] && [[playerController player] isMounted] ){
		
		// In case we didn't stop? Sometimes this happens, it makes me a sad panda
		[movementController pauseMovement];
		
		Position *playerPosition = [playerController position];
		float distance = [playerPosition distanceToPosition: [unit position]];
		float distance2D = [playerPosition distanceToPosition2D: [unit position]];
		float vertDist = [playerPosition verticalDistanceToPosition:[unit position]];

		
		log(LOG_MOVEMENT, @"3D:%0.2f   2D:%0.2f   Vertical:%0.2f", distance, distance2D, vertDist);
		
        //we shouldn't need to recheck our position if we're already in reachedUnit
		// Get off our mount (this could be called if our movement failed, we don't want to get off our mount!)!
		//if ( distance <= NODE_DISTANCE_UNTIL_DISMOUNT){
        if(![auraController unit:[playerController player] hasAura:40120]) //swift flight form
            [movementController dismount];
		[self lootNode: unit];
		//}
		//else{
		//	// This node is "done" - this is a sort of blacklist, we just don't want it anymore!
		//	[nodeController finishedNode: (Node*)self.unitToLoot];
		//
		//	// Resume movement!
		//	[movementController resumeMovementToNearestWaypoint];
		//}
		

		//[self performSelector: @selector(lootUnit:) withObject: unit afterDelay:2.5f];
	}
	else{
		[self lootUnit: unit];
	}
}

- (void)finishedRoute: (Route*)route {
	log(LOG_FUNCTION, @"entering function");
    if( ![self isBotting]) return;
    
    if(self.theRoute) {
        if(route == [self.theRoute routeForKey: CorpseRunRoute]) {
            log(LOG_GENERAL, @"Finished Corpse Run. Begin search for body...");
            [controller setCurrentStatus: @"Bot: Searching for body..."];
            [movementController setPatrolRoute: [self.theRoute routeForKey: PrimaryRoute]];
            [movementController beginPatrol: 1 andAttack: NO];
        } else {
            log(LOG_GENERAL, @"Finished something else...");
        }
	}
}

- (BOOL)shouldProceedFromWaypoint: (Waypoint*)waypoint {
	log(LOG_FUNCTION, @"entering function");
    if( ![self isBotting]) return YES;
    if( [playerController isDead]) return YES;
    
    // see if we would be performing anything in the patrol procedure
    BOOL performPatrolProc = NO;
    for(Rule* rule in [[self.theBehavior procedureForKey: PatrollingProcedure] rules]) {
        if( ([rule resultType] != ActionType_None) && ([rule actionID] > 0) && [self evaluateRule: rule withTarget: nil asTest: NO] ) {
            performPatrolProc = YES;
            break;
        }
    }
    
    // check if all used abilities are instant
    BOOL needToPause = NO;
    for(Rule* rule in [[self.theBehavior procedureForKey: PatrollingProcedure] rules]) {

        if( ([rule resultType] == ActionType_Spell)) {
            Spell *spell = [spellController spellForID: [NSNumber numberWithUnsignedInt: [rule actionID]]];
            if([spell isInstant]) {
                continue;
            }
        }
        
        if([rule resultType] == ActionType_None) continue;
        
        needToPause = YES; 
        break;
    }
    
    // if we are, pause movement and perform it.
    if(performPatrolProc) {
        if(needToPause)  log(LOG_BEHAVIOR, @"Pausing to perform Patrol Procedure.");
        if(!needToPause) log(LOG_BEHAVIOR, @"NOT pausing to perform Patrol Procedure.");
        
        // only pause if we are performing something non instant
        if(needToPause) [movementController pauseMovement];

        [self performSelector: @selector(performProcedureWithState:) 
                   withObject: [NSDictionary dictionaryWithObjectsAndKeys: 
                                PatrollingProcedure,              @"Procedure",
                                [NSNumber numberWithInt: 0],      @"CompletedRules", nil] 
                   afterDelay: (needToPause ? 0.25 : 0.0)];
        
        if(needToPause)  return NO;
    }
    return YES;
}

#pragma mark -

- (void)preRegen {
	log(LOG_FUNCTION, @"entering function");
    BOOL drink = NO, eat = NO;
    Unit *player = [playerController player];
    if([auraController unit: player hasBuffNamed: @"Drink"]) {
        drink = YES;
        log(LOG_BEHAVIOR, @"[Regen] Player started drinking.");
    }
    if([auraController unit: player hasBuffNamed: @"Food"]) {
        eat = YES;
        log(LOG_BEHAVIOR, @"[Regen] Player started eating.");
    }
    NSDictionary *regenDict = [NSDictionary dictionaryWithObjectsAndKeys: 
                               [NSDate date],                       @"RegenStart",
                               [NSNumber numberWithBool: eat],      @"WatchHealth",
                               [NSNumber numberWithBool: drink],    @"WatchMana",
                               nil];
    
    [self evaluateRegen: regenDict];
}

- (void)evaluateRegen: (NSDictionary*)regenDict {
	log(LOG_FUNCTION, @"entering function");
    NSDate *start = [regenDict objectForKey: @"RegenStart"];
    BOOL health   = [[regenDict objectForKey: @"WatchHealth"] boolValue];
    BOOL mana     = [[regenDict objectForKey: @"WatchMana"] boolValue];
    
    if(!health && !mana) {
        float sinceStart = [[NSDate date] timeIntervalSinceDate: start];
        [self performSelector: @selector(evaluateSituation) withObject: nil afterDelay: (28.0f - sinceStart)]; // since we spend 2 seconds in pre-regen
        return;
    }

    Unit *player = [playerController player];
    
    // check health
    if( health && ([playerController health] == [playerController maxHealth]))
        health = NO;
    if( health && (![auraController unit: player hasBuffNamed: @"Food"]))
        health = NO;
    
    if( mana && ([playerController mana] == [playerController maxMana]))
        mana = NO;
    if( mana && (![auraController unit: player hasBuffNamed: @"Drink"]))
        mana = NO;
    
    if(!health && !mana) {
        // we're done here
        log(LOG_BEHAVIOR, @"[Regen] Finished early after %.2f seconds!", [[NSDate date] timeIntervalSinceDate: start]);
        if([playerController isSitting] && ![controller isWoWChatBoxOpen]) {
            [chatController jump];
        }
        [self performSelector: @selector(evaluateSituation) withObject: nil afterDelay: 1.0f];
        return;
    }
    
    // check to see if we've already spent 30 seconds (2 in pre-regen)
    if([[NSDate date] timeIntervalSinceDate: start] >= 28.0f) {
        [self evaluateSituation];
        return;
    }
    
    [self performSelector: _cmd withObject: regenDict afterDelay: 2.0f];
}

- (Mob*)mobToLoot {
	log(LOG_FUNCTION, @"entering function");
	
	NSArray *mobs = [mobController allMobs];
	for ( Mob *mob in mobs )
	{
		[self addLootMob: mob];
	}
	
    if([_mobsToLoot count])
	{
        Mob *mobToLoot = nil;
        		
        // sort the loot list by distance
        [_mobsToLoot sortUsingFunction: DistanceFromPositionCompare context: [playerController position]];
        
        // find a valid mob to loot
        for(mobToLoot in _mobsToLoot) {
            if(mobToLoot && [mobToLoot isValid] && ![blacklistController isBlacklisted:mobToLoot] && [[mobToLoot position] distanceToPosition: [playerController position]] < [theCombatProfile attackRange] && ([mobToLoot isLootable] || ([mobToLoot isSkinnable] && _doSkinning)))
			{
                log(LOG_LOOT, @"Selected a mob to loot: %@", mobToLoot);
                return mobToLoot;
            }
        }
    }
    
    return nil;
}

- (BOOL)isUnitValidToAttack: (Unit*)unit fromPosition: (Position*)position ignoreDistance: (BOOL)ignoreDistance {
	log(LOG_FUNCTION, @"entering function");
    
    float vertOffset = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"CombatBlacklistVerticalOffset"] floatValue];
    
    // unit fits the combat profile
    // unit is within the vertical offset
    // unit is not blacklisted
    if(   ([self.theCombatProfile unitFitsProfile: unit ignoreDistance: ignoreDistance])
       && ([[unit position] verticalDistanceToPosition: position] <= vertOffset)  
       && (![blacklistController isBlacklisted:unit]) ) {
        return YES;
    }
    return NO;
}

- (Unit*)unitToAttack {
	log(LOG_FUNCTION, @"entering function");
    // scan for new, valid, in-range targets to attack
	if(!self.theCombatProfile.combatEnabled)
        return nil;
    
	NSMutableArray *knownUnits = [NSMutableArray array];
	[knownUnits addObjectsFromArray:[combatController unitsAttackingMe]];
	for ( Unit *unit in [combatController attackQueue] ){
		if ( ![knownUnits containsObject:unit] )
		{
			log(LOG_TARGET, @"Adding %@ known unit", unit);
			[knownUnits addObject:unit];
		}
	}
    
    
    // get list of all targets
    NSMutableArray *targetsWithinRange = [NSMutableArray array];
    NSRange levelRange;
    if([theCombatProfile attackAnyLevel])
    {
        levelRange.location = [theCombatProfile ignoreLevelOne] ? 2 : 1;
        levelRange.length = 90 - levelRange.location;
    }
    else
    {
        levelRange.location = [theCombatProfile attackLevelMin];
        levelRange.length = [theCombatProfile attackLevelMax] - levelRange.location;
    }

    if(self.theCombatProfile.attackNeutralNPCs || self.theCombatProfile.attackHostileNPCs) {
        [targetsWithinRange addObjectsFromArray:[mobController mobsWithinDistance:[theCombatProfile attackRange] levelRange:levelRange includeElite:![theCombatProfile ignoreElite] includeFriendly:NO includeNeutral:[theCombatProfile attackNeutralNPCs] includeHostile:[theCombatProfile attackHostileNPCs]]];
    }
    if(self.theCombatProfile.attackPlayers) {
        [targetsWithinRange addObjectsFromArray: [playersController allPlayers]];
    }
    
    // sort by range
    Position *playerPosition = [playerController position];
    [targetsWithinRange sortUsingFunction: DistanceFromPositionCompare context: playerPosition];
    
    // if we have mobs in range
    if([targetsWithinRange count] || [self.preCombatUnit isValid]) {
        Unit *unit = self.preCombatUnit;
        for(unit in targetsWithinRange)
		{
            if([self isUnitValidToAttack: unit fromPosition: playerPosition ignoreDistance: NO] && ![knownUnits containsObject:unit])
			{
				log(LOG_TARGET, @"Found unit %@ to attack.", unit);
				return unit;
			}
			if([knownUnits containsObject:unit])
			{
				log(LOG_TARGET, @"Skipping unit %@ already known.", unit);
			}
        }
    }
    
    return nil;
}

- (BOOL)evaluateSituation {
	log(LOG_FUNCTION, @"entering function");
    if(![self isBotting])						return NO;
    if(![playerController playerIsValid:self])  return NO;
	
	//PGLog(@"[Bot] Evaluate Situation");
    
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: _cmd object: nil];
	
	// Check for preparation buff
	if ( self.isPvPing && [pvpWaitForPreparationBuff state] && [auraController unit: [playerController player] hasAura: PreparationSpellID] ){
		
		[controller setCurrentStatus: @"PvP: Waiting for preparation buff to fade..."];
		[movementController pauseMovement];
	
		[self performSelector: _cmd withObject: nil afterDelay: 1.0f];
		
		return YES;
	}
	
	// wait for boat to settle!
	if ( self.isPvPing && _strandDelay ){
		[controller setCurrentStatus: @"PvP: Waiting for boat to arrive..."];
		[movementController pauseMovement];
		
		[self performSelector: _cmd withObject: nil afterDelay: 1.0f];
		
		return YES;
	}
	
	// walk off boat
	if ( self.isPvPing && [playerController zone] == 4384 && [playerController isOnBoatInStrand] ){
		[controller setCurrentStatus: @"PvP: Walking off the boat..."];
		
		BOOL onLeftBoat = [playerController isOnLeftBoatInStrand];
		Position *pos = nil;
		
		if ( onLeftBoat ){
			log(LOG_PVP, @"Moving off of left boat!");
			pos = [Position positionWithX:1609.5f Y:49.6f Z:7.6f];
			pos = [Position positionWithX:6.23f Y:20.94f Z:4.97f];
			
		}
		else{
			log(LOG_PVP, @"Moving off of right boat!");
			pos = [Position positionWithX:1597.2f Y:-101.4f Z:8.9f];
			pos = [Position positionWithX:5.88f Y:-25.1f Z:5.3f];
		}
		
		// start moving
		[movementController setClickToMove:pos andType:ctmWalkTo andGUID:0x0];

		[self performSelector: _cmd withObject: nil afterDelay: 0.5f];
		
		return YES;
	}
    
    Position *playerPosition = [playerController position];
    //float vertOffset = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"CombatBlacklistVerticalOffset"] floatValue];
    
    // Order of Operations
    // 1) If we are dead, check to see if we can resurrect.
	// 2) If healing is on, check to heal or follow a player
    // 3) If we are moving to melee range, return.
    // 4) If we are in combat but not already attacking, scan for mobs to attack.
    // ---- Not in Combat after here ----
    // 5) Check for bodies to loot, loot if necessary.
    // 6) Scan for valid target in range, attack if found.
    // 7) Check for nodes to harvest, harvest if necessary.
    // 8) Resume movement if needed, nothing else to do.
        
    // if the player is a Ghost...
    if( [playerController isGhost]) {
		
        if( [playerController corpsePosition] && [playerPosition distanceToPosition: [playerController corpsePosition]] < 26.0 ) {
            // we found our corpse
            [controller setCurrentStatus: @"Bot: Waiting to Resurrect"];
            [movementController pauseMovement];
            
            // set our next-revive wait timer
            if(!_reviveAttempt) _reviveAttempt = 1;
            else _reviveAttempt = _reviveAttempt*2;
            
            [macroController useMacroOrSendCmd:@"Resurrect"];    // get corpse
			
			if ( _reviveAttempt > 15 ){
				_reviveAttempt = 15;
			}
            
            log(LOG_GENERAL, @"Waiting %d seconds to resurrect.", _reviveAttempt);
            [self performSelector: _cmd withObject: nil afterDelay: _reviveAttempt];
            return YES;
        }
        return NO;
    }
	
	// Is the player air mounted, and on the ground?  Me no likely - lets jump!
	//if ( [self.theRoute routeForKey: PrimaryRoute].isFlyingRoute || [self.theRoute routeForKey: CorpseRunRoute].isFlyingRoute ){
		UInt32 movementFlags = [playerController movementFlags];
		if ( (movementFlags & 0x1000000) == 0x1000000 && (movementFlags & 0x3000000) != 0x3000000 ){
			if ( _jumpAttempt == 0 && ![controller isWoWChatBoxOpen] ){
				usleep(200000);
				log(LOG_MOVEMENT, @"Player flying on ground, jumping!");
				[chatController jump];
				usleep(10000);
			}
			
			if ( _jumpAttempt++ > 3 )	_jumpAttempt = 0;
			log(LOG_MOVEMENT, @"Jump skip number: %d", _jumpAttempt);
		}
	//}
	
	//check for someone to follow, otherwise move along
	Unit *followUnit = nil;
	if ( [theCombatProfile autoFollowTarget] && [theCombatProfile yardsBehindTarget] > 0.0f ){
		UInt64 followGUID = [playerController focusGUID];
		if ( followGUID )
		{
			for ( Unit *unit in [playersController allPlayers] )
			{
				if ([unit GUID] == followGUID && [playerPosition distanceToPosition: [unit position]] < [theCombatProfile followRange])
				{
					followUnit = unit;
					//cancel the route if we found someone to follow
					self.theRoute = nil;
					break;
				}
			}
			for(Unit *unit in [mobController allMobs])
			{
				if ([unit GUID] == followGUID && [playerPosition distanceToPosition: [unit position]] < [theCombatProfile followRange])
				{
					followUnit = unit;
					//cancel the route if we found a mob to follow
					self.theRoute = nil;
					break;
				}
			}
		}
	}
    
    UInt64 tankGUID = [theCombatProfile selectedTankGUID];
    Unit *tank = [playersController playerWithGUID:tankGUID];

	// Check to see if we should be healing!
	if ( [theCombatProfile healingEnabled] && !([followUnit isMounted] && [theCombatProfile followHealDisabled])){
		
		Unit *healUnit = nil;
		
        if ([tank isValid] && ![tank isDead] && [tank percentHealth] < [theCombatProfile healthThreshold])
		{			
			healUnit = tank;
			log(LOG_HEAL, @"Tank needs heals: %@", tank);
		}
		else
		{
			healUnit = [self unitToHeal];
		}
		
		// Time to heal! We don't want to heal if no LOS! We should follow the target! (PS this isn't smart lul)
		BOOL isTargetUnavailable = _lastActionErrorCode == ErrTargetNotInLOS || _lastActionErrorCode == ErrTargetOutRange;
		// Check to see if the LOS error was w/in the last 3 seconds?  If so shux lets ignore casting
		if ( !(isTargetUnavailable && ([playerController currentTime] - _lastActionTime) < 3000) ){
			isTargetUnavailable = NO;
		}
		
		if ([healUnit isValid] && !isTargetUnavailable)
		{
			log(LOG_HEAL, @"Need to heal: %@", healUnit);
			[self healUnit:healUnit];
			_lastUnitAttemptedToHealed = healUnit;
			//return YES;
		}
	}
    
	// Should we auto follow the focus target?
	if ( _shouldFollow && followUnit && [theCombatProfile autoFollowTarget] && [theCombatProfile yardsBehindTarget] > 0.0f )
	{
		
		// Is our target mounted?  Are we? If not lets!
		if ( [theCombatProfile followMountEnabled] && [followUnit isMounted] && ![[playerController player] isMounted] && ![playerController isCasting]){
			log(LOG_GENERAL, @"mounting to follow");
			// time to mount!
			[self mountNow];
			
			// Check our position again shortly!
			[self performSelector: _cmd withObject: nil afterDelay: 1.6f];
			return YES;
		}
		else
		{
			//log(LOG_DEV, @"not mounting to follow");
		}
		
		// Should we move toward our target?
		Position *playerPosition = [[playerController player] position];
		float range = [playerPosition distanceToPosition: [followUnit position]];
		if(range >= [theCombatProfile yardsBehindTarget]) {
			log(LOG_HEAL, @"Not within %0.2f yards of target, %0.2f away, moving closer", [theCombatProfile yardsBehindTarget], range);
			
			if ( ![playerController isCasting] ){ //&& ![playerController isCTMActive] ){
				[movementController followObject: followUnit];
			}
			
			// Check our position again shortly!
			[self performSelector: _cmd withObject: nil afterDelay: 0.5f];
			return YES;
		}
	}
	
    // check to see if we are moving to attack a unit and bail if we are
    if( combatController.attackUnit && (combatController.attackUnit == [movementController moveToObject])) {
        log(LOG_TARGET, @"attackUnit == moveToObject");
        [self performSelector: _cmd withObject: nil afterDelay: 0.1];
		return NO;
    }
	
	
	//time for combat things
	// first, check if we are in combat already (we agrod something by accident, whatever)
	if([combatController combatEnabled] && ([[playerController player] isInCombat] || [[combatController attackQueue] count]) )
	{
		[combatController doCombatSearch];
        
		if([combatController attackBestTarget])
			return YES;
		else
		{
			[self performSelector: _cmd withObject: nil afterDelay: 0.1];
			return NO;
		}
		//([[unit position] verticalDistanceToPosition: playerPosition] <= vertOffset)
	}
	
	//no known targets to attack, so now check for a new target to attack
	Unit *newUnit  = [self unitToAttack];
	if([theCombatProfile onlyRespond])
		newUnit = nil;
	float newUnitDist  = newUnit ? [[newUnit position] distanceToPosition: playerPosition] : INFINITY;
	
	Mob *mobToLoot      = [self mobToLoot];
    float mobToLootDist     = mobToLoot ? [[mobToLoot position] distanceToPosition: playerPosition] : INFINITY;

	if(self.doLooting && !([followUnit isMounted] && [theCombatProfile followLootDisabled]) && mobToLoot && (mobToLootDist < newUnitDist))
	{
        if(mobToLoot != [movementController moveToObject])
		{
            // either move toward it or loot it now
            if([mobToLoot isValid] && (mobToLootDist < INFINITY) && ![blacklistController isBlacklisted:mobToLoot]) {
				
				// Looting failed :/ I doubt this will ever actually happen, probably more an issue with nodes, but just in case!
				//if ( self.lastAttemptedUnitToLoot == mobToLoot && _lootAttempt >= 3 ){
				//	log(LOG_LOOT, @"Unable to loot %@, removing from loot list", self.lastAttemptedUnitToLoot);
				//	[_mobsToLoot removeObject: self.unitToLoot];
				//}
				//else{
					log(LOG_LOOT, @"Going to loot: %@ at dist %.2f", mobToLoot, mobToLootDist);
					if(mobToLootDist <= 5.0f)    [self performSelector: @selector(reachedUnit:) withObject: mobToLoot afterDelay: 0.1f];
					else                        [movementController moveToObject: mobToLoot andNotify: YES];
					return YES;
				//}
            }
			else{
				log(LOG_LOOT, @"Mob found, but either isn't valid (%d), is too far away (%d) or is blacklisted (%d)", [mobToLoot isValid], (mobToLootDist < INFINITY), [blacklistController isBlacklisted:mobToLoot] );
			}
        }
		else{
			log(LOG_LOOT, @"We're already moving toward %@ (%d)", mobToLoot, mobToLoot != [movementController moveToObject]);
		}
    }
	else if([followUnit isMounted] && [theCombatProfile followLootDisabled])
	{
		log(LOG_LOOT, @"Not looting because we're following");
	}
	
	if([newUnit isValid] && [combatController combatEnabled])
	{
		//attack the newUnit only if we're not flying or following someone on a mount
		if(!([followUnit isValid] && [followUnit isMounted]) && [[playerController player] isOnGround])
		{
			//add additional units to queue
			while ([newUnit isValid])
			{
                if([tank isValid] && !([newUnit targetID] == [tank GUID]))
                {
                    log(LOG_DEV, @"Not attacking %@ because it's targeting %llx and not %@", newUnit, [newUnit targetID], tank);
                    continue;
                }
				log(LOG_TARGET, @"Found %@ and adding to attack queue.", newUnit);
				[combatController addUnitToAttackQueue: newUnit];
				newUnit = [self unitToAttack];
			}
			if([combatController attackBestTarget])
				return YES;
			else
			{
				[self performSelector: _cmd withObject: nil afterDelay: 0.1];
				return NO;
			}
		}
		else if (![[playerController player] isOnGround])
		{
			log(LOG_TARGET, @"Player is in the air. Not engaging in combat.");
		}
		else if([theCombatProfile followCombatDisabled] && [followUnit isValid] && [followUnit isMounted])
		{
			log(LOG_TARGET, @"Mounted and following someone. Not engaging in combat.");
		}
	}
	
    // check for mining and herbalism
    if(![movementController moveToObject] && !([followUnit isMounted] && [theCombatProfile followGatherDisabled])) {
        NSMutableArray *nodes = [NSMutableArray array];
        if(_doMining)			[nodes addObjectsFromArray: [nodeController nodesWithinDistance: self.gatherDistance ofType: MiningNode maxLevel: _miningLevel]];
        if(_doHerbalism)		[nodes addObjectsFromArray: [nodeController nodesWithinDistance: self.gatherDistance ofType: HerbalismNode maxLevel: _herbLevel]];
		if(_doNetherwingEgg)	[nodes addObjectsFromArray: [nodeController nodesWithinDistance: self.gatherDistance EntryID: 185915 position:[playerController position]]];
		
        [nodes sortUsingFunction: DistanceFromPositionCompare context: playerPosition];
        
        if([nodes count]) {
            // find a valid node to loot
            Node *nodeToLoot = nil;
            float nodeDist = INFINITY;
            
            for(nodeToLoot in nodes) {
				
				if ( [blacklistController isBlacklisted:nodeToLoot] ){
					log(LOG_NODE, @"Node %@ blacklisted, ignoring", nodeToLoot);
				}
				
                if(nodeToLoot && [nodeToLoot isValid] && ![blacklistController isBlacklisted:nodeToLoot]) {
                    nodeDist = [playerPosition distanceToPosition: [nodeToLoot position]];
                    break;
                }
            }
			
			BOOL nearbyScaryUnits = [self scaryUnitsNearNode:nodeToLoot doMob:_nodeIgnoreMob doFriendy:_nodeIgnoreFriendly doHostile:_nodeIgnoreHostile];
            
			// We have a valid node!
            if([nodeToLoot isValid] && (nodeDist != INFINITY) && !nearbyScaryUnits) {
				
				[controller setCurrentStatus: @"Bot: Moving to node"];
				
				[movementController pauseMovement];
				log(LOG_NODE, @"Found closest node to loot: %@ at dist %.2f", nodeToLoot, nodeDist);
				if(nodeDist <= NODE_DISTANCE_UNTIL_DISMOUNT){
					if ( self.lastAttemptedUnitToLoot == nodeToLoot && _lootAttempt >= 3 ){
						log(LOG_LOOT, @"Unable to loot %@, blacklisting for 30 seconds", self.lastAttemptedUnitToLoot);
						[nodeController finishedNode: nodeToLoot];
						[nodeController performSelector:@selector(removeFinishedNode:) withObject:nodeToLoot afterDelay:30.0f];
					}
					else{
						[self reachedUnit: nodeToLoot];
						return YES;
					}
				}
				// Should we be mounted before we move to the node?
				else if ( [mountCheckbox state] && [self mountNow] ){
					[self performSelector: _cmd withObject: nil afterDelay: 2.0f];	
					return YES;
				}
				// Safe to move to the node!
				else{
					[movementController moveToObject: nodeToLoot andNotify: YES];
				}
				return YES;
            }
        }
    }
	
	// check for fishing
	if ( ![movementController moveToObject] ){
		if ( _doFishing ){
			
			log(LOG_FISHING, @"Fishing scan!");
			
			// fishing only in schools! (probably have a route we're following)
			if ( _fishingOnlySchools ){
				NSMutableArray *nodes = [NSMutableArray array];
				[nodes addObjectsFromArray:[nodeController nodesWithinDistance:_fishingGatherDistance ofType: FishingSchool maxLevel: 1]];
				[nodes sortUsingFunction: DistanceFromPositionCompare context: playerPosition];
				
				// are we close enough to start fishing?
				if ( [nodes count] ){
					
					// lets find a node
					Node *nodeToFish = nil;
					float nodeDist = INFINITY;
					for(nodeToFish in nodes) {
						
						if ( [blacklistController isBlacklisted:nodeToFish] ){
							log(LOG_FISHING, @"Node %@ blacklisted, ignoring", nodeToFish);
							continue;
						}
						
						if ( nodeToFish && [nodeToFish isValid] ) {
							nodeDist = [playerPosition distanceToPosition: [nodeToFish position]];
							break;
						}
					}
					
					BOOL nearbyScaryUnits = [self scaryUnitsNearNode:nodeToFish doMob:_nodeIgnoreMob doFriendy:_nodeIgnoreFriendly doHostile:_nodeIgnoreHostile];
					
					// we have a valid node!
					if ( [nodeToFish isValid] && (nodeDist != INFINITY) && !nearbyScaryUnits ) {
						[movementController pauseMovement];
						
						log(LOG_FISHING, @"Found closest school %@ at dist %.2f", nodeToFish, nodeDist);
						if(nodeDist <= NODE_DISTANCE_UNTIL_FISH){
							
							// turn toward
							[movementController turnTowardObject:nodeToFish];
							[movementController backEstablishPosition];
							
							// add some blacklisting logic here...
							
							// now we fish!
							
							log(LOG_FISHING, @"We are near %@, time to fish!", nodeToFish);
							
							if ( [[playerController player] isMounted] ){
								log(LOG_FISHING, @"Dismounting...");
								[movementController dismount]; 
							}
							
							if ( ![fishController isFishing] ){
								[fishController fish: _fishingApplyLure
										  withRecast:_fishingRecast
											 withUse:_fishingUseContainers
											withLure:_fishingLureSpellID
										  withSchool:nodeToFish];
							}
							
							return YES;
						}
						/*
						// Should we be mounted before we move to the node?
						else if ( [self mountNow] ){
							[self performSelector: _cmd withObject: nil afterDelay: 2.2f];	
							return YES;
						}
						// Safe to move to the node!
						else{
							[controller setCurrentStatus: @"Bot: Moving to fishing pool"];
							[movementController moveToObject: nodeToFish andNotify: YES];
						}
						return YES;*/
					}
				}
				
				log(LOG_FISHING, @"Didn't find a node, so we're doing nothing...");
			}
			
			// fish where we are
			else{
				log(LOG_FISHING, @"Just fishing from wherever we are!");
				
				[fishController fish: _fishingApplyLure
						  withRecast:NO
							 withUse:_fishingUseContainers
							withLure:_fishingLureSpellID
						  withSchool:nil];		
				
				return YES;
			}
			
			// if we get here, we shouldn't be fishing, stop if we are
			if ( [fishController isFishing] ){
				[fishController stopFishing];
			}
		}
	}
	
	// Should we be mounted?
	if([mountCheckbox state])
		if ( [self mountNow] )
		{
			log(LOG_GENERAL, @"Mounting");
			[self performSelector: _cmd withObject: nil afterDelay: 2.0f];	
			return YES;
		}
    
    // if there's nothing to do, make sure we keep moving if we aren't
    if(self.theRoute) {
        if([movementController isPatrolling] && ([movementController patrolRoute] == [self.theRoute routeForKey: PrimaryRoute])) {
            if(![movementController isMoving])
                [movementController resumeMovementToNearestWaypoint];
        } else {
            [movementController setPatrolRoute: [self.theRoute routeForKey: PrimaryRoute]];
            [movementController beginPatrol: 0 andAttack: self.theCombatProfile.combatEnabled];
        }
        [controller setCurrentStatus: @"Bot: Patrolling"];
    } else {
        [controller setCurrentStatus: @"Bot: Enabled"];
        [self performSelector: _cmd withObject: nil afterDelay: 0.1];
    }
    return NO;
}

-(BOOL)mountNow{
	log(LOG_FUNCTION, @"entering function");
	if ( ![[playerController player] isSwimming] && ![[playerController player] isMounted] && ![playerController isInCombat] && ![playerController isIndoors] ){
		//log(LOG_GENERAL, @"Mounting!");
		usleep(100000);
		if([macroController executeMacro:@"Mount"])
            return YES;
		Spell *mount = [spellController mountSpell:[mountType selectedTag] andFast:YES];
		// Time to cast!
		log(LOG_GENERAL, @"Using mount %@ id: %i", [mount name], [[mount ID] intValue]);
		[self performAction:[[mount ID] intValue]];
		return YES;
	}
	//log(LOG_GENERAL, @"Not Mounting");
	return NO;
}

#pragma mark IBActions


- (IBAction)editCombatProfiles: (id)sender {
    [[CombatProfileEditor sharedEditor] showEditorOnWindow: [self.view window] 
                                           forProfileNamed: [[NSUserDefaults standardUserDefaults] objectForKey: @"CombatProfile"]];
}

- (IBAction)autoJoinWG: (id)sender{
	if ( [autoJoinWG state] ){
		[autoJoinWG setTitle:@"Don't forget to set up your macro on the settings tab!"];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector: @selector(resetAutoJoinWGText) object:nil];
		[self performSelector:@selector(resetAutoJoinWGText) withObject:nil afterDelay:3.5f];
	}
}

- (void)resetAutoJoinWGText{
	[autoJoinWG setTitle:@"Stay in Wintergrasp (this will persist if the bot isn't running)"];
}

- (IBAction)updateStatus: (id)sender {
    CombatProfile *profile = [[combatProfilePopup selectedItem] representedObject];
	
	log(LOG_GENERAL, @"Updating status... %@", profile);
	
    NSString *status = [NSString stringWithFormat: @"%@ (%@). ", 
                        [[[behaviorPopup selectedItem] representedObject] name],    // behavior
                        [[[routePopup selectedItem] representedObject] name]];       // route
    
    NSString *bleh = nil;
    if(!profile || !profile.combatEnabled) {
        bleh = @"Combat disabled.";
    } else {
        if(profile.onlyRespond) {
            bleh = @"Only attacking back.";
        } else {
            NSString *levels = profile.attackAnyLevel ? @"any levels" : [NSString stringWithFormat: @"levels %d-%d", 
                                                                         profile.attackLevelMin,
                                                                         profile.attackLevelMax];
            bleh = [NSString stringWithFormat: @"Attacking %@ within %.1fy.", 
                    levels,
                    profile.attackRange];
        }
    }
    
    status = [status stringByAppendingString: bleh];
    
    
    if([miningCheckbox state])
        status = [status stringByAppendingFormat: @" Mining (%d).", [miningSkillText intValue]];
    if([herbalismCheckbox state])
        status = [status stringByAppendingFormat: @" Herbalism (%d).", [herbalismSkillText intValue]];
    if([skinningCheckbox state])
        status = [status stringByAppendingFormat: @" Skinning (%d).", [skinningSkillText intValue]];
    
    [statusText setStringValue: status];
}


- (IBAction)startBot: (id)sender {
	BOOL ignoreRoute = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"IgnoreRoute"] boolValue];
    
    // gather appropriate information to start the bot
    if(ignoreRoute) {
        self.theRoute = nil;
    } else {
        self.theRoute = [[routePopup selectedItem] representedObject];
    }
    self.theBehavior = [[behaviorPopup selectedItem] representedObject];
    self.theCombatProfile = [[combatProfilePopup selectedItem] representedObject];
	log(LOG_GENERAL, @"Starting with attack range of %0.2f", [self.theCombatProfile attackRange]);
	    
    // get hotkey settings
    KeyCombo hotkey = [shortcutRecorder keyCombo];
    _currentHotkeyModifier = hotkey.flags;
    _currentHotkey = hotkey.code;
    hotkey = [petAttackRecorder keyCombo];
    _currentPetAttackHotkeyModifier = hotkey.flags;
    _currentPetAttackHotkey = hotkey.code;
    
    self.doLooting = [lootCheckbox state];
    self.gatherDistance = [gatherDistText floatValue];
    self.nodeDescend = [nodeDescendCheckbox state];
	
	// We only really need this if we are PvPing, but we want to store it in case they click "start bot" while in a BG, vs. doing the PvP route
	_pvpMarks = [itemController pvpMarks];
    
	if ( ([self isHotKeyInvalid] & HotKeyPrimary) == HotKeyPrimary ){
        log(LOG_ERROR, @"Primary hotkey is not valid.");
        NSBeep();
        NSRunAlertPanel(@"Invalid Hotkey", @"You must choose a valid primary hotkey, or the bot will be unable to use any spells or abilities.", @"Okay", NULL, NULL);
        return;
    }
	
	if ( self.doLooting && ([self isHotKeyInvalid] & HotKeyInteractMouseover) == HotKeyInteractMouseover ){
        log(LOG_ERROR, @"Interact with MouseOver hotkey is not valid.");
        NSBeep();
        NSRunAlertPanel(@"Invalid Looting Hotkey", @"You must choose a valid Interact with MouseOver hotkey, or the bot will be unable to loot bodies.", @"Okay", NULL, NULL);
        return;
	}
    
    // check that we have valid conditions
    if( ![controller isWoWOpen]) {
        log(LOG_ERROR, @"WoW is not open. Bailing.");
        NSBeep();
        NSRunAlertPanel(@"WoW is not open", @"WoW is not open...", @"Okay", NULL, NULL);
        return;
    }
    
    if( ![playerController playerIsValid:self]) {
        log(LOG_ERROR, @"The player is not valid. Bailing.");
        NSBeep();
        NSRunAlertPanel(@"Player not valid or cannot be detected", @"You must be logged into the game before you can start the bot.", @"Okay", NULL, NULL);
        return;
    }
    
    if( !self.theRoute && !ignoreRoute ) {
        NSBeep();
        log(LOG_ERROR, @"The current route is not valid.");
        NSRunAlertPanel(@"Route is not valid", @"You must select a valid route before starting the bot.  If you removed or renamed a route, please select an alternative.", @"Okay", NULL, NULL);
        
        return;
    }
    
    if( !self.theBehavior ) {
        log(LOG_ERROR, @"The current behavior is not valid.");
        NSBeep();
        NSRunAlertPanel(@"Behavior is not valid", @"You must select a valid behavior before starting the bot.  If you removed or renamed a behavior, please select an alternative.", @"Okay", NULL, NULL);
        return;
    }

    if( !self.theCombatProfile ) {
        log(LOG_ERROR, @"The current combat profile is not valid.");
        NSBeep();
        NSRunAlertPanel(@"Combat Profile is not valid", @"You must select a valid combat profile before starting the bot.  If you removed or renamed a profile, please select an alternative.", @"Okay", NULL, NULL);
        return;
    }

    
    if( [self isBotting])
        [self stopBot: nil];
    
    if(self.theCombatProfile && self.theBehavior && (_currentHotkey >= 0)) {
        log(LOG_GENERAL, @"Starting.");
        [spellController reloadPlayerSpells];
        
        // also check that the route has any waypoints
        // and that the behavior has any procedures
        _doMining			= [miningCheckbox state];
		_doNetherwingEgg	= [netherwingEggCheckbox state];
        _miningLevel		= [miningSkillText intValue];
        _doHerbalism		= [herbalismCheckbox state];
        _herbLevel			= [herbalismSkillText intValue];
        _doSkinning			= [skinningCheckbox state];
        _skinLevel			= [skinningSkillText intValue];
        
		// fishing
		_doFishing				= [fishingCheckbox state];
		_fishingGatherDistance	= [fishingGatherDistanceText floatValue];
		_fishingApplyLure		= [fishingApplyLureCheckbox state];
		_fishingOnlySchools		= [fishingOnlySchoolsCheckbox state];
		_fishingRecast			= [fishingRecastCheckbox state];
		_fishingUseContainers	= [fishingUseContainersCheckbox state];
		_fishingLureSpellID		= [fishingLurePopUpButton selectedTag];
		
		// node checking
		_nodeIgnoreFriendly				= [nodeIgnoreFriendlyCheckbox state];
		_nodeIgnoreHostile				= [nodeIgnoreHostileCheckbox state];
		_nodeIgnoreMob					= [nodeIgnoreMobCheckbox state];
		_nodeIgnoreFriendlyDistance		= [nodeIgnoreFriendlyDistanceText floatValue];
		_nodeIgnoreHostileDistance		= [nodeIgnoreHostileDistanceText floatValue];
		_nodeIgnoreMobDistance			= [nodeIgnoreMobDistanceText floatValue];
		
		// start our log out timer - only check every 5 seconds!
		_logOutTimer = [NSTimer scheduledTimerWithTimeInterval: 5.0f target: self selector: @selector(logOutTimer:) userInfo: nil repeats: YES];
		
        int canSkinUpToLevel = 0;
        if(_skinLevel <= 100) {
            canSkinUpToLevel = (_skinLevel/10)+10;
        } else {
            canSkinUpToLevel = (_skinLevel/5);
        }
        log(LOG_GENERAL, @"Starting bot with Sknning skill %d, allowing mobs up to level %d", _skinLevel, canSkinUpToLevel);
        
        self.isBotting = YES;
        [startStopButton setTitle: @"Stop Bot"];
        self.didPreCombatProcedure = NO;
        _reviveAttempt = 0;
		
		// Bot started, lets reset our whisper history!
		[chatLogController clearWhisperHistory];
        
		if ( !self.isPvPing || self.startDate == nil ){
			self.startDate = [[NSDate date] retain];
		}
        
        if( [playerController isGhost] && self.theRoute) {
            Position *playerPosition = [playerController position];
            Route *primaryRoute  = [self.theRoute routeForKey: PrimaryRoute];
            Route *corpseRunRoute = [self.theRoute routeForKey: CorpseRunRoute];
            
            log(LOG_GENERAL, @"Started the bot, but we're a ghost!");
            
            float primaryDist = primaryRoute ? [[[primaryRoute waypointClosestToPosition: playerPosition] position] distanceToPosition: playerPosition] : INFINITY;
            float corpseDist = corpseRunRoute ? [[[corpseRunRoute waypointClosestToPosition: playerPosition] position] distanceToPosition: playerPosition] : INFINITY;
            
            if(primaryDist < corpseDist)
                [movementController setPatrolRoute: primaryRoute];
            else
                [movementController setPatrolRoute: corpseRunRoute];
            
            [movementController beginPatrol: 1 andAttack: NO];
            return;
        }
        
        if( [playerController isDead]) {
            log(LOG_GENERAL, @"Started the bot, but we're dead! Will try to release. (%d:%d:%d:%d)", [playerController health], [playerController isGhost], [playerController maxHealth], [[playerController player] maxHealth] );
            [self playerHasDied: nil];
            return;
        }
        
        [controller setCurrentStatus: @"Bot: Enabled"];
        [combatController setCombatEnabled: self.theCombatProfile.combatEnabled];
        // [movementController setPatrolRoute: [self.theRoute routeForKey: PrimaryRoute]];

        [self evaluateSituation];
    }
}

- (void)updateRunningTimer{
	int duration = (int) [[NSDate date] timeIntervalSinceDate: self.startDate];
	
	NSMutableString *runningFor = [NSMutableString stringWithFormat:@"Running for: "];
	
	if ( duration > 0 ){
		// Prob a better way for this heh
		int seconds = duration % 60;
		duration /= 60;
		int minutes = duration % 60;
		duration /= 60;
		int hours = duration % 24;
		duration /= 24;
		int days = duration;
		
		if (days > 0) [runningFor appendString:[NSString stringWithFormat:@"%d day%@", days, (days > 1) ? @"s " : @" "]];
		if (hours > 0) [runningFor appendString:[NSString stringWithFormat:@"%d hour%@", hours, (hours > 1) ? @"s " : @" "]];
		if (minutes > 0) [runningFor appendString:[NSString stringWithFormat:@"%d minute%@", minutes, (minutes > 1) ? @"s " : @" "]];
		if (seconds > 0) [runningFor appendString:[NSString stringWithFormat:@"%d second%@", seconds, (seconds > 1) ? @"s " : @""]];
		
		[runningTimer setStringValue: runningFor];
	}
}

- (IBAction)stopBot: (id)sender {
	
	// Then a user clicked!
	if ( sender != nil ){
		self.startDate = nil;
	}
	log(LOG_GENERAL, @"Bot Stopped: %@", sender);
    [self cancelCurrentProcedure];
    [movementController setPatrolRoute: nil];
    [combatController cancelAllCombat];
    [blacklistController removeAllUnits];
    

    [_mobsToLoot removeAllObjects];
    self.isBotting = NO;
    self.preCombatUnit = nil;
    [controller setCurrentStatus: @"Bot: Stopped"];
    
    log(LOG_GENERAL, @"Stopped.");
	
	// stop our log out timer
	[_logOutTimer invalidate];_logOutTimer=nil;
    
    if(self.isPvPing) {
        log(LOG_GENERAL, @"Bot stopped but PvP is ongoing...");
    }
    
    [startStopButton setTitle: @"Start Bot"];
}

- (void)reEnableStart {
    [startStopButton setEnabled: YES];
    [pvpStartStopButton setEnabled: YES];
}

- (IBAction)startStopBot: (id)sender {
    if(self.isBotting) {
        [self stopBot: sender];
    } else {
        [self startBot: sender];
    }
}

NSMutableDictionary *_diffDict = nil;
- (IBAction)testHotkey: (id)sender {
    //int value = 28734;
    //[[controller wowMemoryAccess] saveDataForAddress: ([offsetController offset:@"HOTBAR_BASE_STATIC"] + BAR6_OFFSET) Buffer: (Byte *)&value BufLength: sizeof(value)];
    //PGLog(@"Set Mana Tap.");
    
    KeyCombo hotkey = [shortcutRecorder keyCombo];
    [chatController pressHotkey: hotkey.code withModifier: hotkey.flags];
    
    
    if(!_diffDict) _diffDict = [[NSMutableDictionary dictionary] retain];
    
    BOOL firstRun = ([_diffDict count] == 0);
    UInt32 i, value;
    
    if(firstRun) {
        log(LOG_GENERAL, @"First run.");
        for(i=0x900000; i< 0xFFFFFF; i+=4) {
            if([[controller wowMemoryAccess] loadDataForObject: self atAddress: i Buffer: (Byte *)&value BufLength: sizeof(value)]) {
                if(value < 2)
                    [_diffDict setObject: [NSNumber numberWithUnsignedInt: value] forKey: [NSNumber numberWithUnsignedInt: i]];
            }
        }
    } else {
        NSMutableArray *removeKeys = [NSMutableArray array];
        for(NSNumber *key in [_diffDict allKeys]) {
            if([[controller wowMemoryAccess] loadDataForObject: self atAddress: [key unsignedIntValue] Buffer: (Byte *)&value BufLength: sizeof(value)]) {
                if( value == [[_diffDict objectForKey: key] unsignedIntValue]) {
                    [removeKeys addObject: key];
                } else {
                    [_diffDict setObject: [NSNumber numberWithUnsignedInt: value] forKey: key];
                }
            }
        }
        [_diffDict removeObjectsForKeys: removeKeys];
    }
    
    log(LOG_GENERAL, @"%d values.", [_diffDict count]);
    if([_diffDict count] < 20) {
        log(LOG_GENERAL, @"%@", _diffDict);
    }
    
    return;
}


- (IBAction)hotkeyHelp: (id)sender {
	[NSApp beginSheet: hotkeyHelpPanel
	   modalForWindow: [self.view window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
}

- (IBAction)closeHotkeyHelp: (id)sender {
    [NSApp endSheet: hotkeyHelpPanel returnCode: 1];
    [hotkeyHelpPanel orderOut: nil];
}

- (IBAction)lootHotkeyHelp: (id)sender {
	[NSApp beginSheet: lootHotkeyHelpPanel
	   modalForWindow: [self.view window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
}

- (IBAction)closeLootHotkeyHelp: (id)sender {
    [NSApp endSheet: lootHotkeyHelpPanel returnCode: 1];
    [lootHotkeyHelpPanel orderOut: nil];
}

- (IBAction)gatheringLootingOptions: (id)sender{
	[NSApp beginSheet: gatheringLootingPanel
	   modalForWindow: [self.view window]
		modalDelegate: self
	   didEndSelector: @selector(gatheringLootingDidEnd: returnCode: contextInfo:)
		  contextInfo: nil];
}

- (IBAction)gatheringLootingSelectAction: (id)sender {
    [NSApp endSheet: gatheringLootingPanel returnCode: [sender tag]];
}

- (void)gatheringLootingDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    [gatheringLootingPanel orderOut: nil];
}

// sometimes queueing for the BG fails, so lets just check every second to make sure we queued
- (void)queueForBGCheck{
	int status = [playerController battlegroundStatus];
	if ( status == BGWaiting ){
		// queue then check again!
		[macroController useMacroOrSendCmd:@"AcceptBattlefield"];
		[self performSelector:@selector(queueForBGCheck) withObject: nil afterDelay:1.0f];
		log(LOG_PVP, @"Additional join BG check executed!");
	}
}


#pragma mark Notifications

- (void)eventBattlegroundStatusChange: (NSNotification*)notification{
	log(LOG_FUNCTION, @"entering function");
	int status = [[notification object] intValue];
	
	// Lets join the BG!
	if ( status == BGWaiting ){
		[macroController useMacroOrSendCmd:@"AcceptBattlefield"];
		float queueAfter = SSRandomFloatBetween(3.0f, 20.0f);
		[self performSelector:@selector(queueForBGCheck) withObject: nil afterDelay:queueAfter];
		log(LOG_PVP, @"Joining the BG after %0.2f seconds", queueAfter);
	}
	else if ( status == BGNone ){
		// just stop movement
		[movementController resetMovementState];
		log(LOG_PVP, @"Battleground is over?? Resetting movement state");
	}
}

- (void)eventZoneChanged: (NSNotification*)notification{
	log(LOG_FUNCTION, @"entering function");
	NSNumber *lastZone = [notification object];
	
	if ( [playerController isInBG:[lastZone intValue]] && self.isBotting ){
		[self stopBot:nil];
		log(LOG_PVP, @"Left BG, stopping bot!");
		//asdfasfsafd TO FIX
	}
	
	log(LOG_GENERAL, @"Zone change fired... to %@", lastZone);
}

// Want to respond to some commands? o.O
- (void)whisperReceived: (NSNotification*)notification{
	log(LOG_FUNCTION, @"entering function");
	ChatLogEntry *entry = [notification object];
	
	//TO DO: Check to make sure you only respond to people around you that you are healing!
	
	if ( [[entry text] isEqualToString: @"stay"] ){
		log(LOG_HEAL, @"Stop following");
		_shouldFollow = NO;
	}
	else if ( [[entry text] isEqualToString: @"heel"] ){
		log(LOG_HEAL, @"Start following again!");
		_shouldFollow = YES;
	}
}

#pragma mark AKA [Input] PlayerData

- (void)playerHasRevived: (NSNotification*)notification {
	log(LOG_FUNCTION, @"entering function");
    if( ![self isBotting]) return;
    log(LOG_GENERAL, @"Player has revived!");
    [controller setCurrentStatus: @"Bot: Player has Revived"];
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    _reviveAttempt = 0;
    
    // rescan for mobs
    // [mobController enumerateAllMobs];
    
    // reset our route and then pause again
    if(self.theRoute) {
        [movementController setPatrolRoute: [self.theRoute routeForKey: PrimaryRoute]];
        [movementController beginPatrol: 0 andAttack: self.theCombatProfile.combatEnabled];
        [movementController pauseMovement];
    }
    
    // perform post combat
    [self performSelector: @selector(performProcedureWithState:) 
               withObject: [NSDictionary dictionaryWithObjectsAndKeys: 
                            PostCombatProcedure,              @"Procedure",
                            [NSNumber numberWithInt: 0],      @"CompletedRules", nil] 
               afterDelay: 1.0];
}

- (void)playerHasDied: (NSNotification*)notification {
	log(LOG_FUNCTION, @"entering function");
    
    if( ![self isBotting]) return;
	if ( ![playerController playerIsValid:self] ) return;
	
    log(LOG_GENERAL, @"Player has died.");
    [controller setCurrentStatus: @"Bot: Player has Died"];
    
    [self cancelCurrentProcedure];              // this wipes all bot state (except pvp)
    [movementController setPatrolRoute: nil];   // this wipes all movement state
    [combatController cancelAllCombat];         // this wipes all combat state
	
	_shouldFollow = YES;
    
    // send notification to Growl
    if( [controller sendGrowlNotifications] && [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
        // [GrowlApplicationBridge setGrowlDelegate: @""];
        [GrowlApplicationBridge notifyWithTitle: @"Player Has Died!"
                                    description: @"Sorry :("
                               notificationName: @"PlayerDied"
                                       iconData: [[NSImage imageNamed: @"Ability_Warrior_Revenge"] TIFFRepresentation]
                                       priority: 0
                                       isSticky: NO
                                   clickContext: nil];
    }
	
	// Try to res in a second! (give the addon time to release if they're using one!)
    [self performSelector: @selector(rePop:) withObject: [NSNumber numberWithInt:0] afterDelay: 3.0f];
	
	
	// Play an alarm after we die?
	if ( [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"AlarmOnDeath"] boolValue] ){
		[[NSSound soundNamed: @"alarm"] play];
		log(LOG_GENERAL, @"Playing alarm, you have died!");
	}
}

- (void)rePop: (NSNumber *)count{
	log(LOG_FUNCTION, @"entering function");
	if( ![self isBotting]) return;
	if ( ![playerController playerIsValid:self] ) return;

	log(LOG_GENERAL, @"Trying to repop (%d:%d)", [playerController isGhost], [playerController isDead] );
	
	// We need to repop!
	if ( ![playerController isGhost] && [playerController isDead] ) {
		int try = [count intValue];
		// ONLY stop bot if we're not in PvP (we'll auto res in PvP!)
		if(++try > 10 && !self.isPvPing) {
			log(LOG_ERROR, @"Repop failed after 10 tries.  Stopping bot.");
			[self stopBot: nil];
			[controller setCurrentStatus: @"Bot: Failed to Release. Stopped."];
			return;
		}
		log(LOG_GENERAL, @"Attempting to repop %d.", try);
		
		[macroController useMacroOrSendCmd:@"ReleaseCorpse"];
		
		// Try again every 5 seconds pls
		[self performSelector: @selector(rePop:) withObject: [NSNumber numberWithInt:try] afterDelay: 5.0];
	}
	
	// We're a ghost w00t! Lets start the route!
	else{
		// run back if we have a route
		if(!self.isPvPing) {
			if([self.theRoute routeForKey: CorpseRunRoute] && ![playerController isInBG:[playerController zone]]) {
				log(LOG_GENERAL, @"Starting Corpse Run...");
				[controller setCurrentStatus: @"Bot: Running back from graveyard..."];
				[movementController setPatrolRoute: [self.theRoute routeForKey: CorpseRunRoute]];
				[movementController beginPatrolAndStopAtLastPoint];
			}
		} else {
			log(LOG_GENERAL, @"Ignoring Corpse Run route because we are PvPing.");
		}
	}
}

- (void)playerIsInvalid: (NSNotification*)not {
	log(LOG_FUNCTION, @"entering function");
    if( [self isBotting]) {
        log(LOG_ERROR, @"Player is no longer valid, stopping bot.");
        [self stopBot: nil];
    }
}

#pragma mark ShortcutRecorder Delegate

- (void)toggleGlobalHotKey:(SRRecorderControl*)sender
{
	log(LOG_FUNCTION, @"entering function");
	if (StartStopBotGlobalHotkey != nil) {
		[[PTHotKeyCenter sharedCenter] unregisterHotKey: StartStopBotGlobalHotkey];
		[StartStopBotGlobalHotkey release];
		StartStopBotGlobalHotkey = nil;
	}
    
    KeyCombo keyCombo = [sender keyCombo];
    
    if((keyCombo.code >= 0) && (keyCombo.flags >= 0)) {
        StartStopBotGlobalHotkey = [[PTHotKey alloc] initWithIdentifier: @"StartStopBot"
                                                               keyCombo: [PTKeyCombo keyComboWithKeyCode: keyCombo.code
                                                                                               modifiers: [sender cocoaToCarbonFlags: keyCombo.flags]]];
        
        [StartStopBotGlobalHotkey setTarget: startStopButton];
        [StartStopBotGlobalHotkey setAction: @selector(performClick:)];
        
        [[PTHotKeyCenter sharedCenter] registerHotKey: StartStopBotGlobalHotkey];
    }
}

- (void)shortcutRecorder:(SRRecorderControl *)recorder keyComboDidChange:(KeyCombo)newKeyCombo {
	log(LOG_FUNCTION, @"entering function");
    if(recorder == shortcutRecorder) {
        [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.code] forKey: @"HotkeyCode"];
        [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.flags] forKey: @"HotkeyFlags"];
    }
    
    if(recorder == startstopRecorder) {
       [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.code] forKey: @"StartstopCode"];
       [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.flags] forKey: @"StartstopFlags"];
       [self toggleGlobalHotKey: startstopRecorder];
    }
    
    if(recorder == petAttackRecorder) {
        [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.code] forKey: @"PetAttackCode"];
        [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.flags] forKey: @"PetAttackFlags"];
    }
    
    if(recorder == mouseOverRecorder) {
        [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.code] forKey: @"MouseOverTargetCode"];
        [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: newKeyCombo.flags] forKey: @"MouseOverTargetFlags"];
    }
	
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark -
#pragma mark PvP!

- (void)auraGain: (NSNotification*)notification {
	log(LOG_FUNCTION, @"entering function");

	// Player is PvPing!
    if(self.isPvPing) {
        UInt32 spellID = [[(Spell*)[[notification userInfo] objectForKey: @"Spell"] ID] unsignedIntValue];
		
		// if we are waiting to rez, pause the bot (incase it is not)
        if( spellID == WaitingToRezSpellID ) {
            [movementController pauseMovement];
			
        }
		
		// Just got preparation?  Lets check to see if we're in strand + should be attacking/defending
        if( spellID == PreparationSpellID ) {
			log(LOG_PVP, @"We have preparation, checking BG info!");
			
			// Do it in a bit, as we need to wait for our controller to update the object list!
			[self performSelector:@selector(pvpGetBGInfo) withObject:nil afterDelay:3.1f];
        }
    }
}

- (void)auraFade: (NSNotification*)notification {
	log(LOG_FUNCTION, @"entering function");
	
	// Player is PvPing!
    if(self.isPvPing) {
        UInt32 spellID = [[(Spell*)[[notification userInfo] objectForKey: @"Spell"] ID] unsignedIntValue];
		
        if( spellID == PreparationSpellID ) {

			// Only checking for the delay!
			if ( [playerController isOnBoatInStrand] && [playerController zone] == ZoneStrandOfTheAncients ){
				// We want to pause, and not move until the boat stops!  Delay 10 seconds?
				[movementController pauseMovement];
				
				_strandDelay = YES;
				
				// reset the delay in 10 seconds?
				[self performSelector:@selector(pvpResetStrandDelay) withObject:nil afterDelay:10.0f];
				
				log(LOG_PVP, @"We are on a boat in Strand! Starting a delay until the boat stops!");
			}
        }
    }
}

- (void)pvpResetStrandDelay{
	log(LOG_FUNCTION, @"entering function");
	_strandDelay = NO;
	
	log(LOG_PVP, @"Delay reset!");
	
	[controller setCurrentStatus: @"PvP: Delay reset, am I really waiting for eval?..."];
	
	[self performSelector:@selector(evaluateSituation) withObject:nil afterDelay:10.0f];
}

- (void)pvpGetBGInfo{
	log(LOG_FUNCTION, @"entering function");
	
	// Lets gets some info?
	if ( [playerController zone] == ZoneStrandOfTheAncients ){
		// Determine what the player is!
		//int faction = [playerController factionTemplate];
		
		/*BOOL isAlliance = ([controller reactMaskForFaction: faction] & 0x2);
		BOOL isHorde = ([controller reactMaskForFaction: faction] & 0x4);
					   
		PGLog(@"Alliance: %d, Horde: %d", isAlliance, isHorde);*/
		
		/*
		Position *playerPosition = [playerController position];
		NSArray *allianceNodes = [NSArray arrayWithObjects:
								   [NSNumber numberWithInt:StrandAllianceBanner],
								   [NSNumber numberWithInt:StrandAllianceBannerAura],
								   nil];
		NSArray *hordeNodes = [NSArray arrayWithObjects:
								  [NSNumber numberWithInt:StrandHordeBanner],
								  [NSNumber numberWithInt:StrandeHordeBannerAura],
								  nil];
		
		// Since we're only check @ the start, we just have to check to see which exist @ the beginning!
		if ( [[nodeController nodesWithinDistance: 5000.0f NodeIDs:allianceNodes position:playerPosition] count] > 0 ){
			PGLog(@"[PvP] Alliance is defending in strand!");
			if ( isHorde ){
				_attackingInStrand = YES;
			}
			else if ( isAlliance ){
				_attackingInStrand = NO;
			}
		}
		
		// Horde is defending!
		if ( [[nodeController nodesWithinDistance: 5000.0f NodeIDs:hordeNodes position:playerPosition] count] > 0 ){
			PGLog(@"[PvP] Horde is defending in strand!");
			if ( isHorde ){
				_attackingInStrand = NO;
			}
			else if ( isAlliance ){
				_attackingInStrand = YES;
			}
		}*/
		
		NSArray *antipersonnelCannons = [mobController mobsWithEntryID:StrandAntipersonnelCannon];
		
		if ( [antipersonnelCannons count] > 0 ){
			BOOL foundFriendly = NO, foundHostile = NO;
			for ( Mob *mob in antipersonnelCannons ){
				
				int faction = [mob factionTemplate];
				BOOL isHostile = [playerController isHostileWithFaction: faction];
				log(LOG_PVP, @"Faction %d (%d) of Mob %@", faction, isHostile, mob);
				
				if ( isHostile ){
					foundHostile = YES;
				}
				else if ( !isHostile ){
					foundFriendly = YES;
				}
			}
			
			if ( foundHostile && foundFriendly ){
				log(LOG_PVP, @"New round for Strand! Found hostile and friendly! Were we attacking last round? %d", _attackingInStrand);
				_attackingInStrand = _attackingInStrand ? NO : YES;
			}
			else if ( foundHostile ){
				_attackingInStrand = YES;
				log(LOG_PVP, @"We're attacking in strand!");
			}
			else if ( foundFriendly ){
				_attackingInStrand = NO;
				log(LOG_PVP, @"We're defending in strand!");
			}
		}
		// If we don't see anything, then we're attacking!
		else{
			_attackingInStrand = YES;
			log(LOG_PVP, @"We're attacking in strand!");
		}
		
		// Check to see if we're on the boat!
		if ( _attackingInStrand && [playerController isOnBoatInStrand]){
			_strandDelay = YES;
			log(LOG_PVP, @"We're on a boat so lets delay our movement until it settles!");
		}
	}
}

// This little guy controls most of our PvP functions!
- (void)pvpMonitor: (NSTimer*)timer{
	log(LOG_FUNCTION, @"entering function");
	if(!self.isPvPing)						return;
	if(![playerController playerIsValid:self])   return;
	
	BOOL isPlayerInBG = [playerController isInBG:[playerController zone]];
	Player *player = [playerController player];
	
	// Player just left the BG!
	if ( _pvpIsInBG && !isPlayerInBG ){
		_pvpIsInBG = NO;
		
		log(LOG_PVP, @"Player has left the battleground...");
		
		// Stop the bot! (this could be triggered by our marks check, but of course someone could have maxed marks)
		if ( self.isBotting ){
			[self stopBot: nil];
		}
		
		[movementController pauseMovement];
		
		// Only requeue if we're PvPing!
		if ( self.isPvPing ){

			// check for deserter
			BOOL hasDeserter = NO;
			if( [player isValid] && [auraController unit: player hasAura: DeserterSpellID] ) {
				hasDeserter = YES;
			}
			
			if( [controller sendGrowlNotifications] && [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
				// [GrowlApplicationBridge setGrowlDelegate: @""];
				[GrowlApplicationBridge notifyWithTitle: [NSString stringWithFormat: @"Battleground Complete"]
											description: (hasDeserter ? @"Waiting for Deserter to fade." : @"Will re-queue in 15 seconds.")
									   notificationName: @"BattlegroundLeave"
											   iconData: (([controller reactMaskForFaction: [player factionTemplate]] & 0x2) ? [[NSImage imageNamed: @"BannerAlliance"] TIFFRepresentation] : [[NSImage imageNamed: @"BannerHorde"] TIFFRepresentation])
											   priority: 0
											   isSticky: NO
										   clickContext: nil];             
			}
			if(hasDeserter) {
				log(LOG_PVP, @"Deserter! Waiting for deserter to go away :(");
				[controller setCurrentStatus: @"PvP: Waiting for Deserter to fade..."];
				[self performSelector: @selector(pvpQueueBattleground) withObject: nil afterDelay: 10.0];
				return;
			}
			
			// Requeue after 15 seconds (to account for some crappy computers)
			[controller setCurrentStatus: @"PvP: Re-queueing for BG in 15 seconds..."];
			[self performSelector: @selector(pvpQueueBattleground) withObject: nil afterDelay: 15.0f];
		}
	}
	
	// Player just joined the BG!
	else if ( !_pvpIsInBG && isPlayerInBG ){
		_pvpIsInBG = YES;
		
		// cancel the PvP checks
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(pvpCheck) object: nil];
		
		if ( self.isPvPing ){
			_pvpMarks = [itemController pvpMarks];
			
			if( [controller sendGrowlNotifications] && [GrowlApplicationBridge isGrowlInstalled] && [GrowlApplicationBridge isGrowlRunning]) {
				// [GrowlApplicationBridge setGrowlDelegate: @""];
				[GrowlApplicationBridge notifyWithTitle: [NSString stringWithFormat: @"Battleground Entered"]
											description: [NSString stringWithFormat: @"Starting bot in 5 seconds."]
									   notificationName: @"BattlegroundEnter"
											   iconData: (([controller reactMaskForFaction: [[playerController player] factionTemplate]] & 0x2) ? [[NSImage imageNamed: @"BannerAlliance"] TIFFRepresentation] : [[NSImage imageNamed: @"BannerHorde"] TIFFRepresentation])
											   priority: 0
											   isSticky: NO
										   clickContext: nil];             
			}
			
			// Start bot after 5 seconds!
			log(LOG_PVP, @"PvP environment valid. Starting bot in 5 seconds...");
			[controller setCurrentStatus: @"PvP: Starting Bot in 5 seconds..."];
			[self performSelector: @selector(startBotForPvP) withObject: nil afterDelay: 5.0f];
		}
	}
	
	
	// We can do some checks in here amirite?
	if ( _pvpIsInBG && isPlayerInBG ){
		
		if ( self.isPvPing ){
			// Play warning!
			if( self.pvpPlayWarning ) {
				if( [auraController unit: player hasAura: IdleSpellID] || [auraController unit: player hasAura: InactiveSpellID]) {
					[[NSSound soundNamed: @"alarm"] play];
					log(LOG_PVP, @"Idle/Inactive debuff detected!");
				}
			}
			
			// Leave BG?
			if( [auraController unit: player hasAura: InactiveSpellID] && self.pvpLeaveInactive ) {
				// leave the battleground
				log(LOG_PVP, @"Leaving battleground due to Inactive debuff.");
				
				[macroController useMacroOrSendCmd:@"LeaveBattlefield"];
			}
		}
		
		// Check to see if we have been awarded a mark!  If so the BG has closed!
		if ( _pvpMarks > 0 && [itemController pvpMarks] > _pvpMarks ){
			
			// Lets stop botting!
			if ( self.isBotting ){
				[self stopBot: nil];
				
				log(LOG_PVP, @"BG has ended, botting stopped. %d > %d", [itemController pvpMarks], _pvpMarks );
				[controller setCurrentStatus: @"PvP: BG has ended, botting stopped."];
			}
		}
	}
	
	if ( !isPlayerInBG && self.isBotting ){
		log(LOG_ERROR, @"WE SHOULD NEVER BE HERE! Why are we botting outside of the BG?!?!?!");
	}
}

- (void)startBotForPvP{
	log(LOG_FUNCTION, @"entering function");
	// Make sure player is valid, sometimes it takes longer than 5 seconds :(
	if ( self.isPvPing ){
		if ( ![playerController playerIsValid:self] ){
			[self performSelector: @selector(startBotForPvP) withObject: nil afterDelay: 1.0f];
			return;
		}
	
		[self startBot:nil];
	}
}

- (void)pvpQueueRetry{
	log(LOG_FUNCTION, @"entering function");
	if ( [playerController battlegroundStatus] != BGNone ){
		return;
	}
	
	log(LOG_PVP, @"Still not queued, trying again!");
	[macroController useMacroOrSendCmd:@"JoinBattlefield"];
	
	float nextCheck = SSRandomFloatBetween(1.0f, 5.0f);
	[self performSelector: @selector(pvpQueueRetry) withObject: nil afterDelay:nextCheck];
}

- (void)pvpQueueBattleground{
	log(LOG_FUNCTION, @"entering function");
	if(!self.isPvPing)										return;
	if(![playerController playerIsValid:self])				return;
	if ([playerController isInBG:[playerController zone]])	return;
	
	if ( [playerController battlegroundStatus] == BGQueued ){
		log(LOG_PVP, @"Already queued, no need to try again!");
		return;
	}
	
	// check for deserter
    if( [auraController unit: [playerController player] hasAura: DeserterSpellID] ) {
		[controller setCurrentStatus: @"PvP: Waiting for deserter to fade..."];
		
		// Will jump once every 1-3 minutes
        if(self.pvpCheckCount++ >= 4) {
            self.pvpCheckCount = 0;
            if(![controller isWoWChatBoxOpen]) {
				[self noAFK];
			}
        }
		
		// make sure pvpCheck isn't going - it shouldn't be
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(pvpCheck) object: nil];
		
		float nextQueueAttempt = SSRandomFloatBetween(15.0f, 45.0f);
		[self performSelector: @selector(pvpQueueBattleground) withObject: nil afterDelay:nextQueueAttempt];
        return;
    }
	
	log(LOG_PVP, @"Queueing...");
	
	// Open PvP screen
	[chatController sendKeySequence:[NSString stringWithFormat: @"%c", 'h']];
	usleep(10000);
	
	// Lets queue!
	[macroController useMacroOrSendCmd:@"JoinBattlefield"];
	        
	[self noAFK];
	self.pvpCheckCount = 0;
	[controller setCurrentStatus: @"PvP: Waiting to join Battleground."];
	[self pvpCheck];
	
	// To account for sometimes the queue failing, lets try to join after minute or two just in case?
	float nextCheck = SSRandomFloatBetween(60.0f, 120.0f);
	[self performSelector: @selector(pvpQueueBattleground) withObject: nil afterDelay:nextCheck];
	
	// try to queue again in case it failed!
	[self performSelector: @selector(pvpQueueRetry) withObject: nil afterDelay:1.0f];
}

// this will keep us from going afk
- (void)pvpCheck {
	log(LOG_FUNCTION, @"entering function");
	if(![playerController playerIsValid:self])   return;
	
    if(self.isPvPing) {
		if ( [playerController isInBG:[playerController zone]] ){
			return;
		}
		
        [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(pvpCheck) object: nil];
        
		// Will jump once every minute
        if(self.pvpCheckCount++ >= 60) {
            self.pvpCheckCount = 0;
            [self noAFK];
        }
		
        [self performSelector: @selector(pvpCheck) withObject: nil afterDelay: 1.0f];
    }
}

- (NSString*)pvpButtonTitle {
    if(self.isPvPing)   return @"Stop PvP";
    else                return @"Start PvP";
}

- (void)pvpStop {
    [self stopBot: nil];
    
    self.isPvPing = NO;
    self.pvpLeaveInactive = NO;
    self.pvpPlayWarning = NO;
    self.pvpCheckCount = 0;
	
	[_pvpTimer invalidate]; _pvpTimer = nil;
	
    log(LOG_PVP, @"PvP Stopped.");
    
    [self willChangeValueForKey: @"pvpButtonTitle"];
    [self didChangeValueForKey: @"pvpButtonTitle"];
}

- (void)pvpStart {
	log(LOG_FUNCTION, @"entering function");
    Player *player = [playerController player];
    if(![player isValid]) return;
	
	// If we're not PvPing - we want to start!
    if(!self.isPvPing) {
		[chatController sendKeySequence:[NSString stringWithFormat: @"%c", 'h']];

        if(([controller reactMaskForFaction: [player factionTemplate]] & 0x2)) {
            [pvpBannerImage setImage: [NSImage imageNamed: @"BannerAlliance"]];
        } else {
            [pvpBannerImage setImage: [NSImage imageNamed: @"BannerHorde"]];
        }
        
        [NSApp beginSheet: pvpBMSelectPanel
           modalForWindow: [self.view window]
            modalDelegate: self
           didEndSelector: @selector(pvpSheetDidEnd: returnCode: contextInfo:)
              contextInfo: nil];
        return;
    }
	
	// Reset our start date!
	self.startDate = [[NSDate date] retain];
	
	// Close the PvP window!
	[chatController sendKeySequence:[NSString stringWithFormat: @"%c", 'h']];
	
    self.pvpCheckCount = 0;
    self.pvpPlayWarning = [pvpPlayWarningCheckbox state];
    self.pvpLeaveInactive = [pvpLeaveInactiveCheckbox state];
    
    // off we go...?
    log(LOG_PVP, @"PvP Starting...");
	[self pvpQueueBattleground];
	
	// Start our monitor!
	_pvpIsInBG = NO;
	_pvpTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0f target: self selector: @selector(pvpMonitor:) userInfo: nil repeats: YES];
    
    [self willChangeValueForKey: @"pvpButtonTitle"];
    [self didChangeValueForKey: @"pvpButtonTitle"];
}

- (IBAction)pvpStartStop: (id)sender {
    if(self.isPvPing) {
        [self pvpStop];
    } else {
        [self pvpStart];
    }
}

- (void)pvpSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    [pvpBMSelectPanel orderOut: nil];

    if(returnCode == NSCancelButton) {
		self.isPvPing = NO;
        return;
    }
    
    if(returnCode == NSOKButton) {
		self.isPvPing = YES;
        [self pvpStart];
    }
}

- (IBAction)pvpBMSelectAction: (id)sender {
    [NSApp endSheet: pvpBMSelectPanel returnCode: [sender tag]];
}

- (IBAction)pvpTestWarning: (id)sender {
    [[NSSound soundNamed: @"alarm"] play];
}

#pragma mark Timers

- (void)logOutTimer: (NSTimer*)timer {
	if ( !self.isBotting )
		log(LOG_ERROR, @"We should never be here!!");
	
	BOOL logOutNow = NO;
	NSString *logMessage = nil;
	
	// check for full inventory
	if ( [logOutOnFullInventoryCheckbox state] && [itemController arePlayerBagsFull] ){
		logOutNow = YES;
		logMessage = @"Inventory full, closing game";
	}
	
	// check for timer
	if ( [logOutOnTimerExpireCheckbox state] && self.startDate ){
		float hours = [logOutAfterRunningTextField floatValue];
		NSDate *stopDate = [[NSDate alloc] initWithTimeInterval:hours * 60 * 60 sinceDate:self.startDate];
		
		// check to see which date is earlier
		if ( [stopDate earlierDate: [NSDate date] ] == stopDate ){
			logOutNow = YES;
			logMessage = [NSString stringWithFormat:@"Timer expired after %0.2f hours! Logging out!", hours];
		}
	}
	
	// check durability
	if ( [logOutOnBrokenItemsCheckbox state] ){
		float averageDurability = [itemController averageWearableDurability];
		float durabilityPercentage = [logOutAfterRunningTextField floatValue];
		
		if ( averageDurability > 0 && averageDurability < durabilityPercentage ){
			logOutNow = YES;
			logMessage = [NSString stringWithFormat:@"Item durability has reached %02.f, logging out!", averageDurability];
		}
	}
	
	// time to stop botting + log!
	if ( logOutNow ){
		log(LOG_GENERAL, @"%@", logMessage);
		[self logOut];
		[self updateStatus: [NSString stringWithFormat:@"Bot: %@", logMessage]];
	}
}

// called every 30 seconds
- (void)afkTimer: (NSTimer*)timer {
	log(LOG_FUNCTION, @"entering function");
	
	// don't need this if we're botting since we're doing things!
	if ( self.isBotting || ![playerController playerIsValid] )
		return;
	
	log(LOG_AFK, @"Attempt: %d", _afkTimerCounter);
	
	
	if ( [antiAFKButton state] ){
		_afkTimerCounter++;
		
		// then we are at 4 minutes
		if ( _afkTimerCounter > 8 ){

			[self noAFK];
			
			_afkTimerCounter = 0;
		}
	}
}

// call this to prevent afk!
- (void)noAFK{
	log(LOG_FUNCTION, @"entering function");
	// move backward!
	if ( _lastPressedWasForward ){
		[movementController moveBackwardStop];
		_lastPressedWasForward = NO;
		log(LOG_AFK, @"Moving backward!");
	}
	// move forward!
	else{
		[movementController moveForwardStop];
		_lastPressedWasForward = YES;
		log(LOG_AFK, @"Moving forward!");
	}
}

- (void)wgTimer: (NSTimer*)timer {
	log(LOG_FUNCTION, @"entering function");
	
	// WG zone ID: 4197
	if ( [autoJoinWG state] && ![playerController isDead] && [playerController zone] == 4197 && [playerController playerIsValid] ){
		
		NSDate *currentTime = [NSDate date];
		
		// then we are w/in the first hour after we've done a WG!  Let's leave party!
		if ( _dateWGEnded && [currentTime timeIntervalSinceDate: _dateWGEnded] < 3600 ){
			// check to see if they are in a party - and leave!
			UInt32 offset = [offsetController offset:@"PARTY_LEADER_PTR"];
			UInt64 guid = 0;
			if ( [[controller wowMemoryAccess] loadDataForObject: self atAddress: offset Buffer: (Byte *)&guid BufLength: sizeof(guid)] && guid ){
				
				[macroController useMacroOrSendCmd:@"LeaveParty"];
				log(LOG_PVP, @"Player is in party leaving!");				
			}
			
			log(LOG_PVP, @"Leaving party anyways - there a leader? 0x%qX", guid);
			[macroController useMacroOrSendCmd:@"LeaveParty"];
		}
		
		// only autojoin if it's 2 hours+ after a WG end
		if ( _dateWGEnded && [currentTime timeIntervalSinceDate: _dateWGEnded] <= 7200 ){
			log(LOG_PVP, @"Not autojoing WG since it's been %0.2f seconds", [currentTime timeIntervalSinceDate: _dateWGEnded]);
			return;
		}
		
		// should we auto accept quests too? o.O
		
		// click the button!
		[macroController useMacroOrSendCmd:@"ClickFirstButton"];
		log(LOG_PVP, @"Autojoining WG!  Seconds since last WG: %0.2f", [currentTime timeIntervalSinceDate: _dateWGEnded]);
		
		// check how many marks they have (if it went up, we need to leave the group)!
		Item *item = [itemController itemForID:[NSNumber numberWithInt:43589]];
		if ( item && [item isValid] ){
			
			// it's never been set - /cry - lets set it!
			if ( _lastNumWGMarks == 0 ){
				_lastNumWGMarks = [item count];
				log(LOG_PVP, @"Setting wintegrasp mark counter to %d", _lastNumWGMarks);
			}
			
			// the player has more!
			if ( _lastNumWGMarks != [item count] ){
				_lastNumWGMarks = [item count];
				
				log(LOG_PVP, @"Wintergrasp over you now have %d marks! Leaving group!", _lastNumWGMarks);
				[macroController useMacroOrSendCmd:@"LeaveParty"];
				
				// update our time
				log(LOG_PVP, @"It's been %0.2f:: opens seconds since we were last given marks!", [currentTime timeIntervalSinceDate: _dateWGEnded]);
				[_dateWGEnded release]; _dateWGEnded = nil;
				_dateWGEnded = [[NSDate date] retain];
			}
		}
	}
}

- (BOOL)performAction: (int32_t) actionID{
	log(LOG_FUNCTION, @"entering function");
	MemoryAccess *memory = [controller wowMemoryAccess];
	
	if ( !memory )
		return NO;
	
	UInt32 oldActionID = 0;
	UInt32 cooldown = [controller refreshDelay]*2;
	KeyCombo hotkey = [shortcutRecorder keyCombo];
	_currentHotkeyModifier = hotkey.flags;
	_currentHotkey = hotkey.code;
	
	// save the old spell + write the new one
	[memory loadDataForObject: self atAddress: ([offsetController offset:@"HOTBAR_BASE_STATIC"] + BAR6_OFFSET) Buffer: (Byte *)&oldActionID BufLength: sizeof(oldActionID)];
	[memory saveDataForAddress: ([offsetController offset:@"HOTBAR_BASE_STATIC"] + BAR6_OFFSET) Buffer: (Byte *)&actionID BufLength: sizeof(actionID)];
	//PGLog(@"Saved spell %li ; Wrote spell %li to 0x%X", oldActionID, actionID, ([offsetController offset:@"HOTBAR_BASE_STATIC"] + BAR6_OFFSET));
	
	// write gibberish to the error location
	char string[3] = {'_', '_', '\0'};
	[[controller wowMemoryAccess] saveDataForAddress: [offsetController offset:@"LAST_RED_ERROR_MESSAGE"] Buffer: (Byte *)&string BufLength:sizeof(string)];
	
	// wow needs time to process the spell change
	usleep(cooldown);

	// then post keydown if the chat box is not open
	if(![controller isWoWChatBoxOpen] || (_currentHotkey == kVK_F13)) {
		[chatController pressHotkey: _currentHotkey withModifier: _currentHotkeyModifier];
		_lastSpellCastGameTime = [playerController currentTime];
	}
	else {
		log(LOG_ERROR, @"Can't cast. Chat box is open");
	}
	
	// wow needs time to process the spell change before we change it back
	usleep(cooldown*2);
	
	// then save our old action back
	[memory saveDataForAddress: ([offsetController offset:@"HOTBAR_BASE_STATIC"]+BAR6_OFFSET) Buffer: (Byte *)&oldActionID BufLength: sizeof(oldActionID)];
	//PGLog(@"Restored spell %i", oldActionID);
	
	// We don't want to check lastAttemptedActionID if it's not a spell!
	if ( (USE_ITEM_MASK & actionID) || (USE_MACRO_MASK & actionID) ){
		return ErrNone;
	}
	
	// give WoW time to write to memory in case the spell didn't cast
	usleep(cooldown);
	
	_lastActionTime = [playerController currentTime];
	
	if ( ![[playerController lastErrorMessage] isEqualToString:@"__"] )
	{
		log(LOG_COMBAT, @"Spell %@ failed on %@ : %@ (%d)", [spellController spellForID:[NSNumber numberWithInt:actionID]] , [playerController lastErrorMessage], [combatController attackUnit], [self errorValue:[playerController lastErrorMessage]]);
	//}
	
	// did the spell not cast?
	//if ( [spellController lastAttemptedActionID] == actionID ){
		
		int lastErrorMessage = [self errorValue:[playerController lastErrorMessage]];
		 _lastActionErrorCode = lastErrorMessage;
		 //log(LOG_COMBAT, @"Spell (%d) didn't cast(%d): %@", actionID, lastErrorMessage, [playerController lastErrorMessage] );

		 // do something?
		 if ( lastErrorMessage == ErrSpellNot_Ready){
			 [[NSNotificationCenter defaultCenter] postNotificationName: ErrorSpellNotReady object: nil];	
		 }
		 else if ( lastErrorMessage == ErrTargetNotInLOS ){
			 [[NSNotificationCenter defaultCenter] postNotificationName: ErrorTargetNotInLOS object: nil];	
		 }
		 else if ( lastErrorMessage == ErrInvalidTarget ){
			 [[NSNotificationCenter defaultCenter] postNotificationName: ErrorInvalidTarget object: nil];
		 }
		 else if ( lastErrorMessage == ErrTargetOutRange ){
			 [[NSNotificationCenter defaultCenter] postNotificationName: ErrorOutOfRange object: nil];
		 }
		 else if ( lastErrorMessage == ErrCantAttackMounted || lastErrorMessage == ErrYouAreMounted ){
			 if ( ![playerController isOnGround] ){
				 [movementController dismount];
			 }
		 }
		 else if ( lastErrorMessage == ErrTargetNotInFrnt || lastErrorMessage == ErrWrng_Way ){
			 [[NSNotificationCenter defaultCenter] postNotificationName: ErrorTargetNotInFront object: nil];
		 }
		 
		 return lastErrorMessage;
	}

	return ErrNone;
}

- (int)errorValue: (NSString*) errorMessage{
	if (  [errorMessage isEqualToString: INV_FULL] ){
		return ErrInventoryFull;
	}
	else if ( [errorMessage isEqualToString:TARGET_LOS] ){
		return ErrTargetNotInLOS;
	}
	else if ( [errorMessage isEqualToString:SPELL_NOT_READY] ){
		return ErrSpellNotReady;
	}
	else if ( [errorMessage isEqualToString:TARGET_FRNT] ){
		log(LOG_COMBAT, @"TARGET IS NOT IN FRONT OF YOU!");
		return ErrTargetNotInFrnt;
	}
	else if ( [errorMessage isEqualToString:CANT_MOVE] ){
		return ErrCantMove;
	}
	else if ( [errorMessage isEqualToString:WRNG_WAY] ){
		return ErrWrng_Way;
	}
	else if ( [errorMessage isEqualToString:ATTACK_STUNNED] ){
		return ErrAttack_Stunned;
	}
	else if ( [errorMessage isEqualToString:NOT_YET] ){
		return ErrSpell_Cooldown;
	}
	else if ( [errorMessage isEqualToString:SPELL_NOT_READY2] ){
		return ErrSpellNot_Ready;
	}
	else if ( [errorMessage isEqualToString:NOT_RDY2] ){
		return ErrSpellNot_Ready;
	}
	else if ( [errorMessage isEqualToString:TARGET_RNGE] ){
		return ErrTargetOutRange;
	}
	else if ( [errorMessage isEqualToString:TARGET_RNGE2] ){
		return ErrTargetOutRange;
	}
	else if ( [errorMessage isEqualToString:INVALID_TARGET] ){
		return ErrInvalidTarget;
	}
	else if ( [errorMessage isEqualToString:CANT_ATTACK_MOUNTED] ){
		return ErrCantAttackMounted;
	}
	else if ( [errorMessage isEqualToString:YOU_ARE_MOUNTED] ){
		return ErrYouAreMounted;
	}

	return ErrNotFound;
}


- (void)interactWithMob:(UInt32)entryID {
	log(LOG_FUNCTION, @"entering function");
	Mob *mobToInteract = [mobController closestMobForInteraction:entryID];
	
	if([mobToInteract isValid]) {
		[self interactWithMouseoverGUID:[mobToInteract GUID]];
	}
}

- (void)interactWithNode:(UInt32)entryID {
	log(LOG_FUNCTION, @"entering function");
	Node *nodeToInteract = [nodeController closestNodeForInteraction:entryID];
	
	if([nodeToInteract isValid]) {
		[self interactWithMouseoverGUID:[nodeToInteract GUID]];
	}
	else{
		log(LOG_LOOT, @"Node %d not found, unable to interact", entryID);
	}
}

// This will set the GUID of the mouseover + trigger interact with mouseover!
- (BOOL)interactWithMouseoverGUID: (UInt64) guid{
	log(LOG_FUNCTION, @"entering function");
	if ( [[controller wowMemoryAccess] saveDataForAddress: ([offsetController offset:@"TARGET_TABLE_STATIC"] + TARGET_MOUSEOVER) Buffer: (Byte *)&guid BufLength: sizeof(guid)] ){
		
		// wow needs time to process the change
		usleep([controller refreshDelay]);
		
		// Use our hotkey!
		KeyCombo hotkey = [mouseOverRecorder keyCombo];
		
		if ( hotkey.code < 0 ){
			return NO;
		}
		
		// Send out "interact with mouse over" keybinding!
		if(![controller isWoWChatBoxOpen] || (_currentHotkey == kVK_F13)) {
			[chatController pressHotkey: hotkey.code  withModifier: hotkey.flags];
			
			return YES;
		}
	}
	
	return NO;
}

// Simply will log us out!
- (void)logOut{
	log(LOG_FUNCTION, @"entering function");
	
	if ( [logOutUseHearthstoneCheckbox state] && (_zoneBeforeHearth == -1) ){
		
		// Can only use if it's not on CD!
		if ( ![spellController isSpellOnCooldown:HearthStoneSpellID] ){
			
			_zoneBeforeHearth = [playerController zone];
			// Use our hearth
			UInt32 actionID = (USE_ITEM_MASK + HearthstoneItemID);
			[self performAction:actionID];
			
			// Kill bot + log out
			[self performSelector:@selector(logOut) withObject: nil afterDelay:25.0f];
			
			return;
		}
	}
	
	// The zones *should* be different
	if ( [logOutUseHearthstoneCheckbox state] ){
		if ( _zoneBeforeHearth != [playerController zone] ){
			log(LOG_GENERAL, @"Hearth successful from zone %d to %d", _zoneBeforeHearth, [playerController zone]);
		}
		else{
			log(LOG_GENERAL, @"Sorry hearth failed for some reason (on CD?), still closing WoW!");
		}
	}
	
	// Reset our variable in case the player fires up wow again later
	_zoneBeforeHearth = -1;
	
	// Stop the bot
	[self pvpStop];
	[self stopBot: nil];
	usleep(1000000);
		
	// Kill the process
	[controller killWOW];
}

// check if units are nearby
- (BOOL)scaryUnitsNearNode: (WoWObject*)node doMob:(BOOL)doMobCheck doFriendy:(BOOL)doFriendlyCheck doHostile:(BOOL)doHostileCheck{
	log(LOG_FUNCTION, @"entering function");
	if ( doMobCheck ){
		log(LOG_NODE, @"Scanning nearby mobs within %0.2f of %@", _nodeIgnoreMobDistance, [node position]);
		NSArray *mobs = [mobController mobsWithinDistance: _nodeIgnoreMobDistance MobIDs:nil position:[node position] aliveOnly:YES];
		if ( [mobs count] ){
			log(LOG_NODE, @"There %@ %d scary mob(s) near the node, ignoring %@", ([mobs count] == 1) ? @"is" : @"are", [mobs count], node);
			return YES;
		}
	}
	if ( doFriendlyCheck ){
		if ( [playersController playerWithinRangeOfUnit: _nodeIgnoreFriendlyDistance Unit:(Unit*)node includeFriendly:YES includeHostile:NO] ){
			log(LOG_NODE, @"Friendly player(s) near node, ignoring %@", node);
			return YES;
		}
	}
	if ( doHostileCheck ){
		if ( [playersController playerWithinRangeOfUnit: _nodeIgnoreHostileDistance Unit:(Unit*)node includeFriendly:NO includeHostile:YES] ){
			log(LOG_NODE, @"Hostile player(s) near node, ignoring %@", node);
			return YES;
		}
	}
	
	return NO;
}

- (UInt8)isHotKeyInvalid{
	log(LOG_FUNCTION, @"entering function");
	
	// We know it's not set if flags are 0 or code is -1 then it's not set!
	UInt8 flags = 0;

	// Check start/stop hotkey
	KeyCombo combo = [startstopRecorder keyCombo];
	if ( combo.code == -1 ){
		flags |= HotKeyStartStop;
	}
	
	// Check Interact with
	combo = [mouseOverRecorder keyCombo];
	if ( combo.code == -1 ){
		flags |= HotKeyInteractMouseover;
	}
	
	// Check Bottom Left Action Bar
	combo = [shortcutRecorder keyCombo];
	if ( combo.code == -1 ){
		flags |= HotKeyPrimary;
	}
	
	// Check Pet attack
	combo = [petAttackRecorder keyCombo];
	if ( combo.code == -1 ){
		flags |= HotKeyPetAttack;
	}
	
	return flags;	
}

- (char*)randomString: (int)maxLength{
	log(LOG_FUNCTION, @"entering function");
	// generate a random string to write
	int i, len = SSRandomIntBetween(3,maxLength);
	char *string = (char*)malloc(len);
	char randomChar = 0;
    for (i = 0; i < len; i++) {
        while (YES) {
            randomChar = SSRandomIntBetween(0,128);
            if (((randomChar >= '0') && (randomChar <= '9')) || ((randomChar >= 'a') && (randomChar <= 'z'))) {
                string[i] = randomChar;
                break; // we found an alphanumeric character, move on
            }
        }
    }
	string[i] = '\0';
	
	return string;
}

//0x1555BE0
- (IBAction)test: (id)sender{
	
	
	//[playerController isOnRightBoatInStrand];
	
	MemoryAccess *memory = [controller wowMemoryAccess];
	int v0=0,i=0,tmp=0,ptr=0;
	[memory loadDataForObject: self atAddress: 0xF2020C Buffer: (Byte*)&ptr BufLength: sizeof(ptr)];
	[memory loadDataForObject: self atAddress: ptr + 0xB4 Buffer: (Byte*)&v0 BufLength: sizeof(v0)];

	PGLog(@"[Test] v0: %lx", v0);
	
	if ( v0 & 1 || !v0 )
		v0 = 0;
	
	int type = 0;
	for ( i = 0; !(v0 & 1); ){
		[memory loadDataForObject: self atAddress: ptr + 0xA8 Buffer: (Byte*)&tmp BufLength: sizeof(tmp)];
		[memory loadDataForObject: self atAddress: tmp + v0 + 0x04 Buffer: (Byte*)&v0 BufLength: sizeof(v0)];
		[memory loadDataForObject: self atAddress: v0 + 0x10 Buffer: (Byte*)&type BufLength: sizeof(type)];
		PGLog(@"[Test] Address: 0x%X %d", v0, type);
		if ( !v0 || i > 10)
			break;
		++i;
	}
	
	PGLog(@"[Test] Total : %d", i);
	
	int v2=0, v3=0;
	[memory loadDataForObject: self atAddress: ptr + 0x0C Buffer: (Byte*)&v2 BufLength: sizeof(v2)];
	if ( v2 & 1 || !v2 )
		v2 = 0;
	v3 = 0;
	
	/*
	int v0; // eax@1
	int i; // edi@3
	int v2; // eax@6
	int v3; // esi@8
	int v4; // eax@12
	int v5; // eax@16
	int v6; // ebx@18
	
	v0 = *(_DWORD *)(dword_10E760C + 180);
	if ( v0 & 1 || !v0 )
		v0 = 0;
	for ( i = 0; !(v0 & 1); v0 = *(_DWORD *)(*(_DWORD *)(dword_10E760C + 172) + v0 + 4) )
	{
		if ( !v0 )
			break;
		++i;
	}
	v2 = *(_DWORD *)(dword_10E760C + 12);
	if ( v2 & 1 || !v2 )
		v2 = 0;
	v3 = 0;
LABEL_9:
	if ( !(v2 & 1) )
	{
		while ( v2 )
		{
			++v3;
			if ( v2 )
				v4 = *(_DWORD *)(dword_10E760C + 4) + v2;
			else
				v4 = dword_10E760C + 8;
			v2 = *(_DWORD *)(v4 + 4);
			if ( v2 & 1 )
			{
				v2 = 0;
			}
			else
			{
				if ( v2 )
					goto LABEL_9;
				v2 = 0;
			}
			if ( v2 & 1 )
				break;
		}
	}
	v5 = *(_DWORD *)(dword_10E760C + 56);
	if ( v5 & 1 || !v5 )
		v5 = 0;
	v6 = 0;
LABEL_19:
	if ( !(v5 & 1) )
	{
		while ( v5 )
		{
			++v6;
			v5 = *(_DWORD *)(*(_DWORD *)(dword_10E760C + 48) + v5 + 4);
			if ( v5 & 1 )
			{
				v5 = 0;
			}
			else
			{
				if ( v5 )
					goto LABEL_19;
				v5 = 0;
			}
			if ( v5 & 1 )
				break;
		}
	}
	sub_1214D0("Object manager list status:", 7);
	sub_122110("    Active objects:              %u objects (%u visible)", 7, v3);
	sub_122110("    Objects waiting to be freed: %u objects", 7, v6, i);
	return 1;
*/	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	return;
	
	
	
	
	
	
	
	//0-2pi. North is 0, west is pi/2, south is pi, east is 3pi/2.
	
	float direction = [playerController directionFacing];
	int quadrant = 0;
	
	if ( 0.0f < direction && direction <= M_PI/2.0f ){
		quadrant = 1;
	}
	else if ( M_PI/2.0f < direction && direction <= M_PI ){
		quadrant = 2;
	}
	else if ( M_PI < direction && direction <= (3*M_PI)/2.0f ){
		quadrant = 3;
	}
	else if ( (3.0f*M_PI)/2.0f < direction && direction <= 2*M_PI ){
		quadrant = 4;
	}
	
	Node *nearbySchool = [fishController nearbySchool];
	float x,y;
	
	if ( nearbySchool ){
		//Position *schoolPos = [nearbySchool position];
		float closeness = 10.0f;

		if ( quadrant == 1 ){
			x = - (sinf(direction) * closeness);
			y = cosf(direction) * closeness;
		}
		else if ( quadrant == 2 ){
			x = - (sinf(direction) * closeness);
			y = cosf(direction) * closeness;	
		}
		else if ( quadrant == 3 ){
			x = - (sinf(direction) * closeness);
			y = cosf(direction) * closeness;
		}
		else if ( quadrant == 4 ){
			x = - (sinf(direction) * closeness);
			y = cosf(direction) * closeness;
		}
		
		PGLog(@"Change in position: {%0.2f, %0.2f} Quadrant %d", x, y, quadrant);
		
	}
	
	//[controller traverseNameList];
	/*

	PGLog(@"After  write:'%@'", [playerController lastErrorMessage]);
	NSString *lastErrorMessageAltered = [playerController lastErrorMessage];*/
	//free(string);

	
	//(BOOL)saveDataForAddress: (UInt32)address Buffer: (Byte *)DataBuffer BufLength: (vm_size_t)Bytes;
	
	/*
	CombatProfile *profile = [[combatProfilePopup selectedItem] representedObject];
	PGLog(@"Currently selected object: %@  %@", profile, [profile name]);
	PGLog(@"Attack range: %0.2f", [profile attackRange]);
	
	if([[profile name] length]) {
        for(CombatProfile *prof in [combatProfileEditor combatProfiles]) {
            if( [[profile name] isEqualToString: [prof name]] ) {
				PGLog(@"LOOPED: %@ with %0.2f" , prof, [prof attackRange]);
                break;
            }
        }
    }
	
	PGLog(@"CURRENT PROFILE: %@ %0.2f", self.theCombatProfile, [self.theCombatProfile  attackRange]);
	
	
	
	Position *playerPosition = [playerController position];
	Position *destination = [Position positionWithX:5486.823f Y:297.879f Z:147.4111];
	Position *pos = [destination positionAtDistance:15.0f withDestination:playerPosition];
	
	PGLog(@"10 yards from %@ is %@", destination, pos);
	//[movementController turnToward:pos];
	
	[movementController moveNearPosition:pos andCloseness:0.0f];
	
	
	
	*/
	
	
	
	/*if ( self.theCombatProfile == nil )
		self.theCombatProfile = [[combatProfilePopup selectedItem] representedObject];
	
	
	PGLog(@"Attack range: %0.2f", self.theCombatProfile.attackRange);
	PGLog(@"[Bot] Current best target: %@", [combatController findBestUnitToAttack]);*/
	
	

}

#define ACCOUNT_NAME_SEP	@"SET accountName \""
#define ACCOUNT_LIST_SEP	@"SET accountList \""
/*
 
SET accountName "myemail@hotmail.com"
SET accountList "!ACCOUNT1|ACCOUNT2|"
 */
- (IBAction)login: (id)sender{
	log(LOG_FUNCTION, @"entering function");
	//LOGIN_STATE		this will be "login", "charselect", or "charcreate"
	//	note: it will stay in it's last state even if we are logged in + running around!
	
	//LOGIN_SELECTED_CHAR - we want to write the position to memory, the chosen won't change on screen, but it will log into that char!
	//	values: 0-max
	
	//LOGIN_TOTAL_CHARACTERS - obviously the total number of characters on the selection screen
	
	NSString *account = @"MyBNETAccount12312";
	NSString *password = @"My1337Password";
	NSString *accountList = @"!Accoun23t1|Accoun1t2|";
	
	
	
	// ***** GET THE PATH TO OUR CONFIG FILE
	NSString *configFilePath = [controller wowPath];
	// will be the case if wow is closed (lets go with the default option?)
	if ( [configFilePath length] == 0 ){
		[configFilePath release]; configFilePath = nil;
		configFilePath = @"/Applications/World of Warcraft/WTF/Config.wtf";
	}
	// we have a dir
	else{
		configFilePath = [configFilePath stringByDeletingLastPathComponent];
		configFilePath = [configFilePath stringByAppendingPathComponent: @"WTF/Config.wtf"];	
	}

	
	// ***** GET OUR CONFIG FILE DATA + BACK IT UP!
	NSString *configData = [[NSString alloc] initWithContentsOfFile:configFilePath];
	NSMutableString *newConfigFile = [NSMutableString string];
	NSMutableString *configFileBackup = [NSString stringWithFormat:@"%@.bak", configFilePath];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ( ![fileManager fileExistsAtPath:configFilePath] || [configData length] == 0 ){
		log(LOG_ERROR, @"Unable to find config file at path '%@'. Aborting.", configFilePath);
		return;
	}
	// should we create a backup file?
	if ( ![fileManager fileExistsAtPath:configFileBackup] ){
		if ( ![configData writeToFile:configFileBackup atomically:YES encoding:NSUnicodeStringEncoding error:nil] ){
			log(LOG_ERROR, @"Unable to backup existing config file to '%@'. Aborting", configFileBackup);
			return;
		}
	}
	
	// if we get here we have a config file! And have backed it up!
	
	
	// Three conditions for information in this file:
	//	1. Account list and Account name are set
	//	2. Account list is set (when remember checkbox was once checked, but is no longer)
	//	3. Neither exist in config file
	if ( configData != nil ){
		
		NSScanner *scanner = [NSScanner scannerWithString: configData];
		
		BOOL accountNameFound = NO;
		BOOL accountListFound = NO;
		NSString *beforeAccountName = nil;
		NSString *beforeAccountList = nil;

        // get the account name?
		int scanSave = [scanner scanLocation];
		log(LOG_GENERAL, @"Location: %d", [scanner scanLocation]);
        if([scanner scanUpToString: ACCOUNT_NAME_SEP intoString: &beforeAccountName] && [scanner scanString: ACCOUNT_NAME_SEP intoString: nil]) {
            NSString *newName = nil;
            if ( [scanner scanUpToString: @"\"" intoString: &newName] && newName && [newName length] ) { 
				log(LOG_GENERAL, @"Account name: %@", newName);
				accountNameFound = YES;
            }
        }
		
		// if the user doesn't have "remember" checked, the above search will fail, so lets reset to find the account list! (maybe?)
		if ( !accountNameFound ){
			[scanner setScanLocation: scanSave];
		}
		
		// get the account list
		scanSave = [scanner scanLocation];
		log(LOG_GENERAL, @"Location: %d %d", [scanner scanLocation], [beforeAccountName length]);
        if ( [scanner scanUpToString: ACCOUNT_LIST_SEP intoString: &beforeAccountList] && [scanner scanString: ACCOUNT_LIST_SEP intoString: nil] ) {
            NSString *newName = nil;
            if ( [scanner scanUpToString: @"\"" intoString: &newName] && newName && [newName length] ) {
				log(LOG_GENERAL, @"Account list: %@", newName);
				accountListFound = YES;
            }
        }
		
		// reset the location, in case we have info after our login info + can add it back to the config file!
		if ( !accountListFound ){
			[scanner setScanLocation: scanSave];
		}
		log(LOG_GENERAL, @"Location: %d %d", [scanner scanLocation], [beforeAccountList length]);
		// save what we have left in the scanner! There could be config data after our account name!
		NSString *endOfConfigFileData = [[scanner string]substringFromIndex:[scanner scanLocation]];
		
		// condition 1: we have an existing account! we need to replace it (and potentially an account list to add)
		if ( accountNameFound ){
			// add our new account name
			[newConfigFile appendString:beforeAccountName];
			[newConfigFile appendString:ACCOUNT_NAME_SEP];
			[newConfigFile appendString:account];
			[newConfigFile appendString:@"\""];
			
			// did we also have an account list to replace?
			if ( [accountList length] ){
				[newConfigFile appendString:@"\n"];
				[newConfigFile appendString:ACCOUNT_LIST_SEP];
				[newConfigFile appendString:accountList];
				[newConfigFile appendString:@"\""];
			}
		}
		
		// condition 2: only the account list was found, add the account name + potentially replace the account list
		else if ( accountListFound ){
			[newConfigFile appendString:beforeAccountList];
			[newConfigFile appendString:ACCOUNT_NAME_SEP];
			[newConfigFile appendString:account];
			[newConfigFile appendString:@"\""];
			
			if ( [accountList length] ){
				[newConfigFile appendString:@"\n"];
				[newConfigFile appendString:ACCOUNT_LIST_SEP];
				[newConfigFile appendString:accountList];
				[newConfigFile appendString:@"\""];
			}
		}
		
		// condition 3: nothing was found
		else{
			[newConfigFile appendString:beforeAccountList];
			[newConfigFile appendString:ACCOUNT_NAME_SEP];
			[newConfigFile appendString:account];
			[newConfigFile appendString:@"\""];
			
			if ( [accountList length] ){
				[newConfigFile appendString:@"\n"];
				[newConfigFile appendString:ACCOUNT_LIST_SEP];
				[newConfigFile appendString:accountList];
				[newConfigFile appendString:@"\""];
			}
		}
		
		// only add data if we found an account name or list!
		if ( ( accountListFound || accountNameFound ) && [endOfConfigFileData length] ){
			[newConfigFile appendString:endOfConfigFileData];
		}

	}

	// write our new config file!
	[newConfigFile writeToFile:configFileBackup atomically:YES encoding:NSUnicodeStringEncoding error:nil];
	log(LOG_GENERAL, @"New config file written to '%@'", configFilePath);
	
	// make sure wow is open
	if ( [controller isWoWOpen] ){
		
		[chatController sendKeySequence:account];
		usleep(50000);
		[chatController sendKeySequence:password];	   
		
	}
}

#define SimonAuraBlueEntryID	185872
#define SimonAuraYellowEntryID	185875
#define SimonAuraRedEntryID		185874
#define SimonAuraGreenEntryID	185873
//#define SimonRelicDischarger	185894
#define SimonApexisRelic		185890

#define BlueCluster				185828
#define GreenCluster			185830
#define RedCluster				185831
#define YellowCluster			185829

- (IBAction)doTheRelicEmanation: (id)sender{
	
	
	// interact with discharger
	// wait 1.2 seconds
	// send macro or command to click!
	
	// MUST rescan after each time, the object change!!
	
	/*Node *green = [nodeController closestNode:SimonAuraGreenEntryID];
	Node *red = [nodeController closestNode:SimonAuraRedEntryID];
	Node *blue = [nodeController closestNode:SimonAuraBlueEntryID];
	Node *yellow = [nodeController closestNode:SimonAuraYellowEntryID];
	
	if ( green == nil ){
		[self performSelector:@selector(doTheRelicEmanation:) withObject:nil afterDelay:0.1f];
		return;
	}
	
	PGLog(@"Green: %@", green);
	PGLog(@"Red: %@", red);
	PGLog(@"Blue: %@", blue);
	PGLog(@"Yellow: %@", yellow);
	
	//NSArray *objects = [NSArray arrayWithObjects:green, red, blue, yellow, nil];
	
	//[memoryViewController monitorObjects:objects];
	
	
	green = [nodeController closestNode:BlueCluster];
	red = [nodeController closestNode:GreenCluster];
	blue = [nodeController closestNode:RedCluster];
	yellow = [nodeController closestNode:YellowCluster];
	
	
	[self monitorObject: green];
	[self monitorObject: red];
	[self monitorObject: blue];
	[self monitorObject: yellow];*/
	
	/*[memoryViewController monitorObject:green];
	[memoryViewController monitorObject:red];
	[memoryViewController monitorObject:blue];
	[memoryViewController monitorObject:yellow];*/
	//[self performSelector:@selector(doTheRelicEmanation:) withObject:nil afterDelay:0.1];
}

- (void)monitorObject: (WoWObject*)obj{
	log(LOG_FUNCTION, @"entering function");
	
	
	UInt32 addr1 = [obj baseAddress] + 0x1F8;
	UInt32 addr2 = [obj baseAddress] + 0x230;
	UInt32 addr3 = [obj baseAddress] + 0x250;
	UInt32 addr4 = [obj baseAddress] + 0x260;
	
	MemoryAccess *memory = [controller wowMemoryAccess];
    if(memory) {
        UInt16 value1 = 0, value2 = 0, value3 = 0, value4 = 0;
        [memory loadDataForObject: self atAddress: addr1 Buffer: (Byte *)&value1 BufLength: sizeof(value1)];
		[memory loadDataForObject: self atAddress: addr2 Buffer: (Byte *)&value2 BufLength: sizeof(value2)];
		[memory loadDataForObject: self atAddress: addr3 Buffer: (Byte *)&value3 BufLength: sizeof(value3)];
		[memory loadDataForObject: self atAddress: addr4 Buffer: (Byte *)&value4 BufLength: sizeof(value4)];

		log(LOG_MEMORY, @"%d %d %d %d %@", value1, value2, value3, value4, obj);
	}
	
	
	if ( [obj isValid] ){
		[self performSelector:@selector(monitorObject:) withObject:obj afterDelay:0.1f];
	}
	else{
		log(LOG_MEMORY, @"%@ is no longer valid...", obj);
	}
	
}

@end


