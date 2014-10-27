//
//  DetailViewController.m
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//

#import "DetailViewController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import "MCOMessageView.h"

@interface DetailViewController ()  <MCOMessageViewDelegate>
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@end

@implementation DetailViewController

#pragma mark - Managing the detail item

@synthesize folder = _folder;
@synthesize session = _session;

- (void)hideMaster
{
    [self.masterPopoverController dismissPopoverAnimated:YES];
    
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    float ver_float = [ver floatValue];
    
    if (ver_float < 8.0)
    {
    _messageView = [[MCOMessageView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.frame.size.height+40, self.view.frame.size.width, self.view.frame.size.height)];
    }
    else
    {
        _messageView = [[MCOMessageView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.frame.size.height, self.view.frame.size.width, self.view.frame.size.height)];
    }
    
    _messageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_messageView];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"FetchFullMessageEnabled"])
    {
        [_messageView setDelegate:self];
        [_messageView setFolder:_folder];
        [_messageView setMessage:_message];
    }
    else
    {
        [_messageView setMessage:NULL];
        MCOIMAPFetchContentOperation * operation = [_session fetchMessageOperationWithFolder:_folder uid:[_message uid]];
        [_ops addObject:operation];
        [operation start:^(NSError * error, NSData * data)
        {
            if ([error code] != MCOErrorNone)
            {
                return;
            }

            NSAssert(data != nil, @"data != nil");

            MCOMessageParser * msg = [MCOMessageParser messageParserWithData:data];
            [_messageView setDelegate:self];
            [_messageView setFolder:_folder];
            [_messageView setMessage:msg];
        }];
    }
}

- (void)awakeFromNib
{
    _storage = [[NSMutableDictionary alloc] init];
    _ops = [[NSMutableArray alloc] init];
    _pending = [[NSMutableSet alloc] init];
    _callbacks = [[NSMutableDictionary alloc] init];
}

- (id)init
{
    self = [super init];
    
    if(self)
    {
        [self awakeFromNib];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
}

- (void)setMessage:(MCOIMAPMessage *)message
{
    for(MCOOperation * op in _ops)
    {
        [op cancel];
    }
    
    [_ops removeAllObjects];
    [_callbacks removeAllObjects];
    [_pending removeAllObjects];
    [_storage removeAllObjects];
    _message = message;
}

- (MCOIMAPMessage *)message
{
    return _message;
}

- (MCOIMAPFetchContentOperation *)_fetchIMAPPartWithUniqueID:(NSString *)partUniqueID folder:(NSString *)folder
{
    if ([_pending containsObject:partUniqueID])
    {
        return nil;
    }
    
    MCOIMAPPart * part = (MCOIMAPPart *) [_message partForUniqueID:partUniqueID];
    [_pending addObject:partUniqueID];
    MCOIMAPFetchContentOperation * operation = [_session fetchMessageAttachmentOperationWithFolder:folder uid:[_message uid] partID:[part partID] encoding:[part encoding]];
    [_ops addObject:operation];
    [operation start:^(NSError * error, NSData * data)
     {
         
        if ([error code] != MCOErrorNone)
        {
            [self _callbackForPartUniqueID:partUniqueID error:error];
            return;
        }
        
        [_ops removeObject:operation];
        [_storage setObject:data forKey:partUniqueID];
        [_pending removeObject:partUniqueID];
        [self _callbackForPartUniqueID:partUniqueID error:nil];
    }];
    
    return operation;
}

typedef void (^DownloadCallback)(NSError * error);

- (void)_callbackForPartUniqueID:(NSString *)partUniqueID error:(NSError *)error
{
    NSArray * blocks;
    blocks = [_callbacks objectForKey:partUniqueID];
    for(DownloadCallback block in blocks) {
        block(error);
    }
}

- (NSString *)MCOMessageView_templateForAttachment:(MCOMessageView *)view
{
    return @"<div><img src=\"http://www.iconshock.com/img_jpg/OFFICE/general/jpg/128/attachment_icon.jpg\"/></div>\
    {{#HASSIZE}}\
    <div>- {{FILENAME}}, {{SIZE}}</div>\
    {{/HASSIZE}}\
    {{#NOSIZE}}\
    <div>- {{FILENAME}}</div>\
    {{/NOSIZE}}";
}

- (NSString *)MCOMessageView_templateForMessage:(MCOMessageView *)view
{
    return @"<div style=\"padding-bottom: 20px; font-family: Helvetica; font-size: 13px;\">{{HEADER}}</div><div>{{BODY}}</div>";
}

- (BOOL)MCOMessageView:(MCOMessageView *)view canPreviewPart:(MCOAbstractPart *)part
{
    NSString * mimeType = [[part mimeType] lowercaseString];
    
    if ([mimeType isEqualToString:@"image/tiff"])
    {
        return YES;
    }
    else if ([mimeType isEqualToString:@"image/tif"])
    {
        return YES;
    }
    else if ([mimeType isEqualToString:@"application/pdf"])
    {
        return YES;
    }
    
    NSString * ext = nil;
    
    if ([part filename] != nil)
    {
        if ([[part filename] pathExtension] != nil)
        {
            ext = [[[part filename] pathExtension] lowercaseString];
        }
    }
    
    if (ext != nil)
    {
        if ([ext isEqualToString:@"tiff"])
        {
            return YES;
        }
        else if ([ext isEqualToString:@"tif"])
        {
            return YES;
        }
        else if ([ext isEqualToString:@"pdf"])
        {
            return YES;
        }
    }
    
    return NO;
}

- (NSString *)MCOMessageView:(MCOMessageView *)view filteredHTML:(NSString *)html
{
    return html;
}

- (NSData *)MCOMessageView:(MCOMessageView *)view dataForPartWithUniqueID:(NSString *)partUniqueID
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FetchFullMessageEnabled"])
    {
        MCOAttachment * attachment = (MCOAttachment *) [[_messageView message] partForUniqueID:partUniqueID];
        return [attachment data];
    }
    else
    {
        NSData * data = [_storage objectForKey:partUniqueID];
        return data;
    }
}

- (void)MCOMessageView:(MCOMessageView *)view fetchDataForPartWithUniqueID:(NSString *)partUniqueID
     downloadedFinished:(void (^)(NSError * error))downloadFinished
{
    MCOIMAPFetchContentOperation * op = [self _fetchIMAPPartWithUniqueID:partUniqueID folder:_folder];
    [op setProgress:^(unsigned int current, unsigned int maximum) {
        MCLog("progress content: %u/%u", current, maximum);
    }];
    
    if (op != nil)
    {
        [_ops addObject:op];
    }
    
    if (downloadFinished != NULL)
    {
        NSMutableArray * blocks;
        blocks = [_callbacks objectForKey:partUniqueID];
        
        if (blocks == nil)
        {
            blocks = [NSMutableArray array];
            [_callbacks setObject:blocks forKey:partUniqueID];
        }
        [blocks addObject:[downloadFinished copy]];
    }
}

- (NSData *)MCOMessageView:(MCOMessageView *)view previewForData:(NSData *)data isHTMLInlineImage:(BOOL)isHTMLInlineImage
{
    if (isHTMLInlineImage)
    {
        return data;
    }
    else
    {
        return nil;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"List", @"List");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
