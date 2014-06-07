//
//  OSWatchWebViewController.m
//  OSWatch
//
//  Created by Jonathan Cook on 5/8/14.
//  Copyright (c) 2014 DoNothingBox. All rights reserved.
//

#import "OSWatchWebViewController.h"

@interface OSWatchWebViewController ()

@end

@implementation OSWatchWebViewController

UIWebView *webView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    CGRect fullScreenRect=[[UIScreen mainScreen] applicationFrame];

    // Do any additional setup after loading the view from its nib.
    webView=[[UIWebView alloc]initWithFrame:fullScreenRect];
    NSString *url=@"http://oswatch.org";
    NSURL *nsurl=[NSURL URLWithString:url];
    NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
    [webView loadRequest:nsrequest];
    [self.view addSubview:webView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
