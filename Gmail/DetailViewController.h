//
//  DetailViewController.h
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <MailCore/MailCore.h>

@class MCOMessageView;
@class MCOIMAPAsyncSession;
@class MCOMAPMessage;

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>
{
    MCOMessageView * _messageView;
    NSMutableDictionary * _storage;
    NSMutableSet * _pending;
    NSMutableArray * _ops;
    MCOIMAPSession * _session;
    MCOIMAPMessage * _message;
    NSMutableDictionary * _callbacks;
    NSString * _folder;
}

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@property (nonatomic, copy) NSString * folder;
@property (nonatomic, strong) MCOIMAPSession * session;
@property (nonatomic, strong) MCOIMAPMessage * message;

- (void)hideMaster;

@end

