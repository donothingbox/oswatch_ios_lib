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

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PairedDevice.h"

//#define BLE_DEVICE_SERVICE_UUID                         "713D0000-503E-4C75-BA94-3148F18D941E"
//#define BLE_DEVICE_VENDOR_NAME_UUID                     "713D0001-503E-4C75-BA94-3148F18D941E"

//TODO move these to a "Defines" file

#define EVENT_DEVICE_SCAN_STARTED     @"deviceScanStartedNotification"
#define EVENT_DEVICE_SCAN_COMPLETE    @"deviceScanCompleteNotification"
#define EVENT_NO_DEVICES_FOUND        @"noDevicesFoundOnScanNotification"
#define EVENT_DEVICE_CONNECTED        @"deviceScanConnectedNotification"

#define EVENT_DEVICE_UPDATED_RSSI     @"deviceUpdatedRSSINotification"

#define EVENT_DEVICE_DISCONNECTED     @"pairedDeviceDisconnectedNotification"
#define EVENT_DEVICE_SENT_DATA        @"pairedDeviceSentDataNotification"
#define EVENT_DEVICE_RECIEVED_DATA    @"pairedDeviceRecievedDataNotification"

#define EVENT_PHONE_RECIEVED_DATA     @"pairedPhoneRecievedDataNotification"

//BlueCreation, another BLE chip I experimented with
//#define BLE_SERVICE_UUID                         "BC2F4CC6-AAEF-4351-9034-D66268E328F0"
//#define BLE_CHAR_TX_UUID                         "06D1E5E7-79AD-4A71-8FAA-373789F7D93C"
//#define BLE_CHAR_RX_UUID                         "06D1E5E7-79AD-4A71-8FAA-373789F7D93C"

//BlueGiga w BGLib
#define BLE_SERVICE_UUID               "195AE58A-437A-489B-B0CD-B7C9C394BAE4"
#define BLE_CHAR_TX_UUID               "21819AB0-C937-4188-B0DB-B9621E1696CD"
#define BLE_CHAR_RX_UUID               "5FC569A0-74A9-4FA4-B8B7-8354C86E45A4"

//We should move this to user defined
#define MY_CENTRAL_MANAGER_ID          "DoNothingBox-Development-ID"

//Communication IDs
#define BYTE_EVENT_LENGTH  0
#define BYTE_EVENT_APP_ID  1
#define BYTE_EVENT_APP_ACTION  2

#define BYTE_EVENT_TIME  3
#define BYTE_EVENT_VALUE  6
#define BYTE_EVENT_END  7

//Incoming state request IDs
#define GLOBAL_STATE  0
#define MENU_STATE  1
#define TIME_STATE  2
#define RSS_STATE  3

//

#define RSS_APP_ACTION_LOAD_METADATA  1
#define RSS_APP_ACTION_LOAD_BLOCK  2
#define RSS_APP_ACTION_LOAD_PACKET  3




//Outgoing
#define SLAVE_RECONNECT_SYNC_REQUEST  0x00
#define SLAVE_DEVICE_CONNECTED  0x0C
#define SLAVE_PING_RESPONSE  0x01
#define SLAVE_TIME_RESPONSE  0x02

//App/State IDs
#define GLOBAL_STATE  0
#define MENU_STATE  1
#define TIME_STATE  2


@protocol BLEConnectionDelegate
@optional
-(void) bleDidConnect;
-(void) bleDidDisconnect;
-(void) bleDidUpdateRSSI:(NSNumber *) rssi;
-(void) bleDidReceiveData:(unsigned char *) data length:(int) length;

@required
@end

@interface BLEConnectionDelegate : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> {
    BLEConnectionDelegate *s_bleConnectionSingleton;
}

@property (strong, nonatomic) NSMutableArray *m_detectedDevices;
@property (nonatomic,assign) id <BLEConnectionDelegate> delegate;
@property (strong, nonatomic) NSMutableArray *peripherals;
@property (strong, nonatomic) CBCentralManager *CM;
@property (strong, nonatomic) CBPeripheral *activePeripheral;
@property (strong, nonatomic) NSTimer *rssiTimer;

-(IBAction)sendMessage:(Byte)type;
-(IBAction)sendMessage:(Byte)type integerValue:(int)integerValue;
-(IBAction)sendFormattedString:(Byte)stateId stateAction:(Byte)stateAction stateMessage:(NSString*)stateMessage;

-(void) makeUrlRequest:(NSString*) url vars:(NSMutableDictionary*) dict;

-(CBPeripheral *) findPeripheralMatchingUUID:(NSString *) uuidRef;
-(void) connectionTimer:(NSTimer *)timer;
-(void) saveConnectedDeviceToDisk;
-(PairedDevice *) loadConnectedDevicesFromDisk;
-(int) bytesToInteger:(Byte *) byte_array;
-(void) registerEventToServer;
-(NSString *)stringWithUrl:(NSURL *)url;
- (IBAction) sendData:(UInt8*) buf;
- (IBAction) sendString;


-(CBPeripheral *) getActivePeripheral;
-(void) enableReadNotifications;
-(NSMutableArray *) getPeripheralsArray;
-(IBAction)sendReconnectData:(id)sender;
-(void) scanForPeripherals;

-(void) enableReadNotification:(CBPeripheral *)p;
-(void) read;
-(void) writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data;
- (IBAction) scheduleNotification:(NSString*) body soundName:(NSString*) soundName;

-(BOOL) isConnected;
-(void) write:(NSData *)d;
-(void) readRSSI;

-(int) findBLEPeripherals:(int) timeout;
-(void) connectPeripheral:(CBPeripheral *)peripheral;

-(UInt16) swap:(UInt16) s;
-(const char *) centralManagerStateToString:(int)state;
-(void) scanTimer:(NSTimer *)timer;
-(void) logKnownPeripherals;
-(void) logPeripheralInfo:(CBPeripheral*)peripheral;

-(void) getAllServicesFromPeripheral:(CBPeripheral *)p;
-(void) getAllCharacteristicsFromPeripheral:(CBPeripheral *)p;
-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p;
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service;

-(NSString *) CBUUIDToString:(CBUUID *) UUID;
-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2;
-(int) compareCBUUIDToInt:(CBUUID *) UUID1 UUID2:(UInt16)UUID2;
-(UInt16) CBUUIDToInt:(CBUUID *) UUID;
-(BOOL) UUIDSAreEqual:(NSUUID *)UUID1 UUID2:(NSUUID *)UUID2;



@end