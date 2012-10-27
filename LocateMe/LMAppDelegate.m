//
//  LMAppDelegate.m
//  LocateMe
//
//  Created by Dean Davids on 10/12/12.
//  Copyright (c) 2012 Dean S. Davids, Tailgate Technology. All rights reserved.
//  www.tailgatetechnology.com
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

#import "LMAppDelegate.h"
#import "TTLocationHandler.h"
#import "LMPinTracker.h"

@interface LMAppDelegate()
@property(nonatomic, strong) LMPinTracker *pinTracker;
@end

@implementation LMAppDelegate

+(void)initialize {
    
    NSMutableDictionary *defs = [NSMutableDictionary dictionary];
    
    [defs setObject:[NSNumber numberWithInt:25] forKey:@"NUMBER_OF_PINS_SAVED"];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
    
    [super initialize];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    /*
     // NOTE: for this demo to worki in the simulator, go to the menu "Debug/Location/Freeway Drive" and enable
     // to simulate the location events.
     */
    
    // Set up the PinTracker
    self.pinTracker = [[LMPinTracker alloc]init];
    self.pinTracker.uploadInterval = 60.0;
    
    // Set up the location handler.
    self.sharedLocationHandler = [TTLocationHandler sharedLocationHandler];
    self.sharedLocationHandler.locationManagerPurposeString =
    NSLocalizedString(@"LOCATION SERVICES ARE REQUIRED FOR THE PURPOSES OF THE APPLICATION TESTING", @"Location services request purpose string.");
    
    // Set background status. Update continuosly in background only when plugged in or regardless of power state.
    self.sharedLocationHandler.updatesInBackgroundWhenCharging = YES;
    // UPDATING IN BACKGROUND WHILE ON BATTERY WILL IMPACT THE USER'S BATTERY LIFE CONSIDERABLY
    self.sharedLocationHandler.continuesUpdatingOnBattery = YES;
    
    // Set interval of notices on change of location
    self.sharedLocationHandler.recencyThreshold = 10.0;
    
    return YES;
}

@end
