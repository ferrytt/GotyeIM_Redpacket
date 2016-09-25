//
//  GotyeChatViewController.m
//  GotyeIM
//
//  Created by Peter on 14-10-16.
//  Copyright (c) 2014年 Gotye. All rights reserved.
//

#import "GotyeChatViewController.h"

#import "GotyeUIUtil.h"

#import "GotyeChatBubbleView.h"

#import "GotyeLoadingView.h"
#import "GotyeOCAPI.h"
#import "GotyeSettingManager.h"

#import "GotyeChatRoomSettingController.h"
#import "GotyeGroupSettingController.h"
#import "GotyeRealTimeVoiceController.h"
#import "GotyeUserInfoController.h"

#import "GotyeChatTableViewCell.h"

#define BD_API_KEY @"oKUHg75KeH787zPesCSEAGPw"
#define BD_SECRET_KEY @"dIR5nZGZreIUZpfnMRmVDBbBDIGtZlLK"

static GotyeChatViewController *chatViewRetainForBDVR = nil;

@interface GotyeChatViewController () <

    UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate,
    UINavigationControllerDelegate> {
  GotyeOCChatTarget *chatTarget;

  NSString *talkingUserID;

  NSInteger playingRow;

  CGFloat keyboardHeight;
  CGFloat chatViewOriginY;
  CGFloat chatViewOffset;

  UIButton *largeImageView;

  NSArray *messageList;

  GotyeLoadingView *loadingView;
  BOOL haveMoreData;
  NSString *tempImagePath;

  GotyeOCMessage *decodingMessage;
  // BDVRRawDataRecognizer *rawDataRecognizer;

  NSInteger _indexRow;

  BOOL hasscrollView;
}

@end

@implementation GotyeChatViewController

@synthesize chatView, inputView, buttonVoice, buttonWrite, realtimeStartView,
    labelRealTimeStart, textInput, buttonRealTime, buttonSpeak, speakingView;

- (id)initWithTarget:(GotyeOCChatTarget *)target {
  self = [self init];
  if (self) {
    chatTarget = target;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Do any additional setup after loading the view from its nib.
  switch (chatTarget.type) {
  case GotyeChatTargetTypeUser: {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage imageNamed:@"nav_button_user"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(targetUserClick:)];

    GotyeOCUser *user = [GotyeOCAPI getUserDetail:chatTarget forceRequest:NO];
    self.navigationItem.title = user.name;
  } break;

  case GotyeChatTargetTypeGroup: {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage imageNamed:@"nav_button_user"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(groupSettingClick:)];

    GotyeOCGroup *group =
        [GotyeOCAPI getGroupDetail:chatTarget forceRequest:NO];
    self.navigationItem.title = group.name;
  } break;

  case GotyeChatTargetTypeRoom: {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage imageNamed:@"nav_button_user"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(roomSettingClick:)];

    GotyeOCRoom *room = [GotyeOCAPI getRoomDetail:chatTarget forceRequest:NO];
    self.navigationItem.title = room.name;
  } break;
  }

  messageList =
      [GotyeOCAPI getMessageList:chatTarget
                            more:chatTarget.type == GotyeChatTargetTypeRoom];

  loadingView = [[GotyeLoadingView alloc] init];
  loadingView.hidden = YES;
  haveMoreData = YES;

  buttonSpeak.exclusiveTouch = YES;
  buttonSpeak.multipleTouchEnabled = NO;

  speakingView.layer.cornerRadius = 20;
  speakingView.layer.masksToBounds = YES;
  speakingView.hidden = YES;

  hasscrollView = YES;
}

- (void)viewDidLayoutSubviews {
  chatViewOriginY = chatView.frame.origin.y;
}

- (void)reloadHistorys:(BOOL)scrollToEnd {
  playingRow = -1;
  messageList = [GotyeOCAPI getMessageList:chatTarget more:NO];

  [self.tableView reloadData];

  if (messageList.count > 0 && scrollToEnd)
    [self.tableView
        scrollToRowAtIndexPath:[NSIndexPath
                                   indexPathForRow:messageList.count - 1
                                         inSection:0]
              atScrollPosition:UITableViewScrollPositionBottom
                      animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
  [self.view addSubview:chatView];
  if (self.isMovingToParentViewController) {
    chatView.frame =
        CGRectMake(0, self.view.frame.size.height - 50, ScreenWidth, 150);
    self.tableView.frame =
        CGRectMake(0, 0, ScreenWidth, chatView.frame.origin.y);
    //        UIView *footView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
    //        ScreenWidth, 50)];
    //        self.tableView.tableFooterView = footView;
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(exitChatProcesses)
               name:popToRootViewControllerNotification
             object:nil];
  }

  [GotyeOCAPI addListener:self];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(keyboardWillShown:)
             name:UIKeyboardWillShowNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(keyboardWillHidden:)
             name:UIKeyboardWillHideNotification
           object:nil];

  [GotyeOCAPI activeSession:chatTarget];

  [self reloadHistorys:self.isMovingToParentViewController];
}

- (void)viewWillDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:UIKeyboardWillShowNotification
              object:nil];
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:UIKeyboardWillHideNotification
              object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
  if (self.isMovingFromParentViewController) {
    [self exitChatProcesses];
  }
}

- (void)exitChatProcesses {
  [GotyeOCAPI stopPlay];

  [GotyeOCAPI removeListener:self];

  [GotyeOCAPI deactiveSession:chatTarget];
  if (chatTarget.type == GotyeChatTargetTypeRoom) {
    GotyeOCRoom *room = [GotyeOCRoom roomWithId:chatTarget.id];
    [GotyeOCAPI leaveRoom:room];
  }

  [GotyeOCAPI stopTalk];

  // rawDataRecognizer.delegate = nil;

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWillShown:(NSNotification *)notify {
  [self moveTextViewForKeyBoard:notify up:YES];
}

- (void)keyboardWillHidden:(NSNotification *)notify {
  [self moveTextViewForKeyBoard:notify up:NO];

  keyboardHeight = 0;
}

- (void)moveTextViewForKeyBoard:(NSNotification *)notify up:(BOOL)up {
  NSDictionary *userInfo = [notify userInfo];

  // Get animation info from userInfo
  NSTimeInterval animationDuration;
  UIViewAnimationCurve animationCurve;

  CGRect keyboardEndFrame;

  [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey]
      getValue:&animationCurve];
  [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey]
      getValue:&animationDuration];

  [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey]
      getValue:&keyboardEndFrame];

  keyboardHeight = keyboardEndFrame.size.height;

  if (animationDuration > 0) {
    // Animate up or down
    [UIView beginAnimations:@"contentMove" context:nil];
    [UIView setAnimationDuration:animationDuration];
    [UIView setAnimationCurve:animationCurve];
    [UIView setAnimationBeginsFromCurrentState:YES];
  }

  //    CGRect newFrame = chatView.frame;

  if (!up)
    //        newFrame.origin.y = chatViewOriginY;
    chatViewOffset = 0;
  else {
    //        newFrame.origin.y = self.view.frame.size.height - keyboardHeight -
    //        50;
    chatViewOffset = -keyboardHeight;
  }
  chatView.transform = CGAffineTransformMakeTranslation(0, chatViewOffset);
  //    chatView.frame = newFrame;

  if (animationDuration > 0) {
    [UIView commitAnimations];
  }
}
- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)sendClick:(UITextField *)sender {
  [sender resignFirstResponder];

  if (sender.text.length <= 0)
    return;

  GotyeOCMessage *msg =
      [GotyeOCMessage createTextMessage:chatTarget text:sender.text];
  [GotyeOCAPI sendMessage:msg];

  sender.text = @"";

  [self reloadHistorys:YES];
}

- (IBAction)voiceButtonClick:(id)sender {

  if ([[AVAudioSession sharedInstance]
          respondsToSelector:@selector(requestRecordPermission:)]) {
    [[AVAudioSession sharedInstance]
        performSelector:@selector(requestRecordPermission:)
             withObject:^(BOOL granted) {
               if (granted) {
                 [UIView beginAnimations:nil context:NULL];
                 [UIView setAnimationDuration:0.2];

                 buttonWrite.alpha = 1;
                 buttonVoice.alpha = 0;
                 inputView.frame =
                     CGRectMake(inputView.frame.origin.x, -50, 320, 100);

                 [UIView commitAnimations];

                 [textInput resignFirstResponder];

               } else {
                 NSDictionary *infoDictionary =
                     [[NSBundle mainBundle] infoDictionary];
                 CFShow((__bridge CFTypeRef)(infoDictionary));
                 NSString *app_Name =
                     [infoDictionary objectForKey:@"CFBundleDisplayName"];

                 dispatch_async(dispatch_get_main_queue(), ^{
                   [[[UIAlertView alloc]
                           initWithTitle:@""
                                 message:[NSString
                                             stringWithFormat:@"%@需要访问您的"
                                                              @"麦克风。\n请启"
                                                              @"用麦克风-设置/"
                                                              @"隐私/麦克风",
                                                              app_Name]
                                delegate:nil
                       cancelButtonTitle:@"确定"
                       otherButtonTitles:nil] show];
                 });
               }
             }];
  }

  //    [UIView beginAnimations:nil context:NULL];
  //    [UIView setAnimationDuration:0.2];
  //
  //    buttonWrite.alpha = 1;
  //    buttonVoice.alpha = 0;
  //    inputView.frame = CGRectMake(inputView.frame.origin.x, -50, ScreenWidth,
  //    100);
  //
  //    [UIView commitAnimations];
  //
  //    [textInput resignFirstResponder];
}

- (IBAction)writeButtonClick:(id)sender {
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationDuration:0.2];

  buttonWrite.alpha = 0;
  buttonVoice.alpha = 1;
  inputView.frame = CGRectMake(inputView.frame.origin.x, 0, ScreenWidth, 100);

  [UIView commitAnimations];
}

- (IBAction)addButtonClick:(id)sender {
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationDuration:0.2];

  //    CGRect frame = chatView.frame;
  //
  //    if(frame.origin.y < self.view.frame.size.height - 50)
  //        frame.origin.y = self.view.frame.size.height - 50;
  //    else
  //        frame.origin.y = self.view.frame.size.height - frame.size.height;
  //
  //    chatView.frame =frame;
  //    self.tableView.frame = CGRectMake(0, 0, ScreenWidth,
  //    chatView.frame.origin.y);

  if (chatViewOffset < 0)
    chatViewOffset = 0;
  else
    chatViewOffset = -100;

  chatView.transform = CGAffineTransformMakeTranslation(0, chatViewOffset);

  [UIView commitAnimations];

  buttonRealTime.hidden = ![GotyeOCAPI supportRealtime:chatTarget];

  [textInput resignFirstResponder];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
  UIImage *image = info[UIImagePickerControllerOriginalImage];
  NSData *jpgTempImage =
      [GotyeUIUtil ConpressImageToJPEGData:image maxSize:ImageFileSizeMax];
  tempImagePath = [[GotyeSettingManager defaultManager]
                       .settingDirectory stringByAppendingString:@"temp.jpg"];
  [jpgTempImage writeToFile:tempImagePath atomically:YES];

  [picker dismissViewControllerAnimated:YES completion:nil];

  GotyeOCMessage *msg =
      [GotyeOCMessage createImageMessage:chatTarget imagePath:tempImagePath];
  [GotyeOCAPI sendMessage:msg];
  [self reloadHistorys:YES];
}

- (IBAction)albumClick:(id)sender {
  UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];

  imagePicker.delegate = self;

  imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  imagePicker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  imagePicker.allowsEditing = YES;

  [self presentViewController:imagePicker animated:YES completion:nil];
}

- (IBAction)cameraButtonClick:(id)sender {
  if ([UIImagePickerController
          isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    buttonWrite.alpha = 0; //解决在显示“按住说话”时拍照返回时界面显示bug
    buttonVoice.alpha = 1;

    UIImagePickerController *imagePicker =
        [[UIImagePickerController alloc] init];

    imagePicker.delegate = self;

    imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePicker.videoQuality = UIImagePickerControllerQualityTypeLow;
    imagePicker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    imagePicker.allowsEditing = YES;
    [self presentViewController:imagePicker animated:YES completion:nil];
  }
}

- (IBAction)realtimeClick:(id)sender {
  if (chatTarget.type == GotyeChatTargetTypeRoom &&
      [GotyeOCAPI supportRealtime:chatTarget]) {
    if ([[AVAudioSession sharedInstance]
            respondsToSelector:@selector(requestRecordPermission:)]) {
      [[AVAudioSession sharedInstance]
          performSelector:@selector(requestRecordPermission:)
               withObject:^(BOOL granted) {
                 if (granted) {
                   GotyeRealTimeVoiceController *viewController =
                       [[GotyeRealTimeVoiceController alloc]
                           initWithRoomID:(unsigned)chatTarget.id
                                talkingID:talkingUserID];
                   [self.navigationController pushViewController:viewController
                                                        animated:YES];
                 } else {
                   NSDictionary *infoDictionary =
                       [[NSBundle mainBundle] infoDictionary];
                   CFShow((__bridge CFTypeRef)(infoDictionary));
                   NSString *appName =
                       [infoDictionary objectForKey:@"CFBundleDisplayName"];
                   dispatch_async(dispatch_get_main_queue(), ^{
                     [[[UIAlertView alloc]
                             initWithTitle:@""
                                   message:[NSString
                                               stringWithFormat:@"%@需要访问您"
                                                                @"的麦克风。\n"
                                                                @"请启用麦克风"
                                                                @"-设置/隐私/"
                                                                @"麦克风",
                                                                appName]
                                  delegate:nil
                         cancelButtonTitle:@"确定"
                         otherButtonTitles:nil] show];
                   });
                 }
               }];
    }
    //        GotyeRealTimeVoiceController *viewController =
    //        [[GotyeRealTimeVoiceController alloc]
    //        initWithRoomID:(unsigned)chatTarget.id talkingID:talkingUserID];
    //        [self.navigationController pushViewController:viewController
    //        animated:YES];
  }
}

- (IBAction)speakButtonDown:(id)sender {
  if (talkingUserID == nil)
    [GotyeOCAPI stopPlay];

  if ([GotyeOCAPI startTalk:chatTarget
                       mode:GotyeWhineModeDefault
                   realtime:NO
                maxDuration:60 * 1000] == GotyeStatusCodeWaitingCallback) {
    speakingView.hidden = NO;
  }

  //    self.navigationController.view.userInteractionEnabled = NO;
}

- (IBAction)speakButtonUp:(id)sender {
  [GotyeOCAPI stopTalk];

  [self reloadHistorys:YES];

  speakingView.hidden = YES;

  //    self.navigationController.view.userInteractionEnabled = YES;
}

- (void)messageClick:(UIButton *)button {
  NSIndexPath *indexPath = [NSIndexPath indexPathForRow:button.tag inSection:0];

  GotyeOCMessage *message = messageList[indexPath.row];

  //    [GotyeOCAPI report: 1 content:@"涉及暴力" message: message];

  switch (message.type) {
  case GotyeMessageTypeAudio: {
    if (talkingUserID != nil) {
      UIAlertView *alert =
          [[UIAlertView alloc] initWithTitle:@""
                                     message:@"正在实时语音中"
                                    delegate:nil
                           cancelButtonTitle:@"确定"
                           otherButtonTitles:nil, nil];
      [alert show];
      return;

    } else if (playingRow == button.tag) {
      [GotyeOCAPI stopPlay];
      UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
      UIImageView *voiceImage =
          (UIImageView *)[cell viewWithTag:bubblePlayImageTag];
      [voiceImage stopAnimating];
      playingRow = -1;
    } else {
      if (message.media.status != GotyeMediaStatusDownloading &&
          ![[NSFileManager defaultManager]
              fileExistsAtPath:message.media.path]) {
        [GotyeOCAPI downloadMediaInMessage:message];
        [self reloadHistorys:NO];
        break;
      }

      status s = [GotyeOCAPI playMessage:message];
      if (s == GotyeStatusCodeOK) {
        [self onPlayStop];
        UITableViewCell *cell =
            [self.tableView cellForRowAtIndexPath:indexPath];
        UIImageView *voiceImage =
            (UIImageView *)[cell viewWithTag:bubblePlayImageTag];
        [voiceImage startAnimating];
        playingRow = indexPath.row;
      }
    }
  } break;

  case GotyeMessageTypeImage: {
    if (largeImageView != nil)
      break;

    if (message.media.status != GotyeMediaStatusDownloading &&
        ![[NSFileManager defaultManager]
            fileExistsAtPath:message.media.pathEx]) {
      [GotyeOCAPI downloadMediaInMessage:message];
      [self reloadHistorys:NO];
      break;
    }

    UIImage *image = [UIImage imageWithContentsOfFile:message.media.pathEx];

    if (image != nil) {
      UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
      UIImageView *thumbImageView =
          (UIImageView *)[cell viewWithTag:bubbleThumbImageTag];
      CGPoint transCenter =
          [thumbImageView.superview convertPoint:thumbImageView.center
                                          toView:self.view];

      largeImageView = [[UIButton alloc]
          initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,
                                   self.view.frame.size.height)];
      [largeImageView addTarget:self
                         action:@selector(largeImageClose:)
               forControlEvents:UIControlEventTouchUpInside];

      CGSize imgSize = CGSizeMake(image.size.width / 2, image.size.height / 2);
      if (imgSize.width > self.view.frame.size.width) {
        imgSize.height =
            self.view.frame.size.width * imgSize.height / imgSize.width;
        imgSize.width = self.view.frame.size.width;
      }
      if (imgSize.height > self.view.frame.size.height) {
        imgSize.width =
            self.view.frame.size.height * imgSize.width / imgSize.height;
        imgSize.height = self.view.frame.size.height;
      }
      image = [GotyeUIUtil
          scaleImage:image
              toSize:CGSizeMake(imgSize.width * 2, imgSize.height * 2)];

      UIImageView *imageView = [[UIImageView alloc]
          initWithFrame:CGRectMake(0, 0, imgSize.width, imgSize.height)];
      //                imageView.contentMode = UIViewContentModeScaleAspectFit;
      imageView.image = image;
      imageView.center = largeImageView.center;

      [largeImageView addSubview:imageView];
      [self.view addSubview:largeImageView];

      CGAffineTransform transform =
          CGAffineTransformMakeTranslation(transCenter.x - imageView.center.x,
                                           transCenter.y - imageView.center.y);
      transform = CGAffineTransformScale(
          transform,
          thumbImageView.frame.size.width / imageView.frame.size.width,
          thumbImageView.frame.size.height / imageView.frame.size.height);

      largeImageView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
      imageView.transform = transform;

      [UIView beginAnimations:nil context:NULL];
      [UIView setAnimationDuration:0.3];

      largeImageView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
      imageView.transform = CGAffineTransformIdentity;

      [UIView commitAnimations];
    }
  } break;

  default:
    break;
  }
}

- (void)largeImageClose:(id)sender {
  [UIView animateWithDuration:0.3
      delay:0
      options:UIViewAnimationOptionCurveLinear
      animations:^{
        largeImageView.alpha = 0;
      }
      completion:^(BOOL finished) {
        if (finished) {
          [largeImageView removeFromSuperview];
          largeImageView = nil;
        }
      }];
}

- (void)groupSettingClick:(id)sender {
  GotyeGroupSettingController *viewController = [
      [GotyeGroupSettingController alloc]
      initWithTarget:[GotyeOCAPI getGroupDetail:chatTarget forceRequest:NO]];
  [GotyeOCAPI stopPlay];
  [self.navigationController pushViewController:viewController animated:YES];
}

- (void)roomSettingClick:(id)sender {
  GotyeChatRoomSettingController *viewController =
      [[GotyeChatRoomSettingController alloc]
          initWithTarget:[GotyeOCAPI getRoomDetail:chatTarget forceRequest:NO]];
  [GotyeOCAPI stopPlay];
  [self.navigationController pushViewController:viewController animated:YES];
}

- (void)targetUserClick:(id)sender {
  GotyeUserInfoController *viewController = [[GotyeUserInfoController alloc]
      initWithTarget:[GotyeOCAPI getUserDetail:chatTarget forceRequest:NO]
             groupID:0];
  [GotyeOCAPI stopPlay];
  [self.navigationController pushViewController:viewController animated:YES];
}

- (void)userClick:(UIButton *)sender {
  GotyeOCMessage *message = messageList[sender.tag];

  GotyeUserInfoController *viewController = [[GotyeUserInfoController alloc]
      initWithTarget:[GotyeOCAPI getUserDetail:message.sender forceRequest:NO]
             groupID:0];
  [GotyeOCAPI stopPlay];
  [self.navigationController pushViewController:viewController animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  if (loadingView.hidden && scrollView.contentOffset.y < -20 && hasscrollView) {

    hasscrollView = NO;

    loadingView.frame = CGRectMake(0, -40, ScreenWidth, 40);
    [scrollView insertSubview:loadingView atIndex:0];
    loadingView.hidden = NO;
    [loadingView showLoading:haveMoreData];

    if (haveMoreData) {
      NSInteger lastCount = messageList.count;
      messageList = [GotyeOCAPI getMessageList:chatTarget more:YES];
      //            messageList = [GotyeOCAPI getMessageList:chatTarget
      //            more:NO];

      if (chatTarget.type != GotyeChatTargetTypeRoom) {
        if (lastCount == messageList.count) {
          haveMoreData = NO;
          hasscrollView = YES;

          [loadingView showLoading:haveMoreData];
        } else {
          CGFloat lastOffsetY = self.tableView.contentOffset.y;
          CGFloat lastContentHeight = self.tableView.contentSize.height;

          loadingView.hidden = YES;
          [self reloadHistorys:NO];
          hasscrollView = YES;

          CGFloat newOffsetY = self.tableView.contentSize.height -
                               lastContentHeight + lastOffsetY;

          [self.tableView
              scrollRectToVisible:CGRectMake(0, newOffsetY, ScreenHeight,
                                             self.tableView.frame.size.height)
                         animated:NO];
        }
      } else {
      }
    }
  }
}

#pragma mark - Gotye UI delegates

- (void)onSendMessage:(GotyeStatusCode)code message:(GotyeOCMessage *)message {

  [self reloadHistorys:YES];

  if (message.type == GotyeMessageTypeImage) {
    [[NSFileManager defaultManager] removeItemAtPath:tempImagePath error:nil];
    tempImagePath = nil;
  }
}

- (void)onReceiveMessage:(GotyeOCMessage *)message
     downloadMediaIfNeed:(bool *)downloadMediaIfNeed {
  [self reloadHistorys:YES];

  *downloadMediaIfNeed = true;
}

- (void)onGetMessageList:(GotyeStatusCode)code
                 msglist:(NSArray *)msgList
     downloadMediaIfNeed:(bool *)downloadMediaIfNeed {

  CGFloat lastOffsetY = self.tableView.contentOffset.y;
  CGFloat lastContentHeight = self.tableView.contentSize.height;

  [self reloadHistorys:NO];

  CGFloat newOffsetY =
      self.tableView.contentSize.height - lastContentHeight + lastOffsetY;

  [self.tableView
      scrollRectToVisible:CGRectMake(0, newOffsetY, ScreenHeight,
                                     self.tableView.frame.size.height)
                 animated:NO];
  *downloadMediaIfNeed = true;

  hasscrollView = YES;

  loadingView.hidden = YES;
  haveMoreData = (msgList.count > 0);
}

- (void)onDownloadMediaInMessage:(GotyeStatusCode)code
                         message:(GotyeOCMessage *)message {
  [self reloadHistorys:NO];
}

- (void)onUserDismissGroup:(GotyeOCGroup *)group user:(GotyeOCUser *)user {
  if (group.id == chatTarget.id &&
      chatTarget.type == GotyeChatTargetTypeGroup) {
    [GotyeOCAPI deleteSession:group alsoRemoveMessages:NO];
    [GotyeUIUtil popToRootViewControllerForNavgaion:self.navigationController
                                           animated:YES];
  }
}

- (void)onUserKickedFromGroup:(GotyeOCGroup *)group
                       kicked:(GotyeOCUser *)kicked
                        actor:(GotyeOCUser *)actor {
  GotyeOCUser *myself = [GotyeOCAPI getLoginUser];
  if ([myself.name isEqualToString:kicked.name]) {

    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:nil
                                   message:@"您已被群主移出该群！"
                                  delegate:nil
                         cancelButtonTitle:nil
                         otherButtonTitles:nil, nil];
    [alert show];
    [self performSelector:@selector(dismissAlert:)
               withObject:alert
               afterDelay:1.0];
    [GotyeOCAPI deleteSession:group alsoRemoveMessages:NO];
  } else {
  }
}

- (void)dismissAlert:(UIAlertView *)alert {
  if (alert) {
    [alert dismissWithClickedButtonIndex:[alert cancelButtonIndex]
                                animated:YES];

    [GotyeUIUtil popToRootViewControllerForNavgaion:self.navigationController
                                           animated:YES];
  }
}

- (void)onPlayStop {
  for (UITableViewCell *cell in self.tableView.visibleCells) {
    UIImageView *voiceImage =
        (UIImageView *)[cell viewWithTag:bubblePlayImageTag];
    [voiceImage stopAnimating];
  }

  playingRow = -1;

  talkingUserID = nil;
  [realtimeStartView removeFromSuperview];
}

- (void)onRealPlayStart:(GotyeStatusCode)code
                speaker:(GotyeOCUser *)speaker
                   room:(GotyeOCRoom *)room {
  talkingUserID = speaker.name;

  labelRealTimeStart.text =
      [NSString stringWithFormat:@"%@发起了实时对讲", talkingUserID];

  [self.view addSubview:realtimeStartView];
  realtimeStartView.hidden = NO;
}

- (void)onStopTalk:(GotyeStatusCode)code
          realtime:(bool)realtime
           message:(GotyeOCMessage *)message
     cancelSending:(bool *)cancelSending {
  if (code == GotyeStatusCodeVoiceTooShort) {
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:@""
                                   message:@"录音时间太短"
                                  delegate:nil
                         cancelButtonTitle:@"确定"
                         otherButtonTitles:nil, nil];
    [alert show];
  }
  speakingView.hidden = YES;

  *cancelSending = YES;
  if (code == GotyeStatusCodeOK) {

    if (message.text && message.text.length > 0) {
      //        const char* cstring = [message.text UTF8String];
      //        [message putExtraData: cstring len: strlen(cstring)];
      message.extraText = message.text;
    }

    [GotyeOCAPI sendMessage:message];
  }
  //*cancelSending = YES;
  //[GotyeOCAPI decodeAudioMessage:message];
}

- (void)onDecodeMessage:(GotyeStatusCode)code
                message:(GotyeOCMessage *)message {
  if (decodingMessage != nil) {
    [GotyeOCAPI sendMessage:message];
    return;
  }

  decodingMessage = message;
  /*
   if(rawDataRecognizer == nil)
   {
   //
   设置开发者信息，必须修改API_KEY和SECRET_KEY为在百度开发者平台申请得到的值，否则示例不能工作
   [[BDVoiceRecognitionClient sharedInstance] setApiKey:BD_API_KEY
   withSecretKey:BD_SECRET_KEY];
   // 设置是否需要语义理解，只在搜索模式有效
   [[BDVoiceRecognitionClient sharedInstance] setConfig:@"nlu" withFlag:YES];

   // 数据识别
   rawDataRecognizer = [[BDVRRawDataRecognizer alloc]
   initRecognizerWithSampleRate:8000 property:EVoiceRecognitionPropertyInput
   delegate:self];
   }

   int status = [rawDataRecognizer startDataRecognition];
   if (status == EVoiceRecognitionStartWorking) {
   //启动发送数据线程
   //    [self sendAudioThread];

   chatViewRetainForBDVR = self;

   [NSThread detachNewThreadSelector:@selector(sendAudioThread) toTarget:self
   withObject:nil];
   }*/
}

//音频流识别按钮响应函数
- (void)sendAudioThread {
  /*
   NSLog(@"sendAudioThread[IN]");

   int hasReadFileSize = 0;
   //从文件中读取音频
   int sizeToRead = 8000 * 0.080 * 16 / 8;
   while (YES) {
   NSFileHandle *fileHandle = [NSFileHandle
   fileHandleForReadingAtPath:decodingMessage.media.pathEx];
   [fileHandle seekToFileOffset:hasReadFileSize];
   NSData* data = [fileHandle readDataOfLength:sizeToRead];
   [fileHandle closeFile];
   hasReadFileSize += [data length];
   if ([data length]>0)
   {
   [rawDataRecognizer sendDataToRecognizer:data];
   }
   else
   {
   [rawDataRecognizer allDataHasSent];
   break;
   }
   }
   */
  NSLog(@"sendAudioThread[OUT]");
}
/*
 - (void)VoiceRecognitionClientWorkStatus:(int) aStatus obj:(id)aObj
 {
 switch (aStatus)
 {
 case EVoiceRecognitionClientWorkStatusFinish:
 {
 NSMutableString *tmpString;
 if ([[BDVoiceRecognitionClient sharedInstance] getRecognitionProperty] !=
 EVoiceRecognitionPropertyInput)
 {
 NSMutableArray *audioResultData = (NSMutableArray *)aObj;
 tmpString = [[NSMutableString alloc] initWithString:@""];

 for (int i=0; i<[audioResultData count]; i++)
 {
 [tmpString appendFormat:@"%@\r\n",[audioResultData objectAtIndex:i]];
 }
 }
 else
 {
 tmpString = [[NSMutableString alloc] initWithString:@""];
 for (NSArray *result in aObj)
 {
 NSDictionary *dic = [result objectAtIndex:0];
 NSString *candidateWord = [[dic allKeys] objectAtIndex:0];
 [tmpString appendString:candidateWord];
 }
 }

 NSDictionary *resultDic = [tmpString objectFromJSONString];
 NSArray *resultArray = [resultDic objectForKey:@"item"];
 NSString *resultString = [resultArray objectAtIndex:0];

 if(resultString != nil && ![resultString isEqualToString:@""])
 {
 const char* str = [resultString cStringUsingEncoding:NSUTF8StringEncoding];
 [decodingMessage putExtraData:(void*)str len:strlen(str)];
 }

 [GotyeOCAPI sendMessage:decodingMessage];
 decodingMessage = nil;

 NSLog(@"识别完成");

 break;
 }
 case EVoiceRecognitionClientWorkStatusFlushData:
 {
 //            NSMutableString *tmpString = [[NSMutableString alloc]
 initWithString:@""];
 //
 //            [tmpString appendFormat:@"%@",[aObj objectAtIndex:0]];
 //
 //            break;
 }
 case EVoiceRecognitionClientWorkStatusReceiveData:
 {
 //            if ([[BDVoiceRecognitionClient sharedInstance]
 getRecognitionProperty] == EVoiceRecognitionPropertyInput)
 //            {
 //                NSString *tmpString = [self composeInputModeResult:aObj];
 //
 //            }

 break;
 }
 case EVoiceRecognitionClientWorkStatusEnd:
 {
 break;
 }
 default:
 {
 break;
 }
 }
 }

 - (void)VoiceRecognitionClientErrorStatus:(int) aStatus
 subStatus:(int)aSubStatus
 {
 [GotyeOCAPI sendMessage:decodingMessage];
 decodingMessage = nil;
 }
 */

- (void)onReport:(GotyeStatusCode)code message:(GotyeOCMessage *)message;
{
  if (code == GotyeStatusCodeOK) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"举报成功"
                                                    message:nil
                                                   delegate:nil
                                          cancelButtonTitle:@"确定"
                                          otherButtonTitles:nil, nil];
    [alert show];
  }
}
#pragma mark - table delegate & data

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
  return messageList.count;
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  GotyeOCMessage *message = messageList[indexPath.row];

  BOOL showDate = NO;
  if (indexPath.row == 0)
    showDate = YES;
  else {
    GotyeOCMessage *lastmessage = messageList[indexPath.row - 1];
    if (message.date - lastmessage.date > 300)
      showDate = YES;
  }


  return [GotyeChatBubbleView getbubbleHeight:message
                                       target:chatTarget
                                     showDate:showDate];

}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *MessageCellIdentifier = @"MessageCellIdentifier";

  GotyeChatTableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:MessageCellIdentifier];
  if (cell == nil) {
    cell = [[GotyeChatTableViewCell alloc] init];
  }

  for (UIView *view in [cell.contentView subviews]) {
    [view removeFromSuperview];
  }

  GotyeOCMessage *message = messageList[indexPath.row];

  BOOL showDate = NO;
  if (indexPath.row == 0)
    showDate = YES;
  else {
    GotyeOCMessage *lastmessage = messageList[indexPath.row - 1];
    if (message.date - lastmessage.date > 300)
      showDate = YES;
  }

  UIView *bubble = [GotyeChatBubbleView BubbleWithMessage:message
                                                   target:chatTarget
                                                 showDate:showDate];

  UIButton *msgButton =
      (UIButton *)[(UIButton *)bubble viewWithTag:bubbleMessageButtonTag];
  msgButton.tag = indexPath.row;
  [msgButton addTarget:self
                action:@selector(messageClick:)
      forControlEvents:UIControlEventTouchUpInside];

  [cell.contentView addSubview:bubble];

  if (playingRow == indexPath.row) {
    UIImageView *voiceImage =
        (UIImageView *)[cell viewWithTag:bubblePlayImageTag];
    [voiceImage startAnimating];
  }

  UIButton *headButton = (UIButton *)[cell viewWithTag:bubbleHeadButtonTag];
  headButton.tag = indexPath.row;
  [headButton addTarget:self
                 action:@selector(userClick:)
       forControlEvents:UIControlEventTouchUpInside];

  cell.backgroundColor = [UIColor clearColor];

  cell.didSelectedCell = ^(id sender) {
    GotyeOCMessage *mess = [[GotyeOCMessage alloc] init];
    mess = messageList[_indexRow];
    [GotyeOCAPI report:0 content:@"fff" message:mess];
  };
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
  if (playingRow == indexPath.row) {

    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(
        DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
      UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
      UIImageView *voiceImage =
          (UIImageView *)[cell viewWithTag:bubblePlayImageTag];
      [voiceImage startAnimating];
    });

  } else {
  }
}

- (BOOL)tableView:(UITableView *)tableView
    shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {

  UIMenuController *menu = [UIMenuController sharedMenuController];
  UIMenuItem *flag =
      [[UIMenuItem alloc] initWithTitle:@"举报" action:@selector(test:)];
  [menu setMenuItems:[NSArray arrayWithObjects:flag, nil]];
  [[UIMenuController sharedMenuController] update];
  _indexRow = indexPath.row;
  return YES;
}
- (BOOL)tableView:(UITableView *)tableView
 canPerformAction:(SEL)action
forRowAtIndexPath:(NSIndexPath *)indexPath
       withSender:(id)sender {
  if (action == @selector(test:)) {
    return YES;
  } else {
    return NO;
  }
}

//- (BOOL)canBecomeFirstResponder
//{
//    return YES;
//}
//- (BOOL)becomeFirstResponder {
//    return YES;
//}
//
- (void)test:(id)sender {
}
//
//-(BOOL)canPerformAction:(SEL)action withSender:(id)sender
//{
//    if(action ==@selector(test:)){
//
//        return YES;
//    }
//    return [super canPerformAction:action withSender:sender];
//}

- (void)tableView:(UITableView *)tableView
    performAction:(SEL)action
forRowAtIndexPath:(NSIndexPath *)indexPath
       withSender:(id)sender {
}
@end
