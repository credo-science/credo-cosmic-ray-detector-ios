//
//  HelpViewController.m
//  NaturalActivity
//
//  Created by Tom Andersen on 2016/11/14.
//
//

#import "HelpViewController.h"
#import "GLCameraViewController.h"

@interface HelpViewController ()

@end

@implementation HelpViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.uploadSwitch.on = NO;
    if ([GLCameraViewController locationServicesON])
        self.uploadSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"UploadToServer"];
    
    self.dimScreen.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"dimScreen"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)uploadSwitchDidChange:(id)sender {
    if (![GLCameraViewController locationServicesON]) {
        self.uploadSwitch.on = NO;
        UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Location Services Required" message:@"In order to submit events to the global project, location services needs to be on" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
            }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:self.uploadSwitch.on forKey:@"UploadToServer"];
    }
}
- (IBAction)viewEventsOnline:(id)sender {
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString* theURL = [NSString stringWithFormat:@"%@/device/%@", [GLCameraViewController serverBase], vendorID];
    NSURL* destURL = [NSURL URLWithString:theURL];
    UIApplication *application = [UIApplication sharedApplication];
    [application openURL:destURL options:@{} completionHandler:^(BOOL success) {
        if (success) {
             NSLog(@"Opened url");
        }
    }];
}

- (IBAction)openLocationSettings:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

- (IBAction)dimSwitchChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.dimScreen.on forKey:@"dimScreen"];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)doneButtonPressed:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
@end
