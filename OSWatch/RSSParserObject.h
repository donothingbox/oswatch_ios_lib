//
//  RSSParserObject.h
//  OSWatch
//
//  Created by Jonathan Cook on 6/6/14.
//  Copyright (c) 2014 DoNothingBox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSSParserObject : NSObject <NSXMLParserDelegate> {
    
    NSXMLParser *parser;
    NSMutableArray *feeds;
    NSMutableDictionary *item;
    NSMutableString *title;
    NSMutableString *link;
    NSString *element;
}


#define EVENT_RSS_LOAD_COMPLETE       @"rssLoadComplete"



-(void)loadRSS;
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict;
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;
- (void)parserDidEndDocument:(NSXMLParser *)parser;
-(NSMutableArray*)getFeeds;

@end
