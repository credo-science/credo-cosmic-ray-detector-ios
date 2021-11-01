//
//  HelpViewController.h
//  NaturalActivity
//
//  Created by Tom Andersen on 2016/11/14.
//
//

#import <UIKit/UIKit.h>

@interface HelpViewController : UIViewController
- (IBAction)doneButtonPressed:(id)sender;
@property (strong, nonatomic) IBOutlet UISwitch *uploadSwitch;
@property (strong, nonatomic) IBOutlet UIButton *locationSettings;
@property (strong, nonatomic) IBOutlet UISwitch *dimScreen;

@end
