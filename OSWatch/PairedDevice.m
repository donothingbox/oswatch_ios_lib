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

#import "PairedDevice.h"

@implementation PairedDevice
@synthesize uuid, identifier, device_name;


- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:uuid forKey:@"uuid"];
    [encoder encodeObject:identifier forKey:@"identifier"];
    [encoder encodeObject:device_name forKey:@"device_name"]; }

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.identifier = [decoder decodeObjectForKey:@"identifier"];
        self.device_name = [decoder decodeObjectForKey:@"device_name"]; }
    return self;
}

@end
