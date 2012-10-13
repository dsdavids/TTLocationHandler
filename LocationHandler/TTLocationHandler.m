//  TTLocationHandler.m
//
//  Created by Dean Davids on 3/29/12.
//  Copyright (c) 2012 Dean S. Davids, dba Tailgate Technologies. All rights reserved.
//

#import "TTLocationHandler.h"
#import "TestFlight.h"


// Private methods
@interface TTLocationHandler ()

@property(nonatomic) BOOL highwayMode;

-(void) _stopUpdatingLocation;
-(void) _startUpdatingLocationWithSwitch:(NSNotification *)_notification;
-(void) _startUpdatingLocationContinueUpdates;
-(void) _saveLocationAndNotifyObservers:(CLLocation *)locationToSave;
-(void) _acceptBestAvailableLocation:(id)sender;
-(void) _syncBackgroundUpdatesFlagWithBatteryState;
-(void) _batteryStateDidChange:(NSNotification *)notification;
-(void) _saveLastKnownLocation:(CLLocation *)inLocation;
-(void) _updateStatusBarStyleActive:(NSNumber *)active;
@end

/**
 * \brief Abstracts CLLocationManager functionality, acts as delegate
 * \details CLLocationManager sends delegate messages every time the location
 *  is updated, whether or not those events are useful (e.g. recent?  accurate?)
 *  This class abstracts those things away, issuing a single LocationHandlerDidUpdateLocation
 *  notification every time a significant location change occurs.
 */

@implementation TTLocationHandler
{
    NSMutableArray *_pendingLocationsQueue;
    NSTimer *_pendingLocationsTimer;
    BOOL _updateInBackground;
}

@synthesize highwayMode = _highwayMode;

@synthesize locationManager = _locationManager;
@synthesize currentLocation = _currentLocation;
@synthesize continuesUpdatingWhileActive = _continuesUpdatingWhileActive;
@synthesize updatesInBackgroundWhenCharging = _updatesInBackgroundWhenCharging;
@synthesize requiredAccuracy = _requiredAccuracy;
@synthesize recencyThreshold = _recencyThreshold;
@synthesize locationManagerPurposeString = _locationManagerPurposeString;

#define OUTPUT_LOGS 0

static const int MAX_TRIES_FOR_ACCURACY =10;

//! Custom initializer, creates location manager instance
- (id) init
{
  if (self = [super init])
  {
      // Makes all location readings expire after 60 seconds by default
      _recencyThreshold = 60;
      
      // Clear current value to be sure we start fresh
      _currentLocation = nil;
      
      // Default behaviour is to continually update position whenever app is in foreground and whenever the device is plugged in.
      _continuesUpdatingWhileActive = YES;
      _updatesInBackgroundWhenCharging = YES;
      
      // Initial highway mode setting is NO
      // By default it will change to yes whenever speed is over 22mps (about 45mph).
      _highwayMode = NO;
      
      // Start up the location manager
      self.locationManager = [[CLLocationManager alloc] init];
      self.locationManager.delegate = self;
      self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
      self.locationManager.distanceFilter = 10.0f;
      self.requiredAccuracy = 10.0f;
      if ([self.locationManager respondsToSelector:@selector(activityType)]) {
          self.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
      }
      
      // Tell the user why we need location services. This is default message,
      // set self.locationManagerPurposeString from appDelegate for custom message.
      self.locationManager.purpose =
                NSLocalizedString(@"LOCATION SERVICES IS AN IMPORTANT FEATURE ALLOWING ACCESS TO YOUR GPS AND WI-FI HARDWARE TO ATTAIN POSITION INFO", @"Default string for location services enable dialog");
      
      _pendingLocationsQueue = [[NSMutableArray alloc] init];

      // Register an observer for if/when this app goes into background & comes back to foreground
      // NOTE: THIS CODE IS iOS4.0+ ONLY.  If you want iOS3 compatibility, check for NULL pointers
      // on the notification names first.
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_stopUpdatingLocation) name:UIApplicationDidEnterBackgroundNotification object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_startUpdatingLocationWithSwitch:) name:UIApplicationDidFinishLaunchingNotification object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_startUpdatingLocationContinueUpdates) name:UIApplicationWillEnterForegroundNotification object:nil];
      
      // Register for battery state change monitoring to enable active location monitoring in background if the device is plugged in to power
      [UIDevice currentDevice].batteryMonitoringEnabled = YES;
      _updateInBackground = [UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging;
      if (OUTPUT_LOGS) NSLog(@"updateInBackground initially set to %@", _updateInBackground ? @"YES" : @"NO");
      
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_batteryStateDidChange:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
  }
  return self;
}

#pragma mark -
#pragma mark Accessors

-(void)setHighwayMode:(BOOL)highwayMode {
    // If we are in the background, plugged into charger and travelling at highway speed, the location manager is pumping out
    // out new updates several time a second unnecessarily. We'll cut down the activity by changing the distance filter in
    // in highway mode. Highway mode is set yes or no every time we get an update so we want to check if it is being changed
    // to a new value before altering the location manager property.
    if (highwayMode != _highwayMode) {
        CGFloat highwayDistanceFilter = 400.00f;
        CGFloat cityDistanceFilter = 10.00f;
        if (highwayMode) {
            if (OUTPUT_LOGS) NSLog(@"Setting Highway Mode");
            self.locationManager.distanceFilter = highwayDistanceFilter;
        } else {
            if (OUTPUT_LOGS) NSLog(@"Turning off Highway Mode");
            self.locationManager.distanceFilter = cityDistanceFilter;
        }
        _highwayMode = highwayMode;
    }
}

-(CLLocation *)currentLocation {
    if (_currentLocation != nil) {
        return _currentLocation;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *locationInfo = [defaults objectForKey:@"LAST_KNOWN_LOCATION"];
    if (locationInfo != nil) {
        // Create a new location from the last known info saved in user defaults
        CLLocationDegrees lastKnownLat = [[locationInfo valueForKey:@"LATITUDE"] doubleValue];
        CLLocationDegrees lastKnownLong = [[locationInfo valueForKey:@"LONGITUDE"] doubleValue];
        CLLocationCoordinate2D lastKnownCoordinate = CLLocationCoordinate2DMake(lastKnownLat, lastKnownLong);
        NSDate *lastKnownTimestamp = [locationInfo valueForKey:@"TIME_STAMP"];
        
        CLLocation *mostRecentLocation = [[CLLocation alloc] initWithCoordinate:lastKnownCoordinate altitude:0 
                                                             horizontalAccuracy:self.requiredAccuracy * 100 
                                                               verticalAccuracy:-1 
                                                                      timestamp:[lastKnownTimestamp dateByAddingTimeInterval:-self.recencyThreshold]];
        if (OUTPUT_LOGS) NSLog(@"Last Known Location Retrieved = %@",mostRecentLocation);
        self.currentLocation = mostRecentLocation;
    } else {
        CLLocationDegrees defaultLat = [[defaults objectForKey:@"DEFAULT_LOCATION_LATITUDE"] doubleValue];
        CLLocationDegrees defaultLong = [[defaults objectForKey:@"DEFAULT_LOCATION_LONGITUDE"] doubleValue];
        CLLocationCoordinate2D defaultCoordinate = CLLocationCoordinate2DMake(defaultLat, defaultLong);
        CLLocation *defaultLocation = [[CLLocation alloc] initWithCoordinate:defaultCoordinate 
                                                                    altitude:0 
                                                          horizontalAccuracy:self.requiredAccuracy * 1000 
                                                            verticalAccuracy:-1 
                                                                   timestamp:[NSDate dateWithTimeIntervalSinceNow:-self.recencyThreshold * 10]];
        self.currentLocation = defaultLocation;
        if (OUTPUT_LOGS) NSLog(@"Default Location retrieved = %@",defaultLocation);
    }
    
    return _currentLocation;
}

-(void)setCurrentLocation:(CLLocation *)currentLocation {
    NSLog(@"setting location to %@",currentLocation);
    
    _currentLocation = [currentLocation copy];
    
    if (CLLocationCoordinate2DIsValid(_currentLocation.coordinate)&& _currentLocation.coordinate.latitude != 0 && _currentLocation.coordinate.longitude != 0) {
        [self _saveLastKnownLocation:_currentLocation];
    }
}

-(void)setLocationManagerPurposeString:(NSString *)locationManagerPurposeString {
    _locationManagerPurposeString = [locationManagerPurposeString copy];
    self.locationManager.purpose = _locationManagerPurposeString;
}

-(void)setUpdatesInBackgroundWhenCharging:(BOOL)updatesInBackgroundWhenCharging {
    // If it already is set the same, do nothing
    if (_updatesInBackgroundWhenCharging != updatesInBackgroundWhenCharging) {
        // Setting is new, enable/disable battery monitoring and set ivars
        UIDevice *currentDevice = [UIDevice currentDevice];
        currentDevice.batteryMonitoringEnabled = updatesInBackgroundWhenCharging;
        _updatesInBackgroundWhenCharging = updatesInBackgroundWhenCharging;
        
        if (updatesInBackgroundWhenCharging) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_batteryStateDidChange:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
               [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceBatteryStateDidChangeNotification object:Nil]; 
            });
        }
        
        [self _syncBackgroundUpdatesFlagWithBatteryState];
        if (_updateInBackground) {
            [self _startUpdatingLocationContinueUpdates];
        }
        
        if (OUTPUT_LOGS) NSLog(@"Updates In Background property set to %@",(_updatesInBackgroundWhenCharging ? @"YES" : @"NO"));
        if (OUTPUT_LOGS) NSLog(@"updateInBackground Flag set to %@",(_updateInBackground ? @"YES" : @"NO"));
    }
}

#pragma mark -
#pragma mark Public Methods

- (BOOL)registerNotificationForLocation:(CLLocation *)myLocation withRadius:(NSNumber *)myRadius assignIdentifier:(NSString *)identifier {
    // Do not create regions if support is unavailable or disabled.
    if ( ![CLLocationManager regionMonitoringAvailable] || ![CLLocationManager regionMonitoringEnabled] ) {
        return NO;
    }
    
    // If the radius is too large, registration fails automatically,
    // so clamp the radius to the max value.
    CLLocationDistance theRadius = [myRadius doubleValue];
    if (theRadius > self.locationManager.maximumRegionMonitoringDistance) {
        theRadius = self.locationManager.maximumRegionMonitoringDistance;
    }
    
    CLLocationCoordinate2D theCoordinate = myLocation.coordinate;
    
    // Create the region and start monitoring it.
    CLRegion* theRegion = [[CLRegion alloc] initCircularRegionWithCenter:theCoordinate
                                                               radius:theRadius identifier:identifier];
    [self.locationManager startMonitoringForRegion:theRegion
                                   desiredAccuracy:kCLLocationAccuracyNearestTenMeters];
    if (OUTPUT_LOGS) NSLog(@"Registered Region");
    return YES;
}

- (void)removeAllMonitoredRegions {
    NSSet *regions = self.locationManager.monitoredRegions;
    for (CLRegion *theRegion in regions) {
        [self.locationManager stopMonitoringForRegion:theRegion];
    }
    if (OUTPUT_LOGS) NSLog(@"Removed all Monitored Regions");
}

-(CLRegion *)currentRegionWithRadius:(CLLocationDistance)radius {
    CLLocation *workingLocation = [self.currentLocation copy];
    if ([self isReadingRecentForLocation:workingLocation]) {
        CLRegion *theRegion = [[CLRegion alloc] initCircularRegionWithCenter:workingLocation.coordinate 
                                                                      radius:radius 
                                                                  identifier:@"currentRegion"];
        return theRegion;
    }
    return nil;
}

#pragma mark -
#pragma mark Private Methods


/**
 * Main delegate method for CLLocationManager.
 * Called when location is updated - makes decisions about whether or not to update class instance variable currentLocation
 */
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    UIApplication *app = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier UpdatingLocationTaskID = [app beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (UpdatingLocationTaskID != UIBackgroundTaskInvalid) {
                if (OUTPUT_LOGS) NSLog(@"Location Update failed to finish prior to expiration");
                // *** CONSIDER MORE APPROPRIATE RESPONSE TO EXPIRATION *** //
                [app endBackgroundTask:UpdatingLocationTaskID];
                UpdatingLocationTaskID = UIBackgroundTaskInvalid;
            }
        });
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL existingLocationIsAccurate = [self isLocationWithinRequiredAccuracy:self.currentLocation];
        BOOL existingLocationIsRecent = [self isReadingRecentForLocation:self.currentLocation];
        
        // set highway mode if we are moving faster than about 45mph (20mps)
        self.highwayMode = newLocation.speed >= 20.00;
        
        [self _syncBackgroundUpdatesFlagWithBatteryState];
        
        // 1st, if we already have an accurate location that is recent, ignore the new location
        if (existingLocationIsAccurate && existingLocationIsRecent)
        {
            if (OUTPUT_LOGS) NSLog(@"We have a good location already saved");
            // Discontinue location if not set to continue
            [self _stopUpdatingLocation];
            
        } else {
            NSNumber *activeYes = [NSNumber numberWithBool:YES];
            [self performSelectorOnMainThread:@selector(_updateStatusBarStyleActive:) withObject:activeYes waitUntilDone:NO];
            
            // The existing location is either old or inaccurate, if our new location is an accurate location, we'll use it
            // otherwise we are going to save it in a pending queue and wait to see if a better one comes in.
            // We are also setting a cap, if we have already have the max number of locations pending we will go ahead and take
            // this one regardless of accuracy.
            if ([self isLocationWithinRequiredAccuracy:newLocation] ) {
                // New location is good, clear the pending queue and save this one.
                [_pendingLocationsTimer invalidate];
                _pendingLocationsTimer = nil;
                [_pendingLocationsQueue removeAllObjects];
                [self _saveLocationAndNotifyObservers:[newLocation copy]];
                
                if (OUTPUT_LOGS) NSLog(@"New, accurate location was set");
                
            }else if (_pendingLocationsQueue.count > MAX_TRIES_FOR_ACCURACY) {
                // This is the last location we are going to wait for. It's still not as accurate as we'd like but we'll take it anyway.
                [_pendingLocationsTimer invalidate];
                _pendingLocationsTimer = nil;
                [self _saveLocationAndNotifyObservers:[_pendingLocationsQueue lastObject]];
                
                if (OUTPUT_LOGS) NSLog(@"Location attempts limit reached, accepted location %i",_pendingLocationsQueue.count);
                
                [_pendingLocationsQueue removeAllObjects];
            } else {
                // It's not within our requested accuracy preference and we haven't reached limit of tries
                // save to the queue and see if we get a better one before our set wait time.
                [_pendingLocationsQueue addObject:[newLocation copy]];
                if (OUTPUT_LOGS) NSLog(@"Location %i queued for possible acceptance",_pendingLocationsQueue.count);
                
                // set up a timer to limit how long we'll wait before taking what we have.
                [_pendingLocationsTimer invalidate];
                _pendingLocationsTimer = nil;
                _pendingLocationsTimer = [NSTimer timerWithTimeInterval:10.0 
                                                                target:self 
                                                            selector:@selector(_acceptBestAvailableLocation:) 
                                                            userInfo:nil repeats:NO];
                
                // In background on global thread, runloop may be idle
                NSRunLoop *loop = [NSRunLoop currentRunLoop];
                [loop addTimer:_pendingLocationsTimer forMode:NSRunLoopCommonModes];
                [loop run];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (UpdatingLocationTaskID != UIBackgroundTaskInvalid) {
                if (OUTPUT_LOGS) NSLog(@"Ending UpdateLocation task normally");
                [app endBackgroundTask:UpdatingLocationTaskID];
                UpdatingLocationTaskID = UIBackgroundTaskInvalid;
            }
        });
    });
}

// called when timer times out, no better location was received after max wait time.
-(void) _acceptBestAvailableLocation:(id)sender {
    UIApplication *app = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier acceptTaskID = [app beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (acceptTaskID != UIBackgroundTaskInvalid) {
                // *** CONSIDER MORE APPROPRIATE RESPONSE TO EXPIRATION *** //
                [app endBackgroundTask:acceptTaskID];
                acceptTaskID = UIBackgroundTaskInvalid;
            }
        });
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //Enter Background Operations here
        _pendingLocationsTimer = nil;
        [self _saveLocationAndNotifyObservers:[_pendingLocationsQueue lastObject]];
        
        if (OUTPUT_LOGS) NSLog(@"Time limit reached, no better location came in. Accepted location %i",_pendingLocationsQueue.count);
        
        [_pendingLocationsQueue removeAllObjects];
            
        // Close out task Idenetifier on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (acceptTaskID != UIBackgroundTaskInvalid) {
                [app endBackgroundTask:acceptTaskID];
                acceptTaskID = UIBackgroundTaskInvalid;
            }
        });
    });
}

// updates the property currentLocation and sends out notification. Calls stop CL from updating if appropriate
-(void) _saveLocationAndNotifyObservers:(CLLocation *)locationToSave {
    
    self.currentLocation = locationToSave;
    
    NSNumber *activeNO = [NSNumber numberWithBool:NO];
    [self performSelectorOnMainThread:@selector(_updateStatusBarStyleActive:) withObject:activeNO waitUntilDone:NO];
    
    // Discontinue updating location if not set to continue
    [self _stopUpdatingLocation];
    
    // Send notification to everyone that cares
    dispatch_async(dispatch_get_main_queue(), ^{
        if (OUTPUT_LOGS) NSLog(@"Sending notification out");
        NSNotification *aNotification = [NSNotification notificationWithName:LocationHandlerDidUpdateLocation object:[locationToSave copy]];
        [[NSNotificationCenter defaultCenter] postNotification:aNotification];
    });
}

/**
 * Stops updating the location in realtime.
 * Starts the significantLocationChange service instead.
 * Called when the application is about to be put
 * in the background so the user's battery isn't 
 * killed.
 * If set to update in background when plugged into
 * external power source, we skip this method completely
 * letting it continue updating accurately in all circumstances.
 */
- (void) _stopUpdatingLocation
{
    UIApplication *app = [UIApplication sharedApplication];
    BOOL inForegroundAndShouldContinue = app.applicationState == UIApplicationStateActive && self.continuesUpdatingWhileActive;
                                                                        
    if (OUTPUT_LOGS) NSLog(@"inForegroundAndShouldContinue = %@, updateInBackground = %@",inForegroundAndShouldContinue ? @"YES" : @"NO", _updateInBackground ? @"YES" : @"NO");
    if (!_updateInBackground) {
        if (!inForegroundAndShouldContinue) {
            if (OUTPUT_LOGS) NSLog(@"Stopping location updates");
            [[self locationManager] stopUpdatingLocation];
            
            if ([CLLocationManager significantLocationChangeMonitoringAvailable])
            {
            [self.locationManager startMonitoringSignificantLocationChanges];
                if (OUTPUT_LOGS) NSLog(@"Started monitoring for significant location changes");
            }
        }
    }
}

/**
 * Starts updating the location in realtime,
 * Stops the background monitoring.
 * Called when the application is launched from terminal state
 */
- (void) _startUpdatingLocationWithSwitch:(NSNotification *)_notification
{
    if ([CLLocationManager significantLocationChangeMonitoringAvailable])
    {
      if (OUTPUT_LOGS) NSLog(@"Stopped monitoring for significant changes");
    [[self locationManager] stopMonitoringSignificantLocationChanges];
    }

    // note that we can make this call even if it's already updating no problem
    [[self locationManager] startUpdatingLocation];
    if (OUTPUT_LOGS) NSLog(@"Started updating location");
}

/**
 * Starts updating the location in realtime,
 * Stops the background monitoring.
 * Called when the application is launched to the foreground
 */
- (void) _startUpdatingLocationContinueUpdates
{
    _currentLocation = nil;
    if ([CLLocationManager significantLocationChangeMonitoringAvailable])
    {
        if (OUTPUT_LOGS) NSLog(@"Stopped monitoring for significant changes");
        [[self locationManager] stopMonitoringSignificantLocationChanges];
    }
    
    // note that we can make this call even if it's already updating no problem
    [[self locationManager] startUpdatingLocation];
    if (OUTPUT_LOGS) NSLog(@"Started updating location");
}

/* Saves the location to the user defaults for use if the current location
 * would potentially return nil, we'll return the last known location instead
*/
-(void)_saveLastKnownLocation:(CLLocation *)inLocation {
    if (CLLocationCoordinate2DIsValid(inLocation.coordinate)) {
        // Create dictionary from location
        NSMutableDictionary *locationInfo = [NSMutableDictionary dictionary];
        [locationInfo setValue:[NSNumber numberWithDouble:inLocation.coordinate.latitude] forKey:@"LATITUDE"];
        [locationInfo setValue:[NSNumber numberWithDouble:inLocation.coordinate.longitude] forKey:@"LONGITUDE"];
        [locationInfo setValue:inLocation.timestamp forKey:@"TIME_STAMP"];
        // Save dictionary to user defaults
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[NSDictionary dictionaryWithDictionary:locationInfo] forKey:@"LAST_KNOWN_LOCATION"];
    }
}

-(void) _syncBackgroundUpdatesFlagWithBatteryState {
    // Enable/disable battery monitoring and notifications as applicable
    // We would like to call this method only when the battery state changes, but since
    // we do not receive that notification when running in the background, I am calling
    // it every time we get a new location update. This way if user has it plugged in
    // and active, goes to background and then unplugs it, it will stop updating after
    // the next go around.
    if (self.updatesInBackgroundWhenCharging) {
        UIDevice *currentDevice = [UIDevice currentDevice];
        UIDeviceBatteryState currentBatteryState = [currentDevice batteryState];
        if (currentBatteryState == UIDeviceBatteryStateCharging || currentBatteryState == UIDeviceBatteryStateFull) {
            _updateInBackground = YES;
        } else {
            _updateInBackground = NO;
            // The flag, having been set to no, will cause locationManager to stop on the next update
        }
        
    } else {
        _updateInBackground = NO;
    }
}

-(void) _batteryStateDidChange:(NSNotification *)notification {
    // Set our update flag as appropriate
    // This should be the best point of entry to set update flag however it does not
    // necessarily get called when the device is in the background therefore I have
    // to break out the sync method and do some redundant checking every time I get
    // a new location.
    UIApplication *app = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier batteryStateChangeTaskIdentifier = [app beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (batteryStateChangeTaskIdentifier != UIBackgroundTaskInvalid) {
                if (OUTPUT_LOGS) NSLog(@"Battery State change reaction failed to finish prior to expiration");
                // *** CONSIDER MORE APPROPRIATE RESPONSE TO EXPIRATION *** //
                [app endBackgroundTask:batteryStateChangeTaskIdentifier];
                batteryStateChangeTaskIdentifier = UIBackgroundTaskInvalid;
            }
        });
    }];
    
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            _updateInBackground = NO;
            if (self.updatesInBackgroundWhenCharging) {
                UIDeviceBatteryState currentBatteryState = [[UIDevice currentDevice] batteryState];
                if (currentBatteryState == UIDeviceBatteryStateCharging || currentBatteryState == UIDeviceBatteryStateFull) {
                    _updateInBackground = YES;
                    [self _startUpdatingLocationContinueUpdates];
                }
            }
                
            dispatch_async(dispatch_get_main_queue(), ^{
                if (batteryStateChangeTaskIdentifier != UIBackgroundTaskInvalid) {
                    if (OUTPUT_LOGS) NSLog(@"Ending battery state reaction task normally");
                    [app endBackgroundTask:batteryStateChangeTaskIdentifier];
                    batteryStateChangeTaskIdentifier = UIBackgroundTaskInvalid;
                }
            });
        });
}

-(void) _updateStatusBarStyleActive:(NSNumber *)active {
    BOOL existingLocationIsAccurate = [self isLocationWithinRequiredAccuracy:self.currentLocation];
    UIApplication *app = [UIApplication sharedApplication];
    if ([active boolValue]) {
        if (existingLocationIsAccurate) {
            [app setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:YES];
        } else {
            [app setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
        }
    } else {
        if (existingLocationIsAccurate) {
            [app setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
        } else {
            [app setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
        }
    }
}

#pragma mark - iPhone 4 Or Higher Only

//! ONLY IMPLEMENTED on IPHONE 4
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    // Send notification to everyone that cares
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1], @"eventType", region, @"eventRegion",[NSDate date], @"eventDate", nil];
    NSNotification *aNotification = [NSNotification notificationWithName:LocationHandlerDidCrossBoundary object:self userInfo:dict];
    [[NSNotificationCenter defaultCenter] postNotification:aNotification];
    
    // get current location update
    self.currentLocation = nil;
    [self _startUpdatingLocationWithSwitch:nil];
}

//! ONLY IMPLEMENTED on IPHONE 4
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    // Send notification to everyone that cares
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"eventType", region, @"eventRegion",[NSDate date], @"eventDate", nil];
    NSNotification *aNotification = [NSNotification notificationWithName:LocationHandlerDidCrossBoundary object:self userInfo:dict];
    [[NSNotificationCenter defaultCenter] postNotification:aNotification];
    
    // get current location update
    self.currentLocation = nil;
    [self _startUpdatingLocationWithSwitch:nil];
}

//! ONLY IMPLEMENTED on IPHONE 4
- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)regionwithError:(NSError *)error
{
  if (OUTPUT_LOGS) NSLog(@"Error monitoring");
}


#pragma mark - Location Accuracy/Recency Checking

/*!
 @method						isLocationWithinRequiredAccuracy
 @abstract					Determines if a location is within the required accuracy
 @discussion				Compares the horizontal accuracy of the location to the required accuracy
 @param location		The location to check for accuracy
 @return						Whether the specified location fell within the accuracy range
 */
- (BOOL) isLocationWithinRequiredAccuracy:(CLLocation *)location
{
  if (location == nil) return NO;
	else return location.horizontalAccuracy <= self.requiredAccuracy;
}


/*!
    @method         isReadingRecentForLocation
    @abstract       Determines if a location is recent relative to the system time
    @discussion     Compares the location's timestamp to the current time minus the recency threshold (instance property)
    @param location A CLLocation object with the location to be checked
    @return         YES if the timestamp of the location parameter is within the current date minus the threshold, NO if older
*/
- (BOOL) isReadingRecentForLocation:(CLLocation *) location
{
  // Do we have a valid location?
  if (location)
  {
    NSDate *thresholdDate = [NSDate dateWithTimeIntervalSinceNow:-self.recencyThreshold];
    NSComparisonResult res = [thresholdDate compare:[location timestamp]];
    return (res == NSOrderedAscending);    
  }
  else
  {
    return NO;
  }
}

//! Standard dealloc
- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.currentLocation = nil;
    _pendingLocationsQueue = nil;
    [_pendingLocationsTimer invalidate];
    _pendingLocationsTimer = nil;
}

@end

// Notification names
NSString* const LocationHandlerDidUpdateLocation = @"LocationHandlerDidUpdateLocation";
NSString* const LocationHandlerDidCrossBoundary = @"LocationHandlerDidCrossBoundary";
