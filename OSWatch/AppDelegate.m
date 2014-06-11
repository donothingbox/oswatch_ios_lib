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

#import "AppDelegate.h"
#import "BLEConnectionDelegate.h"
#import "SettingsObject.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

@synthesize s_centralManagerSingleton;
//@synthesize bleConnection;
//@synthesize delegate;

static Boolean willRestoreBLE = false;


static CBCentralManager *s_centralManagerSingleton = nil;

static BLEConnectionDelegate *s_bleConnectionDelegateSingleton = nil;


- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    // Override point for customization after application launch.
    return NO;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    // Override point for customization after application launch.
    return NO;
}

//TODO clean this up. I need to Secure the "WillRestoreState" It's still being a pain.

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"Finished loading");
    //May cause issues, but here to clear local notifs and avoid redundant spam
    [AppDelegate setBLEConnectionDelegateInstance: [[BLEConnectionDelegate alloc] init]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bluetoothStatusReady:) name:@"COREBLUETOOTH_READY" object:nil];
    s_bleConnectionDelegateSingleton = [AppDelegate getBLEConnectionDelegateInstance];

    //this probably should be deleted, as it is never realistically called TODO
    if ([AppDelegate getCentralManagerInstance].state == CBCentralManagerStatePoweredOn) {
        [[AppDelegate getCentralManagerInstance] scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@BLE_SERVICE_UUID]] options:nil];
    }
    
    // Override point for customization after application launch.
    NSArray *centralManagerIdentifiers = launchOptions[UIApplicationLaunchOptionsBluetoothCentralsKey];
    NSString *str = [NSString stringWithFormat: @"%@ %lu", @"Manager Restores: ", (unsigned long)centralManagerIdentifiers.count];
    if(centralManagerIdentifiers.count>0)
       willRestoreBLE = true;
    
    [self sendNotification:str];
    for(int i = 0;i<centralManagerIdentifiers.count;i++){
        [self sendNotification:(NSString *)[centralManagerIdentifiers objectAtIndex:i]];
    }
    
    
    //Ok, so this seems to be a "core" issue. Without the Que, the willRestoreState is not called properly, but with this, messages are delayed by 2  - 5 seconds if the app is currently open
    dispatch_queue_t centralQueue = dispatch_queue_create("com.donothingbox", DISPATCH_QUEUE_SERIAL);
    
    [AppDelegate setCentralManagerInstance : [[CBCentralManager alloc] initWithDelegate:[AppDelegate getBLEConnectionDelegateInstance] queue:centralQueue
                                                                                options:@{ CBCentralManagerOptionRestoreIdentifierKey:
                                                                                               @"DoNothingBoxCentralManager" }]];

    if(willRestoreBLE)
        [[AppDelegate getBLEConnectionDelegateInstance] sendMessage:SLAVE_RECONNECT_SYNC_REQUEST]; //resend last transmission request
    
    [[AppDelegate getCentralManagerInstance] scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@BLE_SERVICE_UUID]] options:nil];
    return YES;
}



- (void) bluetoothStatusReady:(NSNotification*)notification
{
    if ([AppDelegate getCentralManagerInstance].state == CBCentralManagerStatePoweredOn) {
        
        NSLog(@"Scanning with callback");
        
        NSString *str = [NSString stringWithFormat: @"Scan W Callback"];
        [self sendNotification:str];
        
        [[AppDelegate getCentralManagerInstance] scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@BLE_SERVICE_UUID]] options:nil];
    }
    
    
}







+(CBCentralManager *)getCentralManagerInstance
{
    return s_centralManagerSingleton;
}

+(void)setCentralManagerInstance:(CBCentralManager *)central
{
    s_centralManagerSingleton = central;
}

+(BLEConnectionDelegate *)getBLEConnectionDelegateInstance
{
    return s_bleConnectionDelegateSingleton;
}

+(void)setBLEConnectionDelegateInstance:(BLEConnectionDelegate *)central
{
    s_bleConnectionDelegateSingleton = central;
}

//This still doesn't work yet
- (void)centralManager:(CBCentralManager *)central
      willRestoreState:(NSDictionary *)state {
    
    [self sendNotification:@"AD->willRestoreState"];
    
    NSLog(@"CoreBluetooth triggered a restored State!!!");
    NSArray *peripheralsConnected = state[CBCentralManagerRestoredStatePeripheralsKey];
    
    NSString *str = [NSString stringWithFormat: @"%@ %lu", @"Saved Devices: ", (unsigned long)peripheralsConnected.count];
    [self sendNotification:str];
    
    for(int i = 0;i<peripheralsConnected.count;i++)
        
    {
        CBPeripheral *object = (CBPeripheral *)[peripheralsConnected objectAtIndex:i];
        NSLog(@"found perf");
        
        //[self.centralManager connectPeripheral:object];
        [self sendNotification:@"AD reconnected peripheral"];
    }
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


- (IBAction) sendNotification:(NSString*) body {
    
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
    localNotif.alertAction = @"Connect";
    
    localNotif.soundName = @"";
    localNotif.applicationIconBadgeNumber = 0;
    
	// Specify custom data for the notification
    NSDictionary *infoDict = [NSDictionary dictionaryWithObject:@"someValue" forKey:@"someKey"];
    localNotif.userInfo = infoDict;
    
	// Schedule the notification
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
    }
    else
    {
        NSLog(@"BLEConnectionDelegate - notificaions disabled");
    }
}


@end
