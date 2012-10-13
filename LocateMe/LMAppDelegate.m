//
//  LMAppDelegate.m
//  LocateMe
//
//  Created by Dean Davids on 10/12/12.
//  Copyright (c) 2012 Dean Davids. All rights reserved.
//

#import "LMAppDelegate.h"
#import "TTLocationHandler.h"

@implementation LMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    // Set up the location handler.
    self.sharedLocationHandler = [[TTLocationHandler alloc] init];
    self.sharedLocationHandler.locationManagerPurposeString =
    NSLocalizedString(@"LOCATION SERVICES ARE REQUIRED FOR THE PURPOSES OF THE APPLICATION TESTING", @"Location services request purpose string.");
    self.sharedLocationHandler.updatesInBackgroundWhenCharging = YES;
    
    return YES;
}

@end
