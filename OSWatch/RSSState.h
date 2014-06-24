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
#import "BLEConnectionDelegate.h"

#define RSS_APP_ACTION_LOAD_METADATA  1
#define RSS_APP_ACTION_LOAD_BLOCK  2
#define RSS_APP_ACTION_LOAD_PACKET  3
#define RSS_APP_ACTION_LOAD_DETAIL_METADATA  4
#define RSS_APP_ACTION_LOAD_DETAIL_TITLE_BLOCK  5
#define RSS_APP_ACTION_LOAD_DETAIL_DESCRIPTION_BLOCK  6
#define RSS_APP_ACTION_LOAD_DETAIL_PACKET  7


@interface RSSState : BaseState

-(void)processIncomingData:(unsigned char *) data length:(int) length;
-(BLEConnectionDelegate*) getBLEDelegate;
+(RSSState *)getRSSState;

@end
