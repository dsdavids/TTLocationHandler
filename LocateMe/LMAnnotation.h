//
//  LMAnnotation.h
//  LocateMe
//
//  Created by Dean Davids on 10/13/12.
//  Copyright (c) 2012 Dean Davids. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface LMAnnotation : NSObject <MKAnnotation>

// for mapping annotation
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subTitle;

@end
