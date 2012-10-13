// TTLocationHandler.h
//
//  Created by Dean Davids on 3/29/12.
//  Copyright (c) 2012 Dean S. Davids, dba Tailgate Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

//! Responsible for all Core Location interaction, implements delegate methods of CLLocationManager
@interface TTLocationHandler : NSObject <CLLocationManagerDelegate>

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
@property (nonatomic, copy) CLLocation *currentLocation;

// Monitoring options
@property (nonatomic) BOOL continuesUpdatingWhileActive;
@property (nonatomic) BOOL updatesInBackgroundWhenCharging;
@property (nonatomic) NSInteger recencyThreshold;
@property (nonatomic) CLLocationAccuracy requiredAccuracy;
@property (nonatomic, copy) NSString *locationManagerPurposeString;

@end

// Notification names
extern NSString *const LocationHandlerDidUpdateLocation;
extern NSString *const LocationHandlerDidCrossBoundary;