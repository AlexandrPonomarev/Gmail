//
//  DetailViewController.h
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
