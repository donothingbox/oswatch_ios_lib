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

#import "SettingsViewController.h"
#import <CoreBluetooth/CBPeripheral.h>
#import "BLEConnectionDelegate.h"
#import "AppDelegate.h"
#import "SettingsObject.h"


@interface SettingsViewController ()

@end

@implementation SettingsViewController

@synthesize bleConnection;
static SettingsViewController* _tableViewController = nil;

static bool CACHE_CONNECTION = true;


+(SettingsViewController*) getTableViewRef {
    return _tableViewController;
}

- (void)viewDidLoad {
    _tableViewController = self;
    [super viewDidLoad];
    
    bleConnection = [AppDelegate getBLEConnectionDelegateInstance];
    SettingsObject *settingsObject = [self loadSettingsStateFromDisk];
    if(settingsObject != NULL){
        NSLog(@"Loaded Settings State");
        notificationsEnabled.on = settingsObject.notificationsEnabled;
        reconnectEnabled.on = settingsObject.reconnectionsEnabled;
        notificationsEnabled.enabled = true;
        reconnectEnabled.enabled = true;
    }
    else
    {
        NSLog(@"Creating New Settings State");
        notificationsEnabled.on = true;
        reconnectEnabled.on = true;
        notificationsEnabled.enabled = true;
        reconnectEnabled.enabled = true;
        [self saveSettingsState];
    }
    
    if([bleConnection isConnected])
    {
        CFStringRef s = CFUUIDCreateString(NULL, [bleConnection getActivePeripheral].UUID);
        dispUUID.text = (__bridge NSString *)(s);
    }
    
   }

-(void) saveSettingsState{
    SettingsObject *settingsObject = [[SettingsObject alloc] init];
    settingsObject.reconnectionsEnabled = reconnectEnabled.on;
    settingsObject.notificationsEnabled = notificationsEnabled.on;
    NSLog(@"Saving State");
    NSLog(@"Notification is: %d", settingsObject.notificationsEnabled);
    NSLog(@"Reconnection is: %d", settingsObject.reconnectionsEnabled);

    
    NSArray *array = [[NSArray alloc] initWithObjects:settingsObject, nil];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *fullFileName = [NSString stringWithFormat:@"%@/settingsData", docDir];
    [NSKeyedArchiver archiveRootObject:array toFile:fullFileName];
}

-(SettingsObject *) loadSettingsStateFromDisk{
    if(CACHE_CONNECTION)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = [paths objectAtIndex:0];
        NSString *fullFileName = [NSString stringWithFormat:@"%@/settingsData", docDir];
        NSMutableArray *arrayFromDisk = [NSKeyedUnarchiver unarchiveObjectWithFile:fullFileName];
        SettingsObject *settingsObject = [arrayFromDisk objectAtIndex:0];
        NSLog(@"Loading State");
        NSLog(@"Notification is: %d", settingsObject.notificationsEnabled);
        NSLog(@"Reconnection is: %d", settingsObject.reconnectionsEnabled);
        return settingsObject;
    }
    else
    {
        return NULL;
    }
}

- (IBAction)changeNotificationState:(id)sender{
    
    if([sender isOn]){
        NSLog(@"Notification is ON");
    } else{
        NSLog(@"Notification is OFF");
    }
    [self saveSettingsState];
}

- (IBAction)changeReconnectState:(id)sender{
    
    if([sender isOn]){
        NSLog(@"Reconnect is ON");
    } else{
        NSLog(@"Reconnect is OFF");
    }
    [self saveSettingsState];
}


-(IBAction)forgetPairedDevice:(id)sender{
    if(bleConnection.isConnected)
        [bleConnection disconnectPeripheral:[bleConnection activePeripheral]];
    [bleConnection deleteConnectedDeviceFromDisk];
    dispUUID.text = @"----------------";
    NSLog(@"Disconnecting Device, and forgetting pair");
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

