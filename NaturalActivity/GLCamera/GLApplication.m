//
//  GLApplication.m
//  Cosmic Ray
//
//  Created by Tom Andersen on 2018-03-17.
//

#import "GLApplication.h"
#import "GLCameraAppDelegate.h"

@implementation GLApplication

- (void)sendEvent:(UIEvent *)event
{
    [super sendEvent:event];
    // Fire up the timer upon first event
    if(!_idleTimer) {
        [self resetIdleTimer];
    }
    
    // Check to see if there was a touch event
    NSSet *allTouches       = [event allTouches];
    
    if  ([allTouches count] > 0)
    {
        UITouchPhase phase  = ((UITouch *)[allTouches anyObject]).phase;
        if  (phase == UITouchPhaseBegan)
        {
            [self resetIdleTimer];
        }
    }
}

- (void)resetIdleTimer
{
    if  (_idleTimer)
    {
        [_idleTimer invalidate];
    }
    
    // Schedule a timer to fire in kApplicationTimeoutInMinutes * 60
    
    
    //  int timeout =   [AppDelegate getInstance].m_iInactivityTime;
    int timeout =   5*60;
#if DEBUG
    timeout =   30;
#endif
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                  target:self
                                                selector:@selector(idleTimerExceeded)
                                                userInfo:nil
                                                 repeats:NO];
    
    [gAppD interactionOccured];
}

- (void)idleTimerExceeded
{
    /* Post a notification so anyone who subscribes to it can be notified when
     * the application times out */

    [gAppD hasBeenIdleForAWhile];
    
    //[[NSNotificationCenter defaultCenter] postNotificationName:kApplicationDidTimeoutNotification object:nil];
}


@end

