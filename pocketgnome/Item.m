//
//  Item.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/27/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import "Item.h"
#import "ObjectConstants.h"

enum eItemObject {
    Item_InfoField1     = 0x3C4,
    Item_InfoField2     = 0x3C8,
};

enum eItemFields {
	ITEM_FIELD_OWNER =                  0x18,
	ITEM_FIELD_CONTAINED =              0x20,
	ITEM_FIELD_CREATOR =                0x28,
	ITEM_FIELD_GIFTCREATOR =            0x30,
	ITEM_FIELD_STACK_COUNT =            0x38,
	ITEM_FIELD_DURATION =               0x3C,
	ITEM_FIELD_SPELL_CHARGES =          0x40,
	ITEM_FIELD_SPELL_CHARGES2 =         0x44, // ?
	ITEM_FIELD_SPELL_CHARGES3 =         0x48, // ?
	ITEM_FIELD_SPELL_CHARGES4 =         0x4C, // ?
	ITEM_FIELD_SPELL_CHARGES5 =         0x50, // ?
	ITEM_FIELD_FLAGS =                  0x54,
	ITEM_FIELD_ENCHANTMENT =            0x58,
        // size: 0x90; 12 enchant slots, each size 0xC
	ITEM_FIELD_PROPERTY_SEED =          0xE8,
	ITEM_FIELD_RANDOM_PROPERTIES_ID =   0xEC,
	ITEM_FIELD_ITEM_TEXT_ID =           0xF0,
	ITEM_FIELD_DURABILITY =             0xF4,
	ITEM_FIELD_MAXDURABILITY =          0xF8,
	ITEM_FIELD_PADDING =                0xFC,
	TOTAL_ITEM_FIELDS =                 0x26
};

enum EnchantmentSlot {
    PERM_ENCHANTMENT_SLOT           = 0,
    TEMP_ENCHANTMENT_SLOT           = 1,
    SOCK_ENCHANTMENT_SLOT           = 2,
    SOCK_ENCHANTMENT_SLOT_2         = 3,
    SOCK_ENCHANTMENT_SLOT_3         = 4,
    BONUS_ENCHANTMENT_SLOT          = 5,
    MAX_INSPECTED_ENCHANTMENT_SLOT  = 6,

    PROP_ENCHANTMENT_SLOT_0         = 6,    // used with RandomSuffix
    PROP_ENCHANTMENT_SLOT_1         = 7,    // used with RandomSuffix
    PROP_ENCHANTMENT_SLOT_2         = 8,    // used with RandomSuffix and RandomProperty
    PROP_ENCHANTMENT_SLOT_3         = 9,    // used with RandomProperty
    PROP_ENCHANTMENT_SLOT_4         = 10,   // used with RandomProperty
    MAX_ENCHANTMENT_SLOT            = 11
};
    
enum EnchantmentOffset {
    ENCHANTMENT_ID_OFFSET           = 0,
    ENCHANTMENT_DURATION_OFFSET     = 1,    // really apply time, not duration
    ENCHANTMENT_CHARGES_OFFSET      = 2,
    ENCHANTMENT_MAX_OFFSET          = 3,
};

enum eContainerFields {
	CONTAINER_FIELD_NUM_SLOTS =         0x100,
	CONTAINER_ALIGN_PAD =               0x104,
	CONTAINER_FIELD_SLOT_1 =            0x108,
	TOTAL_CONTAINER_FIELDS =            3
};

// [?] [?] [Sub Type]    [Item Type]
// [?] [?] [EquipLoc 2?] [EquipLoc 1]

enum eEquipLoc
{
	EQUIP_LOC_SHIRT = 4,

	EQUIP_LOC_WAIST = 6,
	EQUIP_LOC_LEGS,
	EQUIP_LOC_FEET,
	EQUIP_LOC_WRIST,
	EQUIP_LOC_HANDS,

	EQUIP_LOC_BACK = 16,
	EQUIP_LOC_MAIN_HAND
};

enum eConsumableTypes
{
	CONSUMABLE_TYPE_CONSUMABLE = 0,
	CONSUMABLE_TYPE_POTION,
	CONSUMABLE_TYPE_ELIXIR,
	CONSUMABLE_TYPE_FLASK,
	CONSUMABLE_TYPE_SCROLL,
	CONSUMABLE_TYPE_FOOD_DRINK,
	CONSUMABLE_TYPE_ITEM_ENHANCEMENT,
	CONSUMABLE_TYPE_BANDAGE,
	CONSUMABLE_TYPE_OTHER
};

enum eContainerTypes
{
	CONTAINER_TYPE_BAG = 0,
	CONTAINER_TYPE_SOUL_BAG,
	CONTAINER_TYPE_HERB_BAG,
	CONTAINER_TYPE_ENCHANTING_BAG,
	CONTAINER_TYPE_ENGINEERING_BAG,
	CONTAINER_TYPE_GEM_BAG,
	CONTAINER_TYPE_MINING_BAG,
	CONTAINER_TYPE_LEATHERWORKING_BAG
};

enum eWeaponTypes
{
	WEAPON_TYPE_ONE_HANDED_AXE = 0,
	WEAPON_TYPE_TWO_HANDED_AXE,
	WEAPON_TYPE_BOW,
	WEAPON_TYPE_GUN,
	WEAPON_TYPE_ONE_HANDED_MACE,
	WEAPON_TYPE_TWO_HANDED_MACE,
	WEAPON_TYPE_POLEARM,
	WEAPON_TYPE_ONE_HANDED_SWORD,
	WEAPON_TYPE_TWO_HANDED_SWORD,
	WEAPON_TYPE_OBSOLETE,
	WEAPON_TYPE_STAVE,
	WEAPON_TYPE_ONE_HANDED_EXOTIC,
	WEAPON_TYPE_TWO_HANDED_EXOTIC,
	WEAPON_TYPE_FIST,
	WEAPON_TYPE_MISC,
	WEAPON_TYPE_DAGGER,
	WEAPON_TYPE_THROWN,
	WEAPON_TYPE_SPEAR,
	WEAPON_TYPE_CROSSBOW,
	WEAPON_TYPE_WAND,
	WEAPON_TYPE_FISHING_POLE
};

enum eGemTypes
{
	GEM_TYPE_RED = 0,
	GEM_TYPE_BLUE,
	GEM_TYPE_YELLOW,
	GEM_TYPE_PURPLE,
	GEM_TYPE_GREEN,
	GEM_TYPE_ORANGE,
	GEM_TYPE_META,
	GEM_TYPE_SIMPLE,
	GEM_TYPE_PRISMATIC
};

enum eArmorTypes
{
	ARMOR_TYPE_MISC = 0,
	ARMOR_TYPE_CLOTH,
	ARMOR_TYPE_LEATHER,
	ARMOR_TYPE_MAIL,
	ARMOR_TYPE_PLATE,
	ARMOR_TYPE_BUCKLER,
	ARMOR_TYPE_SHIED,
	ARMOR_TYPE_LIBRAM,
	ARMOR_TYPE_IDOL,
	ARMOR_TYPE_TOTEM
};

enum eReagentTypes
{
	REAGENT_TYPE_REAGENT = 0
};

enum eProjectileTypes
{
	PROJECTILE_TYPE_WAND_OBSOLETE = 0,
	PROJECTILE_TYPE_BOLT_OBSOLETE,
	PROJECTILE_TYPE_ARROW,
	PROJECTILE_TYPE_BULLET,
	PROJECTILE_TYPE_THROWN_OBSOLETE
};

enum eTradeGoodTypes
{
	TRADE_GOOD_TYPE_TRADE_GOOD = 0,
	TRADE_GOOD_TYPE_PART,
	TRADE_GOOD_TYPE_EXPLOSIVE,
	TRADE_GOOD_TYPE_DEVICE,
	TRADE_GOOD_TYPE_JEWELCRAFTING,
	TRADE_GOOD_TYPE_CLOTH,
	TRADE_GOOD_TYPE_LEATHER,
	TRADE_GOOD_TYPE_METAL_STONE,
	TRADE_GOOD_TYPE_MEAT,
	TRADE_GOOD_TYPE_HEARB,
	TRADE_GOOD_TYPE_ELEMENTAL,
	TRADE_GOOD_TYPE_OTHER,
	TRADE_GOOD_TYPE_ENCHANTING
};

enum eGenericTypes
{
	GENERIC_TYPE_GENERIC = 0
};

enum eRecipeTypes
{
	RECIPE_TYPE_BOOK = 0,
	RECIPE_TYPE_LEATHERWORKING,
	RECIPE_TYPE_TAILORING,
	RECIPE_TYPE_ENGINEERING,
	RECIPE_TYPE_BLACKSMITHING,
	RECIPE_TYPE_COOKING,
	RECIPE_TYPE_ALCHEMY,
	RECIPE_TYPE_FIRST_AID,
	RECIPE_TYPE_ENCHANTING,
	RECIPE_TYPE_FISHING,
	RECIPE_TYPE_JEWELCRAFTING
};

enum eMoneyTypes
{
	MONEY_TYPE_MONEY = 0
};

enum eQuiverTypes
{
	QUIVER_TYPE_OBSOLETE1 = 0,
	QUIVER_TYPE_OBSOLETE2,
	QUIVER_TYPE_QUIVER,
	QUIVER_TYPE_POUCH
};

enum eQuestTypes
{
	QUEST_TYPE_QUEST = 0
};

enum eKeyTypes
{
	KEY_TYPE_KEY= 0,
	KEY_TYPE_LOCKPICK
};

enum ePermanentTypes
{
	PERMANENT_TYPE_PERMANENT = 0
};

enum eMiscTypes
{
	MISC_TYPE_JUNK = 0,
	MISC_TYPE_REAGENT,
	MISC_TYPE_PET,
	MISC_TYPE_HOLIDAY,
	MISC_TYPE_OTHER,
	MISC_TYPE_MOUNT
};

#define CONTAINER_FIELD_SLOT_SIZE       0x8


@interface Item (Internal)
- (UInt32)flags;
@end

@implementation Item

- (id) init
{
    self = [super init];
    if (self != nil) {
        _name = nil;
    }
    return self;
}

+ (id)itemWithAddress: (NSNumber*)address inMemory: (MemoryAccess*)memory {
    return [[[Item alloc] initWithAddress: address inMemory: memory] autorelease];
}

- (void) dealloc
{
    [_name release];
    [_connection release];
    [_downloadData release];
    
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    Item *copy = [[[self class] allocWithZone: zone] initWithAddress: _baseAddress inMemory: _memory];
    [copy setName: [self name]];
    return copy;
}

#pragma mark -

- (NSString*)description {
    int stack = [self count];
    if(stack > 0)
        return [NSString stringWithFormat: @"<Item \"%@\" (%d)>", [self name], [self entryID]];
    else
        return [NSString stringWithFormat: @"<Item \"%@\" (%d) x%d>", [self name], [self entryID], stack];
}

#pragma mark -

- (NSString*)name {

    NSNumber *temp = nil;
    @synchronized (@"Name") {
        temp = [_name retain];
    }
    return [temp autorelease];
}

- (void)setName: (NSString*)name {
    id temp = nil;
    [name retain];
    @synchronized (@"Name") {
        temp = _name;
        _name = name;
    }
    [temp release];
}

- (void)loadName {

    [_connection cancel];
    [_connection release];
    _connection = [[NSURLConnection alloc] initWithRequest: [NSURLRequest requestWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"http://www.wowhead.com/?item=%d&xml", [self entryID]]]] delegate: self];
    if(_connection) {
        [_downloadData release];
        _downloadData = [[NSMutableData data] retain];
        //[_connection start];
    } else {
        [_downloadData release];
        _downloadData = nil;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_downloadData setLength: 0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_downloadData appendData: data];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [_connection release];      _connection = nil;
    [_downloadData release];    _downloadData = nil;
    // inform the user
    PGLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey: NSErrorFailingURLStringKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // get the download as a string
    NSString *wowhead = [[[NSString alloc] initWithData: _downloadData encoding: NSUTF8StringEncoding] autorelease];
    
    // release the connection, and the data object
    [_connection release];  _connection = nil;
    [_downloadData release]; _downloadData = nil;
    
    // parse out the name
    if([wowhead length]) {
        NSScanner *scanner = [NSScanner scannerWithString: wowhead];
        
        // check to see if this is a valid item
        if([scanner scanUpToString: @"Error - Wowhead" intoString: nil] && ![scanner isAtEnd]) {
            PGLog(@"Item %@ does not exist.", self);
            return;
        } else {
            [scanner setScanLocation: 0];
        }
        
        // get the item name
        if([scanner scanUpToString: @"<name><![CDATA[" intoString: nil] && [scanner scanString: @"<name><![CDATA[" intoString: nil]) {
            NSString *newName = nil;
            if([scanner scanUpToString: @"]]></name>" intoString: &newName]) {
                if(newName && [newName length]) {
                    [self setName: newName];
                    //PGLog(@"Loaded name: %@", newName);
                    [[NSNotificationCenter defaultCenter] postNotificationName: ItemNameLoadedNotification object: self];
                }
            }
        }
    }
}

#pragma mark Item Type/Subtype

- (UInt32)infoFlags {
    UInt32 value = 0;
    if([_memory loadDataForObject: self atAddress: ([self baseAddress] + Item_InfoField1) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
        return CFSwapInt32HostToLittle(value);
    }
    return 0;
}

- (ItemType)itemType {
    return ([self infoFlags] & 0xFF);
}

- (NSString*)itemTypeString {
    return [Item stringForItemType: [self itemType]];
}

+ (NSString*)stringForItemType: (ItemType)type {
    switch(type) {
        case ItemType_Consumable:
            return @"Consumable"; break;
        case ItemType_Container:
            return @"Container"; break;
        case ItemType_Weapon:
            return @"Weapon"; break;
        case ItemType_Gem:
            return @"Gem"; break;
        case ItemType_Armor:
            return @"Armor"; break;
        case ItemType_Reagent:
            return @"Reagent"; break;
        case ItemType_Projectile:
            return @"Projectile"; break;
        case ItemType_TradeGoods:
            return @"Trade Goods"; break;
        case ItemType_Generic:
            return @"Generic"; break;
        case ItemType_Recipe:
            return @"Recipe"; break;
        case ItemType_Money:
            return @"Currency"; break;
        case ItemType_Quiver:
            return @"Quiver"; break;
        case ItemType_Quest:
            return @"Quest Item"; break;
        case ItemType_Key:
            return @"Key"; break;
        case ItemType_Permanent:
            return @"Permanent"; break;
        case ItemType_Misc:
            return @"Miscellaneous"; break;
        default:
            return @"Unknown"; break;
    }
    return nil;
}


- (int)itemSubtype {
    return (([self infoFlags] >> 8) & 0xFF);
}

- (NSString*)itemSubtypeString {
    ItemType type = [self itemType];
    int subType = [self itemSubtype];
    
    if(type == ItemType_Consumable) {
        switch(subType) {
            case CONSUMABLE_TYPE_CONSUMABLE:
                return @"Consumable"; break;
            case CONSUMABLE_TYPE_POTION:
                return @"Potion"; break;
            case CONSUMABLE_TYPE_ELIXIR:
                return @"Elixir"; break;
            case CONSUMABLE_TYPE_FLASK:
                return @"Flask"; break;
            case CONSUMABLE_TYPE_SCROLL:
                return @"Scroll"; break;
            case CONSUMABLE_TYPE_FOOD_DRINK:
                return @"Food/Drink"; break;
            case CONSUMABLE_TYPE_ITEM_ENHANCEMENT:
                return @"Item Enhancement"; break;
            case CONSUMABLE_TYPE_BANDAGE:
                return @"Bandage"; break;
            case CONSUMABLE_TYPE_OTHER:
                return @"Other"; break;
            default:
                return @"Unknown"; break;
        }
    }

    if(type == ItemType_Container) {
        switch(subType) {
            case CONTAINER_TYPE_BAG:
                return @"Bag"; break;
            case CONTAINER_TYPE_SOUL_BAG:
                return @"Soul Bag"; break;
            case CONTAINER_TYPE_HERB_BAG:
                return @"Herbalism Bag"; break;
            case CONTAINER_TYPE_ENCHANTING_BAG:
                return @"Enchanting Bag"; break;
            case CONTAINER_TYPE_ENGINEERING_BAG:
                return @"Engineering Bag"; break;
            case CONTAINER_TYPE_GEM_BAG:
                return @"Gem Bag"; break;
            case CONTAINER_TYPE_MINING_BAG:
                return @"Mining Bag"; break;
            case CONTAINER_TYPE_LEATHERWORKING_BAG:
                return @"Leatherworking Bag"; break;
            default:
                return @"Unknown"; break;
        }
    }
    
    
    if(type == ItemType_Weapon) {
        switch(subType) {
            case WEAPON_TYPE_ONE_HANDED_AXE:
                return @"One-Handed Axe"; break;
            case WEAPON_TYPE_TWO_HANDED_AXE:
                return @"Two-Handed Axe"; break;
            case WEAPON_TYPE_BOW:
                return @"Bow"; break;
            case WEAPON_TYPE_GUN:
                return @"Gun"; break;
            case WEAPON_TYPE_ONE_HANDED_MACE:
                return @"One-Handed Mace"; break;
            case WEAPON_TYPE_TWO_HANDED_MACE:
                return @"Two-Handed Mace"; break;
            case WEAPON_TYPE_POLEARM:
                return @"Polearm"; break;
            case WEAPON_TYPE_ONE_HANDED_SWORD:
                return @"One-Handed Sword"; break;
            case WEAPON_TYPE_TWO_HANDED_SWORD:
                return @"Two-Handed Sword"; break;
            case WEAPON_TYPE_OBSOLETE:
                return @"Obsolete"; break;
            case WEAPON_TYPE_STAVE:
                return @"Staff"; break;
            case WEAPON_TYPE_ONE_HANDED_EXOTIC:
                return @"One-Handed Exotic"; break;
            case WEAPON_TYPE_TWO_HANDED_EXOTIC:
                return @"Two-Handed Exotic"; break;
            case WEAPON_TYPE_FIST:
                return @"Fist"; break;
            case WEAPON_TYPE_MISC:
                return @"Miscellaneous"; break;
            case WEAPON_TYPE_DAGGER:
                return @"Dagger"; break;
            case WEAPON_TYPE_THROWN:
                return @"Thrown"; break;
            case WEAPON_TYPE_SPEAR:
                return @"Spear"; break;
            case WEAPON_TYPE_CROSSBOW:
                return @"Crossbow"; break;
            case WEAPON_TYPE_WAND:
                return @"Wand"; break;
            case WEAPON_TYPE_FISHING_POLE:
                return @"Fishing Pole"; break;

            default:
                return @"Unknown"; break;
        }
    }
    
    
    if(type == ItemType_Gem) {
        switch(subType) {
            case GEM_TYPE_RED:
                return @"Red"; break;
            case GEM_TYPE_BLUE:
                return @"Blue"; break;
            case GEM_TYPE_YELLOW:
                return @"Yellow"; break;
            case GEM_TYPE_PURPLE:
                return @"Purple"; break;
            case GEM_TYPE_GREEN:
                return @"Green"; break;
            case GEM_TYPE_ORANGE:
                return @"Orange"; break;
            case GEM_TYPE_META:
                return @"Meta"; break;
            case GEM_TYPE_SIMPLE:
                return @"Simple"; break;
            case GEM_TYPE_PRISMATIC:
                return @"Prismatic"; break;

            default:
                return @"Unknown"; break;
        }
    }

    if(type == ItemType_Armor) {
        switch(subType) {
            case ARMOR_TYPE_MISC:
                return @"Miscellaneous"; break;
            case ARMOR_TYPE_CLOTH:
                return @"Cloth"; break;
            case ARMOR_TYPE_LEATHER:
                return @"Leather"; break;
            case ARMOR_TYPE_MAIL:
                return @"Mail"; break;
            case ARMOR_TYPE_PLATE:
                return @"Plate"; break;
            case ARMOR_TYPE_BUCKLER:
                return @"Buckler"; break;
            case ARMOR_TYPE_SHIED:
                return @"Shield"; break;
            case ARMOR_TYPE_LIBRAM:
                return @"Libram"; break;
            case ARMOR_TYPE_IDOL:
                return @"Idol"; break;
            case ARMOR_TYPE_TOTEM:
                return @"Totem"; break;
        }
    }
    
    if(type == ItemType_Reagent) {
        return @"";
    }

    
    if(type == ItemType_Projectile) {
        switch(subType) {
            case PROJECTILE_TYPE_WAND_OBSOLETE:
                return @"Wand (Obsolete)"; break;
            case PROJECTILE_TYPE_BOLT_OBSOLETE:
                return @"Bolt (Obsolete)"; break;
            case PROJECTILE_TYPE_ARROW:
                return @"Arrow"; break;
            case PROJECTILE_TYPE_BULLET:
                return @"Bullet"; break;
            case PROJECTILE_TYPE_THROWN_OBSOLETE:
                return @"Thrown (Obsolete)"; break;
        }
    }
    
    if(type == ItemType_TradeGoods) {
        switch(subType) {
            case TRADE_GOOD_TYPE_TRADE_GOOD:
                return @"Trade Good"; break;
            case TRADE_GOOD_TYPE_PART:
                return @"Part"; break;
            case TRADE_GOOD_TYPE_EXPLOSIVE:
                return @"Explosive"; break;
            case TRADE_GOOD_TYPE_DEVICE:
                return @"Device"; break;
            case TRADE_GOOD_TYPE_JEWELCRAFTING:
                return @"Jewelcrafting"; break;
            case TRADE_GOOD_TYPE_CLOTH:
                return @"Cloth"; break;
            case TRADE_GOOD_TYPE_LEATHER:
                return @"Leather"; break;
            case TRADE_GOOD_TYPE_METAL_STONE:
                return @"Metal/Stone"; break;
            case TRADE_GOOD_TYPE_MEAT:
                return @"Meat"; break;
            case TRADE_GOOD_TYPE_HEARB:
                return @"Herbalism"; break;
            case TRADE_GOOD_TYPE_ELEMENTAL:
                return @"Elemental"; break;
            case TRADE_GOOD_TYPE_OTHER:
                return @"Other"; break;
            case TRADE_GOOD_TYPE_ENCHANTING:
                return @"Enchanting"; break;
        }
    }

    if(type == ItemType_Generic) {
        return @"";
    }
    
    if(type == ItemType_Recipe) {
        switch(subType) {
            case RECIPE_TYPE_BOOK:
                return @"Book"; break;
            case RECIPE_TYPE_LEATHERWORKING:
                return @"Leatherworking"; break;
            case RECIPE_TYPE_TAILORING:
                return @"Tailoring"; break;
            case RECIPE_TYPE_ENGINEERING:
                return @"Engineering"; break;
            case RECIPE_TYPE_BLACKSMITHING:
                return @"Blacksmithing"; break;
            case RECIPE_TYPE_COOKING:
                return @"Cooking"; break;
            case RECIPE_TYPE_ALCHEMY:
                return @"Alchemy"; break;
            case RECIPE_TYPE_FIRST_AID:
                return @"First Aid"; break;
            case RECIPE_TYPE_ENCHANTING:
                return @"Enchanting"; break;
            case RECIPE_TYPE_FISHING:
                return @"Fishing"; break;
            case RECIPE_TYPE_JEWELCRAFTING:
                return @"Jewelcrafting"; break;
        }
    }
    
    if(type == ItemType_Money) {
        return @"";
    }
    
    
    if(type == ItemType_Quiver) {
        switch(subType) {
            case QUIVER_TYPE_OBSOLETE1:
                return @"Obsolete 1"; break;
            case QUIVER_TYPE_OBSOLETE2:
                return @"Obsolete 2"; break;
            case QUIVER_TYPE_QUIVER:
                return @"Quiver"; break;
            case QUIVER_TYPE_POUCH:
                return @"Pouch"; break;
        }
    }
        
    if(type == ItemType_Quest) {
        return @"";
    }
    
    if(type == ItemType_Key) {
        switch(subType) {
            case KEY_TYPE_KEY:
                return @"Key"; break;
            case KEY_TYPE_LOCKPICK:
                return @"Lockpick"; break;
        }
    }

    if(type == ItemType_Permanent) {
        return @"";
    }
    

    if(type == ItemType_Misc) {
        switch(subType) {
            case MISC_TYPE_JUNK:
                return @"Junk"; break;
            case MISC_TYPE_REAGENT:
                return @"Reagent"; break;
            case MISC_TYPE_PET:
                return @"Pet"; break;
            case MISC_TYPE_HOLIDAY:
                return @"Holiday"; break;
            case MISC_TYPE_OTHER:
                return @"Other"; break;
            case MISC_TYPE_MOUNT:
                return @"Mount"; break;
        }
    }
    
    return @"Unknown";
}

#pragma mark Info Accessors

- (UInt64)ownerUID {
    UInt64 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_OWNER) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (UInt64)containerUID {
    UInt64 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_CONTAINED) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (UInt64)creatorUID {
    UInt64 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_CREATOR) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (UInt64)giftCreatorUID {
    UInt64 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_GIFTCREATOR) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

// 1 read
- (UInt32)count {
    UInt32 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_STACK_COUNT) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (UInt32)duration {
    UInt32 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_DURATION) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

- (UInt32)charges {
    UInt32 value[5];
    if([_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_SPELL_CHARGES) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
        int i;
        for(i=0; i<5; i++) {
            if(value[i] > 0) {
                return ((0xFFFFFFFF - value[i]) + 1);
            }
        }
    }
    return 0;
}

- (UInt32)flags {
    UInt32 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_FLAGS) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return value;
}

// 1 read
- (NSNumber*)durability {
    UInt32 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_DURABILITY) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return [NSNumber numberWithUnsignedInt: value];
}

// 1 read
- (NSNumber*)maxDurability {
    UInt32 value = 0;
    [_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_MAXDURABILITY) Buffer: (Byte *)&value BufLength: sizeof(value)];
    return [NSNumber numberWithUnsignedInt: value];
}

- (UInt32)enchantAtSlot: (UInt32)slotNum {
    if(slotNum < 0 || slotNum >= MAX_ENCHANTMENT_SLOT) return 0;
    
    UInt32 value = 0;
    if([_memory loadDataForObject: self atAddress: ([self infoAddress] + ITEM_FIELD_ENCHANTMENT + ENCHANTMENT_MAX_OFFSET*sizeof(value)*slotNum) Buffer: (Byte *)&value BufLength: sizeof(value)]) {
        return value;
    }
    return 0;
}

- (UInt32)hasPermEnchantment {
    return [self enchantAtSlot: PERM_ENCHANTMENT_SLOT];
}

- (UInt32)hasTempEnchantment {
    return [self enchantAtSlot: TEMP_ENCHANTMENT_SLOT];
}

// 1 read
- (BOOL)isBag {
    if( [self objectTypeID] == TYPEID_CONTAINER)  return YES;
    return NO;
}

- (BOOL)isSoulbound {
    if( ([self flags] & 1) == 1) return YES;
    return NO;
}

- (UInt32)bagSize {
    if([self isBag]) {
        UInt32 value = 0;
        if([_memory loadDataForObject: self atAddress: ([self infoAddress] + CONTAINER_FIELD_NUM_SLOTS) Buffer: (Byte *)&value BufLength: sizeof(value)])
            return value;
    }
    return 0;
}


- (UInt64)itemUIDinSlot: (UInt32)slotNum {
    if(slotNum < 1 || slotNum > [self bagSize])
        return 0;

    if([self isBag]) {
        UInt64 value = 0;
        if([_memory loadDataForObject: self atAddress: ([self infoAddress] + CONTAINER_FIELD_SLOT_1 + (CONTAINER_FIELD_SLOT_SIZE*(slotNum-1)) ) Buffer: (Byte *)&value BufLength: sizeof(value)])
            return value;
    }
    return 0;
}

@end
