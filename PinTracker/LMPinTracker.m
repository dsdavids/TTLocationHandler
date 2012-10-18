//
//  LMPinTracker.m
//  LocateMe
//
//  Created by Dean Davids on 10/17/12.
//  Copyright (c) 2012 Dean Davids. All rights reserved.
//

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
        if (!lastKnowLocationInfo) {
            return;
        }
        
        // Store the location into your sqlite database here
        NSLog(@"Received location info: %@ \n Ready for store to database",lastKnowLocationInfo);
        
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
