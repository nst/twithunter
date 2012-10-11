//
//  THTweetLocation.m
//  TwitHunter
//
//  Created by Nicolas Seriot on 10/4/12.
//  Copyright (c) 2012 seriot.ch. All rights reserved.
//

#import "THTweetLocation.h"

@implementation THTweetLocation

- (void)dealloc {
    [_ipAddress release];
    [_placeID release];
    [_latitude release];
    [_longitude release];
    [_fullName release];
    [_query release];

    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
    THTweetLocation *tl = [[THTweetLocation alloc] init];
    
    tl.ipAddress = [[_ipAddress copy] autorelease];
    tl.placeID = [[_placeID copy] autorelease];
    tl.latitude = [[_latitude copy] autorelease];
    tl.longitude = [[_longitude copy] autorelease];
    tl.fullName = [[_fullName copy] autorelease];
    tl.query = [[_query copy] autorelease];
    
    return tl;
}

- (NSString *)description {
    if(_placeID) {
        return _fullName;
    } else if(_latitude && _longitude) {
        return [NSString stringWithFormat:@"%@, %@", _latitude, _longitude];
    }
    
    return @"";
}

@end