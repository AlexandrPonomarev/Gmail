//
//  MasterViewController.h
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MailCore/MailCore.h>
#import "SettingsViewController.h"

@class DetailViewController;

@interface MasterViewController : UITableViewController <SettingsViewControllerDelegate>

@property (strong, nonatomic) DetailViewController *detailViewController;

@end
