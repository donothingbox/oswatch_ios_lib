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

#import "ConnectionViewController.h"
#import <CoreBluetooth/CBPeripheral.h>
#import "PairedDevice.h"
#import "BLEConnectionDelegate.h"
#import "AppDelegate.h"
#import <AVFoundation/AVAudioPlayer.h>

#define EVENT_CONSUME_WATER  0x0A
#define EVENT_REQUEST_TIME  0x01

@interface ConnectionViewController ()

@end

@implementation ConnectionViewController

@synthesize bleConnection;
@synthesize m_detectedDevices;
@synthesize m_avalableConnectionButtons;
static ConnectionViewController* _tableViewController = nil;
static UIButton* myPopup = nil;

UIScrollView *scrollView;

UIView *greyOut;

+(ConnectionViewController*) getTableViewRef {
    return _tableViewController;
}

- (void)viewDidLoad {
    _tableViewController = self;
    [super viewDidLoad];
    bleConnection = [AppDelegate getBLEConnectionDelegateInstance];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceUpdatedRSSI:) name:EVENT_DEVICE_UPDATED_RSSI object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bleMessageReceived:) name:EVENT_DEVICE_SENT_DATA object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceScanStarted:) name:EVENT_DEVICE_SCAN_STARTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceScanCompleted:) name:EVENT_DEVICE_SCAN_COMPLETE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnected:) name:EVENT_DEVICE_CONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceScanReturnedNone:) name:EVENT_NO_DEVICES_FOUND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lostActiveBluetoothConnection:) name:EVENT_DEVICE_DISCONNECTED object:nil];
}

/*
 * BLE event listeners
 *
 * Listening to Events the BLEConnectionDelegate will broadcast
 *
 */

- (void) deviceScanStarted:(NSNotification*)notification {
    statusFeedback.text = @"Scanning for 3 seconds . . . ";
    [indConnecting startAnimating];
    NSLog(@"TableViewController->deviceScanStarted");
    [btnConnect setEnabled:true];
    [btnConnect setTitle:@"Scanning" forState:UIControlStateNormal];
}

- (void) bleMessageReceived:(NSNotification*)notification {
    
    NSLog(@"We got data!");

    NSArray  *theArray = [[notification userInfo] objectForKey:@"messageData"];
    NSInteger lengthByte = [theArray[0] integerValue];
    NSLog(@"MESSAGE LENGTH ->:%d", lengthByte);
    for (int i = 0; i < lengthByte; i++){
        NSLog(@"BYTE:%@", theArray[i]);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *displayData = [NSString stringWithFormat: @"Length %d, [%@, %@]", lengthByte, theArray[1], theArray[2]];
        statusFeedback.text = displayData;
        [self displayBleMessage];
    });
}

- (void) deviceScanCompleted:(NSNotification*)notification{
    NSLog(@"TableViewController->deviceScanCompleted");
    NSArray  *theArray = [[notification userInfo] objectForKey:@"myArray"];
    UIImage *buttonBG = [UIImage imageNamed:@"ble_select_btn.png"];
    
    if(theArray.count>0)
        [self addScrollViewForDevices];
    
    m_detectedDevices = [[NSMutableArray alloc] initWithCapacity:theArray.count];
    m_avalableConnectionButtons = [[NSMutableArray alloc] initWithCapacity:theArray.count];
    for(int i = 0;i<theArray.count;i++){
        CBPeripheral *currentPerf = [theArray objectAtIndex:i];
        [bleConnection getAllServicesFromPeripheral:currentPerf];
        CFStringRef cfUUID = CFUUIDCreateString(NULL, currentPerf.UUID);
        NSString *uuidStr = (__bridge NSString *) cfUUID;
        NSString *subUUID = [uuidStr substringWithRange:NSMakeRange(uuidStr.length-10, 9)];
        NSString *displayStr = [NSString stringWithFormat:@"%@,%@", subUUID, currentPerf.name];
        CFStringRef s = CFUUIDCreateString(NULL, currentPerf.UUID);
        NSString *aNSString = (__bridge NSString *) s;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        button.tag = 1000 + i;
        [button addTarget:self action:@selector(deviceSelectPressed:) forControlEvents:UIControlEventTouchDown];
        //NSString *subString = [aNSString substringWithRange:NSMakeRange(aNSString.length-10, 9)];
        [button setTitle:displayStr forState:UIControlStateNormal];
        //[button setTitle:(__bridge NSString *)(s) forState:UIControlStateNormal];
        [button setBackgroundImage:buttonBG forState:UIControlStateNormal];
        button.frame = CGRectMake(35.0/2, 50.0+(i*50), buttonBG.size.width/2, buttonBG.size.height/2);
        [scrollView addSubview:button];
        [m_detectedDevices addObject:[theArray objectAtIndex:i]];
        [m_avalableConnectionButtons addObject:button];
    }

    statusFeedback.text = @"Scan Complete";
    [btnConnect setEnabled:true];
    [btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
    [indConnecting stopAnimating];
}

- (void) deviceScanReturnedNone:(NSNotification*)notification{
    statusFeedback.text = @"No BLE devices advertizing and in range";
    [btnConnect setEnabled:true];
    [btnConnect setTitle:@"connect" forState:UIControlStateNormal];
    [indConnecting stopAnimating];
    NSLog(@"ConnectionViewController->deviceScanReturnedNone");
}

- (void) lostActiveBluetoothConnection:(NSNotification*)notification{
    [btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
    dispUUID.text = @"----------------";
    
    statusFeedback.text = @"hmmm . . . not sure if you meant to do this or not, but for some strange reason we lost contact with the watch. Ignore this if this was an intentional action";
    NSLog(@"ConnectionViewController->Active Bluetooth Connection lost . . . ");
    NSString *title     = @"Bluetooth Disconnected";
    NSString *message   = @"Please reconnect to sync data";
    //Fixed since this is called from the seperate BLE thread
    dispatch_async(dispatch_get_main_queue(), ^{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alertView show];
    });
    
}

//Enable Interfaces
- (void) deviceConnected:(NSNotification*)notification{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"ConnectionViewController->deviceConnected");
        [btnConnect setTitle:@"Disonnect" forState:UIControlStateNormal];
        lblAnalogIn.enabled = true;
        swDigitalOut.enabled = true;
        swDigitalIn.enabled = true;
        swAnalogIn.enabled = true;
        sldPWM.enabled = true;
        sldServo.enabled = true;

        swDigitalOut.on = false;
        swDigitalIn.on = false;
        swAnalogIn.on = false;
        sldPWM.value = 0;
        sldServo.value = 0;
    
        CFStringRef s = CFUUIDCreateString(NULL, [bleConnection getActivePeripheral].UUID);
        dispUUID.text = (__bridge NSString *)(s);
        statusFeedback.text = @"Device Connected!";
    });
}

-(void) deviceUpdatedRSSI:(NSNotification*) notification{

    //Fixed since this is called from the seperate BLE thread
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"ConnectionViewController->deviceUpdatedRSSI");
        //Temp hack to get display to change on recovery TODO restoreState
        CFStringRef s = CFUUIDCreateString(NULL, [bleConnection getActivePeripheral].UUID);
        dispUUID.text = (__bridge NSString *)(s);
        [btnConnect setTitle:@"Disonnect" forState:UIControlStateNormal];
        //end of hack
        
        NSNumber *rssi = [[notification userInfo] objectForKey:@"rssi"];
        lblRSSI.text = rssi.stringValue;
        if([bleConnection isConnected])
        {
            CFStringRef s = CFUUIDCreateString(NULL, [bleConnection getActivePeripheral].UUID);
            dispUUID.text = (__bridge NSString *)(s);
        }
    });
    

}

/*
 * UI Interactions
 *
 */

-(void) displayBleMessage{
    [self addGreyOut];
    //Used for BLE connection testing
    //[self playAudio];
    
    if(myPopup)
        [myPopup removeFromSuperview];
    
    UIImage *buttonBG = [UIImage imageNamed:@"ble_popup_1_bg.png"];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button addTarget:self action:@selector(messageAcknowledged:) forControlEvents:UIControlEventTouchDown];
    [button setTitle:@"Recieved Message" forState:UIControlStateNormal];
    //[button setTitle:(__bridge NSString *)(s) forState:UIControlStateNormal];
    [button setBackgroundImage:buttonBG forState:UIControlStateNormal];
    button.frame = CGRectMake(35.0/2, 100.0, buttonBG.size.width/2, buttonBG.size.height/2);
    [self.view addSubview:button];
    myPopup = button;  
}

-(IBAction)messageAcknowledged:(UIButton *)sender{
    if(myPopup){
        [myPopup removeFromSuperview];
        myPopup = nil;
    }
    [self removeGreyOut];
}

// Connect button will call to this
- (IBAction)btnScanForPeripherals:(id)sender
{
    [bleConnection scanForPeripherals];
    [indConnecting startAnimating];
}

// Connect button will call to this
- (IBAction)btnKillApp:(id)sender
{
    kill(getpid(), SIGKILL);
}

-(void) addScrollViewForDevices{
    
    [self addGreyOut];
    CGRect fullScreenRect=[[UIScreen mainScreen] applicationFrame];
    scrollView=[[UIScrollView alloc] initWithFrame:fullScreenRect];
    scrollView.contentSize=CGSizeMake(320,758);
    [self.view addSubview:scrollView];
    //[scrollView release];
}

-(void)addGreyOut{
    if(greyOut)
        [greyOut removeFromSuperview];
    CGRect fullScreenRect=[[UIScreen mainScreen] applicationFrame];
    greyOut=[[UIView alloc]initWithFrame:fullScreenRect];
    [greyOut setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.5]];
    [self.view addSubview:greyOut];
}

-(void)removeGreyOut{
    if(greyOut){
        [greyOut removeFromSuperview];
        greyOut = nil;
    }
}



-(IBAction)deviceSelectPressed:(UIButton *)sender
{
    statusFeedback.text = @"Attempting to Connect to Selected Device";
    NSLog(@"TableViewController ->deviceSelectPressed");
    NSUInteger index = sender.tag - 1000;
    CBPeripheral *object = (CBPeripheral *)[m_detectedDevices objectAtIndex:index];
    CFStringRef s = CFUUIDCreateString(NULL, object.UUID);
    NSLog(@"UUID: %@", s);
    [bleConnection connectPeripheral:object];
    NSLog(@"Connecting By Selection!");
    for (UIButton *button in m_avalableConnectionButtons) {
        [button removeFromSuperview];
    }
    [bleConnection saveConnectedDeviceToDisk];
    [scrollView removeFromSuperview];
    [self removeGreyOut];
}



-(IBAction)sendCommandAOut:(id)sender{
    
    [bleConnection sendString];
    
    //UInt8 buf[6] = {0x0A, 0x00, 0x00 , 0x00, 0x00 , 0x00};
    //statusFeedback.text = @"{0x0A, 0x00, 0x00 , 0x00, 0x00 , 0x00}";
    //NSLog(@"CSending digital out");
   // [bleConnection sendData:(buf)];
}

-(IBAction)sendCommandBOut:(id)sender{
    UInt8 buf[6] = {0x0B, 0x00, 0x00 , 0x00, 0x00 , 0x00};
    statusFeedback.text = @"{0x0B, 0x00, 0x00 , 0x00, 0x00 , 0x00}";
    NSLog(@"CSending digital out");
    [bleConnection sendData:(buf)];
}


// basic 3 byte init packet, for connection activation (turn on a connected light, etc)
-(IBAction)sendConnectedInitData:(id)sender
{
    UInt8 buf[6] = {0x04, 0x00, 0x00, 0x00, 0x00, 0x00};
    //NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    //[ble write:data];
    [bleConnection sendData:(buf)];
}


- (IBAction) scheduleAlarm:(id) sender {
    
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
    localNotif.alertBody = @"Bluetooth Connection Lost";
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

- (void) playAudio{
    
    /*
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                         pathForResource:@"cardiac_arrest"
                                         ofType:@"wav"]];
    NSError *error = nil;
    _theAudio = [[AVAudioPlayer alloc]
                 initWithContentsOfURL:url
                 error:&error];
    if (error){
        NSLog(@"Error in audioPlayer: %@",[error localizedDescription]);
    }
    else{
        //audioPlayer.delegate = self;
        [_theAudio play];
        //[_theAudio setNumberOfLoops:INT32_MAX]; // for continuous play
        [_theAudio setNumberOfLoops:1]; // for single play
    }*/
}


- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
