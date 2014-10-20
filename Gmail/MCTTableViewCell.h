//
//  MCTTableViewCell.h
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MailCore/MailCore.h>

@interface MCTTableViewCell : UITableViewCell

@property (nonatomic, strong) MCOIMAPMessageRenderingOperation * messageRenderingOperation;

@end
