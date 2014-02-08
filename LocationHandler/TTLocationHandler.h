// TTLocationHandler.h
//
//  Created by Dean Davids on 3/29/12.
//  Copyright (c) 2012 Dean S. Davids, Tailgate Technology. All rights reserved.
//  http://www.tailgatetechnology.com
//
// Portions of this software Copyright (c) 2010, Long Weekend LLC
// Long Weekend LLC credit for basis of the origination of this code.
// Original code and tutorial for same can be found at http://longweekendmobile.com/2010/06/30/location-region-data-in-background-on-ios4-iphone/
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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

//! Responsible for all Core Location interaction, implements delegate methods of CLLocationManager
@interface TTLocationHandler : NSObject <CLLocationManagerDelegate>

//  Singleton class method to retrieve or create
+ (id) sharedLocationHandler;

//! Helper function to determine if this reading is good enough in terms of accuracy
- (BOOL) isLocationWithinRequiredAccuracy:(CLLocation *)location;

//! Helper function to determine if this reading is good enough in terms of recency
- (BOOL) isReadingRecentForLocation: (CLLocation *)location;

// Registers a region for region monitoring.
- (BOOL)registerNotificationForLocation:(CLLocation *)myLocation withRadius:(NSNumber *)myRadius assignIdentifier:(NSString *)identifier;

// Remove all registered regions currently being monitored;
- (void)removeAllMonitoredRegions;

// Returns a region comprised of the current location and of the requested radius
-(CLRegion *)currentRegionWithRadius:(CLLocationDistance)radius;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy) CLLocation *lastKnownLocation;

// Monitoring options
@property (nonatomic) BOOL continuesUpdatingWhileActive;
@property (nonatomic) BOOL continuesUpdatingOnBattery;
@property (nonatomic) BOOL updatesInBackgroundWhenCharging;
@property (nonatomic) BOOL ignorePossibleDuplicates;
@property (nonatomic) NSInteger recencyThreshold;
@property (nonatomic) CLLocationAccuracy requiredAccuracy;
@property (nonatomic) BOOL walkMode;

@end

// Notification names
extern NSString *const LocationHandlerDidUpdateLocation;
extern NSString *const LocationHandlerDidCrossBoundary;