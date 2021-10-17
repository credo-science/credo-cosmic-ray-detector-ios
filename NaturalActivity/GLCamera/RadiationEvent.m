//
//  RadiationEvent.m
//  NaturalActivity
//
//  Created by Tom Andersen on 2016-10-23.
//
//

#import "RadiationEvent.h"

@implementation RadiationEvent
-(NSComparisonResult)scoreCompare:(RadiationEvent*)other;
{
    if (other.score == self.score)
        return NSOrderedSame;
    if (other.score > self.score)
        return NSOrderedDescending;
    return NSOrderedAscending;
}
@end
