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

@interface BaseState : NSObject

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

//Assumes 4 Byte Arrays
-(int) bytesToInteger:(Byte *) byte_array;
-(int) byteToInteger:(Byte *) byte;
-(Byte *) integerToBytes:(int) int_to_convert;
-(Byte *) integerToByte:(int) int_to_convert;

@end
