//
//  MyLoginViewController.m
//  Cosmic Ray
//
//  Created by Michał Frontczak on 16/10/2021.
//

#import <sys/utsname.h>

#import "MyLoginViewController.h"
#import "GLCameraViewController.h"



@interface MyLoginViewController ()

@end

@implementation MyLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self.loginToCredoButton addTarget:self action:@selector(loginToCredoButtonPressed:)  forControlEvents:UIControlEventTouchUpInside];
}


- (void)loginToCredoButtonPressed:(id)sender {
    NSString* urlString = [NSString stringWithFormat:@"%@/api/v2/user/login", [GLCameraViewController serverBase]];
    NSMutableDictionary* loginData = [NSMutableDictionary dictionary];
    /*
     let json = [
         "email": username,
         "password": password,
         "app_version": 1,
         "device_id": device_id,
         "device_type": "iphone",
         "device_model": UIDevice.modelName,
         "system_version": "IOS \(UIDevice.current.systemVersion as String)"
     ] as [String : Any]
     */
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *code = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *osVersion = [NSString stringWithFormat:@"IOS %@", [[NSProcessInfo processInfo] operatingSystemVersionString]];
    loginData[@"email"] = self.usernameTxtField.text;
    loginData[@"password"] = self.passwordTxtField.text;
    loginData[@"app_version"] = @"1";
    loginData[@"device_type"] = @"iphone";
    loginData[@"device_model"] = code;
    loginData[@"device_id"] = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    loginData[@"system_version"] = osVersion;

    NSArray *keys = [loginData allKeys];
    
    for (id key in keys) {
        NSLog(@"%s %s", [key UTF8String], [[loginData valueForKey:key] UTF8String]);
    }
    
    [self placePostRequestWithURL:urlString withData:loginData withHandler:^(NSURLResponse *response, NSData *rawData, NSError *error) {
        NSString *string = [[NSString alloc] initWithData:rawData
                                                 encoding:NSUTF8StringEncoding];
        
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        NSInteger code = [httpResponse statusCode];
        NSLog(@"body:\n%s\n\nstatus code: %ld", [string UTF8String], (long)code);
        if (code == 200) {
            NSError *jsonError;
            NSData *objectData = [string dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData options:NSJSONReadingMutableContainers error:&jsonError];
            NSString *token = [json valueForKey:@"token"];
            NSLog(@"user token: %s", [token UTF8String]);
            [[NSUserDefaults standardUserDefaults] setObject:token forKey:@"CREDO_TOKEN"];
        } else {
            NSLog(@"Error invalid login or password");
        }
    }];
    
}


-(void)placePostRequestWithURL:(NSString *)action withData:(NSDictionary *)dataToSend withHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))ourBlock {
    NSString *urlString = [NSString stringWithFormat:@"%@", action];
    NSLog(@"%@", urlString);
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dataToSend options:0 error:&error];
    
    NSString *jsonString;
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        NSData *requestData = [NSData dataWithBytes:[jsonString UTF8String] length:[jsonString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody: requestData];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:ourBlock];
    }
}

@end
