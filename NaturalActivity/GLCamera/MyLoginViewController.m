//
//  MyLoginViewController.m
//  Cosmic Ray
//
//  Created by Michał Frontczak on 16/10/2021.
//

#import "MyLoginViewController.h"

@interface MyLoginViewController ()

@end

@implementation MyLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self.loginToCredoButton addTarget:self action:@selector(loginToCredoButtonPressed:)  forControlEvents:UIControlEventTouchUpInside];
}


- (void)loginToCredoButtonPressed:(id)sender {
    [[NSUserDefaults standardUserDefaults] setObject:@"TOKEN123" forKey:@"CREDO_TOKEN"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    printf("Hello from Login To Credo Button\n\n");
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"CREDO_TOKEN"];
    printf("Token is '%s'\n", [token UTF8String]);
    printf("password: %s username: %s\n", [self.passwordTxtField.text UTF8String], [self.usernameTxtField.text UTF8String]);
}

@end
