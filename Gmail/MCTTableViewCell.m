//
//  MCTTableViewCell.m
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//

#import "MCTTableViewCell.h"

@implementation MCTTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    return self;
}

- (void)prepareForReuse
{
    [self.messageRenderingOperation cancel];
    self.detailTextLabel.text = @" ";
}

@end
