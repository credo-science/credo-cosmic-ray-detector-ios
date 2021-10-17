//
//  GLApplication.h
//  Cosmic Ray
//
//  Created by Tom Andersen on 2018-03-17.
//

#import <UIKit/UIKit.h>

// Notification that gets sent when the timeout occurs
// not used #define kApplicationDidTimeoutNotification @"ApplicationDidTimeout"

/**
 * This is a subclass of UIApplication with the sendEvent: method
 * overridden in order to catch all touch events.
 */

@interface GLApplication : UIApplication
{
    NSTimer *_idleTimer;
}

/**
 * Resets the idle timer to its initial state. This method gets called
 * every time there is a touch on the screen.  
 */
- (void)resetIdleTimer;

@end
