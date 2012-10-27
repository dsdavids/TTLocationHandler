//
//  LMViewController.m
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

#import "LMViewController.h"
#import "TTLocationHandler.h"
#import "LMAnnotation.h"
#import "LMPinTracker.h"

@interface LMViewController ()
@property (nonatomic, strong)NSArray *locationsArray;
@property (nonatomic, weak)IBOutlet MKMapView *mapView;

-(void)handleLocationUpdate;
-(void)updateLocationsArray;
-(void)refreshMapView;
@end


@implementation LMViewController

#pragma mark - View LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self updateLocationsArray];
    
    [self refreshMapView];
    
    NSNotificationCenter *defaultNotificatoinCenter = [NSNotificationCenter defaultCenter];
    [defaultNotificatoinCenter addObserver:self selector:@selector(handleLocationUpdate) name:PinLoggerDidSaveNewLocation object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    NSNotificationCenter *defaultNotificationCenter = [NSNotificationCenter defaultCenter];
    [defaultNotificationCenter removeObserver:self name:PinLoggerDidSaveNewLocation object:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSNotificationCenter *defaultNotificatoinCenter = [NSNotificationCenter defaultCenter];
    [defaultNotificatoinCenter addObserver:self selector:@selector(handleLocationUpdate) name:PinLoggerDidSaveNewLocation object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private Methods

-(void)refreshMapView
{
    NSArray *oldAnnotations = [_mapView.annotations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"!(self isKindOfClass: %@)", [MKUserLocation class]]];
    [self.mapView removeAnnotations:oldAnnotations];
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
    [self updateLocationsArray];
    [self refreshMapView];
}

-(void)updateLocationsArray
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int numberOfPins = [defaults integerForKey:@"NUMBER_OF_PINS_SAVED"];
    NSMutableArray *mArray = [NSMutableArray arrayWithCapacity:numberOfPins];
    
    for (int index = 0; index < numberOfPins; index++) {
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
