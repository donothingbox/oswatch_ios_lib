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

#import "TimeState.h"
#import "BaseState.h"
#import "BLEConnectionDelegate.h"
#import "AppDelegate.h"

@implementation TimeState
static TimeState *s_timeState = nil;

-(void)processIncomingData:(unsigned char *) data length:(int) length {
    NSLog(@"TIME STATE EVENT DETECTED");
    [[self getBLEDelegate] scheduleNotification:@"Time Request: PING" soundName:@"cardiac_arrest.wav"];
    [[self getBLEDelegate] sendMessage:SLAVE_TIME_RESPONSE];
}

-(BLEConnectionDelegate*) getBLEDelegate{
    return [AppDelegate getBLEConnectionDelegateInstance];
}

+(TimeState *) getTimeState{
    if(!s_timeState)
        s_timeState = [[TimeState alloc] init];
    return s_timeState;
}

@end
