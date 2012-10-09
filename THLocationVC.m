//
//  THLocationVC.m
//  TwitHunter
//
//  Created by Nicolas Seriot on 10/9/12.
//  Copyright (c) 2012 seriot.ch. All rights reserved.
//

#import "THLocationVC.h"
#import "THTweetLocation.h"
#import "STTwitterAPIWrapper.h"

@interface THLocationVC ()

@end

@implementation THLocationVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc {
    [_twitter release];
    [_tweetLocation release];
    [_twitterPlaces release];
    [_twitterPlacesController release];
    [super dealloc];
}

- (IBAction)ok:(id)sender {
    NSLog(@"-- ok");
    
    NSString *selectedPlaceID = [[_twitterPlacesController selectedObjects] lastObject];
    
    // 46.5199617
    // 6.6335971
    
    _tweetLocation.placeID = [selectedPlaceID valueForKey:@"id"];
    
    [_locationDelegate locationVC:self didChooseLocation:_tweetLocation];
}

- (IBAction)cancel:(id)sender {
    NSLog(@"-- cancel");
    
    [_locationDelegate locationVCDidCancel:self];
}

- (IBAction)lookupLocation:(id)sender {
    
    //    THTweetLocation *location = (THTweetLocation *)
    
    [_twitter getReverseGeocodeWithLatitude:_tweetLocation.latitude longitude:_tweetLocation.longitude successBlock:^(NSArray *places) {
        
        self.twitterPlaces = places;
        
        NSLog(@"-- places: %@", places);
        
        //        self.locationDescription = [firstPlace valueForKey:@"full_name"];
        
    } errorBlock:^(NSError *error) {
        NSLog(@"-- %@", [error localizedDescription]);
    }];
}

@end
