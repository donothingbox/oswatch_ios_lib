//
//  RSSReader.m
//  OSWatch
//
//  Created by Jonathan Cook on 5/9/14.
//  Copyright (c) 2014 DoNothingBox. All rights reserved.
//

#import "RSSReader.h"

@interface RSSReader () {
    NSXMLParser *parser;
    NSMutableArray *feeds;
    NSMutableDictionary *item;
    NSMutableString *title;
    NSMutableString *link;
    NSString *element;
}

@end

@implementation RSSReader

-(RSSReader *)init{
    return self;
}

//- (void)loadRSS:(NSURL *)targetURL
- (void)loadRSS
{
    feeds = [[NSMutableArray alloc] init];
    NSURL *targetURL = [NSURL URLWithString:@"http://www.reddit.com/.rss"];
    parser = [[NSXMLParser alloc] initWithContentsOfURL:targetURL];
    [parser setDelegate:self];
    [parser setShouldResolveExternalEntities:NO];
    [parser parse];
}

/*

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return feeds.count;
}*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = [[feeds objectAtIndex:indexPath.row] objectForKey: @"title"];
    return cell;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    NSLog(@"We are trying to parse data: %@", elementName);
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
    for(int i = 0;i<feeds.count;i++){
        NSLog(@"%@" ,[feeds[i] objectForKey:@"title"]);
    }
    //add a call / event here
}


@end
