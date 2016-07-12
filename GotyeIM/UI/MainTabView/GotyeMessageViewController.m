//
//  GotyeTableViewController.m
//  GotyeIM
//
//  Created by Peter on 14-9-29.
//  Copyright (c) 2014年 Gotye. All rights reserved.
//

#import "GotyeMessageViewController.h"

#import "GotyeNotifyController.h"

#import "GotyeUIUtil.h"

#import "GotyeOCAPI.h"

#import "GotyeChatViewController.h"

#ifdef REDPACKET_AVALABLE

#import "RedpacketMessageModel.h"

#endif


@interface GotyeMessageViewController () <GotyeContextMenuCellDataSource, GotyeContextMenuCellDelegate, GotyeOCDelegate>
{
    BOOL enteringRoom;
    
    BOOL isTabTop;
    
    NSArray *notifyList;
    NSArray *sessionList;
}

@end

@implementation GotyeMessageViewController

#ifdef REDPACKET_AVALABLE

- (NSString *)handleMessage:(GotyeOCMessage*)message withChatType:(GotyeChatTargetType)type andUser:(GotyeOCUser*)user andContent:(NSString *)content{
    
    NSDictionary *dict = [self transformExtToDictionary:message];
    if ([RedpacketMessageModel isRedpacketTakenMessage:dict]) {
        NSString *senderID = [dict valueForKey:RedpacketKeyRedpacketSenderId];
        NSString *receiverID = [dict valueForKey:RedpacketKeyRedpacketReceiverId];
        //  标记为已读
        if ([senderID isEqualToString:[GotyeOCAPI getLoginUser].name] && ![receiverID isEqualToString:[GotyeOCAPI getLoginUser].name]){
            /**
             *  当前用户是红包发送者。
             */
            NSString *text = [NSString stringWithFormat:@"%@领取了你的红包",receiverID];
            return text;
        }
        else{
            return message.text;
        }
    }
    else{
        if (type == GotyeChatTargetTypeUser ) {
            return content;
            
        }
        else{
            return [NSString stringWithFormat:@"%@:%@", user.name, content];
        }
    }
}

- (void)delToSelfPacketMessage:(GotyeOCMessage*)message{
    
    if (message == nil) {
        return;
    }
    
    GotyeOCUser* loginUser = [GotyeOCAPI getLoginUser];
    
    NSDictionary * ext = [self transformExtToDictionary:message];
    if ([RedpacketMessageModel isRedpacketRelatedMessage:ext]) {
        if ([RedpacketMessageModel isRedpacketTakenMessage:ext])    {
            
            // 如果群红包，A发的，A打开，others收到消息，others删除消息 ||  // 如果群红包，A发的，B打开，other收到消息，除了A之外的others删除
            if ([ext[@"money_sender_id"] isEqualToString:ext[@"money_receiver_id"]] || ![ext[@"money_sender_id"] isEqualToString:loginUser.name]) {
                if (message.receiver.type == GotyeChatTargetTypeRoom ) {
                    [GotyeOCAPI deleteMessage:[GotyeOCRoom roomWithId:message.dbID] msg:message];
                    
                }
                else if(message.receiver.type == GotyeChatTargetTypeGroup){
                    [GotyeOCAPI deleteMessage:[GotyeOCGroup groupWithId:message.dbID] msg:message];
                }
                return;
            }
        }
    }
}

- (NSDictionary *)transformExtToDictionary:(GotyeOCMessage*)message{
    
    NSDictionary * dic = nil;
    
    NSData *data = [message getExtraData];//[NSData dataWithContentsOfFile:message.extra.path];
    if(data != nil)
    {
        char * str = malloc(data.length + 1);
        [data getBytes:str length:data.length];
        str[data.length] = 0;
        NSString *extraStr = [NSString stringWithUTF8String:str];
        free(str);
        NSData *jsonData = [extraStr dataUsingEncoding:NSUTF8StringEncoding];
        NSError *err;
        dic = [NSJSONSerialization
               JSONObjectWithData:jsonData
               options:NSJSONReadingMutableContainers
               error:&err];
    }
    return dic;
}


#endif

- (id)init
{
    self = [super init];
    if (self) {
        self.tabBarItem.image = [[UIImage imageNamed:@"tab_button_message"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        self.tabBarItem.selectedImage = [UIImage imageNamed:@"tab_button_message"];
        self.tabBarItem.imageInsets = UIEdgeInsetsMake(5, 0, -5, 0);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    //    self.tableView.tableHeaderView = viewSearch;
    
    [GotyeOCAPI addListener:self];
    self.tabBarController.navigationItem.title = @"消息";
    
    enteringRoom = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    isTabTop = YES;
    [GotyeOCAPI addListener:self];
    self.tabBarController.navigationItem.title = @"消息";
    
    for(GotyeOCChatTarget* target in sessionList)
    {
        switch (target.type) {
            case GotyeChatTargetTypeUser:
            {
                GotyeOCUser* user = [GotyeOCAPI getUserDetail:target forceRequest:NO];
                [GotyeOCAPI downloadMedia:user.icon];
            }
                break;
                
            case GotyeChatTargetTypeRoom:
            {
                GotyeOCRoom* room = [GotyeOCAPI getRoomDetail:target forceRequest: NO];
                [GotyeOCAPI downloadMedia:room.icon];
            }
                break;
                
            case GotyeChatTargetTypeGroup:
            {
                GotyeOCGroup* group = [GotyeOCAPI getGroupDetail:target forceRequest:NO];
                [GotyeOCAPI downloadMedia:group.icon];
            }
                break;
        }
    }
    
    notifyList = [GotyeOCAPI getNotifyList];
    sessionList = [GotyeOCAPI getSessionList];
    
    [self.tableView reloadData];
    
    [self setTabBarItemIcon];
}

- (void)setTabBarItemIcon
{
    NSInteger unreadCount = [GotyeOCAPI getTotalUnreadMessageCount] + [GotyeOCAPI getUnreadNotifyCount];
    
    if(unreadCount > 0)
        self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%ld", (long)unreadCount];
    else
        self.tabBarItem.badgeValue = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
    isTabTop= NO;
    //[GotyeOCAPI removeListener:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Gotye UI delegates

-(void)onLogin:(GotyeStatusCode)code user:(GotyeOCUser *)user
{
    if(code == GotyeStatusCodeOK || code == GotyeStatusCodeOfflineLoginOK || code == GotyeStatusCodeReloginOK)
    {
        [self.tableView reloadData];
        
        [self setTabBarItemIcon];
    }
    self.tableView.tableHeaderView = nil;
}

-(void)onLogout:(GotyeStatusCode)code
{
    if(code == GotyeStatusCodeNetworkDisConnected)
    {
        self.tableView.tableHeaderView = self.viewNetworkFail;
        self.labelNetwork.text = @"未连接";
        
        [GotyeUIUtil hideHUD];
    }
}

-(void)onReconnecting:(GotyeStatusCode)code user:(GotyeOCUser *)user
{
    self.labelNetwork.text = @"连接中...";
}

-(void)onReceiveMessage:(GotyeOCMessage *)message downloadMediaIfNeed:(bool *)downloadMediaIfNeed
{
#ifdef REDPACKET_AVALABLE
    [self delToSelfPacketMessage:message];
#endif
    
    [self setTabBarItemIcon];
    
    if(!isTabTop)
        return;
    
    sessionList = [GotyeOCAPI getSessionList];
    *downloadMediaIfNeed = true;
    
    [self.tableView reloadData];
}

-(void)onReceiveNotify:(GotyeOCNotify *)notify
{
    [self setTabBarItemIcon];
    
    if(!isTabTop)
        return;
    
    notifyList = [GotyeOCAPI getNotifyList];
    [self.tableView reloadData];
}

-(void)onGetMessageList:(GotyeStatusCode)code msglist:(NSArray *)msgList downloadMediaIfNeed:(bool *)downloadMediaIfNeed
{
    
#ifdef REDPACKET_AVALABLE
    
    @autoreleasepool {
        for (GotyeOCMessage * msg in msgList) {
            [self delToSelfPacketMessage:msg];
        }
    }
#endif
    
    
    [self setTabBarItemIcon];
    
    if(!isTabTop)
        return;
    
    sessionList = [GotyeOCAPI getSessionList];
    *downloadMediaIfNeed = true;
    
    if(code == GotyeStatusCodeOK)
        [self.tableView reloadData];
}

- (void)onGetUserInfo:(GotyeStatusCode)code user:(GotyeOCUser*)user
{
    if(!isTabTop)
        return;
    
    if(code == GotyeStatusCodeOK)
        [self.tableView reloadData];
}

- (void)onGetGroupDetail:(GotyeStatusCode)code group:(GotyeOCGroup *)group
{
    if(!isTabTop)
        return;
    
    if(code == GotyeStatusCodeOK)
        [self.tableView reloadData];
}

- (void)onDownloadMedia:(GotyeStatusCode)code media:(GotyeOCMedia*)media
{
    if(!isTabTop)
        return;
    
    if(code == GotyeStatusCodeOK)
        [self.tableView reloadData];
}

-(void)onEnterRoom:(GotyeStatusCode)code room:(GotyeOCRoom *)room
{
    if(!isTabTop)
        return;
    
    if(code == GotyeStatusCodeOK)
    {
        if(self.navigationController.topViewController == self.tabBarController)
        {
            GotyeChatViewController*viewController = [[GotyeChatViewController alloc] initWithTarget:room];
            [self.navigationController pushViewController:viewController animated:YES];
        }
    }
    else
    {
        NSString *errorStr;
        
        if(code == GotyeStatusCodeRoomIsFull)
            errorStr = @"房间已满";
        else if(code == GotyeStatusCodeRoomNotExist)
            errorStr = @"房间不存在";
        else if(code == GotyeStatusCodeAlreadyInRoom)
            errorStr = @"重复进入房间请求";
        else
            errorStr = [NSString stringWithFormat:@"未知错误(%d)", code];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:errorStr
                                                       delegate:nil
                                              cancelButtonTitle:@"确定"
                                              otherButtonTitles:nil, nil];
        [alert show];
    }
    
    [GotyeUIUtil hideHUD];
    enteringRoom = NO;
}


#pragma mark - table delegate & data

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger notifyCount = notifyList.count;
    NSInteger count = sessionList.count + (notifyCount > 0 ? 1 : 0);
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MessageCellIdentifier = @"MessageCellIdentifier";
    
    GotyeMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:MessageCellIdentifier];
    if(cell == nil)
    {
        cell = [[[NSBundle mainBundle] loadNibNamed:@"GotyeMessageCell" owner:self options:nil] firstObject];
    }
    
    if(sessionList.count + notifyList.count > sessionList.count)
    {
        if (indexPath.row == 0) {
            
            int notifyCount = [GotyeOCAPI getUnreadNotifyCount];
            
            cell.labelUsername.text = @"通知";
            cell.imageHead.image = [UIImage imageNamed:@"head_icon_group"];
            cell.labelMessage.text = [NSString stringWithFormat:@"共收到%lu个通知", (unsigned long)notifyList.count];
            
            cell.dataSource = nil;
            cell.delegate = nil;
            
            if(notifyCount > 0)
            {
                cell.buttonNewCount.hidden = NO;
                [cell.buttonNewCount setTitle:[NSString stringWithFormat:@"%d", notifyCount] forState:UIControlStateNormal];
            }
            else
                cell.buttonNewCount.hidden = YES;
            
            return cell;
        }else {
            cell.dataSource = self;
            cell.delegate = self;
            
            GotyeOCChatTarget* target = sessionList[indexPath.row-1];
            GotyeOCMessage* lastMessage = [GotyeOCAPI getLastMessage:target];
            
            int newCount = [GotyeOCAPI getUnreadMessageCount:target];
            if(newCount > 0)
            {
                cell.buttonNewCount.hidden = NO;
                [cell.buttonNewCount setTitle:newCount > 99 ? @"99+" : [NSString stringWithFormat:@"%d", newCount] forState:UIControlStateNormal];
            }
            else
                cell.buttonNewCount.hidden = YES;
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setLocale:[NSLocale systemLocale]];
            [formatter setTimeZone:[NSTimeZone systemTimeZone]];
            [formatter setDateFormat:@"MM-dd HH:mm"];
            NSString *msgDate = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:lastMessage.date]];
            
            [formatter setDateFormat:@"MM-dd"];
            NSString *curDate = [formatter stringFromDate:[NSDate date]];
            if([curDate compare:[msgDate substringToIndex:5]] == NSOrderedSame)
                cell.labelTime.text = [msgDate substringFromIndex:6];
            else
                cell.labelTime.text = [msgDate substringToIndex:5];
            //
            NSString *contentStr;
            NSInteger msgType = lastMessage.type;
            if(msgType == GotyeMessageTypeImage)
                contentStr = @"[图片]";
            else if(msgType == GotyeMessageTypeAudio)
                contentStr = @"[语音]";
            else
                contentStr = lastMessage.text;
            
            switch (target.type) {
                case GotyeChatTargetTypeUser:
                {
                    GotyeOCUser* user = [GotyeOCAPI getUserDetail:target forceRequest:NO];
                    
                    cell.labelUsername.text = user.name;
#ifdef REDPACKET_AVALABLE
                    
                    cell.labelMessage.text = [self handleMessage:lastMessage withChatType:target.type andUser:user andContent:contentStr];
#else
                    cell.labelMessage.text = contentStr;
                    
#endif
                    
                    UIImage *headImage = [GotyeUIUtil getHeadImage:user.icon.path defaultIcon:@"head_icon_user"];
                    
                    cell.imageHead.image = headImage;
                }
                    break;
                    
                case GotyeChatTargetTypeRoom:
                {
                    GotyeOCRoom* room = [GotyeOCAPI getRoomDetail:target forceRequest: NO];
                    GotyeOCUser* user = [GotyeOCAPI getUserDetail:lastMessage.sender forceRequest:NO];
                    
                    cell.labelUsername.text = room.name;
#ifdef REDPACKET_AVALABLE
                    
                    cell.labelMessage.text = [self handleMessage:lastMessage withChatType:target.type andUser:user andContent:contentStr];
#else
                    cell.labelMessage.text = [NSString stringWithFormat:@"%@:%@", user.name, contentStr];
                    
#endif
                    cell.imageHead.image = [GotyeUIUtil getHeadImage:room.icon.path defaultIcon:@"head_icon_room"];
                    
                }
                    break;
                    
                case GotyeChatTargetTypeGroup:
                {
                    GotyeOCGroup* group = [GotyeOCAPI getGroupDetail:target forceRequest:NO];
                    GotyeOCUser* user = [GotyeOCAPI getUserDetail:lastMessage.sender forceRequest:NO];
                    
                    cell.labelUsername.text = group.name;
#ifdef REDPACKET_AVALABLE
                    
                    cell.labelMessage.text = [self handleMessage:lastMessage withChatType:target.type andUser:user andContent:contentStr];
#else
                    cell.labelMessage.text = [NSString stringWithFormat:@"%@:%@", user.name, contentStr];
                    
#endif
                    cell.imageHead.image = [GotyeUIUtil getHeadImage:group.icon.path defaultIcon:@"head_icon_room"];
                }
                    break;
                    
                    //        case 3:
                    //        {
                    //            cell.labelUsername.text = @"群邀请";
                    //            cell.imageHead.image = [UIImage imageNamed:@"head_icon_group"];
                    //            cell.labelMessage.text = [NSString stringWithFormat:@"%d位好友邀请你群聊", messageArray.count];
                    //        }
                    break;
                    
                default:
                    break;
            }
            
            cell.tag = indexPath.row + 1;
            
            return cell;
            
        }
    }else {
        
        cell.dataSource = self;
        cell.delegate = self;
        
        GotyeOCChatTarget* target = sessionList[indexPath.row];
        GotyeOCMessage* lastMessage = [GotyeOCAPI getLastMessage:target];
        
        int newCount = [GotyeOCAPI getUnreadMessageCount:target];
        if(newCount > 0)
        {
            cell.buttonNewCount.hidden = NO;
            [cell.buttonNewCount setTitle:newCount > 99 ? @"99+" : [NSString stringWithFormat:@"%d", newCount] forState:UIControlStateNormal];
        }
        else
            cell.buttonNewCount.hidden = YES;
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[NSLocale systemLocale]];
        [formatter setTimeZone:[NSTimeZone systemTimeZone]];
        [formatter setDateFormat:@"MM-dd HH:mm"];
        NSString *msgDate = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:lastMessage.date]];
        
        [formatter setDateFormat:@"MM-dd"];
        NSString *curDate = [formatter stringFromDate:[NSDate date]];
        if([curDate compare:[msgDate substringToIndex:5]] == NSOrderedSame)
            cell.labelTime.text = [msgDate substringFromIndex:6];
        else
            cell.labelTime.text = [msgDate substringToIndex:5];
        //
        NSString *contentStr;
        NSInteger msgType = lastMessage.type;
        if(msgType == GotyeMessageTypeImage)
            contentStr = @"[图片]";
        else if(msgType == GotyeMessageTypeAudio)
            contentStr = @"[语音]";
        else
            contentStr = lastMessage.text;
        
        switch (target.type) {
            case GotyeChatTargetTypeUser:
            {
                GotyeOCUser* user = [GotyeOCAPI getUserDetail:target forceRequest:NO];
                
                cell.labelUsername.text = user.name;
                
#ifdef REDPACKET_AVALABLE
                
                cell.labelMessage.text = [self handleMessage:lastMessage withChatType:target.type andUser:user andContent:contentStr];
#else
                cell.labelMessage.text = contentStr;
                
#endif
                UIImage *headImage = [GotyeUIUtil getHeadImage:user.icon.path defaultIcon:@"head_icon_user"];
                
                cell.imageHead.image = headImage;
            }
                break;
                
            case GotyeChatTargetTypeRoom:
            {
                GotyeOCRoom* room = [GotyeOCAPI getRoomDetail:target forceRequest: NO];
                GotyeOCUser* user = [GotyeOCAPI getUserDetail:lastMessage.sender forceRequest:NO];
                
                cell.labelUsername.text = room.name;
#ifdef REDPACKET_AVALABLE
                
                cell.labelMessage.text = [self handleMessage:lastMessage withChatType:target.type andUser:user andContent:contentStr];
#else
                cell.labelMessage.text = [NSString stringWithFormat:@"%@:%@", user.name, contentStr];
                
#endif
                cell.imageHead.image = [GotyeUIUtil getHeadImage:room.icon.path defaultIcon:@"head_icon_room"];
                
            }
                break;
                
            case GotyeChatTargetTypeGroup:
            {
                GotyeOCGroup* group = [GotyeOCAPI getGroupDetail:target forceRequest:NO];
                GotyeOCUser* user = [GotyeOCAPI getUserDetail:lastMessage.sender forceRequest:NO];
                
                cell.labelUsername.text = group.name;
                
#ifdef REDPACKET_AVALABLE
                
                cell.labelMessage.text = [self handleMessage:lastMessage withChatType:target.type andUser:user andContent:contentStr];
#else
                cell.labelMessage.text = [NSString stringWithFormat:@"%@:%@", user.name, contentStr];
                
#endif
                cell.imageHead.image = [GotyeUIUtil getHeadImage:group.icon.path defaultIcon:@"head_icon_room"];
            }
                break;
                
                //        case 3:
                //        {
                //            cell.labelUsername.text = @"群邀请";
                //            cell.imageHead.image = [UIImage imageNamed:@"head_icon_group"];
                //            cell.labelMessage.text = [NSString stringWithFormat:@"%d位好友邀请你群聊", messageArray.count];
                //        }
                break;
                
            default:
                break;
        }
        
        cell.tag = indexPath.row + 1;
        
        return cell;
    }
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(sessionList.count + notifyList.count > sessionList.count)
    {
        if (indexPath.row == 0) {
            
            GotyeNotifyController *viewController = [[GotyeNotifyController alloc] init];
            [self.tabBarController.navigationController pushViewController:viewController animated:YES];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }else {
            
            GotyeOCChatTarget* target = sessionList[indexPath.row-1];
            
            switch (target.type) {
                case GotyeChatTargetTypeGroup:
                case GotyeChatTargetTypeUser:
                {
                    GotyeChatViewController*viewController = [[GotyeChatViewController alloc] initWithTarget:target];
                    [self.tabBarController.navigationController pushViewController:viewController animated:YES];
                }
                    break;
                    
                case GotyeChatTargetTypeRoom:
                {
                    GotyeOCRoom* room = [GotyeOCRoom roomWithId:(unsigned)target.id];
                    
                    if(!enteringRoom)
                    {
                        GotyeStatusCode code = [GotyeOCAPI enterRoom:room];
                        if(code  == GotyeStatusCodeWaitingCallback)
                        {
                            enteringRoom = YES;
                            [GotyeUIUtil showHUD:@"进入聊天室"];
                        }
                        else if(code == GotyeStatusCodeOK)
                        {
                            if(self.navigationController.topViewController == self)
                            {
                                GotyeChatViewController*viewController = [[GotyeChatViewController alloc] initWithTarget:room];
                                [self.navigationController pushViewController:viewController animated:YES];
                            }
                        }
                    }
                }
                    break;
                    
                default:
                    break;
            }
        }
    }else {
        GotyeOCChatTarget* target = sessionList[indexPath.row];
        
        switch (target.type) {
            case GotyeChatTargetTypeGroup:
            case GotyeChatTargetTypeUser:
            {
                GotyeChatViewController*viewController = [[GotyeChatViewController alloc] initWithTarget:target];
                [self.tabBarController.navigationController pushViewController:viewController animated:YES];
            }
                break;
                
            case GotyeChatTargetTypeRoom:
            {
                GotyeOCRoom* room = [GotyeOCRoom roomWithId:(unsigned)target.id];
                
                if(!enteringRoom)
                {
                    GotyeStatusCode code = [GotyeOCAPI enterRoom:room];
                    if(code  == GotyeStatusCodeWaitingCallback)
                    {
                        enteringRoom = YES;
                        [GotyeUIUtil showHUD:@"进入聊天室"];
                    }
                    else if(code == GotyeStatusCodeOK)
                    {
                        if(self.navigationController.topViewController == self)
                        {
                            GotyeChatViewController*viewController = [[GotyeChatViewController alloc] initWithTarget:room];
                            [self.navigationController pushViewController:viewController animated:YES];
                        }
                    }
                }
            }
                break;
                
            default:
                break;
        }
        
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark * GotyeContextMenuCell data source

- (NSUInteger)numberOfButtonsInContextMenuCell:(GotyeContextMenuCell *)cell
{
    return 1;
}

- (UIButton *)contextMenuCell:(GotyeContextMenuCell *)cell buttonAtIndex:(NSUInteger)index
{
    GotyeMessageCell *msgCell = [cell isKindOfClass:[GotyeMessageCell class]] ? (GotyeMessageCell *)cell : nil;
    switch (index) {
        case 0: return msgCell.buttonDelete;
        default: return nil;
    }
}

- (GotyeContextMenuCellButtonVerticalAlignmentMode)contextMenuCell:(GotyeContextMenuCell *)cell alignmentForButtonAtIndex:(NSUInteger)index
{
    return GotyeContextMenuCellButtonVerticalAlignmentModeCenter;
}

#pragma mark * GotyeContextMenuCell delegate

- (void)contextMenuCell:(GotyeContextMenuCell *)cell buttonTappedAtIndex:(NSUInteger)index
{
    switch (index) {
        case 0:
        {
            if( notifyList.count > 0)
            {
                NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                GotyeOCChatTarget* target = sessionList[indexPath.row-1];
                //            [GotyeOCAPI deleteSession:target alsoRemoveMessages: YES];
                [GotyeOCAPI deleteSession:target alsoRemoveMessages: NO];
                
                notifyList = [GotyeOCAPI getNotifyList];
                sessionList = [GotyeOCAPI getSessionList];
                
                [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
                
                [self setTabBarItemIcon];
            }else {
                NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                GotyeOCChatTarget* target = sessionList[indexPath.row];
                //            [GotyeOCAPI deleteSession:target alsoRemoveMessages: YES];
                [GotyeOCAPI deleteSession:target alsoRemoveMessages: NO];
                
                notifyList = [GotyeOCAPI getNotifyList];
                sessionList = [GotyeOCAPI getSessionList];
                
                [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
                
                [self setTabBarItemIcon];
            }
            
        }
            break;
    }
}


@end

@implementation GotyeMessageCell

@end
