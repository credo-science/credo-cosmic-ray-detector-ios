//
//  RadiationEvent.h
//  NaturalActivity
//
//  Created by Tom Andersen on 2016-10-23.
//
//

#import <Foundation/Foundation.h>

@interface RadiationEvent : NSObject
@property UIImageView* imageView;
@property long score;
@property long blocks;
@property NSDate* dateTime;

-(NSComparisonResult)scoreCompare:(RadiationEvent*)other;

@end
