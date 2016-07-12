//
//  GotyeChatRoomSettingController.m
//  GotyeIM
//
//  Created by Peter on 14-10-24.
//  Copyright (c) 2014年 Gotye. All rights reserved.
//

#import "GotyeChatRoomSettingController.h"

#import "GotyeUIUtil.h"
#import "GotyeSettingManager.h"
#import "GotyeOCAPI.h"

#import "GotyeUserInfoController.h"

#define IconSize            50
#define IconGap             10
#define IconXOffset         15
#define IconNameHeight      10

@interface GotyeChatRoomSettingController () <GotyeOCDelegate>

@end

@implementation GotyeChatRoomSettingController

- (id)initWithTarget:(GotyeOCRoom*)target
{
    self = [self init];
    if(self)
    {
        roomTarget = target;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    headListView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, 70)];
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
//                                              initWithImage:[UIImage imageNamed:@"nav_button_add"]
//                                              style:UIBarButtonItemStylePlain
//                                              target:self
//                                              action:@selector(signClick)];
    UIBarButtonItem * rightButton = [[UIBarButtonItem alloc]
                                     initWithTitle:@"刷新"
                                     style:UIBarButtonItemStyleBordered
                                     target:self
                                     action:@selector(signClick)];
    rightButton.tintColor=[UIColor whiteColor];
    self.navigationItem.rightBarButtonItem = rightButton;
    
    [GotyeOCAPI reqRoomMemberList:roomTarget pageIndex: 0];
    
    roomSetting = [[GotyeSettingManager defaultManager] getSetting:GotyeChatTargetTypeRoom targetID:[NSString stringWithFormat:@"%lld", roomTarget.id]];
}

- (void)signClick
{
    [GotyeOCAPI getRoomDetail:roomTarget forceRequest:YES];
}

-(void) onGetRoomDetail:(GotyeStatusCode)code room:(GotyeOCRoom*)room
{
    if (code == GotyeStatusCodeOK) {
        if(room.id == roomTarget.id)
        {
            roomTarget = room;
            [GotyeOCAPI downloadMedia:room.icon];
            [GotyeOCAPI reqRoomMemberList:roomTarget pageIndex:0];
        }
        [GotyeOCAPI GetRoomsMemberCount:room];
        UIAlertView *al = [[UIAlertView alloc] initWithTitle:nil message:@"获取详情成功" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
        [al show];
        [self performSelector:@selector(dismissAlert:) withObject:al afterDelay:1.0];
    }
}


-(void) onGetRoomsMemberCount:(GotyeStatusCode)code count:(int)count
{
    NSLog(@"\n%d\n",count);
    roomTarget.onlineNumber = count;
    [self.tableView reloadData];
}
- (void)dismissAlert:(UIAlertView *)alert
{
    if (alert) {
        [alert dismissWithClickedButtonIndex:[alert cancelButtonIndex] animated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [GotyeOCAPI addListener:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [GotyeOCAPI removeListener:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)swichChanged:(UISwitch*)sw
{
    UITableViewCell *cell = (UITableViewCell *)sw.superview.superview;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
//    if(indexPath.section == RoomSettingSectionNickname)
    {
        roomSetting[Setting_key_NickName] = [NSNumber numberWithBool:sw.isOn];
        [self swichNickName];
    }
//    else if(indexPath.section == RoomSettingSectionMessage && indexPath.row == 0)
//        roomSetting[Setting_key_Stick] = [NSNumber numberWithBool:sw.isOn];
//    else if(indexPath.section == RoomSettingSectionMessage && indexPath.row == 1)
//        roomSetting[Setting_key_NoDisturb] = [NSNumber numberWithBool:sw.isOn];
    
    [[GotyeSettingManager defaultManager] saveSetting:roomSetting targetType:GotyeChatTargetTypeRoom targetID:[NSString stringWithFormat:@"%lld", roomTarget.id]];
}

- (void)userClick:(UIButton*)sender
{
    GotyeUserInfoController *viewController = [[GotyeUserInfoController alloc] initWithTarget:roomUserlist[sender.tag-1] groupID:0];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)resetHeadIcon:(NSInteger)headIconIndex
{
    UIButton *button = (UIButton*)[headListView viewWithTag:headIconIndex + 1];
    GotyeOCUser* user = roomUserlist[headIconIndex];
    UIImage *headImage= [GotyeUIUtil getHeadImage:user.icon.path defaultIcon:@"head_icon_user"];
    
    UIImageView *buttonIcon = (UIImageView *)button.subviews[button.subviews.count - 1];
    buttonIcon.image = headImage;
}

- (void)swichNickName
{
    BOOL showNickName = [roomSetting[Setting_key_NickName] boolValue];
    NSInteger IconRow = (roomUserlist.count + 1 + 4) / 5;
    for(int i = 0; i<roomUserlist.count; i++)
    {
        GotyeOCUser* user = roomUserlist[i];
        UIButton *button = (UIButton*)[headListView viewWithTag:i + 1];
        
        NSInteger row = i / 5;
        NSInteger col = i % 5;
        
        button.frame = CGRectMake(IconXOffset + (IconSize + IconGap) * col, IconGap + (IconSize + IconGap + (showNickName ? IconNameHeight : 0)) * row, IconSize, IconSize + IconNameHeight);
        
        [button setTitle:(showNickName ? user.name: @"") forState:UIControlStateNormal];
    }
    headListView.frame = CGRectMake(0, 0, ScreenWidth, IconGap + (IconSize + IconGap + (showNickName ? IconNameHeight : 0)) * IconRow);
    
    [self.tableView reloadData];
}

#pragma mark - Gotye UI delegates

- (void)onGetRoomMemberList:(GotyeStatusCode)code room:(GotyeOCRoom*)room pageIndex:(unsigned int)pageIndex curPageMemberList:(NSArray*)curPageMemberList allMemberList:(NSArray*)allMemberList
{
    for (UIView *view in [headListView subviews]) {
        [view removeFromSuperview];
    }
    
    roomUserlist = allMemberList;
    
    BOOL showNickName = [roomSetting[Setting_key_NickName] boolValue];
    NSInteger IconRow = (roomUserlist.count + 4) / 5;
    headListView.frame = CGRectMake(0, 0, ScreenWidth, IconGap + (IconSize + IconGap + (showNickName ? IconNameHeight : 0)) * IconRow);
    
    for(int i = 0; i<roomUserlist.count; i++)
    {
        GotyeOCUser* user = roomUserlist[i];
        
        NSInteger row = i / 5;
        NSInteger col = i % 5;
        
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(IconXOffset + (IconSize + IconGap) * col, IconGap + (IconSize + IconGap) * row, IconSize, IconSize + IconNameHeight)];
        button.tag = i + 1;
        [button addTarget:self action:@selector(userClick:) forControlEvents:UIControlEventTouchUpInside];
        
        button.titleEdgeInsets = UIEdgeInsetsMake(IconSize, 0, 0, 0);
        [button.titleLabel setFont:[UIFont systemFontOfSize:11]];
        [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        
        NSString *displayName = [roomSetting[Setting_key_NickName] boolValue] ? user.name: @"";
        [button setTitle:displayName forState:UIControlStateNormal];
        
        UIImageView *buttonIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, IconSize, IconSize)];
        [button addSubview:buttonIcon];
        
        [headListView addSubview:button];
        
        [GotyeOCAPI downloadMedia:user.icon];
        
        [self resetHeadIcon:i];
    }
    
    [self.tableView reloadData];
}

- (void)onDownloadMedia:(GotyeStatusCode)code media:(GotyeOCMedia*)media
{
    if(code == GotyeStatusCodeOK)
    {
        for(int i = 0; i<roomUserlist.count; i++)
        {
            GotyeOCUser* user = roomUserlist[i];
            if([user.icon.path isEqualToString:media.path])
            {
                [self resetHeadIcon:i];
                break;
            }
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return RoomSettingSectionMaxCount;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if(section == 0)
        return 0;
    
    return 21;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == RoomSettingSectionMember)
        return headListView.frame.size.height;

    return 60;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
//    if(section == RoomSettingSectionMessage)
//        return 2;
    if (section == 1) {
        return 3;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *SettingCellIdentifier = @"SettingCellIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SettingCellIdentifier];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] init];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    for (UIView *view in [cell.contentView subviews]) {
        [view removeFromSuperview];
    }
    
    NSString *titleStr;
    
    switch (indexPath.section) {
        case RoomSettingSectionMember:
            [cell.contentView addSubview:headListView];
            break;

        case RoomSettingSectionNickname:
        {
            if (indexPath.row == 0) {
                
                titleStr = @"显示用户昵称";
                UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectMake(ScreenWidth - 20 - 49, 10, 49, 31)];
                
                switchView.onTintColor = Common_Color_Def_Gray;
                switchView.thumbTintColor = Common_Color_Def_Nav;
                
                switchView.on = [roomSetting[Setting_key_NickName] boolValue];
                [switchView addTarget:self action:@selector(swichChanged:) forControlEvents:UIControlEventValueChanged];
                cell.textLabel.text = titleStr;
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                [cell addSubview:switchView];
            }else if (indexPath.row == 1) {
                titleStr = @"在线/总数";
                UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(20, 10, cell.frame.size.width - 20*2, 40)];
                label.text = [NSString stringWithFormat:@"%lu/%d",(unsigned long)roomUserlist.count/*roomTarget.onlineNumber*/,roomTarget.capacity];
                label.font = [UIFont systemFontOfSize:15];
                label.textColor = [UIColor blackColor];
                label.textAlignment = NSTextAlignmentRight;
                [cell addSubview:label];
//                UIButton *signBtn = [[UIButton alloc] initWithFrame:CGRectMake(50, 10, cell.frame.size.width - 50*2, 40)];
//                signBtn.backgroundColor = Common_Color_Def_Nav;
//                [signBtn setTitle:@"获取详情" forState:UIControlStateNormal];
//                [signBtn addTarget:self action:@selector(signClick) forControlEvents:UIControlEventTouchUpInside];
//                signBtn.layer.borderWidth = 0;
//                signBtn.layer.cornerRadius = 5.0;
//                signBtn.layer.masksToBounds = YES;
//                [signBtn setAdjustsImageWhenHighlighted:NO];
//                [signBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//                signBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16.f];
//                signBtn.layer.borderColor = [UIColor clearColor].CGColor;
//                [cell addSubview:signBtn];
            }else {
//                UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(ScreenWidth - 20 - 49, 10, cell.frame.size.width - 20*2, 40)];
//                label.text = [NSString stringWithFormat:@"%d/%d",roomTarget.onlineNumber,roomTarget.capacity];
//                label.font = [UIFont systemFontOfSize:15];
//                label.textColor = [UIColor blackColor];
//                label.textAlignment = NSTextAlignmentCenter;
//                [cell addSubview:label];
            }
        }
            
            break;
            
//        case RoomSettingSectionMessage:
//        {
//            UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectMake(300 - 49, 10, 49, 31)];
//            
//            switchView.onTintColor = Common_Color_Def_Gray;
//            switchView.thumbTintColor = Common_Color_Def_Nav;
//            if (indexPath.row == 0)
//            {
//                titleStr = @"聊天置顶";
//                switchView.on = [roomSetting[Setting_key_Stick] boolValue];
//            }
//            else
//            {
//                titleStr = @"群消息免打扰";
//                switchView.on = [roomSetting[Setting_key_NoDisturb] boolValue];
//            }
//            [switchView addTarget:self action:@selector(swichChanged:) forControlEvents:UIControlEventValueChanged];
//            
//            [cell addSubview:switchView];
//        }
//            break;
            
//        case 2:
//            titleStr = @"举报群";
//            break;
            
        default:
            break;
    }
    
    cell.textLabel.text = titleStr;
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    
    return cell;
}

@end
