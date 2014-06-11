/*
 Copyright 2014 DoNothingBox LLC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

#import "BLEConnectionDelegate.h"
#import "PairedDevice.h"
#import "ConnectionViewController.h"
#import "AppDelegate.h"
#import "RSSParserObject.h"
#import "TimeState.h"
#import "RSSState.h"
#import "SettingsObject.h"

@implementation BLEConnectionDelegate
@synthesize m_detectedDevices;
@synthesize delegate;
@synthesize peripherals;
@synthesize activePeripheral;

//Set this to false to manually select the BLE connection each time. If true, the UUID will be saved locally, and it will always try to reconnect to the device
static bool CACHE_CONNECTION = true;

//App will always try to reconnect to "memorized" peripheral
static bool AUTO_RECONNECT = true;

static bool isConnected = false;
static bool done = false;
static int rssi = 0;
NSTimer *rssiTimer;


static RSSParserObject *rssParserObject;

static NSMutableArray *packetArray;
static NSInteger packetCount;
static NSInteger rssCount;

TimeState *m_timeState;



-(BLEConnectionDelegate *)init{
    NSLog(@"BLEConnectionDelegate->init");
    self =[super init];
    rssParserObject = [[RSSParserObject alloc] init];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rssLoadComplete:) name:EVENT_RSS_LOAD_COMPLETE object:nil];

    return self;
}

-(void) bleDidConnect{
    NSLog(@"BLEConnectionDelegate->bleDidConnect");
    [self getAllServicesFromPeripheral:[self activePeripheral]];
    [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_DEVICE_CONNECTED object:self];
    // Find the desired service. For the current setup, its the generic
    for (CBService *service in [[self activePeripheral] services]) {
        NSLog(@" Ser UUUID:  %@", service.UUID);
        if ([[service UUID] isEqual:[CBUUID UUIDWithString:@BLE_SERVICE_UUID]]) {
            // Find the characteristic
            for (CBCharacteristic *characteristic in [service characteristics]) {
                //NSLog(@" Char UUUID: %@", [characteristic UUID]);
                if ( [[characteristic UUID] isEqual:[CBUUID UUIDWithString:@BLE_CHAR_RX_UUID]]) {
                    //NSLog(@"setting notify value to true");
                    [self enableReadNotification:[self activePeripheral]];
                }
            }
        }

    }
    // Schedule to read RSSI every 1 sec

    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.rssiTimer = [NSTimer scheduledTimerWithTimeInterval:(float)1.0 target:self selector:@selector(readRSSITimer:) userInfo:nil repeats:YES];
    });
    // send connection message to Peripheral
    //[self sendMessage:SLAVE_DEVICE_CONNECTED]; //Immediately sending a message on connection seems to create instabilities. TODO, add a delay
   }

-(void) bleDidDisconnect{
    [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_DEVICE_DISCONNECTED object:self];
    [self scheduleNotification:@"BCD -> BLE Disconnected" soundName:@""];
    NSLog(@"BLEConnectionDelegate->Disconnected");
    [self.rssiTimer invalidate];
    self.rssiTimer = nil;
    
    SettingsObject *settingsObject = [SettingsObject getSettingsObjectSingleton];
    if(settingsObject.reconnectionsEnabled)
        [self huntForPeripherals];

}

-(void) bleDidUpdateRSSI:(NSNumber *) rssi{
    
    //NSLog(@"BLEConnectionDelegate->bleDidUpdateRSSI");

    NSDictionary *theInfo = [NSDictionary dictionaryWithObjectsAndKeys:rssi,@"rssi", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_DEVICE_UPDATED_RSSI object:self userInfo:theInfo];
}

-(void) didDiscoverPeripheral{
    CBCentralManager *cm =[AppDelegate getCentralManagerInstance];
    NSLog(@"trying to connect to a Old Device");
    //If we're already connected, do nothing
    if (self.activePeripheral)
    if(self.activePeripheral.isConnected){
        NSLog(@"already connected, stopping");
        [cm cancelPeripheralConnection:[self activePeripheral]];
        return;
    }
    
    SettingsObject *settingsObject = [SettingsObject getSettingsObjectSingleton];
    if(settingsObject.reconnectionsEnabled)
    {
        //Look at the perfs discovered and check to see if any are previously connected
        PairedDevice *diskPerf = [self loadConnectedDevicesFromDisk];
        CBPeripheral *targetPerf;
        if(diskPerf != NULL){
            targetPerf = [self findPeripheralMatchingUUID:diskPerf.uuid];
            NSLog(@"loaded previous match off of disk");
        
            if(targetPerf != NULL){
                [self connectPeripheral:targetPerf];
                NSLog(@"Reconnected to a Old Device");
            }
        }
    }
}



-(CBPeripheral *) getActivePeripheral{
    return [self activePeripheral];
}

-(void) enableReadNotifications{
    [self enableReadNotification:[self activePeripheral]];
}

-(NSMutableArray *) getPeripheralsArray{
    return [self peripherals];
}

/*
      The heart and soul of incoming requests. The packet format is as follows:
      Byte 1: Expected Length of message (minimum 3, length, App ID, and App Action)
      Byte 2: App "ID" (lets you parse the data to helper functions / classes easily
      Byte 3: App "Action" (the apps desired incoming message, again, for action parsing)
      Bytes 4+: Specifically used for individual app / functions.
*/

-(void) bleDidReceiveData:(unsigned char *) data length:(int) length
{
    int lengthByte = (int) data[0];
    NSMutableArray *byteArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < lengthByte; i++) {
        [byteArray addObject:[NSNumber numberWithUnsignedChar:data[i]]];
    }
    NSDictionary *theInfo = [NSDictionary dictionaryWithObjectsAndKeys:byteArray,@"messageData", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_DEVICE_SENT_DATA object:self userInfo:theInfo];
    
    // Below should probably be re-written. The State Events should also go to an eventual Mobile State Delegate, or something similar
    //
    //
    //NSLog(@"Length: %d", data[0]);
    // parse data as needed
    for (int i = 0; i < data[0]; i+=data[0]){
        //debug trace
        unsigned char data_test[] = { data[i+3], data[i+4], data[i+5], data[i+6] };
        //NSLog(@"0x%02X, timestamp:%d, 0x%02X", data[i], [self bytesToInteger:data_test], data[i+7]);
        //NSLog(@"App Id: %d", data[BYTE_EVENT_APP_ID]);
        [[UIApplication sharedApplication] cancelAllLocalNotifications];

        switch (data[BYTE_EVENT_APP_ID])
        {
            case GLOBAL_STATE:
                //Parse global Events here. This is a reserved App ID. Currently None Setup
                NSLog(@"MASTER STATE EVENT DETECTED");
                break;
            case MENU_STATE:
                //Currently, no Class to forward to, so handle it locally
                NSLog(@"PING STATE EVENT DETECTED");
                [self scheduleNotification:@"Incoming Data: PING" soundName:@"cardiac_arrest.wav"];
                [self sendMessage:SLAVE_PING_RESPONSE];
                break;
            case TIME_STATE:
                [[TimeState getTimeState] processIncomingData:data length:length];
                break;
            case RSS_STATE:
                [[RSSState getRSSState] processIncomingData:data length:length];
                break;
            default:
                //This is an Error and should never happen
                [self scheduleNotification:@"Incoming Data: UNKNOWN" soundName:@"cardiac_arrest.wav"];
                break;
        }
    }
}




-(void) readRSSITimer:(NSTimer *)timer{
    //NSLog(@"BLEConnectionDelegate->readRSSITimer");
    [self readRSSI];
}

-(void) disconnectPeripheral:(CBPeripheral*)connectedPeripheral{
    CBCentralManager *cm =[AppDelegate getCentralManagerInstance];
    [cm cancelPeripheralConnection:connectedPeripheral];
}


-(void) scanForPeripherals{
    NSLog(@"BLEConnectionDelegate->scanForPeripherals");
    CBCentralManager *cm =[AppDelegate getCentralManagerInstance];
    if (self.activePeripheral)
        if(self.activePeripheral.isConnected)
        {
            [cm cancelPeripheralConnection:[self activePeripheral]];
            return;
        }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_DEVICE_SCAN_STARTED object:self];

    if (self.peripherals)
        self.peripherals = nil;
    [self findBLEPeripherals:3];
    //[NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(deviceScanCompleteTimer:) userInfo:nil repeats:NO];
}


-(int) huntForPeripherals{
    CBCentralManager *cm =[AppDelegate getCentralManagerInstance];
        if (cm.state != CBCentralManagerStatePoweredOn){
            NSLog(@"CoreBluetooth not correctly initialized for Hunt mode!");
            NSLog(@"State = %d (%s)\r\n", cm.state, [self centralManagerStateToString:cm.state]);
            return -1;
        }
        [cm scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@BLE_SERVICE_UUID]] options:nil];
        NSLog(@"scanForPeripheralsWithServices");
        return 0; // Started scanning OK !
}

-(void) deviceScanCompleteTimer:(NSTimer *)timer{
    NSLog(@"BLEConnectionDelegate->deviceScanCompleteTimer");
    if (self.peripherals.count > 0){
        PairedDevice *diskPerf = [self loadConnectedDevicesFromDisk];
        CBPeripheral *targetPerf;
        if(diskPerf != NULL){
            targetPerf = [self findPeripheralMatchingUUID:diskPerf.uuid];
            NSLog(@"loaded previous match off of disk");
        }
        else{
            m_detectedDevices = [[NSMutableArray alloc] initWithCapacity:self.peripherals.count];
            for(int i = 0;i<self.peripherals.count;i++){
                [m_detectedDevices addObject:[self.peripherals objectAtIndex:i]];
            }
            
            NSDictionary *theInfo = [NSDictionary dictionaryWithObjectsAndKeys:self.peripherals,@"myArray", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_DEVICE_SCAN_COMPLETE object:self userInfo:theInfo];
        }
        if(targetPerf != NULL){
            [self connectPeripheral:targetPerf];
            [self saveConnectedDeviceToDisk];
        }
        
    }
    else{
        [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_NO_DEVICES_FOUND object:self];
    }
}

-(CBPeripheral *) findPeripheralMatchingUUID:(NSString *) uuidRef {
    CBPeripheral *returnPerf = NULL;
    for(int i = 0;i<self.peripherals.count;i++) {
        CBPeripheral *testPerf = [self.peripherals objectAtIndex:i];
        CFStringRef s = CFUUIDCreateString(NULL, testPerf.UUID);
        CFStringRef t = (__bridge CFStringRef)uuidRef;
        
        if(CFStringCompare(s, t, 0) == kCFCompareEqualTo){
            NSLog(@"They Match");
            returnPerf = testPerf;
            return returnPerf;
        }
        else{
            NSLog(@"They Dont Match");
        }
    }
    return returnPerf;
}

-(void) saveConnectedDeviceToDisk{
    PairedDevice *activeDevice = [[PairedDevice alloc] init];
    activeDevice.uuid = (NSString *)CFBridgingRelease(CFUUIDCreateString(NULL, self.activePeripheral.UUID));
    activeDevice.identifier = (NSUUID *) self.activePeripheral.identifier;
    activeDevice.device_name = @"my_device";
    NSArray *array = [[NSArray alloc] initWithObjects:activeDevice, nil];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *fullFileName = [NSString stringWithFormat:@"%@/ourArray", docDir];
    [NSKeyedArchiver archiveRootObject:array toFile:fullFileName];
}

-(void) deleteConnectedDeviceFromDisk{
    
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //NSString *fullFileName = [NSString stringWithFormat:@"%@/ourArray", docDir];
    //NSMutableArray *arrayFromDisk = [NSKeyedUnarchiver unarchiveObjectWithFile:fullFileName];
    //PairedDevice *activeDevice = [arrayFromDisk objectAtIndex:0];
    
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,   YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *fullFileName = [NSString stringWithFormat:@"%@/ourArray", docDir];
    NSString *fullPath = [docDir stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@", fullFileName]];

    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if(![fileManager removeItemAtPath: fullFileName error:&error]) {
        NSLog(@"Delete failed:%@", error);
    } else {
        NSLog(@"image removed: %@", fullFileName);
    }
    
}

-(PairedDevice *) loadConnectedDevicesFromDisk{
    if(CACHE_CONNECTION)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = [paths objectAtIndex:0];
        NSString *fullFileName = [NSString stringWithFormat:@"%@/ourArray", docDir];
        NSMutableArray *arrayFromDisk = [NSKeyedUnarchiver unarchiveObjectWithFile:fullFileName];
        PairedDevice *activeDevice = [arrayFromDisk objectAtIndex:0];
        return activeDevice;
    }
    else
        return NULL;
}

-(IBAction)sendConnectedInitData:(id)sender {
    UInt8 buf[6] = {0x04, 0x00, 0x00, 0x00, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:6];
    [self write:data];
}

-(IBAction)sendConnectData:(id)sender {
    UInt8 buf[6] = {0x09, 0x00, 0x00, 0x00, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:6];
    [self write:data];
}

-(IBAction)sendData:(UInt8*)buf
{
    NSLog(@"Send Data ->");
    NSData *data = [[NSData alloc] initWithBytes:buf length:6];
    [self write:data];
}


-(IBAction)sendFormattedString:(Byte)stateId stateAction:(Byte)stateAction stateMessage:(NSString*)stateMessage
{
    //First append the first 2 bytes of data
    NSString *dataToTransmit = [NSString stringWithFormat:@"%hhu%hhu%@", stateId, stateAction, stateMessage];
    //then encode to data
    NSData* buf = [dataToTransmit dataUsingEncoding:NSUTF8StringEncoding];
    //finally send the string, we'll parse out the sentence later.
    
    NSLog(@"Send String -> %@", stateMessage);
    NSLog(@"Send buf -> %@", buf);
    NSLog(@"Send Hex -> %@", [self stringToHex : dataToTransmit]);

    
    
    
    
    NSData *data = [[NSData alloc] initWithBytes:(__bridge const void *)(buf) length:stateMessage.length+2];
    [self write:data];
}

- (NSString *)stringToHex:(NSString *)string
{
    char *utf8 = [string UTF8String];
    NSMutableString *hex = [NSMutableString string];
    while ( *utf8 ) [hex appendFormat:@"%02X" , *utf8++ & 0x00FF];
    
    return [NSString stringWithFormat:@"%@", hex];
}










-(IBAction)sendMessage:(Byte)type integerValue:(int)integerValue{
    
    UInt8 intValByte[6] = {type, 0x00, 0x00, 0x00, 0x00, 0x00};
    int timestamp = [[NSDate date] timeIntervalSince1970]; //always imbed timestamp
    NSLog(@"TimeStamp: %i", timestamp);
    //NSLog(@"Data 1: %i", [self integerToBytes:timestamp][0]);
    //NSLog(@"Data 2: %i", [self integerToBytes:timestamp][1]);
    //NSLog(@"Data 3: %i", [self integerToBytes:timestamp][2]);
    //NSLog(@"Data 4: %i", [self integerToBytes:timestamp][3]);
    intValByte[1] = [self integerToBytes:timestamp][3];
    intValByte[2] = [self integerToBytes:timestamp][2];
    intValByte[3] = [self integerToBytes:timestamp][1];
    intValByte[4] = [self integerToBytes:timestamp][0];
    NSLog(@"Send Data ->");
    [self sendData:intValByte];
}

-(IBAction)sendMessage:(Byte)type{
    UInt8 intValByte[6] = {type, 0x00, 0x00, 0x00, 0x00, 0x00};
    int timestamp = [[NSDate date] timeIntervalSince1970]; //always imbed timestamp
    NSLog(@"TimeStamp: %i", timestamp);
    //NSLog(@"Data 1: %i", [self integerToBytes:timestamp][0]);
    //NSLog(@"Data 2: %i", [self integerToBytes:timestamp][1]);
    //NSLog(@"Data 3: %i", [self integerToBytes:timestamp][2]);
    //NSLog(@"Data 4: %i", [self integerToBytes:timestamp][3]);
    intValByte[1] = [self integerToBytes:timestamp][3];
    intValByte[2] = [self integerToBytes:timestamp][2];
    intValByte[3] = [self integerToBytes:timestamp][1];
    intValByte[4] = [self integerToBytes:timestamp][0];
    NSLog(@"Send Data ->");
    [self sendData:intValByte];
}


-(void) readRSSI{
    [activePeripheral readRSSI];
}

-(BOOL) isConnected{
    return isConnected;
}

-(void) read{
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_CHAR_TX_UUID];
    
    [self readValue:uuid_service characteristicUUID:uuid_char p:activePeripheral];
}

-(void) write:(NSData *)d{
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_CHAR_RX_UUID];
    
    [self writeValue:uuid_service characteristicUUID:uuid_char p:activePeripheral data:d];
}

-(void) enableReadNotification:(CBPeripheral *)p{
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_CHAR_TX_UUID];
    
    [self notification:uuid_service characteristicUUID:uuid_char p:p on:YES];
}

-(void) notification:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p on:(BOOL)on{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    if (!service){
        NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
              [self CBUUIDToString:serviceUUID],
              p.identifier.UUIDString);
        
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if (!characteristic){
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              [self CBUUIDToString:characteristicUUID],
              [self CBUUIDToString:serviceUUID],
              p.identifier.UUIDString);
        
        return;
    }
    [p setNotifyValue:on forCharacteristic:characteristic];
}


- (int) findBLEPeripherals:(int) timeout{
    CBCentralManager *cm =[AppDelegate getCentralManagerInstance];
    
    if (cm.state != CBCentralManagerStatePoweredOn){
        NSLog(@"CoreBluetooth not correctly initialized !");
        NSLog(@"State = %d (%s)\r\n", cm.state, [self centralManagerStateToString:cm.state]);
        return -1;
    }
    
    //[NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];
    [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(deviceScanCompleteTimer:) userInfo:nil repeats:NO];

    
    /*
    else if([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
    {
        // Device Information Service - discover manufacture name characteristic
        [peripheralManager discoverCharacteristics:[NSArray arrayWithObject:[CBUUID UUIDWithString:@"2A29"]] forService:service];
    }
    else if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
    {
        // GAP (Generic Access Profile) - discover device name characteristic
        [peripheralManager discoverCharacteristics:[NSArray arrayWithObject:[CBUUID UUIDWithString:CBUUIDDeviceNameString]]  forService:service];
    }*/
    
    //Use this for Device Information Service . . .
    //[cm scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@"180A"]] options:nil];

    
    //Use this to only scan for defined service advertizers
    //[cm scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@BLE_SERVICE_UUID]] options:nil];

    [cm scanForPeripheralsWithServices:nil options:nil]; // Start scanning

    NSLog(@"scanForPeripheralsWithServices");
    return 0; // Started scanning OK !
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;{
    done = false;
    [self bleDidDisconnect];
    isConnected = false;
}

- (void) connectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"Connecting to peripheral with UUID : %@", peripheral.identifier.UUIDString);
    self.activePeripheral = peripheral;
    self.activePeripheral.delegate = self;
    CBCentralManager *cm =[AppDelegate getCentralManagerInstance];
    [cm connectPeripheral:self.activePeripheral
                  options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    [cm stopScan];
}

- (void) scanTimer:(NSTimer *)timer
{
    CBCentralManager *cm =[AppDelegate getCentralManagerInstance];
    [cm stopScan];
    NSLog(@"Stopped Scanning");
    NSLog(@"Known peripherals : %lu", (unsigned long)[self.peripherals count]);
    [self logKnownPeripherals];
    if([self.peripherals count]<=0)
    {
        //[[NSNotificationCenter defaultCenter] postNotificationName:EVENT_DEVICE_SCAN_COMPLETE object:self userInfo:theInfo];

    }
}



#if TARGET_OS_IPHONE
//-- no need for iOS
#else
- (BOOL) isLECapableHardware{
    NSString * state = nil;
    CBCentralManager *cm =[AppDelegate centralManagerInstance];
    switch ([cm state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
            
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
            
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
            
        case CBCentralManagerStatePoweredOn:
            return TRUE;
            
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
            
    }
    
    NSLog(@"Central manager state: %@", state);
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:state];
    [alert addButtonWithTitle:@"OK"];
    [alert setIcon:[[NSImage alloc] initWithContentsOfFile:@"AppIcon"]];
    [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:nil];
    return FALSE;
}
#endif

//Central manager delegate methods

- (void)centralManager:(CBCentralManager *)central
      willRestoreState:(NSDictionary *)state {
    
    [self scheduleNotification:@"BLE->willRestoreState" soundName:@""];
    
    NSLog(@"CoreBluetooth triggered a restored State!!!");
    //self.activePeripheral = [state[CBCentralManagerRestoredStatePeripheralsKey] firstItem];
    //self.activePeripheral.delegate = self;
    
    
    
    NSArray *peripheralsConnected = state[CBCentralManagerRestoredStatePeripheralsKey];
    
    NSString *str = [NSString stringWithFormat: @"%@ %lu", @"Saved Devices: ", (unsigned long)peripheralsConnected.count];
    [self scheduleNotification:str soundName:@""];
    
    for(int i = 0;i<peripheralsConnected.count;i++)
    {
        CBPeripheral *object = (CBPeripheral *)[peripheralsConnected objectAtIndex:i];
        [self connectPeripheral:object];
        
        [self scheduleNotification:@"reconnected peripheral" soundName:@""];
    }
    
    [self sendMessage:SLAVE_RECONNECT_SYNC_REQUEST];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self scheduleNotification:@"Update State" soundName:@""];
    if(central.state == CBCentralManagerStatePoweredOn)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"COREBLUETOOTH_READY" object:self];
    
#if TARGET_OS_IPHONE
    NSLog(@"Status of CoreBluetooth central manager changed %d (%s)", central.state, [self centralManagerStateToString:central.state]);
#else
    [self isLECapableHardware];
#endif
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    [self scheduleNotification:@"Found Perf" soundName:@""];
    if (!self.peripherals)
        self.peripherals = [[NSMutableArray alloc] initWithObjects:peripheral,nil];
    else
    {
        for(int i = 0; i < self.peripherals.count; i++)
        {
            CBPeripheral *p = [self.peripherals objectAtIndex:i];
            
            if ((p.identifier == NULL) || (peripheral.identifier == NULL))
                continue;
            
            if ([self UUIDSAreEqual:p.identifier UUID2:peripheral.identifier])
            {
                [self.peripherals replaceObjectAtIndex:i withObject:peripheral];
                NSLog(@"Duplicate UUID found updating...");
                NSDictionary *theInfo = [NSDictionary dictionaryWithObjectsAndKeys:peripherals,@"myArray", nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DID_DISCOVER_PERIPHERAL" object:self userInfo:theInfo];
                [self didDiscoverPeripheral];
                return;
            }
        }
        
        [self.peripherals addObject:peripheral];
        
        NSLog(@"New UUID, adding");
    }
    
    NSDictionary *theInfo = [NSDictionary dictionaryWithObjectsAndKeys:peripherals,@"myArray", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DID_DISCOVER_PERIPHERAL" object:self userInfo:theInfo];
    
    
    //Connect to peripheral if already Cached
    
    CBPeripheral *targetPerf;
    PairedDevice *diskPerf = [self loadConnectedDevicesFromDisk];
    if(diskPerf != NULL){
        targetPerf = [self findPeripheralMatchingUUID:diskPerf.uuid];
        NSLog(@"loaded previous match off of disk");
        
        if(targetPerf != NULL){
            [self connectPeripheral:targetPerf];
            NSLog(@"Reconnected to a Old Device");
        }
    }
    NSLog(@"didDiscoverPeripheral");
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (peripheral.identifier != NULL)
        NSLog(@"Connected to %@ successful", peripheral.identifier.UUIDString);
    else
        NSLog(@"Connected to NULL successful");
    
    self.activePeripheral = peripheral;
    [self.activePeripheral discoverServices:nil];
    [self getAllServicesFromPeripheral:peripheral];
}





//END central manager delegate methods


//Peripheral Delegate Methods
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (!error){
        //NSLog(@"Characteristics of service with UUID : %@ found\n",[self CBUUIDToString:service.UUID]);
        for (int i=0; i < service.characteristics.count; i++){
                CBCharacteristic *c = [service.characteristics objectAtIndex:i];
                //NSLog(@"Found characteristic %@\n",[ self CBUUIDToString:c.UUID]);
            CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count - 1)];
            if ([service.UUID isEqual:s.UUID]){
                if (!done){
                    [self enableReadNotification:activePeripheral];
                    [self bleDidConnect];
                    isConnected = true;
                    done = true;
                }
                break;
            }
        }
    }
    else{
        NSLog(@"Characteristic discorvery unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (!error){
        [self getAllCharacteristicsFromPeripheral:peripheral];
    }
    else{
        NSLog(@"Service discovery was unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (!error)
    {
        //Removed, spammy. TODO add debug flag. If you want to debug, add a log here.
    }
    else{
        NSLog(@"Error in setting notification state for characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              [self CBUUIDToString:characteristic.UUID],
              [self CBUUIDToString:characteristic.service.UUID],
              peripheral.identifier.UUIDString);
        NSLog(@"Error code was %s", [[error description] cStringUsingEncoding:NSStringEncodingConversionAllowLossy]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    unsigned char data[20];
    static unsigned char buf[512];
    static int len = 0;
    NSInteger data_len;
    
    if (!error){
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@BLE_CHAR_TX_UUID]]){
            data_len = characteristic.value.length;
            [characteristic.value getBytes:data length:data_len];
            if (data_len == 20){
                memcpy(&buf[len], data, 20);
                len += data_len;
                
                if (len >= 64){
                    [self bleDidReceiveData:buf length:len];
                    len = 0;
                }
            }
            else if (data_len < 20){
                memcpy(&buf[len], data, data_len);
                len += data_len;
                
                [self bleDidReceiveData:buf length:len];
                len = 0;
            }
        }
    }
    else{
        [self scheduleNotification:@"Incoming Data: Corrupted!" soundName:@""];
        NSLog(@"updateValueForCharacteristic failed!");
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error{
    //NSLog(@"BLEConnectionDelegate->peripheralDidUpdateRSSI");
    if (!isConnected)
        return;
    
    if (rssi != peripheral.RSSI.intValue)
    {
        rssi = peripheral.RSSI.intValue;
        [self bleDidUpdateRSSI:activePeripheral.RSSI];
    }
}

/**
 * Utility functions
 *
 * Helpler functions for various BLE related things
 *
 */


-(void) readValue: (CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    if (!service){
        NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
              [self CBUUIDToString:serviceUUID],
              p.identifier.UUIDString);
        
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if (!characteristic){
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              [self CBUUIDToString:characteristicUUID],
              [self CBUUIDToString:serviceUUID],
              p.identifier.UUIDString);
        return;
    }
    [p readValueForCharacteristic:characteristic];
}

-(void) writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    if (!service){
        NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
              [self CBUUIDToString:serviceUUID],
              p.identifier.UUIDString);
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if (!characteristic){
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              [self CBUUIDToString:characteristicUUID],
              [self CBUUIDToString:serviceUUID],
              p.identifier.UUIDString);
        return;
    }
    [p writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
}

//Assumes 4 Byte Arrays
-(int) bytesToInteger:(Byte *) byte_array {
    long val = 0;
    val = ((long )byte_array[0]) << 24;
    val |= ((long )byte_array[1]) << 16;
    val |= ((long )byte_array[2]) << 8;
    val |= byte_array[3];
    return val;
}

-(int) byteToInteger:(Byte *) byte{
    long val = 0;
    val |= *byte;
    return val;
}


-(Byte *) integerToBytes:(int) int_to_convert {
    UInt8 buf[4] = {0x00, 0x00, 0x00 , 0x00};
    buf[0] = int_to_convert;
    buf[1] = int_to_convert >> 8;
    buf[2] = int_to_convert >> 16;
    buf[3] = int_to_convert >> 24;
    return buf;
}

-(Byte *) integerToByte:(int) int_to_convert {
    UInt8 buf[4] = {0x00};
    buf[0] = int_to_convert;
    return buf;
}


-(NSString *)stringWithUrl:(NSURL *)url {
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url
                                                cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                            timeoutInterval:30];
    // Fetch the JSON response
    NSData *urlData;
    NSURLResponse *response;
    NSError *error;
    // Make synchronous request
    urlData = [NSURLConnection sendSynchronousRequest:urlRequest
                                    returningResponse:&response
                                                error:&error];
    // Construct a String around the Data from the response
    return [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
}



- (BOOL) UUIDSAreEqual:(NSUUID *)UUID1 UUID2:(NSUUID *)UUID2{
    if ([UUID1.UUIDString isEqualToString:UUID2.UUIDString])
        return TRUE;
    else
        return FALSE;
}

-(void) getAllServicesFromPeripheral:(CBPeripheral *)p{
    [p discoverServices:nil]; // Discover all services without filter, for debugging puproses
}

-(void) getAllCharacteristicsFromPeripheral:(CBPeripheral *)p{
    for (int i=0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        [p discoverCharacteristics:nil forService:s];
    }
}

-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2{
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1];
    [UUID2.data getBytes:b2];
    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}

-(int) compareCBUUIDToInt:(CBUUID *)UUID1 UUID2:(UInt16)UUID2{
    char b1[16];
    
    [UUID1.data getBytes:b1];
    UInt16 b2 = [self swap:UUID2];
    
    if (memcmp(b1, (char *)&b2, 2) == 0)
        return 1;
    else
        return 0;
}

-(UInt16) CBUUIDToInt:(CBUUID *) UUID{
    char b1[16];
    [UUID.data getBytes:b1];
    return ((b1[0] << 8) | b1[1]);
}

-(CBUUID *) IntToCBUUID:(UInt16)UUID{
    char t[16];
    t[0] = ((UUID >> 8) & 0xff); t[1] = (UUID & 0xff);
    NSData *data = [[NSData alloc] initWithBytes:t length:16];
    return [CBUUID UUIDWithData:data];
}

-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p{
    for(int i = 0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }
    return nil; //Service not found on this peripheral
}

-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service{
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([self compareCBUUID:c.UUID UUID2:UUID]) return c;
    }
    return nil; //Characteristic not found on this service
}


-(void) makeUrlRequest:(NSString*) url vars:(NSMutableDictionary*) dict{
    uint counter = 0;
    NSMutableString* urlString = [NSMutableString string];
    [urlString appendString:[NSString stringWithFormat:@"%@", url]];
    [urlString appendString:[NSString stringWithFormat:@"%s", "?"]];
    for(id key in dict)
    {
        if(counter>0)
            [urlString appendString:[NSString stringWithFormat:@"%s", "&"]];
        [urlString appendString:[NSString stringWithFormat:@"%@", key]];
        [urlString appendString:[NSString stringWithFormat:@"%s", "="]];
        [urlString appendString:[NSString stringWithFormat:@"%@", [dict objectForKey:key]]];
        counter++;
    }
    NSURL *testUrl = nil;
    testUrl = [NSURL URLWithString:urlString];
    //NSString *returnVal = [self stringWithUrl:testUrl];
    //NSLog(urlString);
    //NSLog(returnVal);
}

-(NSString *) CBUUIDToString:(CBUUID *) cbuuid;{
    NSData *data = cbuuid.data;
    
    if ([data length] == 2)
    {
        const unsigned char *tokenBytes = [data bytes];
        return [NSString stringWithFormat:@"%02x%02x", tokenBytes[0], tokenBytes[1]];
    }
    else if ([data length] == 16)
    {
        NSUUID* nsuuid = [[NSUUID alloc] initWithUUIDBytes:[data bytes]];
        return [nsuuid UUIDString];
    }
    
    return [cbuuid description];
}

- (const char *) centralManagerStateToString: (int)state{
    switch(state){
        case CBCentralManagerStateUnknown:
            return "State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return "State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return "State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return "State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return "State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return "State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return "State unknown";
    }
    return "Unknown state";
}


-(UInt16) swap:(UInt16)s{
    UInt16 temp = s << 8;
    temp |= (s >> 8);
    return temp;
}

/**
 * Debugging functions
 *
 * For assistance in logging and notifications with debugging info TODO add boolean switch
 *
 */



- (void) logKnownPeripherals
{
    NSLog(@"List of currently known peripherals :");
    for (int i = 0; i < self.peripherals.count; i++)
    {
        CBPeripheral *p = [self.peripherals objectAtIndex:i];
        
        if (p.identifier != NULL)
            NSLog(@"%d  |  %@", i, p.identifier.UUIDString);
        else
            NSLog(@"%d  |  NULL", i);
        
        [self logPeripheralInfo:p];
    }
}

- (void) logPeripheralInfo:(CBPeripheral*)peripheral{
    NSLog(@"Peripheral Info :");
    if (peripheral.identifier != NULL)
        NSLog(@"UUID : %@", peripheral.identifier.UUIDString);
    else
        NSLog(@"UUID : NULL");
    NSLog(@"Name : %@", peripheral.name);
}


- (IBAction) scheduleNotification:(NSString*) body soundName:(NSString*) soundName{
    
    SettingsObject *settingsObject = [SettingsObject getSettingsObjectSingleton];
    if(settingsObject.notificationsEnabled)
    {
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    // Get the current date
    NSDate *pickerDate = [NSDate date];
    // Break the date up into components
    NSDateComponents *dateComponents = [calendar components:( NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit )
												   fromDate:pickerDate];
    NSDateComponents *timeComponents = [calendar components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit )
												   fromDate:pickerDate];
    // Set up the fire time
    NSDateComponents *dateComps = [[NSDateComponents alloc] init];
    [dateComps setDay:[dateComponents day]];
    [dateComps setMonth:[dateComponents month]];
    [dateComps setYear:[dateComponents year]];
    [dateComps setHour:[timeComponents hour]];
	// Notification will fire in one minute
    [dateComps setMinute:[timeComponents minute]];
	[dateComps setSecond:[timeComponents second]];
    NSDate *itemDate = [calendar dateFromComponents:dateComps];
    
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif == nil)
        return;
    localNotif.fireDate = itemDate;
    localNotif.timeZone = [NSTimeZone defaultTimeZone];
    
	// Notification details
    localNotif.alertBody = body;
	// Set the action button
    localNotif.alertAction = @"Ok";
    
    localNotif.soundName = @"";//soundName;
    localNotif.applicationIconBadgeNumber = 0;
    
	// Specify custom data for the notification
    NSDictionary *infoDict = [NSDictionary dictionaryWithObject:@"someValue" forKey:@"someKey"];
    localNotif.userInfo = infoDict;
	// Schedule the notification
    //[[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
    }
    else
    {
        NSLog(@"BLEConnectionDelegate - notificaions disabled");
    }
}

-(void) registerEventToServer{
    int timestamp = [[NSDate date] timeIntervalSince1970]; //always imbed timestamp
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setValue:@"10" forKey:@"value"];
    [dict setValue:@"1" forKey:@"user"];
    [dict setValue:[NSNumber numberWithInt:timestamp] forKey:@"time"];
    [self makeUrlRequest: @"http://donothingbox.com/add_water_test.php" vars:dict];
}

-(NSString *) stringByStrippingHTML:(NSString*)targetString {
    NSRange r;
    NSString *s = [targetString copy];
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s;
}

@end
