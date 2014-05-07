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
#import "PairedDevice.h"
#import "BLEConnectionDelegate.h"
#import <AVFoundation/AVAudioPlayer.h>

@interface ConnectionViewController : UITableViewController <BLEConnectionDelegate>
{
    IBOutlet UIButton *btnCommandA;
    IBOutlet UIButton *btnCommandB;
    IBOutlet UILabel *statusFeedback;
    IBOutlet UIButton *btnConnect;
    IBOutlet UISwitch *swDigitalIn;
    IBOutlet UISwitch *swDigitalOut;
    IBOutlet UISwitch *swAnalogIn;
    IBOutlet UILabel *lblAnalogIn;
    IBOutlet UISlider *sldPWM;
    IBOutlet UISlider *sldServo;
    IBOutlet UIActivityIndicatorView *indConnecting;
    IBOutlet UILabel *lblRSSI;
    IBOutlet UILabel *dispUUID;
}

+(ConnectionViewController*) getTableViewRef;


//below are added vars
@property (nonatomic, retain) AVAudioPlayer *theAudio;
@property (strong, nonatomic) BLEConnectionDelegate *bleConnection;
@property (strong, nonatomic) NSMutableArray *m_detectedDevices;

@property (strong, nonatomic) NSMutableArray *m_avalableConnectionButtons;


-(NSString *) stringWithUrl:(NSURL *)url;
-(int) bytesToInteger:(Byte *)byte_array;

- (void) lostActiveBluetoothConnection:(NSNotification*)notification;
- (void) deviceScanStarted:(NSNotification*)notification;
- (void) deviceScanCompleted:(NSNotification*)notification;
- (void) deviceConnected:(NSNotification*)notification;
-(void) addScrollViewForDevices;

//- (void)decodeRestorableStateWithCoder:(NSCoder *)coder;

- (IBAction) scheduleAlarm:(id) sender;
-(IBAction)deviceSelectPressed:(UIButton *)sender;
- (IBAction)btnKillApp:(id)sender;



@end
