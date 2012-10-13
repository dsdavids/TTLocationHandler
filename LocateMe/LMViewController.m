//
//  LMViewController.m
//  LocateMe
//
//  Created by Dean Davids on 10/12/12.
//  Copyright (c) 2012 Dean Davids. All rights reserved.
//

#import "LMViewController.h"
#import "TTLocationHandler.h"
#import "LMAnnotation.h"

@interface LMViewController ()
@property (nonatomic, strong)NSArray *locationsArray;
@property (nonatomic, weak)IBOutlet MKMapView *mapView;

-(void)handleLocationUpdate;
-(void)updateLocationsArray;
-(void)refreshMapView;
-(void)storeMostRecentLocationInfo;
@end


@implementation LMViewController

#define NUMBER_OF_LOCATIONS_TO_HOLD 25

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self updateLocationsArray];
    
    [self refreshMapView];
    
    NSNotificationCenter *defaultNotificatoinCenter = [NSNotificationCenter defaultCenter];
    [defaultNotificatoinCenter addObserver:self selector:@selector(handleLocationUpdate) name:LocationHandlerDidUpdateLocation object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private Methods

-(void)refreshMapView
{
    MKMapRect zoomRect = MKMapRectNull;
    for (id <MKAnnotation> annotation in self.locationsArray) {
        CLLocationCoordinate2D thisLocation = annotation.coordinate;
        if (CLLocationCoordinate2DIsValid(thisLocation) && ![annotation isKindOfClass:[MKUserLocation class]]) {
            [self.mapView addAnnotation:annotation];
            // determine limits of map
            MKMapPoint annotationPoint = MKMapPointForCoordinate(thisLocation);
            MKMapRect pointRect = MKMapRectMake(annotationPoint.x - 4500.0, annotationPoint.y - 6000.0, 9000.0, 12000.0);
            if (MKMapRectIsNull(zoomRect)) {
                zoomRect = pointRect;
            } else {
                zoomRect = MKMapRectUnion(zoomRect, pointRect);
            }
        }
    }
    [self.mapView setVisibleMapRect:zoomRect animated:YES];
}

-(void)handleLocationUpdate
{
    UIApplication *app = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier thisTaskID = [app beginBackgroundTaskWithExpirationHandler:^{
    dispatch_async(dispatch_get_main_queue(), ^{
            if (thisTaskID != UIBackgroundTaskInvalid) {
                // *** CONSIDER MORE APPROPRIATE RESPONSE TO EXPIRATION *** //
                [app endBackgroundTask:thisTaskID];
                thisTaskID = UIBackgroundTaskInvalid;
            }
        });
    }];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Update the info in background thread
            [self storeMostRecentLocationInfo];
            [self updateLocationsArray];
            
            // Refresh map and close out task Idenetifier on main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                [self refreshMapView];
                
                if (thisTaskID != UIBackgroundTaskInvalid) {
                    [app endBackgroundTask:thisTaskID];
                    thisTaskID = UIBackgroundTaskInvalid;
                }
            });
        });
}

-(void)updateLocationsArray
{
    NSMutableArray *mArray = [NSMutableArray array];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (int index = 0; index < NUMBER_OF_LOCATIONS_TO_HOLD; index++) {
        NSString *theKey = [NSString stringWithFormat:@"location%i", index];
        NSDictionary *savedDict = [defaults objectForKey:theKey];
        if (!savedDict) break;
        
        LMAnnotation *theAnnotation = [[LMAnnotation alloc] init];
        CLLocationDegrees lat = [[savedDict valueForKey:@"LATITUDE"] doubleValue];
        CLLocationDegrees Long = [[savedDict valueForKey:@"LONGITUDE"] doubleValue];
        CLLocationCoordinate2D theCoordinate = CLLocationCoordinate2DMake(lat, Long);
        theAnnotation.coordinate = theCoordinate;
        theAnnotation.title = [NSString stringWithFormat:@"Location%i", index];
        
        [mArray addObject:theAnnotation];
    }
    
    self.locationsArray = [NSArray arrayWithArray:mArray];
}

-(void)storeMostRecentLocationInfo
{
    static int locationIndex = 0;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *lastKnowLocationInfo = [defaults objectForKey:@"LAST_KNOWN_LOCATION"];
    if (!lastKnowLocationInfo) {
        return;
    }
    
    // store the location info
    NSString *theKey = [NSString stringWithFormat:@"location%i", locationIndex];
    [defaults setObject:[NSDictionary dictionaryWithDictionary:lastKnowLocationInfo] forKey:theKey];
    
    if (locationIndex == NUMBER_OF_LOCATIONS_TO_HOLD) {
        locationIndex = 0;
        return;
    }

    locationIndex++;    
}

#pragma mark -
#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
	
	if (oldState == MKAnnotationViewDragStateDragging) {
        
	}
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
	}
    
	static NSString * const kPinAnnotationIdentifier = @"PinIdentifier";
	MKAnnotationView *pinView = [self.mapView dequeueReusableAnnotationViewWithIdentifier:kPinAnnotationIdentifier];
	
    
	if (pinView) {
		pinView.annotation = annotation;
	} else {
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kPinAnnotationIdentifier];
        [pinView setDraggable:NO];
		pinView.canShowCallout = YES;
    }
	
	return pinView;
}

@end
