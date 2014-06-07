//
//  RSSParserObject.m
//  OSWatch
//
//  Created by Jonathan Cook on 6/6/14.
//  Copyright (c) 2014 DoNothingBox. All rights reserved.
//

#import "RSSParserObject.h"

@implementation RSSParserObject



-(void)loadRSS{
    feeds = [[NSMutableArray alloc] init];
    NSURL *url = [NSURL URLWithString:@"http://www.reddit.com/r/jokes.rss"];
    parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    [parser setDelegate:self];
    [parser setShouldResolveExternalEntities:NO];
    [parser parse];
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    //NSLog(@"We are trying to parse data: %@", elementName);
    element = elementName;
    if ([element isEqualToString:@"item"]) {
        item    = [[NSMutableDictionary alloc] init];
        title   = [[NSMutableString alloc] init];
        link    = [[NSMutableString alloc] init];
    }
    
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    if ([elementName isEqualToString:@"item"]) {
        
        [item setObject:title forKey:@"title"];
        [item setObject:link forKey:@"link"];
        [feeds addObject:[item copy]];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    
    if ([element isEqualToString:@"title"]) {
        [title appendString:string];
    } else if ([element isEqualToString:@"link"]) {
        [link appendString:string];
    }
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    [[NSNotificationCenter defaultCenter] postNotificationName:EVENT_RSS_LOAD_COMPLETE object:self userInfo:NULL];
    NSLog(@"Parsing of document complete");
    for(int i = 0;i<feeds.count;i++){
        //NSLog(@"%@" ,[feeds[i] objectForKey:@"title"]);
    }
}

-(NSMutableArray*)getFeeds{
    return feeds;
}

@end
