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

#import "RSSState.h"
#import "BaseState.h"
#import "BLEConnectionDelegate.h"
#import "AppDelegate.h"
#import "RSSParserObject.h"

@implementation RSSState
static RSSState *s_rssState = nil;
static RSSParserObject *rssParserObject;
static NSMutableArray *packetArray;
static NSInteger packetCount;
static NSInteger rssCount;


-(RSSState *)init{
    self =[super init];
    rssParserObject = [[RSSParserObject alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rssLoadComplete:) name:EVENT_RSS_LOAD_COMPLETE object:nil];
    return self;
}

-(void)processIncomingData:(unsigned char *) data length:(int) length
{
    NSMutableArray *feeds;
    switch (data[BYTE_EVENT_APP_ACTION]) {
        case RSS_APP_ACTION_LOAD_METADATA:
            NSLog(@"RSS LOAD RSS DETECTED");
            [rssParserObject loadRSS];
            break;
        case RSS_APP_ACTION_LOAD_BLOCK:
            NSLog(@"RSS LOAD BLOCK DETECTED: %d", data[3]);
            feeds = [rssParserObject getFeeds];
            [self sendRSSFeedLine:(NSString *)[feeds[[self byteToInteger:&data[3]]] objectForKey:@"title"]];
            //[self sendRequestedPacket:[self byteToInteger:&data[3]]];
            break;
        case RSS_APP_ACTION_LOAD_PACKET:
            NSLog(@"RSS LOAD PACKET DETECTED: %d", data[3]);
            NSLog(@"BLEDelegate: %@", [self getBLEDelegate]);
            [self sendRequestedPacket:[self byteToInteger:&data[3]]];
            break;
        default:
            [[self getBLEDelegate] sendFormattedString:0x03 stateAction:0x00 stateMessage:@"THis is a test"];
            break;
    }

}

-(IBAction)sendRSSFeedLine:(NSString*)mySentence{
    
    UInt8 buf[3] = {0x03, 0x02, 0x04};
    NSInteger totalCharLength = [mySentence length];
    NSInteger numberOfPackets = ceil(totalCharLength/17);
    
    //NSLog(@"Total Char Length: %ld", (long)totalCharLength);
    
    //Reset packet array
    packetArray = [NSMutableArray array];
    packetCount = 0;
    
    
    NSInteger currentPacket = 0;
    
    for(int i = 0;i<=numberOfPackets;i++) {
        
        NSInteger startPoint = i*17;
        NSInteger endPoint = 17;
        if((endPoint+startPoint)>=totalCharLength)
            endPoint = totalCharLength-startPoint;
        //NSLog(@"End Point: %ld", (long)endPoint);
        //NSLog(@"Length: %ld", (long)[mySentence length]);
        NSRange packetRange = NSMakeRange(startPoint,endPoint);
        NSString *packet = [mySentence substringWithRange:packetRange];
        
        while ([packet length]<17) {
            packet = [packet stringByAppendingString:@" "];
        }
        //NSLog(@"SubString: %@", packet);
        [packetArray addObject:packet];
        packetCount++;
    }
    
    buf[2] = *[[self getBLEDelegate] integerToByte:packetCount];
    //NSLog(@"Sending First String: %@", packetArray[0]);
    
    NSMutableData *dataObj = [[NSMutableData alloc] initWithBytes:buf length:3];
    [dataObj appendData:[packetArray[0] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // NSLog(@"%@", dataObj);
    
    // NSLog(@"%lu", (unsigned long)[dataObj length]);
    [[self getBLEDelegate] write:dataObj];
}

- (void) rssLoadComplete:(NSNotification*)notification {
    NSLog(@"RSS Load Event Complete, ship it!");
    rssCount = 10; //set manually for now
    [self sendRSSFeedMetadata]; 
}


-(IBAction)sendRequestedPacket:(NSInteger)packetID{
    //NSLog(@"Requesting next packet: %ld", (long)packetID);
    UInt8 buf[3] = {0x03, 0x03, 0x04};
    NSMutableData *dataObj = [[NSMutableData alloc] initWithBytes:buf length:3];
    [dataObj appendData:[packetArray[packetID] dataUsingEncoding:NSUTF8StringEncoding]];
    // NSLog(@"Sending Next String: %@", packetArray[packetID]);
    // NSLog(@"%@", dataObj);
    //NSLog(@"%lu", (unsigned long)[dataObj length]);
    [[self getBLEDelegate] write:dataObj];
}

//the inital batch of all the info
-(IBAction)sendRSSFeedMetadata{
    UInt8 buf[6] = {0x03, 0x01, 0x09, 0x01, 0x01, 0x01};
    [[self getBLEDelegate] sendData:buf];
}

-(BLEConnectionDelegate*) getBLEDelegate{
    return [AppDelegate getBLEConnectionDelegateInstance];
}

+(RSSState *) getRSSState{
    if(!s_rssState)
        s_rssState = [[RSSState alloc] init];
    return s_rssState;
}

@end