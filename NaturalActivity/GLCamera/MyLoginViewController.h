//
//  MyLoginViewController.h
//  Cosmic Ray
//
//  Created by Michał Frontczak on 16/10/2021.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>

@class GLCameraViewController;

@interface MyLoginViewController : UIViewController

//@property (strong, nonatomic) GLCameraViewController *viewController;
@property (strong, nonatomic) IBOutlet UITextField *usernameTxtField;
@property (strong, nonatomic) IBOutlet UITextField *passwordTxtField;
@property (strong, nonatomic) IBOutlet UIButton *loginToCredoButton;
- (IBAction)loginToCredoButtonPressed:(id)sender;


@end

