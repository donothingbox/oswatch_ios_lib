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

#import "BaseState.h"

@implementation BaseState

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

@end
