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

#import "SettingsObject.h"

@implementation SettingsObject

static bool CACHE_CONNECTION = true;


@synthesize notificationsEnabled, reconnectionsEnabled;

static SettingsObject *s_settingsObjectSingleton = nil;


- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeBool:notificationsEnabled forKey:@"notificationsEnabled"];
    [encoder encodeBool:reconnectionsEnabled forKey:@"reconnectionsEnabled"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.notificationsEnabled = [decoder decodeBoolForKey:@"notificationsEnabled"];
        self.reconnectionsEnabled = [decoder decodeBoolForKey:@"reconnectionsEnabled"];
    }
    return self;
}

+(SettingsObject *)getSettingsObjectSingleton {
    
    if(s_settingsObjectSingleton)
        return s_settingsObjectSingleton;
    
    SettingsObject *settingsObject = [SettingsObject loadSettingsStateFromDisk];
    if(settingsObject != NULL)
    {
        s_settingsObjectSingleton = settingsObject;
        return settingsObject;
    }
    else
    {
        [SettingsObject createSettingsObjectInstance];
        SettingsObject *settingsObject = [SettingsObject loadSettingsStateFromDisk];
        s_settingsObjectSingleton = settingsObject;
        return settingsObject;
    }
}

+(void)setSettingsObjectSingleton:(SettingsObject*) settingsObject{
    NSLog(@"Saving State");
    NSLog(@"Notification is: %d", settingsObject.notificationsEnabled);
    NSLog(@"Reconnection is: %d", settingsObject.reconnectionsEnabled);
    NSArray *array = [[NSArray alloc] initWithObjects:settingsObject, nil];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *fullFileName = [NSString stringWithFormat:@"%@/settingsData", docDir];
    [NSKeyedArchiver archiveRootObject:array toFile:fullFileName];
    s_settingsObjectSingleton = settingsObject;
}



+(SettingsObject *) loadSettingsStateFromDisk{
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

+(void) createSettingsObjectInstance{
    SettingsObject *settingsObject = [[SettingsObject alloc] init];
    settingsObject.reconnectionsEnabled = true;
    settingsObject.notificationsEnabled = true;
    NSLog(@"Saving State");
    NSLog(@"Notification is: %d", settingsObject.notificationsEnabled);
    NSLog(@"Reconnection is: %d", settingsObject.reconnectionsEnabled);
    NSArray *array = [[NSArray alloc] initWithObjects:settingsObject, nil];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *fullFileName = [NSString stringWithFormat:@"%@/settingsData", docDir];
    [NSKeyedArchiver archiveRootObject:array toFile:fullFileName];
}



@end
