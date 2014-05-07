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

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PairedDevice.h"
#import "BLEConnectionDelegate.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (IBAction) sendNotification:(NSString*) body;
@end

@interface AppDelegate () <CBCentralManagerDelegate> {
    CBCentralManager *s_centralManagerSingleton;
}

@property (strong, nonatomic) NSMutableArray *peripherals;
@property (strong, nonatomic) CBPeripheral *activePeripheral;
@property (strong, nonatomic) BLEConnectionDelegate *delegate;
@property(nonatomic,retain)CBCentralManager *s_centralManagerSingleton;
@property (strong, nonatomic) BLEConnectionDelegate *bleConnection;
@property(nonatomic,retain)BLEConnectionDelegate *s_bleConnectionDelegateSingleton;

- (void) bluetoothStatusReady:(NSNotification*)notification;
+(BLEConnectionDelegate *)getBLEConnectionDelegateInstance;
+(void)setBLEConnectionDelegateInstance:(BLEConnectionDelegate *)central;
+(CBCentralManager *)getCentralManagerInstance;
+(void)setCentralManagerInstance:(CBCentralManager *)central;
@end

