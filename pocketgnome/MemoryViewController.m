//
//  MemoryViewController.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/16/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import "MemoryViewController.h"
#import "Controller.h"
#import "OffsetController.h"

#import "WoWObject.h"

typedef enum ViewTypes {
	View_UInt32 = 0,
	View_Int32	= 1,
	View_UInt64	= 2,
	View_Float	= 3,
	View_Hex32	= 4,
	View_UInt16 = 5,
} ViewTypes;


@interface MemoryViewController ()
@property (readwrite, retain) NSNumber *currentAddress;
@property (readwrite, retain) id wowObject;
@end

@interface MemoryViewController (Internal)
- (void)setBaseAddress: (NSNumber*)address withCount: (int)count;
- (NSString*)formatNumber:(NSNumber *)num WithAddress:(UInt32)addr DisplayFormat:(int)displayFormat;
- (NSDictionary*)valuesForObject: (id)object withAddressSize:(int)addressSize;
@end

@implementation MemoryViewController

- (id) init
{
    self = [super init];
    if (self != nil) {
        [NSBundle loadNibNamed: @"Memory" owner: self];
        self.currentAddress = nil;
        _displayCount = 0;
        self.wowObject = nil;
		_lastValues = [[NSMutableDictionary dictionary] retain];
		_pointerList = [[NSMutableDictionary dictionary] retain];
		_formatOfSavedValues = 0;
    }
    return self;
}

- (void)dealloc {
    self.currentAddress = nil;
	
	[_lastValues release];
	[_pointerList release];
    
    [super dealloc];
}

- (void)awakeFromNib {
    
    self.minSectionSize = [self.view frame].size;
    self.maxSectionSize = NSZeroSize;
	
    [memoryTable setDoubleAction: @selector(tableDoubleClick:)];
    [(NSTableView*)memoryTable setTarget: self];
    
    [self setRefreshFrequency: 0.5];
}

@synthesize view;
@synthesize refreshFrequency;
@synthesize minSectionSize;
@synthesize maxSectionSize;
@synthesize currentAddress = _currentAddress;
@synthesize wowObject = _wowObject;

- (NSString*)sectionTitle {
    return @"Memory";
}

- (void)setRefreshFrequency: (float)frequency {
    [_refreshTimer invalidate];
    [_refreshTimer release];
	
    [self willChangeValueForKey: @"refreshFrequency"];
    refreshFrequency = frequency;
    [self didChangeValueForKey: @"refreshFrequency"];
	
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval: frequency target: self selector: @selector(reloadData:) userInfo: nil repeats: YES];
    [_refreshTimer retain];
}

- (int)displayFormat {
    return _displayFormat;
}

- (void)setDisplayFormat: (int)displayFormat {
    _displayFormat = displayFormat;
    [memoryTable reloadData];
}


- (void)showObjectMemory: (id)object {
    if( [object conformsToProtocol: @protocol(WoWObjectMemory)]) {
        self.wowObject = object;
        [self setBaseAddress: [NSNumber numberWithUnsignedInt: [object baseAddress]] 
                   withCount: (([object memoryEnd] - [object memoryStart] + 0x1000) / sizeof(UInt32))];
    } else {
        self.wowObject = nil;
    }
}

- (void)setBaseAddress: (NSNumber*)address {
    self.wowObject = nil;
    [self setBaseAddress: address withCount: 5000];
}

- (void)setBaseAddress: (NSNumber*)address withCount: (int)count {
    _displayCount = count;
    
    self.currentAddress = address;
    
    [memoryTable reloadData];
}

- (IBAction)setCustomAddress: (id)sender {
    
    if( [[sender stringValue] length]) {
        NSScanner *scanner = [NSScanner scannerWithString: [sender stringValue]];
        uint32_t addr;
        [scanner scanHexInt: &addr];
        [self setBaseAddress: [NSNumber numberWithUnsignedInt: addr]];
    } else {
        self.currentAddress = nil;
    }
    
    [memoryTable reloadData];
}

- (IBAction)clearTable: (id)sender {
    self.currentAddress = nil;
    _displayCount = 0;
    self.wowObject = nil;
}

- (IBAction)snapshotMemory: (id)sender {
    
    UInt32 startAddress = [self.currentAddress unsignedIntValue];
    MemoryAccess *memory = [controller wowMemoryAccess];
    
    if(!startAddress || !memory || ([self displayFormat] == 2) || ([self displayFormat] == 5)) {
        NSBeep();
        return;
    }
    
    int i = 0;
    UInt32 buffer = 0;
    //Byte buffer[4] = { 0, 0, 0, 0 };
    NSString *export = @"";
    
    for(i=0; i<_displayCount; i++) {
        if([memory loadDataForObject: self atAddress: (startAddress + sizeof(buffer)*i) Buffer: (Byte*)&buffer BufLength: sizeof(buffer)]) {
            if([self displayFormat] == 0)
                export = [NSString stringWithFormat: @"%@\n0x%X: %u", export, 4*i, (UInt32)buffer];
            if([self displayFormat] == 1)
                export = [NSString stringWithFormat: @"%@\n0x%X: %d", export, 4*i, (int)buffer];
            if([self displayFormat] == 3)
                export = [NSString stringWithFormat: @"%@\n0x%X: %f", export, 4*i, *(float*)&buffer];
            if([self displayFormat] == 4)
                export = [NSString stringWithFormat: @"%@\n0x%X: 0x%X", export, 4*i, (UInt32)buffer];
        }
		else {
            export = [NSString stringWithFormat: @"%@\n0x%X: err", export, 4*i];
        }
    }
    
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setCanCreateDirectories: YES];
    [savePanel setTitle: @"Save Snapshot"];
    [savePanel setMessage: @"Please choose a destination for this snapshot."];
    int ret = [savePanel runModalForDirectory: @"~/" file: [[NSString stringWithFormat: @"%X", startAddress] stringByAppendingPathExtension: @"txt"]];
    
	if(ret == NSFileHandlingPanelOKButton) {
        NSString *saveLocation = [savePanel filename];
        [export writeToFile: saveLocation atomically: YES encoding: NSUTF8StringEncoding error: NULL];
    }
}

#pragma mark - Menu Options

- (IBAction)menuAction: (id)sender{
	
	int clickedRow = [memoryTable clickedRow];
	unsigned startAddress = [self.currentAddress unsignedIntValue];
	
	// jump to address
	if ( [sender tag] == 0 ){
		// we have to be in 32 bit mode!
		if ( clickedRow >= 0 && ( [self displayFormat] == 0 || [self displayFormat] == 1 || [self displayFormat] == 4 ) ){
			size_t size = sizeof(uint32_t);
			uint32_t addr = startAddress + clickedRow*size;
			uint32_t value32 = 0;
			MemoryAccess *memory = [controller wowMemoryAccess];
			if ( memory && [memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value32 BufLength: sizeof(value32)] ){
				[self setBaseAddress:[NSNumber numberWithInt:value32]];
				[memoryTable scrollRowToVisible: 0];
			}
		}
	}
	
	// copy value
	else if ( [sender tag] == 1 ){
		if ( clickedRow > 0 ){
			size_t size = ([self displayFormat] == 2) ? sizeof(uint64_t) : sizeof(uint32_t);
			size = ([self displayFormat] == 5) ? sizeof(uint16_t) : size;
			uint32_t addr = startAddress + clickedRow*size;
			NSString *num = [self formatNumber:nil WithAddress:addr DisplayFormat:[self displayFormat]];
			[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
			[[NSPasteboard generalPasteboard] setString:num forType:NSStringPboardType];
		}
	}
	
	// copy address
	else if ( [sender tag] == 2 ){
		if ( clickedRow > 0 ){
			size_t size = ([self displayFormat] == 2) ? sizeof(uint64_t) : sizeof(uint32_t);
			size = ([self displayFormat] == 5) ? sizeof(uint16_t) : size;
			uint32_t addr = startAddress + clickedRow*size;
			NSString *num = [self formatNumber:[NSNumber numberWithLong:addr] WithAddress:0 DisplayFormat:4];
			[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
			[[NSPasteboard generalPasteboard] setString:num forType:NSStringPboardType];
		}
	}
	
	// view bits
	else if ( [sender tag] == 3 ){
		[bitPanel makeKeyAndOrderFront: self];
		[bitTableView reloadData];
	}
	
	// find all pointers
	else if ( [sender tag] == 4 ){
		size_t size = sizeof(uint32_t);
		uint32_t addr = startAddress + clickedRow*size;
		NSNumber *address = [NSNumber numberWithInt:addr];
		PGLog(@"[Memory] Searching for pointers to 0x%X", addr);
		[NSThread detachNewThreadSelector: @selector(findAllPointers:) toTarget: self withObject: address];	
	}
}

- (IBAction)findPointers: (id)sender{
	int numAddresses = [numAddressesToScan intValue];
	if ( numAddresses > 0 && numAddresses < 5000 ){
		int i = 0;
		UInt32 currentAddress = [self.currentAddress unsignedIntValue];
		for ( ; i < numAddresses; i++ ){
			
			NSNumber *address = [NSNumber numberWithInt:currentAddress + i*4];
			PGLog(@"[Memory] Searching for pointers to 0x%X", [address intValue]);
			[NSThread detachNewThreadSelector: @selector(findAllPointers:) toTarget: self withObject: address];	
		}
	}
}

- (NSString*)formatNumber:(NSNumber *)num WithAddress:(UInt32)addr DisplayFormat:(int)displayFormat{
	
	// Then we need to read the value!
	if ( num == nil && addr > 0 ){
		MemoryAccess *memory = [controller wowMemoryAccess];
		
		// 32 bit
		if ( displayFormat == 0 || displayFormat == 1 || displayFormat == 4 ){
			uint32_t value32;
			if ( [memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value32 BufLength: sizeof(value32)] )
				num = [NSNumber numberWithInt:value32];				
		}
		// 64 bit
		else if ( displayFormat == 2 ){
			uint64_t value64;
			if ( [memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value64 BufLength: sizeof(uint64_t)] ){
				num = [NSNumber numberWithLongLong:value64];
			}
		}
		// Float
		else if ( displayFormat == 3 ){
			float floatVal;
			if ( [memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&floatVal BufLength: sizeof(float)] ){
				num = [NSNumber numberWithFloat:floatVal];
			}
		}
		// 16 bit
		else if ( displayFormat == 5 ){
			uint16_t value16 = 0;
			if ( [memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value16 BufLength: sizeof(uint16_t)] ){
				num = [NSNumber numberWithShort:value16];
			}
		}
	}
	
	// We have a number to display! Yay!
	if ( num != nil ){
		// Unsigned int 32-bit
		if ( displayFormat == 0 ){
			return [NSString stringWithFormat: @"%u", [num unsignedIntValue]];
		}
		// Signed int 32-bit
		else if ( displayFormat == 1 ){
			return [NSString stringWithFormat: @"%d", [num intValue]];
		}
		// Unsigned int 64-bit
		else if ( displayFormat == 2 ){
			return [NSString stringWithFormat: @"%llu", [num unsignedLongLongValue]];
		}
		// Float
		else if ( displayFormat == 3 ){
			return [NSString stringWithFormat: @"%f", [num floatValue]];
		}
		// Hex 32-bit
		else if ( displayFormat == 4 ){
			return [NSString stringWithFormat: @"0x%X", [num intValue]];
		}
		// Unsigned int 16-bit
		else if ( displayFormat == 5 ){
			return [NSString stringWithFormat: @"%d", [num unsignedShortValue]];
		}
	}
	// Error while reading
	else if ( addr > 0 ){
		uint32_t value32;
		MemoryAccess *memory = [controller wowMemoryAccess];
		int ret = [memory readAddress: addr Buffer: (Byte*)&value32 BufLength: sizeof(value32)];
		return [NSString stringWithFormat: @"(error: %d)", ret];
	}
	
	// Will be here if we have no saved values
	return @"";
}

- (IBAction)saveValues: (id)sender{
	
	unsigned startAddress = [self.currentAddress unsignedIntValue];
	size_t size = ([self displayFormat] == 2) ? sizeof(uint64_t) : sizeof(uint32_t);
	size = ([self displayFormat] == 5) ? sizeof(uint16_t) : size;
    
	_formatOfSavedValues = [self displayFormat];
	
	uint32_t value32;
	int i;
	for ( i = 0; i < _displayCount; i++ ){
		uint32_t addr = startAddress + i*size;	
		
		MemoryAccess *memory = [controller wowMemoryAccess];
        int ret = [memory readAddress: addr Buffer: (Byte*)&value32 BufLength: sizeof(value32)];
        if((ret == KERN_SUCCESS)) {
			
			if ( [self displayFormat] == 2 ){
				uint64_t value64;
                [memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value64 BufLength: sizeof(uint64_t)];
				[_lastValues setObject:[NSNumber numberWithLongLong:value64] forKey:[NSNumber numberWithInt:addr]];
			}
			else if ( [self displayFormat] == 3 ){
                float floatVal;
                [memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&floatVal BufLength: sizeof(float)];
				[_lastValues setObject:[NSNumber numberWithFloat:floatVal] forKey:[NSNumber numberWithInt:addr]];
			}
			else if ( [self displayFormat] == 5 ){
				uint16_t value16 = 0;
				[memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value16 BufLength: sizeof(uint16_t)];
				[_lastValues setObject:[NSNumber numberWithShort:value16] forKey:[NSNumber numberWithInt:addr]];
			}
			else{
				uint32_t value32;
				[memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value32 BufLength: sizeof(uint32_t)];
				[_lastValues setObject:[NSNumber numberWithLong:value32] forKey:[NSNumber numberWithInt:addr]];
			}
		}
	}
}

- (IBAction)clearValues: (id)sender{
	[_lastValues removeAllObjects];
}

- (void)findAllPointers: (NSNumber*)address {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	UInt32 addressToFind = [address unsignedIntValue];
	NSMutableArray *addressesFound = [[NSMutableArray array] retain];
    NSDate *date = [NSDate date];
	
    // get the WoW PID
    pid_t wowPID = 0;
    ProcessSerialNumber wowPSN = [controller getWoWProcessSerialNumber];
    OSStatus err = GetProcessPID(&wowPSN, &wowPID);
    
    if((err == noErr) && (wowPID > 0)) {
        
        // now we need a Task for this PID
        mach_port_t MySlaveTask;
        kern_return_t KernelResult = task_for_pid(current_task(), wowPID, &MySlaveTask);
        if(KernelResult == KERN_SUCCESS) {
            // Cool! we have a task...
            // Now we need to start grabbing blocks of memory from our slave task and copying it into our memory space for analysis
            vm_address_t SourceAddress = 0;
            vm_size_t SourceSize = 0;
            vm_region_basic_info_data_t SourceInfo;
            mach_msg_type_number_t SourceInfoSize = VM_REGION_BASIC_INFO_COUNT;
            mach_port_t ObjectName = MACH_PORT_NULL;
            
			// this will always be 4, as the address space will only be 32-bit!
            int MemSize = sizeof(UInt32);
            int x;
            vm_size_t ReturnedBufferContentSize;
            Byte *ReturnedBuffer = nil;
            
            while(KERN_SUCCESS == (KernelResult = vm_region(MySlaveTask,&SourceAddress,&SourceSize,VM_REGION_BASIC_INFO,(vm_region_info_t) &SourceInfo,&SourceInfoSize,&ObjectName))) {
                // If we get here then we have a block of memory and we know how big it is... let's copy readable blocks and see what we've got!
				//PGLog(@"we have a block of memory!");
				
                // ensure we have access to this block
                if ((SourceInfo.protection & VM_PROT_READ)) {
                    NS_DURING {
                        ReturnedBuffer = malloc(SourceSize);
                        ReturnedBufferContentSize = SourceSize;
                        if ( (KERN_SUCCESS == vm_read_overwrite(MySlaveTask,SourceAddress,SourceSize,(vm_address_t)ReturnedBuffer,&ReturnedBufferContentSize)) &&
                            (ReturnedBufferContentSize > 0) )
                        {
                            // the last address we check must be far enough from the end of the buffer to check all the bytes of our sought value
                            if((ReturnedBufferContentSize % MemSize) != 0) {
                                ReturnedBufferContentSize -= (ReturnedBufferContentSize % MemSize);
                            }
                            
                            // Note: We can assume memory alignment because... well, it's always aligned.
                            for (x=0; x<ReturnedBufferContentSize; x+=4) // x++
                            {
                                UInt32 *checkVal = (UInt32*)&ReturnedBuffer[x];
								
								// compare each one, clearly this will take a long time!
								/*for ( NSNumber *address in addresses ){
									if ( [address unsignedIntValue] == *checkVal ){
										
										UInt32 foundAddress = SourceAddress + x;
										PGLog(@"Match for 0x%X found at 0x%X", [address unsignedIntValue], foundAddress);
									}
								}*/
								// is this our address?
								if ( *checkVal == addressToFind ){
									UInt32 foundAddress = SourceAddress + x;
									PGLog(@"Match for 0x%X found at 0x%X", addressToFind, foundAddress);
									[addressesFound addObject:[NSNumber numberWithUnsignedInt:foundAddress]];
								}
                            }
                        }
                    } NS_HANDLER {
                    } NS_ENDHANDLER
                    
                    if (ReturnedBuffer != nil)
                    {
                        free(ReturnedBuffer);
                        ReturnedBuffer = nil;
                    }
                }
                
                // reset some values to search some more
                SourceAddress += SourceSize;
            }
            //[pBar setHidden:true];
        }
    }
    
    PGLog(@"[Memory] Pointer scan took %.4f seconds and found %d pointers.", 0.0f-[date timeIntervalSinceNow], [addressesFound count]);
    
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
								   address,				@"Address",
                                   addressesFound,      @"Addresses",
                                   nil];
	
	
    // tell the main thread we are done
	[self performSelectorOnMainThread: @selector(findPointerAddresses:)
						   withObject: dict
                        waitUntilDone: NO];
    
    [pool release];
}

- (void)findPointerAddresses: (NSDictionary*)dict {
	
	NSNumber *address = [dict objectForKey:@"Address"];
	NSArray *addresses = [dict objectForKey:@"Addresses"];
	
	PGLog(@"B4[] Address: %d  Addresses: %d", [address retainCount], [addresses retainCount]);
	
	// add them to our mutable dictionary!
	if ( [addresses count] ){
		[_pointerList setObject:addresses forKey:[NSString stringWithFormat:@"%d", [address unsignedIntValue]]];
	}
	// we need to realize we searched for this!
	else{
		[_pointerList setObject:[NSNumber numberWithInt:0] forKey:[NSString stringWithFormat:@"%d", [address unsignedIntValue]]];
	}
	
	PGLog(@"After[] Address: %d  Addresses: %d", [address retainCount], [addresses retainCount]);
	
	// since we retained it in the detached thread!
	[addresses release];
	
	// reload our table
	[memoryTable reloadData];
}


#pragma mark -

- (void)reloadData: (id)timer {
    if([memoryTable editedRow] == -1)
        [memoryTable reloadData];
}

- (BOOL)validState {
    return (self.currentAddress && [controller wowMemoryAccess]);
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	
	// memory table
	if ( aTableView == memoryTable ){
		if ( [self validState] ) {
			return _displayCount;
		}
	}
	
	// bit table
	else if ( aTableView == bitTableView ){
		size_t size = ([self displayFormat] == 2) ? sizeof(uint64_t) : sizeof(uint32_t);
		size = ([self displayFormat] == 5) ? sizeof(uint16_t) : size;
		
		// Our length will be the number of bytes!
		return size * 8;
	}
	
    return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    if(rowIndex == -1)      return nil;
    
	// memory table
	if ( aTableView == memoryTable ){
		if(![self validState])  return nil;
		
		unsigned startAddress = [self.currentAddress unsignedIntValue];
		size_t size = ([self displayFormat] == 2) ? sizeof(uint64_t) : sizeof(uint32_t);
		size = ([self displayFormat] == 5) ? sizeof(uint16_t) : size;
		
		uint32_t addr = startAddress + rowIndex*size;
		
		if( [[aTableColumn identifier] isEqualToString: @"Address"] ) {
			return [NSString stringWithFormat: @"0x%X", addr];
		}
		if( [[aTableColumn identifier] isEqualToString: @"Offset"] ) {
			return [NSString stringWithFormat: @"+0x%X", (addr - startAddress)];
		}
		
		if( [[aTableColumn identifier] isEqualToString: @"Saved"] ) {
			return [self formatNumber:[_lastValues objectForKey:[NSNumber numberWithInt:addr]] WithAddress:0 DisplayFormat:_formatOfSavedValues];
		}
		
		if( [[aTableColumn identifier] isEqualToString: @"Value"] ) {
			return [self formatNumber:nil WithAddress:addr DisplayFormat:[self displayFormat]];
		}
		
		if( [[aTableColumn identifier] isEqualToString: @"Info"] ) {
			
			NSArray *pointers = [_pointerList valueForKey:[NSString stringWithFormat:@"%d", addr]];
			if ( pointers ){
				// is it a number?  o noes nothing found
				if ( [[pointers className] isEqualToString:@"NSCFNumber"] ){
					return @"No pointer found";
				}
				// we have an array of ptrs!
				else{
					if ( [pointers count] > 1 ){
						NSMutableString *addresses = [NSMutableString string];
						
						for ( NSNumber *address in pointers ){
							[addresses appendString:[NSString stringWithFormat:@"0x%X ", [address unsignedIntValue]]];							
						}
						return addresses;
					}
					else{
						return [NSString stringWithFormat:@"PTR: 0x%X", [[pointers objectAtIndex:0] unsignedIntValue]];					
					}
				}
			}
			
			NSString *value = [self formatNumber:nil WithAddress:addr DisplayFormat:0];
			NSNumber *num = [NSNumber numberWithInt:[value integerValue]];
			NSArray *objectAddresses = [controller allObjectAddresses];
			
			if ( [objectAddresses containsObject:num] ){
				return @"OBJECT POINTER";
			}
			
			id info = nil;
			if([self.wowObject respondsToSelector: @selector(descriptionForOffset:)])
				info = [self.wowObject descriptionForOffset: (addr - startAddress)];
			
			if(!info || ![info length]) {
				char str[5];
				str[4] = '\0';
				[[controller wowMemoryAccess] loadDataForObject: self atAddress: addr Buffer: (Byte*)&str BufLength: 4];
				
				NSString *tehString = [NSString stringWithUTF8String: str];
				if([tehString length])
					return [NSString stringWithFormat: @"\"%@\"", [NSString stringWithUTF8String: str]];
			}
			return info;
		}
	}
	
	// bit table
	else if ( aTableView == bitTableView ){
		
		if( [[aTableColumn identifier] isEqualToString: @"Bit"] ) {
			
			//  0x0   0x1  0x2  0x4  0x8  0x10  0x20  0x40  0x80	0x100
			
			NSString *num = [NSString stringWithFormat:@"0x%X", rowIndex];
			
			return num;
		}
		if( [[aTableColumn identifier] isEqualToString: @"On/Off"] ) {
			return @"0";
		}
	}
    
    return nil;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	
	// memory table
	if ( aTableView == memoryTable ){
		if([[aTableColumn identifier] isEqualToString: @"Value"])
			return YES;
	}
	
    return NO;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	
	// memory table
	if ( aTableView == memoryTable ){
		int type = [self displayFormat];
		if(type == 0 || type == 4) {
			UInt32 value = [anObject intValue];
			[[controller wowMemoryAccess] saveDataForAddress: ([self.currentAddress unsignedIntValue] + rowIndex*4) Buffer: (Byte*)&value BufLength: sizeof(value)];
		}
		if(type == 1) {
			SInt32 value = [anObject intValue];
			[[controller wowMemoryAccess] saveDataForAddress:([self.currentAddress unsignedIntValue] + rowIndex*4) Buffer: (Byte*)&value BufLength: sizeof(value)];
		}
		if(type == 2) {
			UInt64 value = [anObject longLongValue];
			[[controller wowMemoryAccess] saveDataForAddress: ([self.currentAddress unsignedIntValue] + rowIndex*4) Buffer: (Byte*)&value BufLength: sizeof(value)];
		}
		if(type == 3) {
			float value = [anObject floatValue];
			[[controller wowMemoryAccess] saveDataForAddress: ([self.currentAddress unsignedIntValue] + rowIndex*4) Buffer: (Byte*)&value BufLength: sizeof(value)];
		}
		if(type == 5) {
			UInt16 value = [anObject intValue];
			[[controller wowMemoryAccess] saveDataForAddress: ([self.currentAddress unsignedIntValue] + rowIndex*4) Buffer: (Byte*)&value BufLength: sizeof(value)];
		}
	}
	
	// bit table
	else if ( aTableView == bitTableView ){
		
	}
}

// memory table
- (void)tableDoubleClick: (id)sender {
    if( [sender clickedRow] == -1 ) return;
    
    unsigned startAddress = [self.currentAddress unsignedIntValue];
    size_t size = ([self displayFormat] == 2) ? sizeof(uint64_t) : sizeof(uint32_t);
	size = ([self displayFormat] == 5) ? sizeof(uint16_t) : size;
    
    uint32_t addr = startAddress + [sender clickedRow]*size;
    
    uint32_t value = 0;
    if([[controller wowMemoryAccess] loadDataForObject: self atAddress: addr Buffer: (Byte*)&value BufLength: sizeof(value)] && value) {
        if(value >= startAddress && value <= startAddress + _displayCount*size) {
            int line = (value - startAddress)/4;
            [memoryTable scrollRowToVisible: line];
            [memoryTable selectRowIndexes: [NSIndexSet indexSetWithIndex: line] byExtendingSelection: NO];
        }
    }
}

- (void)tableView: (NSTableView *)aTableView willDisplayCell: (id)aCell forTableColumn: (NSTableColumn *)aTableColumn row: (int)aRowIndex{
    if(aRowIndex == -1)      return;
    
	// memory table
	if ( aTableView == memoryTable ){
		if(![self validState])  return;
		
		int size = 4;
		if ( [self displayFormat] == View_UInt16 )
			size = 2;
		else if ( [self displayFormat] == View_UInt64 )
			size = 8;
		
		UInt32 addr = [self.currentAddress intValue] + aRowIndex * size;
		
		// we want the rows that have values changed to be red!
		NSNumber *savedNum = [_lastValues objectForKey:[NSNumber numberWithInt:addr]];
		if ( savedNum && [savedNum intValue] > 0 ){
			NSString *currentNum = [self formatNumber:nil WithAddress:addr DisplayFormat:[self displayFormat]];
			
			if ( [savedNum longLongValue] != [currentNum longLongValue] ){
				[aCell setTextColor: [NSColor redColor]];
				//PGLog(@"[Memory] Different values found at address 0x%X 0x%qX 0x%qX", addr, [currentNum longLongValue], [savedNum longLongValue] );
				return;
			}
		}
		
		[aCell setTextColor: [NSColor blackColor]];
	}
	
	return;
}

- (void)monitorObjects: (id)objects{
	
	BOOL firstCall = NO;
	
	if ( objects && [objects count] && ![[[objects objectAtIndex:0] className] isEqualToString:@"NSCFDictionary"] ){
		firstCall = YES;
	}
	
	PGLog(@"%@ %@", [objects className],   [[objects objectAtIndex:0] className]);
	// here is where we do our comparisons
	if ( !firstCall ){
		
		int totalInvalids = 0;
		// update values
		for ( NSMutableDictionary *dict in (NSArray*)objects ){

			WoWObject *obj = [dict valueForKey:@"Object"];
			
			if ( [obj isStale] || ![obj isValid] ){
				PGLog(@"[Memory] Object no longer valid, aborting");
				totalInvalids++;
				continue;		
			}
			
			UInt32 addressSize = [[(NSMutableDictionary*)dict valueForKey:@"Size"] unsignedIntValue];
			NSDictionary *currentValues = [self valuesForObject:obj withAddressSize:addressSize];
			
			[dict setObject:currentValues forKey:@"StartValues"];
		}
		
		// now compare all objects!
		NSDictionary *firstObjectDict = [(NSArray*)objects objectAtIndex:0];
		uint32_t firstObjectStartAddress = [(WoWObject*)[firstObjectDict valueForKey:@"Object"] baseAddress];
		NSDictionary *firstObjectValues = [firstObjectDict valueForKey:@"StartValues"];
		UInt32 addressSize = [[firstObjectDict valueForKey:@"Size"] unsignedIntValue];
		int i;
		for ( i = 0; i < addressSize; i++ ){
			uint32_t addr = firstObjectStartAddress + i*4;	
			NSNumber *value = [firstObjectValues objectForKey:[NSNumber numberWithUnsignedInt:addr]];
			
			BOOL different = NO;
			// now check the other objects!
			int j = 1;
			for ( ;j < [(NSArray*)objects count];j++){
				WoWObject *obj = [[(NSArray*)objects objectAtIndex:j] valueForKey:@"Object"];
				uint32_t startAddress = [obj baseAddress];
				NSDictionary *objectValues = [[(NSArray*)objects objectAtIndex:j] valueForKey:@"StartValues"];
				uint32_t addr2 = startAddress + i*4;
				NSNumber *value2 = [objectValues objectForKey:[NSNumber numberWithUnsignedInt:addr2]];
				
				if ( [value2 intValue] != [value intValue] ){
					different = YES;
					break;
				}
			}

			if ( different ){
				WoWObject *obj = [[(NSArray*)objects objectAtIndex:0] valueForKey:@"Object"];
				uint32_t startAddress = [obj baseAddress];
				uint32_t addr3 = startAddress + i*4;
				NSNumber *value0 = [[[(NSArray*)objects objectAtIndex:0] valueForKey:@"StartValues"] objectForKey:[NSNumber numberWithUnsignedInt:addr3]];
				
				obj = [[(NSArray*)objects objectAtIndex:1] valueForKey:@"Object"];
				startAddress = [obj baseAddress];
				addr3 = startAddress + i*4;
				NSNumber *value1 = [[[(NSArray*)objects objectAtIndex:1] valueForKey:@"StartValues"] objectForKey:[NSNumber numberWithUnsignedInt:addr3]];
				
				/*obj = [[(NSArray*)objects objectAtIndex:2] valueForKey:@"Object"];
				startAddress = [obj baseAddress];
				addr3 = startAddress + i*4;
				NSNumber *value2 = [[[(NSArray*)objects objectAtIndex:2] valueForKey:@"StartValues"] objectForKey:[NSNumber numberWithUnsignedInt:addr3]];
				
				obj = [[(NSArray*)objects objectAtIndex:3] valueForKey:@"Object"];
				startAddress = [obj baseAddress];
				addr3 = startAddress + i*4;
				NSNumber *value3 = [[[(NSArray*)objects objectAtIndex:3] valueForKey:@"StartValues"] objectForKey:[NSNumber numberWithUnsignedInt:addr3]];*/
				
				UInt32 offset = addr - firstObjectStartAddress;
				
				PGLog(@"[0x%X] 0x%X 0x%X", offset, value0, value1);
			}
			
		}
		
		PGLog(@"------------------------------");

		
		// all are invalid :(
		if ( totalInvalids == [objects count] ){
			PGLog(@"[Memory] All monitored objects are invalid, quitting");
			return;
		}
		
		[self performSelector:@selector(monitorObjects:) withObject:objects afterDelay:0.1f];	
	}
	
	// lets start monitoring!
	else {
		
		NSMutableArray *objectsWithData = [[NSMutableArray array] retain];
		

		for ( WoWObject *obj in (NSArray*)objects ){
			
			NSNumber *addressesToMonitor = [NSNumber numberWithUnsignedInt:(([obj memoryEnd] - [obj memoryStart] + 0x1000) / sizeof(UInt32))];
			NSDictionary *startValues = [self valuesForObject:obj withAddressSize:[addressesToMonitor intValue]];
			
			NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 obj, @"Object",
										 addressesToMonitor, @"Size",
										 startValues,@"StartValues",
										 nil];
			
			[objectsWithData addObject:dict];				
		}
		
		[self performSelector:@selector(monitorObjects:) withObject:objectsWithData afterDelay:0.1f];		
	}
	
}

// this function will monitor an object for changes!
- (void)monitorObject: (id)object{
	
	if ( object ){
		// check to see if we have a dictionary - if so then we're monitoring already!
		if ( [[object className] isEqualToString:@"NSCFDictionary"] ){
			WoWObject *obj = [object valueForKey:@"Object"];
			
			if ( [obj isStale] || ![obj isValid] ){
				PGLog(@"[Memory] Object no longer valid, aborting");
				return;				
			}
			
			UInt32 addressSize = [[(NSMutableDictionary*)object valueForKey:@"Size"] unsignedIntValue];
			NSMutableDictionary *startValues = [NSMutableDictionary dictionaryWithDictionary:[(NSMutableDictionary*)object valueForKey:@"StartValues"]];
			NSDictionary *currentValues = [self valuesForObject:obj withAddressSize:addressSize];
			
			NSArray *allKeys = [startValues allKeys];
			for ( NSNumber *key in allKeys ){
				
				NSNumber *current = [currentValues objectForKey:key];
				NSNumber *start = [startValues objectForKey:key];
				
				if ( [start intValue] != [current intValue] ){
					PGLog(@"[Memory] %@ at 0x%X from 0x%X to 0x%X", obj, [key unsignedIntValue], [start intValue], [current intValue] );
					[startValues setObject:current forKey:key];
				}
			}
			
			[(NSMutableDictionary*)object setObject:startValues forKey:@"StartValues"];
			
			[self performSelector:@selector(monitorObject:) withObject:object afterDelay:0.1f];
		}
		
		// starting to monitor
		else{
			NSNumber *addressesToMonitor = [NSNumber numberWithUnsignedInt:(([object memoryEnd] - [object memoryStart] + 0x1000) / sizeof(UInt32))];
			NSDictionary *startValues = [self valuesForObject:object withAddressSize:[addressesToMonitor intValue]];
			
			NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								  object, @"Object",
								  addressesToMonitor, @"Size",
								  startValues,@"StartValues",
								  nil];
			
			PGLog(@"[Memory] Starting to monitor %@ with base address 0x%X!", object, [object baseAddress]);
			[self performSelector:@selector(monitorObject:) withObject:dict afterDelay:0.1f];
		}
	}
}

- (NSDictionary*)valuesForObject: (id)object withAddressSize:(int)addressSize{
	unsigned startAddress = [(WoWObject*)object baseAddress];
	size_t size = 4;
	
	//PGLog(@"[Memory] Scanning object %@ starting at 0x%X with length %d", object, startAddress, addressSize);
	
	NSMutableDictionary *dict = [[NSMutableDictionary dictionary] retain];
	
	uint32_t value32;
	int i;
	for ( i = 0; i < addressSize; i++ ){
		uint32_t addr = startAddress + i*size;	
		
		MemoryAccess *memory = [controller wowMemoryAccess];
        int ret = [memory readAddress: addr Buffer: (Byte*)&value32 BufLength: sizeof(value32)];
        if((ret == KERN_SUCCESS)) {
			uint32_t value32;
			[memory loadDataForObject: self atAddress: addr Buffer: (Byte*)&value32 BufLength: sizeof(uint32_t)];
			[dict setObject:[NSNumber numberWithLong:value32] forKey:[NSNumber numberWithInt:addr]];
		}
	}
	
	//PGLog(@"[Memory] Total found: %d", [dict count]);
	
	return [dict autorelease];
}

@end
