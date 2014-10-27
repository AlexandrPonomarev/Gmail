//
//  MasterViewController.m
//  Gmail
//
//  Created by Alexandr Ponomarev on 16.10.14.
//  Copyright (c) 2014 AleksandrPonomarev. All rights reserved.
//

#import "MasterViewController.h"

#import "DetailViewController.h"
#import <MailCore/MailCore.h>
#import "FXKeychain.h"
#import "MCTTableViewCell.h"
#import "SettingsViewController.h"


#define CLIENT_ID @"the-client-id"
#define CLIENT_SECRET @"the-client-secret"
#define KEYCHAIN_ITEM_NAME @"MailCore OAuth 2.0 Token"

#define NUMBER_OF_MESSAGES_TO_LOAD		50

static NSString *mailCellIdentifier = @"MailCell";
static NSString *inboxInfoIdentifier = @"InboxStatusCell";

@interface MasterViewController ()
@property (nonatomic, strong) NSArray *messages;

@property (nonatomic, strong) MCOIMAPOperation *imapCheckOp;
@property (nonatomic, strong) MCOIMAPSession *imapSession;
@property (nonatomic, strong) MCOIMAPFetchMessagesOperation *imapMessagesFetchOp;


@property (nonatomic) NSInteger totalNumberOfInboxMessages;
@property (nonatomic) BOOL isLoading;
@property (nonatomic, strong) UIActivityIndicatorView *loadMoreActivityView;
@property (nonatomic, strong) NSMutableDictionary *messagePreviews;


@end

@implementation MasterViewController

- (void)awakeFromNib
{
    self.clearsSelectionOnViewWillAppear = NO;
    self.preferredContentSize = CGSizeMake(320.0, 600.0);
    [super awakeFromNib];
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self.tableView registerClass:[MCTTableViewCell class] forCellReuseIdentifier:mailCellIdentifier];
    self.loadMoreActivityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ HostnameKey: @"imap.gmail.com" }];
    
    [self startLogin];
}

- (void)startLogin
{
    [self performSelector:@selector(showSettingsViewController:) withObject:nil afterDelay:0.0];
    return;
}

- (void)showSettingsViewController:(id)sender
{
    [self.imapMessagesFetchOp cancel];
    
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] initWithNibName:nil bundle:nil];
    settingsViewController.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)loadAccountWithUsername:(NSString *)username password:(NSString *)password hostname:(NSString *)hostname oauth2Token:(NSString *)oauth2Token
{
    self.imapSession = [[MCOIMAPSession alloc] init];
    self.imapSession.hostname = hostname;
    self.imapSession.port = 993;
    self.imapSession.username = username;
    self.imapSession.password = password;
    
    if (oauth2Token != nil)
    {
        self.imapSession.OAuth2Token = oauth2Token;
        self.imapSession.authType = MCOAuthTypeXOAuth2;
    }
    
    self.imapSession.connectionType = MCOConnectionTypeTLS;
    MasterViewController * __weak weakSelf = self;
    
    self.imapSession.connectionLogger = ^(void * connectionID, MCOConnectionLogType type, NSData * data)
    {
        @synchronized(weakSelf)
        {
            
            if (type != MCOConnectionLogTypeSentPrivate)
            {
                NSLog(@"event logged:%p %li withData: %@", connectionID, type, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
        }
    };
    
    self.messages = nil;
    self.totalNumberOfInboxMessages = -1;
    self.isLoading = NO;
    self.messagePreviews = [NSMutableDictionary dictionary];
    [self.tableView reloadData];
    
    NSLog(@"checking account");
    
    self.imapCheckOp = [self.imapSession checkAccountOperation];
    
    [self.imapCheckOp start:^(NSError *error)
    {
        MasterViewController *strongSelf = weakSelf;
        NSLog(@"finished checking account.");
        
        if (error == nil)
        {
            [strongSelf loadLastNMessages:NUMBER_OF_MESSAGES_TO_LOAD];
        }
        else
        {
            NSLog(@"error loading account: %@", error);
        }
        
        strongSelf.imapCheckOp = nil;
    }];
}

- (void)loadLastNMessages:(NSUInteger)nMessages
{
    self.isLoading = YES;
    
    MCOIMAPMessagesRequestKind requestKind = (MCOIMAPMessagesRequestKind)
    (MCOIMAPMessagesRequestKindHeaders | MCOIMAPMessagesRequestKindStructure |
     MCOIMAPMessagesRequestKindInternalDate | MCOIMAPMessagesRequestKindHeaderSubject |
     MCOIMAPMessagesRequestKindFlags);
    
    NSString *inboxFolder = @"INBOX";
    MCOIMAPFolderInfoOperation *inboxFolderInfo = [self.imapSession folderInfoOperation:inboxFolder];
    
    [inboxFolderInfo start:^(NSError *error, MCOIMAPFolderInfo *info)
    {
         BOOL totalNumberOfMessagesDidChange =
         self.totalNumberOfInboxMessages != [info messageCount];
         
         self.totalNumberOfInboxMessages = [info messageCount];
         
         NSUInteger numberOfMessagesToLoad =
         MIN(self.totalNumberOfInboxMessages, nMessages);
         
         if (numberOfMessagesToLoad == 0)
         {
             self.isLoading = NO;
             return;
         }
         
         MCORange fetchRange;
         
         if (!totalNumberOfMessagesDidChange && self.messages.count)
         {
             numberOfMessagesToLoad -= self.messages.count;
             
             fetchRange =
             MCORangeMake(self.totalNumberOfInboxMessages -
                          self.messages.count -
                          (numberOfMessagesToLoad - 1),
                          (numberOfMessagesToLoad - 1));
         }
         else
         {
             fetchRange =
             MCORangeMake(self.totalNumberOfInboxMessages -
                          (numberOfMessagesToLoad - 1),
                          (numberOfMessagesToLoad - 1));
         }
         
         self.imapMessagesFetchOp =
         [self.imapSession fetchMessagesByNumberOperationWithFolder:inboxFolder
                                                        requestKind:requestKind
                                                            numbers:
          [MCOIndexSet indexSetWithRange:fetchRange]];
         
         [self.imapMessagesFetchOp setProgress:^(unsigned int progress) {
             NSLog(@"Progress: %u of %lu", progress, (unsigned long)numberOfMessagesToLoad);
         }];
         
         __weak MasterViewController *weakSelf = self;
         [self.imapMessagesFetchOp start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages)
          {
              MasterViewController *strongSelf = weakSelf;
              NSLog(@"fetched all messages.");
              
              self.isLoading = NO;
              
              NSSortDescriptor *sort =
              [NSSortDescriptor sortDescriptorWithKey:@"header.date" ascending:NO];
              
              NSMutableArray *combinedMessages =
              [NSMutableArray arrayWithArray:messages];
              [combinedMessages addObjectsFromArray:strongSelf.messages];
              
              strongSelf.messages =
              [combinedMessages sortedArrayUsingDescriptors:@[sort]];
              [strongSelf.tableView reloadData];
          }];
     }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 1)
    {
        if (self.totalNumberOfInboxMessages >= 0)
        {
            return 1;
        }
        
        return 0;
    }
    
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case 0:
        {
            MCTTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:mailCellIdentifier forIndexPath:indexPath];
            MCOIMAPMessage *message = self.messages[indexPath.row];
            
            cell.textLabel.text = message.header.subject;
            
            NSString *uidKey = [NSString stringWithFormat:@"%d", message.uid];
            NSString *cachedPreview = self.messagePreviews[uidKey];
            
            if (cachedPreview)
            {
                cell.detailTextLabel.text = cachedPreview;
            }
            else
            {
                cell.messageRenderingOperation = [self.imapSession plainTextBodyRenderingOperationWithMessage:message folder:@"INBOX"];
                
                [cell.messageRenderingOperation start:^(NSString * plainTextBodyString, NSError * error)
                 {
                    cell.detailTextLabel.text = plainTextBodyString;
                    cell.messageRenderingOperation = nil;
                    self.messagePreviews[uidKey] = plainTextBodyString;
                }];
            }
            
            return cell;
            break;
        }
            
        case 1:
        {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:inboxInfoIdentifier];
            
            if (!cell)
            {
                cell =
                [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:inboxInfoIdentifier];
                
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.detailTextLabel.textAlignment = NSTextAlignmentCenter;
            }
            
            if (self.messages.count < self.totalNumberOfInboxMessages)
            {
                cell.textLabel.text =
                [NSString stringWithFormat:@"Load %lu more",
                 MIN(self.totalNumberOfInboxMessages - self.messages.count,
                     NUMBER_OF_MESSAGES_TO_LOAD)];
            }
            else
            {
                cell.textLabel.text = nil;
            }
            
            cell.detailTextLabel.text =
            [NSString stringWithFormat:@"%ld message(s)",
             (long)self.totalNumberOfInboxMessages];
            
            cell.accessoryView = self.loadMoreActivityView;
            
            if (self.isLoading)
            {
                [self.loadMoreActivityView startAnimating];
            }
            else
            {
                [self.loadMoreActivityView stopAnimating];
            }
            
            return cell;
            break;
        }
            
        default:
            return nil;
            break;
    }
    
}

- (void)settingsViewControllerFinished:(SettingsViewController *)viewController
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:UsernameKey];
    NSString *password = [[FXKeychain defaultKeychain] objectForKey:PasswordKey];
    NSString *hostname = [[NSUserDefaults standardUserDefaults] objectForKey:HostnameKey];
    
    if (![username isEqualToString:self.imapSession.username] ||
        ![password isEqualToString:self.imapSession.password] ||
        ![hostname isEqualToString:self.imapSession.hostname])
    {
        self.imapSession = nil;
        [self loadAccountWithUsername:username password:password hostname:hostname oauth2Token:nil];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case 0:
        {
            MCOIMAPMessage *msg = self.messages[indexPath.row];
            _detailViewController.folder = @"INBOX";
            _detailViewController.message = msg;
            _detailViewController.session = self.imapSession;
            [_detailViewController hideMaster];
            break;
        }
        case 1:
        {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            
            if (!self.isLoading &&
                self.messages.count < self.totalNumberOfInboxMessages)
            {
                [self loadLastNMessages:self.messages.count + NUMBER_OF_MESSAGES_TO_LOAD];
                cell.accessoryView = self.loadMoreActivityView;
                [self.loadMoreActivityView startAnimating];
            }
            
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            break;
        }
            
        default:
            break;
    }
}

@end