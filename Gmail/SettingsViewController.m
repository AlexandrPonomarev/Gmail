
//  SettingsViewController.m
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//


#import "SettingsViewController.h"
#import "FXKeychain.h"

NSString * const UsernameKey = @"username";
NSString * const PasswordKey = @"password";
NSString * const HostnameKey = @"hostname";

@implementation SettingsViewController

- (void)done:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:self.emailTextField.text ?: @"" forKey:UsernameKey];
    [[FXKeychain defaultKeychain] setObject:self.passwordTextField.text ?: @"" forKey:PasswordKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.hostnameTextField.text ?: @"" forKey:HostnameKey];
    
    [self.delegate settingsViewControllerFinished:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Settings";
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(done:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.emailTextField.text = [[NSUserDefaults standardUserDefaults] stringForKey:UsernameKey];
    self.passwordTextField.text = [[FXKeychain defaultKeychain] objectForKey:PasswordKey];
    self.hostnameTextField.text = [[NSUserDefaults standardUserDefaults] stringForKey:HostnameKey];
}

@end
