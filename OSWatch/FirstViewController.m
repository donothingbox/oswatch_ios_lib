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

#import "FirstViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>


@interface FirstViewController ()

@end

@implementation FirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    UIImage *buttonBG = [UIImage imageNamed:@"logo_in_app.png"];
    
    CGFloat offsetX = (screenWidth - buttonBG.size.width/2)/2;
    CGFloat offsetY = (screenHeight - buttonBG.size.height/2)/2;

    
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(offsetX, offsetY, buttonBG.size.width/2, buttonBG.size.height/2)];
    [iv setImage:buttonBG];
    
    
    [self.view addSubview:iv];

    
	// Do any additional setup after loading the view, typically from a nib.
    
    CBUUID *heartRateServiceUUID = [CBUUID UUIDWithString: @"68E3"];
    NSLog(@"created string");
    NSString *test = [self CBUUIDToString:heartRateServiceUUID];
    
    NSLog(@"%@",test);

    

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSString *) CBUUIDToString:(CBUUID *) cbuuid;
{
    NSData *data = cbuuid.data;
    
    if ([data length] == 2)
    {
        const unsigned char *tokenBytes = [data bytes];
        return [NSString stringWithFormat:@"%02x%02x", tokenBytes[0], tokenBytes[1]];
    }
    else if ([data length] == 16)
    {
        NSUUID* nsuuid = [[NSUUID alloc] initWithUUIDBytes:[data bytes]];
        return [nsuuid UUIDString];
    }
    
    return [cbuuid description];
}


-(void) displayBleMessage
{
    


}






@end
