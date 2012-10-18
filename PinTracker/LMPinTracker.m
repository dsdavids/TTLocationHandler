//
//  LMPinTracker.m
//  LocateMe
//
//  Created by Dean Davids on 10/17/12.
//  Copyright (c) 2012 Dean Davids. All rights reserved.
//
// All of the code in this file shares same permissions as follows:
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
// associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial
// portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "LMPinTracker.h"
#import "TTLocationHandler.h"

@interface LMPinTracker()

{
    NSDate *_mostRecentUploadDate;
}

-(void)handleLocationUpdate;
-(void)uploadCurrentData;

@end

@implementation LMPinTracker

-(id)init
{
    self = [super init];
    if (self) {
        
        NSNotificationCenter *defaultNotificatoinCenter = [NSNotificationCenter defaultCenter];
        [defaultNotificatoinCenter addObserver:self selector:@selector(handleLocationUpdate) name:LocationHandlerDidUpdateLocation object:nil];
    }

    return self;
}

-(void)handleLocationUpdate
{
    UIApplication *app = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier locationUpdateTaskID = [app beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (locationUpdateTaskID != UIBackgroundTaskInvalid) {
                // *** CONSIDER MORE APPROPRIATE RESPONSE TO EXPIRATION *** //
                [app endBackgroundTask:locationUpdateTaskID];
                locationUpdateTaskID = UIBackgroundTaskInvalid;
            }
        });
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //Enter Background Operations here
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *lastKnowLocationInfo = [defaults objectForKey:@"LAST_KNOWN_LOCATION"];
        
        // Alternately, lastKnownLocation could be obtained directly like so:
        CLLocation *lastKnownLocation = [[TTLocationHandler sharedLocationHandler] lastKnownLocation];
        NSLog(@"Alternate location object directly from handler is \n%@",lastKnownLocation);
        
        if (!lastKnowLocationInfo) {
            return;
        }
        
        // Store the location into your sqlite database here
        NSLog(@"Retrieved from defaults location info: \n%@ \n Ready for store to database",lastKnowLocationInfo);
        
        NSTimeInterval timeSinceLastUpload = [_mostRecentUploadDate timeIntervalSinceNow] * -1;
        
        if (timeSinceLastUpload == 0 || timeSinceLastUpload >= self.uploadInterval) {
            [self uploadCurrentData];
        }
            
        // Close out task Idenetifier on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (locationUpdateTaskID != UIBackgroundTaskInvalid) {
                [app endBackgroundTask:locationUpdateTaskID];
                locationUpdateTaskID = UIBackgroundTaskInvalid;
            }
        });
    });
}

-(void)uploadCurrentData
{
    // Do your upload to web operations here
    
    
    
    NSLog(@"Uploaded location data to the web");
    _mostRecentUploadDate = [NSDate date];
}

@end
