//
//  AppDelegate.m
//  Frog
//
//  Created by kill on 14/10/24.
//  Copyright (c) 2014年 zengxc. All rights reserved.
//

#import "AppDelegate.h"
#import "ActivityListViewController.h"
#import "InfoViewController.h"
#import "FrogDiscoveryViewController.h"
#import "Frog_GuideViewController.h"
#import <MapKit/MapKit.h>
#import "BaiduMap.h"
#import "UITabBarController+HideTabBar.h"
#import "BoundAccountViewController.h"
#import "LoginViewController.h"
#import "CheckModel.h"
#import "DIVRecordPopView.h"
#import <AlipaySDK/AlipaySDK.h>
#import "AnimationManager.h"
#import "FrogAccelerometerViewController.h"
#import "DataNewMangeger.h"//用于计步管理数据插入，里面的数据用于画折线图
#import "sdkCall.h"//用于注册QQ分享
#import "DateManager.h"
#import "FrogMainMessageViewController.h"
#import "MJLineView.h"

#import "FrogKeyChain.h" //把UUID存到钥匙串
#import <TencentOpenAPI/TencentOAuth.h>//用于QQ分享

#import "FrogAcceleData.h"



#define kCircleOfFriends  @"circleOfFriends.archiver"
#define kPostsOfDivingBars @"divingBar.archiver"
#define kFilePath(FileName) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:FileName]
#define FIFTEENMIN 15*60

@interface AppDelegate ()
@property (nonatomic,strong)MJLineView *lineView;
@property (strong , nonatomic) CMStepCounter* stepCounter;//M7计步器
@property (nonatomic, strong) NSOperationQueue *operationQueue;//用于
@end

static double defaultMileage = 0; //里程
static CLLocationDegrees defaultLatitude = 0; //点
static CLLocationDegrees defaultLongitude = 0;
static NSString *defaultLastTime = @"";
static double defaultConsuming = 0;
static BOOL isHave = NO;
static NSInteger isJudge = 0;
static NSInteger intervalTime;

static FrogMainMessageViewController * frogmeg = nil;
static FrogDiscoveryViewController * frogDis = nil;
//static double LastDistance;

@implementation AppDelegate
{
    BMKMapManager *mapManager; //地图管理器
    NSString *trackViewUrl;
    /************ 计步 **************/
    
    
    AccelerometerFilter *filter;            //加速器
    
    BOOL stepFlag;                          //检测
    
    BOOL isRecord;                          //是否可以累加数据
    
    NSMutableArray *arrtempTimestamp;       //存储未累加时的时间戳中间变量
    
    NSMutableArray *arrcurrentTimestamp;    //存储15分钟内的每步的时间戳
    
    NSMutableArray *arrStepCount;           //存储用来计步的SituationModel（目前设定满20个存储一次）
    
    NSMutableArray *arrForLineView;         //用来画折线图
    
    NSInteger tempPace;                     //未累加时的步数步数中间变量
    
    NSTimer *timerCheck;                    //用于4秒检测线程
    NSTimer *timerCount;
    
    CGFloat lastCommitTime;                 //上传保存数据的时间
    NSInteger first;
    
    /************ 计步 **************/
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
    //initialized    language ...
    [InternationalControl initUserLanguage];[FrogAcceleData shareInstance];
    
    APP.RingNoice = YES;
    if ([AutoCheckVersion isEqualToString:@"YES"]) {
        
        [self checkVersion];
    }
    //写上微信注册的应用id
    //[WXApi registerApp:kWeChatAppKey];
    [WXApi registerApp:kWeChatAppKey withDescription:@"绿青蛙"];
    //新浪微博sdk方法
    [WeiboSDK enableDebugMode:YES];
    [WeiboSDK registerApp:kAppKey];
    
    [self autoLogin];
    if (!_pathArr) {
        _pathArr = [[NSMutableArray alloc]init];
    }
    if (!_pathPointArr) {
        _pathPointArr = [[NSMutableArray alloc]init];
    }
    [DataBaseManager shareGlobleInstance];
    [DataBaseManager createUserAboutTable];
    [DataBaseManager createCommenTable];

    [DataNewMangeger creatData];//打开数据库（用于画折线图）
    [sdkCall getinstance];//注册QQ分享的AppKey
    [DataBaseManager closeDataBase];

    /***** 计步 *****/
    lastCommitTime = [DateManager timestampTransitionOfCurrentFormatter]; //上次跟新的时间
    [DataBaseManager createSituationTable];//创建 tb_Situation
    [self check];//用于检测DataBaseManager的tb_Situation表
    self.stepCount = [DataBaseManager currentPace];
    first =  self.stepCount;
    arrcurrentTimestamp = [NSMutableArray array];
    arrtempTimestamp = [NSMutableArray array];
    arrStepCount = [NSMutableArray array];    //存储用来计步的SituationModel（目前设定满...个存储一次）
    arrForLineView = [NSMutableArray array];    //用来画折线图
//    isRecord = (self.stepCount > 10) ? TRUE: FALSE;
//    NSLog(@"isRecord---->%d",isRecord);
    tempPace = 0;
    
    if([CMStepCounter isStepCountingAvailable]
       &&[UIDevice currentDevice].systemVersion.floatValue > 8.0){
        // 创建CMStepCounter对象
        [self setpCpuntWithM7];//M7处理器开始计步
    }else{
       [self smasherCount];//加速计开始计步
    }
    
    mapManager = [[BMKMapManager alloc]init];
    intervalTime = 120;
    
    BOOL ret = [mapManager start:baiduAppKey  generalDelegate:self];
    if (!ret)
    {
        NSLog(@"manager start failed!");
    }
    
    [[BaiduMap shareLocation]getCityName:^(NSString *cityString) {
        
        if(cityString!=nil && cityString.length>0){
            NSString *city = [cityString substringToIndex:cityString.length - 1];
            
            [[NSUserDefaults standardUserDefaults] setObject:city forKey:LocationCity];
        }
        
    }];
    
    
    [[BaiduMap shareLocation]getLocationCoordinate:^(CLLocationCoordinate2D location){
        if (location.latitude > 0 && location.longitude > 0) {
            self.myCityLocation = location;
            self.myNowLatitude = location.latitude;
            self.myNowLongitude = location.longitude;
        }
        
    } withAddress:^(NSString *cityString){
       
        
    }];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageComeIn:) name:RECIVE_MESSAGE object:nil];
     // 接收掉线通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadMyGroupList) name:kREFRESHMYGROUPLIST object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginConflict) name:LOGIN_CONFLICT object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(re_loginConflict) name:RELOGIN_CONFLICT object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBadge) name:ExitNSNotification object:nil];
    
        if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 8.0) {
            [[UIApplication sharedApplication]registerForRemoteNotifications];
            UIUserNotificationType type=UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
            UIUserNotificationSettings *setting=[UIUserNotificationSettings settingsForTypes:type categories:nil];
            [[UIApplication sharedApplication]registerUserNotificationSettings:setting];
        }else{
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
             (UIRemoteNotificationTypeNewsstandContentAvailability |
              UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge |
              UIRemoteNotificationTypeSound)];
        }

    XMPPManager * xmppmgr=[XMPPManager defaultInstance];
    [xmppmgr.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    
    [self showMainPage];
    // 状态栏文字颜色
    [application setStatusBarHidden:NO];
    [application setStatusBarStyle:UIStatusBarStyleLightContent];

    
    [self changeTabBarStyle];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *isShowedUserGuide = [defs  objectForKey:kIsShowedUserGuide];
    if ([isShowedUserGuide isEqualToString:@"NO"] || isShowedUserGuide == nil)
    {
        
        Frog_GuideViewController *guideVC = [[Frog_GuideViewController alloc] init];
        BaseNavigationViewController *nav = [[BaseNavigationViewController alloc] initWithRootViewController:guideVC];
        guideVC.injoyBlock = ^{
            //用户点击了立即体验
            self.window.rootViewController = _baseTabBar;
        };
        [defs setObject:@"YES" forKey:kIsShowedUserGuide];
        [defs synchronize];
        
        self.window.rootViewController = nav;
        [self.window makeKeyAndVisible];
    }
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    [self uuid];
    
//    [self updateBadge];
    
    
    return YES;
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    
    NSString *token = [NSString stringWithFormat:@"%@",deviceToken];
    NSLog(@"-- token:%@",token);
    
    NSString *tokenStr = [token substringFrom:1 to:token.length-1];
    tokenStr = [tokenStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    /*<presence><x xmlns="vcard-temp:x:update"><photo/></x><c xmlns="http://jabber.org/protocol/caps" hash="sha-1" node="http://code.google.com/p/xmppframework" ver="VyOFcFX6+YNmKssVXSBKGFP0BS4="/></presence>*/
    
    /*<presence xmlns="jabber:client" type="unavailable" from="kai205793@webimqa.byd.com.cn/BydFans" to="five304157@webimqa.byd.com.cn"/>*/
    [[NSUserDefaults standardUserDefaults]setObject:@"1" forKey:kPushStatus];
    [[NSUserDefaults standardUserDefaults]setObject:tokenStr forKey:kPushToken];
    if (![[GlobalCommen CurrentUser] user_name]) {
        return;
    }
    NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
    
    NSXMLElement *eleX = [NSXMLElement elementWithName:@"x" xmlns:@"vcard-temp:x:update"];
    NSXMLElement *elePhoto = [NSXMLElement elementWithName:@"photo"];
    [eleX addChild:elePhoto];
    
    NSXMLElement *eleC = [NSXMLElement elementWithName:@"c" xmlns:@"http://jabber.org/protocol/caps"];
    [eleC addAttributeWithName:@"hash" stringValue:@"sha-1"];
    [eleC addAttributeWithName:@"node" stringValue:@"http://code.google.com/p/xmppframework"];
    [eleC addAttributeWithName:@"ver" stringValue:@"VyOFcFX6+YNmKssVXSBKGFP0BS4="];
    
    NSXMLElement *eleStatus = [NSXMLElement elementWithName:@"status" stringValue:tokenStr];
    
    [presence addChild:eleX];
    [presence addChild:eleStatus];
    [presence addChild:eleC];
    
    
    
    [[[XMPPManager defaultInstance] xmppStream] sendElement:presence];
    
    NSLog(@"token:%@CCC...tokenStr:%@...presence:%@",token,tokenStr,presence);
    
    if ([token length] == 0) {
        return;
    }
    
}
- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error{
    [[NSUserDefaults standardUserDefaults]setObject:@"0" forKey:kPushStatus];
    NSLog(@"获得令牌失败: %@", error);
    
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    
}
/**
 *  新浪微博sdk方法 （判断发送状态）
 */
- (void)didReceiveWeiboResponse:(WBBaseResponse *)response{
    NSLog(@"response.statusCode---->%ld",response.statusCode);
    if ([response isKindOfClass:WBSendMessageToWeiboResponse.class])
    {
        NSString *title = [[NSString alloc]init];
        if (response.statusCode == 0) {
            title = NSLocalizedString(@"分享成功", nil);
        }else if(response.statusCode == -1){
            title = NSLocalizedString(@"取消分享", nil);
        }else if(response.statusCode == -2){
            title = NSLocalizedString(@"分享失败", nil);
        }
        
//        NSString *message = [NSString stringWithFormat:@"%@: %d\n%@: %@\n%@: %@", NSLocalizedString(@"响应状态", nil), (int)response.statusCode, NSLocalizedString(@"响应UserInfo数据", nil), response.userInfo, NSLocalizedString(@"原请求UserInfo数据", nil),response.requestUserInfo];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"确定", nil)
                                              otherButtonTitles:nil];
        WBSendMessageToWeiboResponse* sendMessageToWeiboResponse = (WBSendMessageToWeiboResponse*)response;
        NSString* accessToken = [sendMessageToWeiboResponse.authResponse accessToken];
        if (accessToken)
        {
            self.wbtoken = accessToken;
        }
        NSString* userID = [sendMessageToWeiboResponse.authResponse userID];
        if (userID) {
            self.wbCurrentUserID = userID;
        }
        [alert show];
    }
    
}

//支付回调
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    //    if ([[url host] isEqualToString:@"frog://platformapi/startApp"]) {

    if ([[NSString stringWithFormat:@"%@",url] hasPrefix:@"tencent1103452376"]) {
    //QQsdk
        return [TencentOAuth HandleOpenURL:url];
    }else if([[NSString stringWithFormat:@"%@",url] hasPrefix:@"wxc7f090dc5d74120e"]){
        //微信sdk
        return [WXApi handleOpenURL:url delegate:self];
    }
    
    //支付宝64位代码
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic){
            
            if ([[resultDic objectForKey:@"resultStatus"] integerValue] == 9000){
                [[NSNotificationCenter defaultCenter] postNotificationName:PaySuccessNotification object:nil];
                
            }
            else
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:PayFailedNotification object:nil];
            }
            
        }];
        
        
        return YES;
    }
    
    
    //新浪微博sdk
//    return [WeiboSDK handleOpenURL:url delegate:self];
    
    
    
  
    

    
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url{
    
    //新浪微博sdk
    return [WeiboSDK handleOpenURL:url delegate:self ];
    
    //QQsdk
//    [QQApiInterface handleOpenURL:url delegate:self];
    return [TencentOAuth HandleOpenURL:url];

    //微信sdk
    return [WXApi handleOpenURL:url delegate:self];
}
#pragma mark 版本更新检测

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        //        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms://itunes.apple.com/us/app/wolframalpha/id334989259?mt=8"]];
        
        if (trackViewUrl.length > 0) {
            
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:trackViewUrl]];
        }
    }
}
- (void)checkVersion
{
    
    NSString *urlStr;
    if ([[InternationalControl userLanguageEnOrZh] isEqualToString:@"en"]) {
        urlStr = [NSString stringWithFormat:kCheckUpdateURL,@"", kAPPID_AT_APP_STORE];
    } else {
        urlStr = [NSString stringWithFormat:kCheckUpdateURL,@"cn/", kAPPID_AT_APP_STORE];
    }
    
    
    ASIHTTPRequest *checkVersionRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlStr]];
    checkVersionRequest.delegate = self;
    [checkVersionRequest startAsynchronous];
    
}

- (void)requestFinished:(ASIHTTPRequest *)request
{
    
    NSString *jsonStr = [[request responseString] trim];
    
    jsonStr = [jsonStr stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br />"];
    
    jsonStr = [jsonStr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    jsonStr = [jsonStr stringByReplacingOccurrencesOfString:@"\n\n" withString:@"<br />"];
    
    jsonStr = [jsonStr stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
    NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    
    NSDictionary *results = [[jsonObject objectForKey:@"results"] firstObject];
    if (results) {
        
        NSString *version = [results objectForKey:@"version"];
        NSString *releaseNotes = [results objectForKey:@"releaseNotes"];
        trackViewUrl = [results objectForKey:@"trackViewUrl"];
        
        NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
        
        NSString *appVersion = [infoDic objectForKey:@"CFBundleShortVersionString"];
        
        if ([version compare:appVersion] == NSOrderedDescending) {
            
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"%@-%@",[CommenMethod localizationString:@"ADCheckNewVersion"] ,version]
                                                            message:releaseNotes
                                                           delegate:self
                                                  cancelButtonTitle:[CommenMethod localizationString:@"Cancel"]
                                                  otherButtonTitles:[CommenMethod localizationString:@"ADUpdateNow"], nil];
            
            [alert show];
        }
    }
}

#pragma mark receive new message notification
/**
 *  @author zhaok
 *
 *  @brief  来消息的时候，并且不是当前聊天用户，声音和振动提醒控制
 */
-(void) playAudo{
    if (self.RingNoice) {
        if (CURRENTUSER.c_bell_status.integerValue == 1) {
            NSLog(@"播放声音！！！");
            if([GlobalCommen audioEnabled])
            {
                NSURL *system_sound_url=[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"msgIn" ofType:@"caf"]];
                SystemSoundID system_sound_id;
                AudioServicesCreateSystemSoundID((__bridge  CFURLRef)system_sound_url, &system_sound_id);
                
                if (self.isplaying==0) {
                    [UIView animateWithDuration:1.0f animations:^{
                        self.isplaying=1;
                        //                AudioServicesPlaySystemSound(system_sound_id);
                        AudioServicesPlaySystemSound(1007);
                    } completion:^(BOOL finished) {
                        self.isplaying=0;
                    }];
                }
            }
            
            if([GlobalCommen vibrationEnabled])
            {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
        }
    }else{
        
    }
    
    
}


- (void)handleMessageComeIn:(NSNotification *)noti{
    NSString *fromJID = [noti object];
    if(![self.currentChatJID isEqualToString:fromJID]) //不是当前聊天就提示
    {
//        NSString *strVoice = [[NSUserDefaults standardUserDefaults] objectForKey:voiceCharge];
//        NSString *strVibrate = [[NSUserDefaults standardUserDefaults] objectForKey:vibrateCharge];
//        if (!strVoice)
//        {
            [self playAudo];
//        }
//        
//        if (strVibrate)
//        {
//            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
//            NSLog(@"zhaohao test vibrate");
//        }
    }
    
    //    [_mainTabBarViewController refreshBadge];
}


#pragma mark -showMainPage
-(void)showMainPage{
    
//    FrogAccelerometerViewController *acceleroVc = [[FrogAccelerometerViewController alloc] init];
//    BaseNavigationViewController *acceleroNavc = [[BaseNavigationViewController alloc] initWithRootViewController:acceleroVc];
    
    ActivityListViewController *activityVc = [[ActivityListViewController alloc] init];
    BaseNavigationViewController *activityNavc = [[BaseNavigationViewController alloc] initWithRootViewController:activityVc];
    
    FrogMainMessageViewController * messageVC = [[FrogMainMessageViewController alloc]initWithNibName:@"FrogMainMessageViewController" bundle:nil];
    BaseNavigationViewController * messageNavc = [[BaseNavigationViewController alloc]initWithRootViewController:messageVC];
    
    
    InfoViewController *infoVC = [[InfoViewController alloc]init];
    BaseNavigationViewController * infoNav = [[BaseNavigationViewController alloc]initWithRootViewController:infoVC];
    
    
//    SettingViewController * setVC = [[SettingViewController alloc]init];
//    BaseNavigationViewController *setNav = [[BaseNavigationViewController alloc]initWithRootViewController:setVC];
    
    FrogDiscoveryViewController *discoveryVC = [[FrogDiscoveryViewController alloc]init];
    BaseNavigationViewController * disNav = [[BaseNavigationViewController alloc]initWithRootViewController:discoveryVC];
    
    
    if (iOS7) {
//        acceleroVc.tabBarItem = [UIFactory createTabBarItemWithTitle:@"记录" imageName:@"record_N" selectedImageName:@"record_H"];
        
        activityVc.tabBarItem = [UIFactory createTabBarItemWithTitle:@"活动" imageName:@"activity_N" selectedImageName:@"activity_H"];
        discoveryVC.tabBarItem = [UIFactory createTabBarItemWithTitle:@"发现" imageName:@"discover_N" selectedImageName:@"discover_H"];
        
        messageNavc.tabBarItem = [UIFactory createTabBarItemWithTitle:@"消息" imageName:@"message_N" selectedImageName:@"message_H"];//消息
        
        infoNav.tabBarItem = [UIFactory createTabBarItemWithTitle:@"我的" imageName:@"mine_N" selectedImageName:@"mine_H"];//我的
    }
    else
    {
//        [acceleroVc.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"record_H"]
//                            withFinishedUnselectedImage:[UIImage imageNamed:@"record_N"]];
//        [acceleroVc.tabBarItem setTitle:@"记录"];
        
        [activityVc.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"activity_H"]
                            withFinishedUnselectedImage:[UIImage imageNamed:@"activity_N"]];
        [activityVc.tabBarItem setTitle:@"活动"];
        
        [discoveryVC.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"discover_H"]
                             withFinishedUnselectedImage:[UIImage imageNamed:@"discover_N"]];
        [discoveryVC.tabBarItem setTitle:@"发现"];
        
        [messageNavc.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"message_H"]
                             withFinishedUnselectedImage:[UIImage imageNamed:@"message_N"]];
        [messageNavc.tabBarItem setTitle:@"消息"];
        
        [infoNav.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"mine_H"]
                        withFinishedUnselectedImage:[UIImage imageNamed:@"mine_N"]];
        [infoNav.tabBarItem setTitle:@"我的"];
        
        
    }
    
    _baseTabBar = [[UITabBarController alloc] init];

//    _baseTabBar.viewControllers = @[acceleroNavc,activityNavc,disNav,messageNavc,infoNav];
    _baseTabBar.viewControllers = @[activityNavc,disNav,messageNavc,infoNav];

    _baseTabBar.delegate = self;
    self.window.rootViewController = _baseTabBar;
    [self changeTabBarStyle];
    _baseTabBar.selectedIndex = 0;
    frogmeg = messageVC;
    [frogmeg tabBadgeValue];
    [discoveryVC refreshRedPointCFriend];
    frogDis = discoveryVC;
}

- (void)updateBadge
{
    
    User *user = [GlobalCommen CurrentUser];
    
    //用户在登录状态显示badgeValue，否则不显示
    if (user != nil) {
        
        NSLog(@"%@",[GlobalCommen CurrentUser]);
        int isUnread=[GlobalCommen countOfUnReadMessages];
        
        
        int unreadCount = [DataBaseManager selectAllUnreadNewFriend] + [DataBaseManager selectAllUnreadNewGroup];
        
        isUnread += unreadCount;
        NSString *badgeNumber = isUnread == 0 ? nil: StringFromInt(isUnread);
        if (isUnread > 99) {
            badgeNumber = @"99+";
            [UIApplication sharedApplication].applicationIconBadgeNumber = [badgeNumber intValue];
        }
        
//        dispatch_async(dispatch_get_main_queue(), ^{
        
            [_baseTabBar.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                
                if ([obj isKindOfClass:[FrogMainMessageViewController class]]) {
                    
                    FrogMainMessageViewController *mVC = (FrogMainMessageViewController *)obj;
                    mVC.baseNavigationController.tabBarItem.badgeValue = badgeNumber;
//                    mVC.tabBarItem.badgeValue = badgeNumber;
                    *stop = YES;
                }
                
                
            }];
            
            [UIApplication sharedApplication].applicationIconBadgeNumber = [badgeNumber intValue];
//        });
        
        
    }
    else
    {
        //        self.tabBarItem.badgeValue = nil;
        
        [_baseTabBar.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            
            BaseNavigationViewController * OBJ = (BaseNavigationViewController *)obj;
            for (id VC in OBJ.viewControllers) {
                if ([VC isKindOfClass:[FrogMainMessageViewController class]]) {
                    FrogMainMessageViewController * vc = (FrogMainMessageViewController *)VC;
                    [vc tabBadgeValue];
                    break;
                }
            }
            
//            if ([obj.viewControllers[0] isKindOfClass:[FrogMainMessageViewController class]]) {
//                
//                FrogMainMessageViewController *mVC = (FrogMainMessageViewController *)obj;
//                
//            }
            
//            *stop = YES;
        }];
        
    }
    
//    self performSelector:@selector(<#selector#>) withObject:<#(id)#> afterDelay:<#(NSTimeInterval)#>
}


- (void)loginConflict
{
    //    GBAlertView *alert = [GBAlertView alertWithTitle:[CommenMethod localizationString:@"WarmTips"] message:[CommenMethod localizationString:@"UserLoginInOtherDevice"] delegate:self cancelButtonTitle:[CommenMethod localizationString:@"Ok"] otherButtonTitle: nil];
    //    [alert show];
    
    DIVRecordPopView *rec = [[DIVRecordPopView alloc]initWithFrame:[[[UIApplication sharedApplication] keyWindow] frame] title:@"温馨提示" subTitle:@"您的帐号已在其他设备上登录，如非本人操作，请注意帐号安全并立即登录" items:@[@"重新登录"]];
    
    __block typeof(self) blockSelf =self;
    rec.chackIndexBlock = ^(NSInteger index)
    {
        if (index == 0) {
            LoginViewController *vc = [[LoginViewController alloc] init];
            
            BaseNavigationViewController *LoginNavc = [[BaseNavigationViewController alloc] initWithRootViewController:vc];
            
            vc.loginEnum = liveRoomLogin;
            vc.backEnum = backToMain;
            [blockSelf.baseTabBar presentViewController:LoginNavc animated:YES completion:nil];
            return;
        }
    };
    [rec showModal];
}
- (void)re_loginConflict{
    
    DIVRecordPopView *rec = [[DIVRecordPopView alloc]initWithFrame:[[[UIApplication sharedApplication] keyWindow] frame] title:@"温馨提示" subTitle:@"修改成功，请重新登录！" items:@[@"重新登录"]];
    
    __block typeof(self) blockSelf =self;
    rec.chackIndexBlock = ^(NSInteger index)
    {
        if (index == 0) {
            LoginViewController *vc = [[LoginViewController alloc] init];
            
            BaseNavigationViewController *LoginNavc = [[BaseNavigationViewController alloc] initWithRootViewController:vc];
            
            vc.loginEnum = liveRoomLogin;
            vc.backEnum = backToMain;
            [blockSelf.baseTabBar presentViewController:LoginNavc animated:YES completion:nil];
            return;
        }
    };
    [rec showModal];

}

#pragma mark -tabbar
- (void)changeTabBarStyle{
    
    if (iOS7) {
        [[UITabBar appearance] setShadowImage:[[UIImage alloc]init]];
        
        [[UITabBar appearance] setBackgroundImage:[[UIImage alloc]init]];
    }
    
    
     [[UITabBar appearance] setBackgroundImage:[UIImage imageNamed:@"tabbar_bg"] ];
    [[UITabBar appearance] setSelectionIndicatorImage:[UIImage imageNamed:@"transparent"]];
//    [_baseTabBar.tabBar setClipsToBounds:YES];
    
    [[UITabBarItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:BarColor, UITextAttributeTextColor, nil] forState:UIControlStateSelected];
    [[UITabBarItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:Rgb(165, 165, 165), UITextAttributeTextColor, nil] forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setBackgroundImage:[UIImage new]
                                            forState:UIControlStateNormal
                                          barMetrics:UIBarMetricsDefault];
//    _baseTabBar.tabBar.selectionIndicatorImage = [[UIImage imageNamed:@"bottomtabbar_H"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 2, 5, 2)];
//    _baseTabBar.tabBar.selectionIndicatorImage = [self reSizeImage:[UIImage imageNamed:@"bottomtabbar_H"] toSize:CGSizeMake(SCREEN_WIDTH/3, 49)];

}

- (UIImage *)reSizeImage:(UIImage *)image toSize:(CGSize)reSize
{
    
    UIGraphicsBeginImageContext(CGSizeMake(reSize.width, reSize.height));
    
    [image drawInRect:CGRectMake(0, 0, reSize.width, reSize.height)];
    
    UIImage *reSizeImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();

    return reSizeImage;
 
}

#pragma mark -UUID

//获取uuid
-(NSString*)keyChainUUid {
    NSString *result = nil;
    if ([FrogKeyChain load:MYUUID]) {
        result = [FrogKeyChain load:MYUUID];
    }
    else
    {
        CFUUIDRef puuid = CFUUIDCreate( nil );
        CFStringRef uuidString = CFUUIDCreateString( nil, puuid );
        result = (__bridge NSString *)CFStringCreateCopy( NULL, uuidString);
        CFRelease(puuid);
        CFRelease(uuidString);
        [FrogKeyChain save:MYUUID data:result];
    }
    return result;
}

-(void) uuid {
//    CFUUIDRef puuid = CFUUIDCreate( nil );
//    CFStringRef uuidString = CFUUIDCreateString( nil, puuid );
//    NSString * result = (NSString *)CFBridgingRelease(CFStringCreateCopy( NULL, uuidString));
//    result = [result stringByReplacingOccurrencesOfString:@"-" withString:@""];
//    NSLog(@"UUID is  %@",result);
//    _UUID = result;
    NSString *result=[self keyChainUUid];
    if (![[NSUserDefaults standardUserDefaults] stringForKey:MYUUID]) {
        [[NSUserDefaults standardUserDefaults] setObject:result forKey:MYUUID];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    _UUID =[[NSUserDefaults standardUserDefaults] stringForKey:MYUUID];
}


- (void)siderSelectFunction:(NSInteger)sender
{
    //[_sideViewController hideSideViewController:YES];
    _baseTabBar.selectedIndex = sender;
}


- (void)exit
{
    _baseTabBar.selectedIndex = 0;
}
#pragma mark -自动登陆

-(void)autoLogin{
    NSString * userName = [[NSUserDefaults standardUserDefaults] stringForKey:c_user_phone];
    NSString * password = [[NSUserDefaults standardUserDefaults] stringForKey:passWord];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:IsLogin]) {
        SessionManager *mgr = [SessionManager manager];
        
        //登录失败
        mgr.failedBlock=^(NSString * errorInfo){
            NSLog(@"登录失败");
            [GlobalCommen setCurrentUser:nil];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:IsLogin];
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_type];
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:k_user_no];
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_sex];
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_id];
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_name];
            [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:c_consuming_time];
            [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:c_all_mileage];
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_iamge];
            [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:c_all_co_section];
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_idcard_org];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:ExitNSNotification object:Nil];
            
            
        };
        
        //登录成功
        mgr.completeBlock = ^(id result)
        {
            
//            [self updateBadge];
            [frogmeg tabBadgeValue];
            [frogmeg refreshRedPoint];
            [frogDis refreshRedPointCFriend];
            NSLog(@"登陆成功");
           
            
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:IsLogin];
            // 登陆openfire
            XMPPManager *xmppManager = [XMPPManager defaultInstance];
            [xmppManager updateHostName:kXMPPServer andHostPort:kXMPPProt];
            
            if ([xmppManager connect])
            {
                
                if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 8.0) {
                    [[UIApplication sharedApplication]registerForRemoteNotifications];
                    UIUserNotificationType type=UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
                    UIUserNotificationSettings *setting=[UIUserNotificationSettings settingsForTypes:type categories:nil];
                    [[UIApplication sharedApplication]registerUserNotificationSettings:setting];
                }else{
                    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
                     (UIRemoteNotificationTypeNewsstandContentAvailability |
                      UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge |
                      UIRemoteNotificationTypeSound)];
                }

                [[NSUserDefaults standardUserDefaults] synchronize];
                NSLog(@"已登录openfire");
                
            }
            else
            {
                //openFire 登陆不上
                BYDLogDebug(@"cant connect openfire");
                
//                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"登录openFire失败" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
//                [alert show];
                NSLog(@"登录openFire失败");
                [[XMPPManager defaultInstance] disconnect];
            }
            
        };
        
        [mgr loginWithUerName:userName password:password];
    }
    else
    {
        [GlobalCommen setCurrentUser:nil];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:IsLogin];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_type];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:k_user_no];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_sex];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_id];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_name];
        [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:c_consuming_time];
        [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:c_all_mileage];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_iamge];
        [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:c_all_co_section];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:c_user_idcard_org];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:ExitNSNotification object:Nil];
        
    }
}
/**
 *  @author chums, 15-03-03 14:03:53
 *
 *  @brief  匿名登录后 在登录先要下线
 *
 */
- (void)exitOpenfire{
    NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
    
    NSXMLElement *eleX = [NSXMLElement elementWithName:@"x" xmlns:@"vcard-temp:x:update"];
    NSXMLElement *elePhoto = [NSXMLElement elementWithName:@"photo"];
    [eleX addChild:elePhoto];
    
    NSXMLElement *eleC = [NSXMLElement elementWithName:@"c" xmlns:@"http://jabber.org/protocol/caps"];
    [eleC addAttributeWithName:@"hash" stringValue:@"sha-1"];
    [eleC addAttributeWithName:@"node" stringValue:@"http://code.google.com/p/xmppframework"];
    [eleC addAttributeWithName:@"ver" stringValue:@"VyOFcFX6+YNmKssVXSBKGFP0BS4="];
    
    NSXMLElement *eleStatus = [NSXMLElement elementWithName:@"status" stringValue:@"IOS"];
    
    [presence addChild:eleX];
    [presence addChild:eleStatus];
    [presence addChild:eleC];
    
    [[[XMPPManager defaultInstance] xmppStream] sendElement:presence];
    
    [[XMPPManager defaultInstance] disconnect];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    if (CURRENTUSER.user_id) {
        NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
        
        [presence addAttributeWithName:@"type" stringValue:@"unavailable"];
        
        NSInteger isUnread=[GlobalCommen countOfUnReadMessages];
        NSInteger unreadCount = [DataBaseManager selectAllUnreadNewFriend] + [DataBaseManager selectAllUnreadNewGroup];
        isUnread += unreadCount;
        NSString *badgeNumber = isUnread == 0 ? @"0": [NSString stringWithFormat:@"%ld",(long)isUnread];
        if (isUnread > 99) {
            badgeNumber = @"99";
        }
        [UIApplication sharedApplication].applicationIconBadgeNumber = [badgeNumber intValue];
        
        
        NSString *myToken = [[NSUserDefaults standardUserDefaults]objectForKey:kPushToken];
        NSXMLElement *eleStatus = [NSXMLElement elementWithName:@"status" stringValue:myToken];
        NSXMLElement *eleOffline = [NSXMLElement elementWithName:@"offline" stringValue:badgeNumber];
        
        [presence addChild:eleStatus];
        [presence addChild:eleOffline];
        
        
        [[[XMPPManager defaultInstance]xmppStream]sendElement:presence];
    }
    
    [self recodeThread];
    _shouldStopRecord = NO;
    //是否有正在进行的活动
    if (_inActivities) {
        [DataBaseManager closeDataBase];
    // 结束前台2个子线程
    _shouldStopInActivities = YES; // 是否需要结束前台的子线程
    // 开启后台1个子线程
     _shouldStop = NO;             // 是否需要结束后台的子线程
    [_pathPointArr removeAllObjects];
    [self backgroundHandler];
        
    }
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    
    _shouldStopRecord = YES;
    
    if (_inActivities) {
        _shouldStop = YES;
        _shouldStopInActivities = NO;
        
        [APP activityStartAndrecord];
        [APP activityUpDataAndrecord];
        
    }
    
}
-(void)recodeThread{
    NSLog(@"计步线程开启");
    
    UIApplication * app = [UIApplication sharedApplication];
    __block    UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid) {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
        
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        while (1) {
            
            if (_shouldStopRecord)
            {
                goto CancelRecodeBlock;
            }
            sleep(120);
            if (!_inActivities) {
                [[BaiduMap shareLocation]getCityName:^(NSString *cityString){}];
            }
        }
        CancelRecodeBlock:
            //Do some clean up operations here
            NSLog(@"计步线程取消");
            return;
        });
}


#pragma mark--前台开线程记录轨迹线程
// 活动开始，开一个线程，每三分钟记录自己位置
-(void)activityStartAndrecord{
    NSLog(@"前台3分钟线程开启");
    
    UIApplication * app = [UIApplication sharedApplication];
    __block    UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid) {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
        
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        while (1) {
            
            if (_shouldStopInActivities)
            {
                goto CancelBlock;
            }
            
            sleep(15);
             [[BaiduMap shareLocation]getLocationCoordinate:^(CLLocationCoordinate2D location) {
                 if (!_shouldStopInActivities)
                 {
                     if (location.latitude>1 && location.longitude>1) {
                     // 每三分钟更新自己坐标
                         NSLog(@"前台记录");
                         if (!_isActivityVC) {
                             self.myNowLatitude = location.latitude;
                             self.myNowLongitude = location.longitude;
                         }
                         
                         NSLog(@"c_latitude is %f",self.myNowLatitude);
                         NSLog(@"c_longitude is %f",self.myNowLongitude);
                         
                         User *user = [GlobalCommen CurrentUser];
                         TrackModle *model = [[TrackModle alloc] init];
                         model.c_latitude = [NSString stringWithFormat:@"%f",self.myNowLatitude];
                         model.c_longitude = [NSString stringWithFormat:@"%f",self.myNowLongitude];
                         model.c_activity_id = self.goingActivityId;
                         model.c_userid = user.user_id;
                         NSDate *datenow = [NSDate date];
                         NSString *createTime = [NSString stringWithFormat:@"%.0f",[datenow timeIntervalSince1970]];
                         model.c_time =[NSString stringWithFormat:@"%@000",createTime];
                         
                         model.c_status = @"1";
                         model.c_group = @"1";
                         model.c_isUpload = @"0";
                         
                         // 存数据库之前判断是否偏离
                         if ([self JudgeIsDeviation:APP.pathArr]) {
                             model.isDeviated = @"YES";
                             isJudge++;
                             _nowIsDeviation = YES;
                         }else{
                             model.isDeviated = @"NO";
                             isJudge = 0;
                             _nowIsDeviation = NO;
                         }
                         
                         // 如果偏离大于10次  停掉线程
                         if (isJudge>=10) {
                             _inActivities = NO;
                             _shouldStopInActivities = YES;
                         }
                         
                         if (!isHave) {
                             NSArray *fmdbArr = [DataBaseManager selectAll:self.goingActivityId];
                             [DataBaseManager closeDataBase];
                             if (fmdbArr.count != 0)
                             {
                                 TrackModle *fmdbModel = [fmdbArr lastObject];
                                 model.mileage = StringFromFloat([fmdbModel.mileage doubleValue] + [GlobalCommen CalculateDistanceTwoPoints:[fmdbModel.c_latitude doubleValue] andlongitude1:[fmdbModel.c_longitude doubleValue] andlatitude2:self.myNowLatitude andlongitude2:self.myNowLongitude]);
                                 
                                 model.consuming = StringFromFloat([fmdbModel.consuming doubleValue] + [GlobalCommen CalculateTimes:[model.c_time doubleValue] andtime:[fmdbModel.c_time doubleValue]]);
                                 
                                 defaultConsuming = [model.consuming doubleValue];
                                 defaultMileage = [model.mileage doubleValue];
                                 defaultLastTime = model.c_time;
                                 defaultLatitude = self.myNowLatitude;
                                 defaultLongitude = self.myNowLongitude;
                                 isHave = YES;
                                 
                             }
                             else
                             {
                                 model.mileage = @"0";
                                 model.consuming = @"0";
                                 defaultConsuming = [model.consuming doubleValue];
                                 defaultMileage = [model.mileage doubleValue];
                                 defaultLastTime = model.c_time;
                                 defaultLatitude = self.myNowLatitude;
                                 defaultLongitude = self.myNowLongitude;
                                 isHave = YES;
                             }
                         }
                         else{
                             model.mileage = StringFromFloat(defaultMileage + [GlobalCommen CalculateDistanceTwoPoints:defaultLatitude andlongitude1:defaultLongitude andlatitude2:self.myNowLatitude andlongitude2:self.myNowLongitude)];
                             model.consuming = StringFromFloat(defaultConsuming + [GlobalCommen CalculateTimes:[model.c_time doubleValue] andtime:[defaultLastTime doubleValue]]);
                             NSLog(@"mileage is %@",model.mileage);
                             defaultConsuming = [model.consuming doubleValue];
                             defaultMileage = [model.mileage doubleValue];
                             defaultLastTime = model.c_time;
                             defaultLatitude = self.myNowLatitude;
                             defaultLongitude = self.myNowLongitude;
                         }
                         //动态算时间
//                         intervalTime = [self calculateTimeWithDistance:defaultMileage-LastDistance withLastTime:intervalTime];
//                         LastDistance = defaultMileage;
//
                                 [DataBaseManager insertTrack:model];
                                 [DataBaseManager closeDataBase];
                                 
                                 if (_pathPointArr.count>0) {
                                     
                                     for (TrackModle *model in _pathPointArr) {
                                         [DataBaseManager insertTrack:model];
                                         
                                     }
                                     [DataBaseManager closeDataBase];
                                 }

                             if(isJudge== 0 && _inActivities)
                             {
                                 TrackModle * newModel = [[TrackModle alloc]init];
                                 newModel.c_latitude =model.c_latitude;
                                 newModel.c_longitude = model.c_longitude;
                                 [[NSNotificationCenter defaultCenter] postNotificationName:HaveNewLineMessage object:newModel];
                             }

                     }
                 
             }
             
             
            } withAddress:^(NSString *cityString) {
                [DataBaseManager closeDataBase];

            }];
                                                         
        }
    CancelBlock:
        //Do some clean up operations here
        NSLog(@"前台3分钟线程取消");
        return;
    });

}

// 活动开始，开一个线程，每10分钟上传数据库内容
-(void)activityUpDataAndrecord{
    NSLog(@"前台10分钟线程开启");
    UIApplication * app = [UIApplication sharedApplication];
    
    //声明一个任务标记 可在.h中声明为全局的
    __block    UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid) {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
        
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        while (1) {
            if (_shouldStopInActivities)
            {
                goto CancelBlock;
            }
            sleep(480);
            if (!_shouldStopInActivities) {
                [self upDataTrack];
            }
            
            
        }
    CancelBlock:
        //Do some clean up operations here
        NSLog(@"前台10分钟线程取消");
        return;
        
    });
    
}

//上传路径
- (void)upDataTrack
{
    if (_shouldStopInActivities) {
        return;
    }
    NSArray * josnArr = [DataBaseManager queryTrackWithActivityID:self.goingActivityId];
    [DataBaseManager closeDataBase];
    if (josnArr.count==0) {
        return;
    }
    
    NSString *josnString = [self jointJsonWithArr:josnArr];
    SessionManager *mgr = [SessionManager manager];
    
    mgr.failedBlock = ^(NSString *error)
    {
        NSLog(@"error %@",error);
    };
    
    mgr.completeBlock = ^(id reuslt)
    {
        NSLog(@"上传成功");
        [DataBaseManager updateDTrackWithArray:josnArr];
        [DataBaseManager closeDataBase];
    };
    
    [mgr upLoadingMylocationWithJson:josnString withUUID:self.UUID];
}

//josn拼接
- (NSString *)jointJsonWithArr:(NSArray *)josnArr
{
    NSMutableArray * listArr = [NSMutableArray array];
    for(TrackModle *modle in josnArr)
    {
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:modle.c_longitude,@"c_addr_longitude",modle.c_latitude,@"c_addr_latitude", nil];
        [listArr addObject:dict];
    }
    TrackModle *model = [josnArr lastObject];
    NSDictionary *josnDict = [[NSDictionary alloc] initWithObjectsAndKeys:model.c_status,@"c_status",model.c_userid,@"n_user_id",model.c_activity_id,@"n_activity_id",model.c_group,@"n_group",model.c_time,@"c_create_time",model.consuming,@"c_consuming_time",model.mileage,@"c_mileage",listArr,@"datalist", nil];
    NSString *jsonStr = [josnDict JSONString];

    return jsonStr;
}
// 计算下次记录时间间隔
-(NSInteger)calculateTimeWithDistance:(double)distance withLastTime:(NSInteger)lastTime{
    if (distance == 0) {
        distance=100;
    }
    if (distance<0) {
        distance = 100;
    }
    
    double lastVelocity  = distance/lastTime;
    NSInteger nextTime = (NSInteger)(100/lastVelocity);
    NSLog(@"%ld",(long)nextTime);
    if (nextTime > 120) {
        nextTime = 120;
    }
    
    if (nextTime < 10) {
        nextTime = 10;
    }
    
    return nextTime;
}
                         
#pragma mark-- 判断是否偏离
-(BOOL)JudgeIsDeviation:(NSArray *)arr{
    
    CGFloat dis = 0;
    
    for (NSInteger i = 0 ;i<arr.count;i++) {
        TrackModle *model = [arr objectAtIndex:i];
        
       CGFloat newDis = [GlobalCommen CalculateDistanceTwoPoints:_myNowLatitude andlongitude1:_myNowLongitude andlatitude2:[model.c_latitude doubleValue] andlongitude2:[model.c_longitude doubleValue]];
        if (i==0) {
           dis = newDis;
        }else{
            if (newDis<dis) {
                dis = newDis;
            }
        }
    }
    if (dis>2000) {  //超出500米
        return YES;
    }else{
        return NO;
    }

}
#pragma mark-- 后台
- (void)backgroundHandler {
    NSLog(@"后台3分钟线程开启");
    UIApplication * app = [UIApplication sharedApplication];
    
    __block    UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid) {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
        
    }];
    
    // 开始执行长时间后台执行的任务 项目中启动后定位就开始了 这里不需要再去执行定位 可根据自己的项目做执行任务调整
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        while (1) {
            if (_shouldStop)
            {
                goto CancelBlock;
            }
            sleep(15);
           [[BaiduMap shareLocation]getLocationCoordinate:^(CLLocationCoordinate2D location){
            //                code
               
               if (location.latitude>1) {
                   NSLog(@"后台记录");
                   if (!_isActivityVC) {
                       self.myNowLatitude = location.latitude;
                       self.myNowLongitude = location.longitude;
                   }
                   
                   
                   User *user = [GlobalCommen CurrentUser];
                   TrackModle *model = [[TrackModle alloc] init];
                   model.c_latitude = [NSString stringWithFormat:@"%f",self.myNowLatitude];
                   model.c_longitude = [NSString stringWithFormat:@"%f",self.myNowLongitude];
                   model.c_activity_id = self.goingActivityId;
                   model.c_userid = user.user_id;
                   NSDate *datenow = [NSDate date];
                   NSString *createTime = [NSString stringWithFormat:@"%.0f",[datenow timeIntervalSince1970]];
                   model.c_time =[NSString stringWithFormat:@"%@000",createTime];
                   
                   model.c_status = @"1";
                   model.c_group = @"1";
                   model.c_isUpload = @"0";
                   
                   // 存数据库之前判断是否偏离
                   if ([self JudgeIsDeviation:APP.pathArr]) {
                       model.isDeviated = @"YES";
                       isJudge++;
                       
                   }else{
                       model.isDeviated = @"NO";
                       isJudge = 0;
                   }
                   
                   // 如果偏离大于10次  停掉线程
                   if (isJudge>=10) {
                       _inActivities = NO;
                       _shouldStopInActivities = YES;
                   }
                   
                   if (isHave) {
                       model.mileage = StringFromFloat(defaultMileage + [GlobalCommen CalculateDistanceTwoPoints:self.myNowLatitude andlongitude1:self.myNowLongitude andlatitude2:defaultLatitude andlongitude2:defaultLongitude)];
                       model.consuming = StringFromFloat(defaultConsuming + [GlobalCommen CalculateTimes:[model.c_time doubleValue] andtime:[defaultLastTime doubleValue]]);
                       defaultConsuming = [model.consuming doubleValue];
                       defaultMileage = [model.mileage doubleValue];
                       defaultLastTime = model.c_time;
                       defaultLatitude = self.myNowLatitude;
                       defaultLongitude = self.myNowLongitude;
                       
                       }else{
                           model.mileage = @"0";
                           model.consuming =@"0";
                           
                           defaultConsuming = [model.consuming doubleValue];
                           defaultMileage = [model.mileage doubleValue];
                           defaultLastTime = model.c_time;
                           defaultLatitude = self.myNowLatitude;
                           defaultLongitude = self.myNowLongitude;
                           isHave = YES;
                           
                       }
                       [_pathPointArr addObject:model];
               }
               
            } withAddress:^(NSString *cityString) {
                //                code
            }];

        }
    CancelBlock:
        //Do some clean up operations here
        NSLog(@"后台3分钟线程取消");
        return;
        
    });
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
- (void)applicationWillEnterForeground:(UIApplication *)application
{
//    NSLog(@"*********************************************************************************");
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    if (CURRENTUSER.user_id || [[NSUserDefaults standardUserDefaults] objectForKey: kLOGINWITHANONYMITY]) {
        NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
        
        [presence addAttributeWithName:@"type" stringValue:@"available"];
        
        [[[XMPPManager defaultInstance]xmppStream]sendElement:presence];
        
        User * user =[GlobalCommen CurrentUser];
 /****5_11***/
        SessionManager * mgr=[SessionManager manager];
        mgr.failedBlock=^(NSString*errorStatus){
            NSLog(@"zhaohao test GetMyGroupList Block");
            
        };
        mgr.completeBlock=^(id result){
            NSArray *groupList = (NSArray*)result;
            
            for (Group * group in groupList) {

                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
                    [self setRoomManager:nil];
                    _roomManager = [[XMPPRoomManager alloc] initWithRoomName:group.group_id];
                    [_roomManager joinRoomByMyNick:user.user_no];
                });
            }
        };
        
        [mgr loadMyGroupListWithUserId:user.user_id];
    }
}
/****5_11***/
- (void)loadMyGroupList{
    
    SessionManager * mgr=[SessionManager manager];
    mgr.failedBlock=^(NSString*errorStatus){
        NSLog(@"zhaohao test GetMyGroupList Block");
        
    };
    mgr.completeBlock=^(id result){
        NSArray *groupList = (NSArray*)result;
        //  NSLog(@"zhaohao test joinGroup data:%@",groupList);
        
        for (Group * group in groupList) {
            
            
            [DataBaseManager updateMesagec_group_portrait:group.portrait WhereChat_object_id:group.group_id];
            if (![DataBaseManager insertGroup:group]) {
                NSLog(@"zhaohao test insert Group !");
            }
            else
            {}
        }
    };
    
    [mgr loadMyGroupListWithUserId:CURRENTUSER.user_id];
    
}
                   
#pragma mark TabBarController Delegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController{
    
    if (tabBarController == self.baseTabBar) {
        
        UIViewController *visibleVC = nil;
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            
            visibleVC = [(UINavigationController *)viewController visibleViewController];
        }
        User *user =[GlobalCommen CurrentUser];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:IsLogin] || user==nil) {
            if ([visibleVC isKindOfClass:[InfoViewController class]] ) {
                
                LoginViewController *vc = [[LoginViewController alloc] init];
                
                BaseNavigationViewController *LoginNavc = [[BaseNavigationViewController alloc] initWithRootViewController:vc];
                
                vc.loginEnum = liveRoomLogin;
                vc.backEnum = backTobase;
                [self.baseTabBar presentViewController:LoginNavc animated:YES completion:nil];

            }
            
            if ([visibleVC isKindOfClass:[FrogMainMessageViewController class]] ) {
                
                LoginViewController *vc = [[LoginViewController alloc] init];
                
                BaseNavigationViewController *LoginNavc = [[BaseNavigationViewController alloc] initWithRootViewController:vc];
                
                vc.loginEnum = liveRoomLogin;
                vc.backEnum = backTobase;
                [self.baseTabBar presentViewController:LoginNavc animated:YES completion:nil];
            }
        }
    }
    
    return YES;
}
// 显示登录界面
-(void)showLoginVC{
    LoginViewController *vc = [[LoginViewController alloc] init];
    
    BaseNavigationViewController *LoginNavc = [[BaseNavigationViewController alloc] initWithRootViewController:vc];
    
    vc.loginEnum = defaultLogin;
    
    [self.baseTabBar presentViewController:LoginNavc animated:YES completion:nil];
}
                   
#pragma mark -- 计算步数
//使用M7处理器计步
- (void)setpCpuntWithM7{
    self.stepCounter = [[CMStepCounter alloc] init];
    self.operationQueue = [[NSOperationQueue alloc] init];
    [self.stepCounter startStepCountingUpdatesToQueue:self.operationQueue
                                             updateOn:1
                                          withHandler:
     ^(NSInteger numberOfSteps, NSDate *timestamp, NSError *error) {
         
         dispatch_async(dispatch_get_main_queue(), ^{
             
             if (error) {
                 UIAlertView *error = [[UIAlertView alloc] initWithTitle:@"计步意外停止！" message:@"error" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                 [error show];
             }
             else {
                  SituationModel *model = [[SituationModel alloc] init];
                  model.dayDate = [DateManager weakFormatterTransitionOfDate];
                 self.stepCount = self.stepCount+numberOfSteps;
                  model.current_pace = [NSString stringWithFormat:@"%ld",(long)self.stepCount];
                  model.objectives_pace = StringFromNSInteger(5000);
                 [[NSNotificationCenter defaultCenter] postNotificationName:DetectionAcceleratorNotification object:StringFromNSInteger(self.stepCount)];
                 //获取当前的小时
                 NSDate * date = [NSDate date];
                 NSDateFormatter * f = [[NSDateFormatter alloc] init];
                 [f setDateFormat:@"HH"];
                 NSString * timeHour = [f stringFromDate:date];
                 BOOL isPerfix = [timeHour hasPrefix:@"0"];
                 if(isPerfix){
                     NSRange rang = {1,1};
                     NSString * time = [timeHour substringWithRange:rang];
                     model.hour = time;
                 }else{
                     model.hour = timeHour;
                 };
                 [arrStepCount addObject:model];
                 if([[NSUserDefaults standardUserDefaults] boolForKey:IsLogin]){
                     //        [DataBaseManager insertCurrentSituationOfUserWithArray:arrcurrentTimestamp]; //插入时间戳到(用户表 tb_Accelerometer)
                     //        [arrcurrentTimestamp removeAllObjects];
                     //存储数据到stepCount（画折线图）
                     if(arrStepCount.count>=10){
                         SituationModel *m = [arrStepCount lastObject];
                         [arrStepCount removeAllObjects];
                         [DataNewMangeger inserr:m];
                         [[NSNotificationCenter defaultCenter] postNotificationName:RedrawLine object:nil];
                     }
                     
                     NSString *timeF = [DataBaseManager queryCurrentTime];
                     if(timeF!=nil && ![timeF isEqualToString:@""]){
                         NSDate *dateEnd = [NSDate dateWithTimeIntervalSince1970:[timeF doubleValue]];
                         NSDate *dateNow = [NSDate dateWithTimeIntervalSince1970:[DateManager timestampTransitionOfCurrentFormatter]];
                         NSInteger count = [self calcDaysFromBegin:dateEnd end:dateNow];
                         if (count>1) {
                             for (int i=1;i<count ;i++) {
                                 SituationModel *m = [[SituationModel alloc]init];
                                 double a = [timeF doubleValue] + (24*60*60)*i;
                                 NSDate *date = [NSDate dateWithTimeIntervalSince1970:a];
                                 m.dayDate = [self retureDay:date];
                                 m.objectives_pace = @"5000";
                                 m.current_pace = @"0";
                                 m.current_time = [NSString stringWithFormat:@"%.2f",a];
                                 [DataBaseManager insertCurrentSituationWithModel:m];
                             }
                             [DataBaseManager insertCurrentSituationWithModel:model];
                           self.stepCount = first;
                         }else{
                             [DataBaseManager insertCurrentSituationWithModel:model];
                             self.stepCount = first;
                         }
                     }else{
                         //这是数据库为空的时候，第一次插入一条数据
                         [DataBaseManager insertCurrentSituationWithModel:model];// 插入到公共表tb_Situation
                         self.stepCount = first;
                     }
                 }
                 else{//不在登陆情况下
                     //存储数据到stepCount（画折线图）
                     if(arrStepCount.count>=10){
                         SituationModel *m = [arrStepCount lastObject];
                         [arrStepCount removeAllObjects];
                         [DataNewMangeger inserr:m];
                         [[NSNotificationCenter defaultCenter] postNotificationName:RedrawLine object:nil];
                     }
                     
                     [DataBaseManager insertCurrentSituationWithModel:model];
                     self.stepCount = first;
                 }
             }
         });
     }];
}
                   
//使用加速计计步
- (void)smasherCount{
    
    UIApplication*   app = [UIApplication sharedApplication];
    __block    UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid)
            {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
    }];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid)
            {
                bgTask = UIBackgroundTaskInvalid;
            }
            
            double updateFrequency = 60.0;
            
            //计步器
            filter = [[LowpassFilter alloc] initWithSampleRate:updateFrequency cutoffFrequency:5.0];
            
            //加速器
            [[UIAccelerometer sharedAccelerometer] setUpdateInterval:1.0 / updateFrequency];
            [[UIAccelerometer sharedAccelerometer] setDelegate:self];
        });
    });
}

-(void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {
   //过滤器
   [filter addAcceleration:acceleration];
   //检测步行
   [self analyzeWalk:filter.x:filter.y:filter.z];
}
                   
//检测步行
-(void)analyzeWalk:(UIAccelerationValue)x :(UIAccelerationValue)y :(UIAccelerationValue)z {
   //「山」の閾値
   UIAccelerationValue hiThreshold = 1.1;
   //「谷」の閾値
    UIAccelerationValue lowThreshold = 0.9;
    UIAccelerationValue composite;
   composite = sqrt(pow(x,2)+pow(y,2)+pow(z,2));
//    NSLog(@"---->%f",composite);
   //「山」の後に「谷」を検知すると1歩進んだと認識
   if ( stepFlag == TRUE ) {
       if ( composite < lowThreshold ) {
           stepFlag = FALSE;
           [self isRecordThePace];
       }
   } else {
       if ( composite > hiThreshold ){
           stepFlag = TRUE;
       }
   }
}

/**
*  是否累加
*/
- (void)isRecordThePace{
   if(!isRecord){
       [timerCheck invalidate];
       tempPace += 1;
//       NSLog(@"tempPace--->%d",tempPace);
       [arrtempTimestamp addObject:[NSNumber numberWithDouble:[DateManager timestampTransitionOfCurrentFormatter]]];
       if(tempPace > 8){//置为有效累加
//           isRecord = TRUE;
//           arrcurrentTimestamp = [NSMutableArray arrayWithArray:arrtempTimestamp];
//           [arrtempTimestamp removeAllObjects];
//           self.stepCount = tempPace;
//           tempPace = 0;
//           isRecord = TRUE;
//
//           arrcurrentTimestamp = [NSMutableArray arrayWithArray:arrtempTimestamp];
//           [arrtempTimestamp removeAllObjects];
//           self.stepCount = tempPace;
//           tempPace = 0;
           isRecord = TRUE;
           arrcurrentTimestamp = [NSMutableArray arrayWithArray:arrtempTimestamp];
           [arrtempTimestamp removeAllObjects];
           self.stepCount = self.stepCount+tempPace;
           tempPace = 0;
       }
       else{
           timerCheck = [NSTimer scheduledTimerWithTimeInterval:4.0 target:self selector:@selector(checkIsRecord) userInfo:Nil repeats:YES];
       }
   }
   else{//有效累加
       isRecord = TRUE;
//       NSLog(@"stepCount---->%d",self.stepCount);

       self.stepCount ++;
        [[NSNotificationCenter defaultCenter] postNotificationName:DetectionAcceleratorNotification object:StringFromNSInteger(self.stepCount)];
       [arrcurrentTimestamp addObject:[NSNumber numberWithDouble:[DateManager timestampTransitionOfCurrentFormatter]]];
       if(([DateManager timestampTransitionOfCurrentFormatter] - lastCommitTime) > 10){
           [self commitData];
           isRecord = TRUE;
       }
   }
}
                   
/**
*  提交数据库
*  (15秒测试)
*/
- (void)commitData{
    if(!isRecord){
        return;
    }
    SituationModel *model = [[SituationModel alloc] init];
    model.dayDate = [DateManager weakFormatterTransitionOfDate];
    model.current_pace = StringFromNSInteger(self.stepCount);
    model.current_time = StringFromFloat([DateManager timestampTransitionOfCurrentFormatter]);
    model.objectives_pace = StringFromNSInteger(5000);
    //获取当前的小时
    NSDate * date = [NSDate date];
    NSDateFormatter * f = [[NSDateFormatter alloc] init];
    [f setDateFormat:@"HH"];
    NSString * timeHour = [f stringFromDate:date];
    BOOL isPerfix = [timeHour hasPrefix:@"0"];
    if(isPerfix){
        NSRange rang = {1,1};
        NSString * time = [timeHour substringWithRange:rang];
        model.hour = time;
    }else{
        model.hour = timeHour;
    };
    [arrStepCount addObject:model];
    if([[NSUserDefaults standardUserDefaults] boolForKey:IsLogin]){
//        [DataBaseManager insertCurrentSituationOfUserWithArray:arrcurrentTimestamp]; //插入时间戳到(用户表 tb_Accelerometer)
//        [arrcurrentTimestamp removeAllObjects];
        //存储数据到stepCount（画折线图）
        if(arrStepCount.count>=10){
            SituationModel *m = [arrStepCount lastObject];
            [arrStepCount removeAllObjects];
            [DataNewMangeger inserr:m];
            [[NSNotificationCenter defaultCenter] postNotificationName:RedrawLine object:nil];
        }
        
        NSString *timeF = [DataBaseManager queryCurrentTime];
        if(timeF!=nil && ![timeF isEqualToString:@""]){
            NSDate *dateEnd = [NSDate dateWithTimeIntervalSince1970:[timeF doubleValue]];
            NSDate *dateNow = [NSDate dateWithTimeIntervalSince1970:[DateManager timestampTransitionOfCurrentFormatter]];
            NSInteger count = [self calcDaysFromBegin:dateEnd end:dateNow];
            if (count>1) {
                for (int i=1;i<count ;i++) {
                    SituationModel *m = [[SituationModel alloc]init];
                    double a = [timeF doubleValue] + (24*60*60)*i;
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:a];
                    m.dayDate = [self retureDay:date];
                    m.objectives_pace = @"5000";
                    m.current_pace = @"0";
                    m.current_time = [NSString stringWithFormat:@"%.2f",a];
                    [DataBaseManager insertCurrentSituationWithModel:m];
                }
                [DataBaseManager insertCurrentSituationWithModel:model];
            }else{
                [DataBaseManager insertCurrentSituationWithModel:model];
                [timerCount invalidate];
                timerCount = nil;
                timerCount = [[NSTimer alloc]init];
                timerCount = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(resetStepcount) userInfo:Nil repeats:NO];
            }
        }else{
            //这是数据库为空的时候，第一次插入一条数据
            [DataBaseManager insertCurrentSituationWithModel:model];// 插入到公共表tb_Situation
        }
    }
    else{//不在登陆情况下
        //存储数据到stepCount（画折线图）
        if(arrStepCount.count>=10){
            SituationModel *m = [arrStepCount lastObject];
            [arrStepCount removeAllObjects];
            [DataNewMangeger inserr:m];
            [[NSNotificationCenter defaultCenter] postNotificationName:RedrawLine object:nil];
        }

         [DataBaseManager insertCurrentSituationWithModel:model];
          [timerCount invalidate];
          timerCount = nil;
          timerCount = [[NSTimer alloc]init];
          timerCount = [NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(resetStepcount) userInfo:Nil repeats:NO];
    }
}

            
//用于检测DataBaseManager的tb_Situation表的最后一条数据的时间与现在执行这条代码的时间间隔超过一天就会执行这个方法，把间隔的天数插入数据库
- (void)check{
    NSString *timeF = [DataBaseManager queryCurrentTime];
    if(timeF!=nil && ![timeF isEqualToString:@""]){
       NSDate *dateEnd = [NSDate dateWithTimeIntervalSince1970:[timeF doubleValue]];
       NSDate *dateNow = [NSDate dateWithTimeIntervalSince1970:[DateManager timestampTransitionOfCurrentFormatter]];
       NSInteger count = [self calcDaysFromBegin:dateEnd end:dateNow];
        if (count>1) {
            for (int i=1;i<count ;i++) {
                SituationModel *m = [[SituationModel alloc]init];
                double a = [timeF doubleValue] + (24*60*60)*i;
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:a];
                m.dayDate = [self retureDay:date];
                m.objectives_pace = @"5000";
                m.current_pace = @"0";
                m.current_time = [NSString stringWithFormat:@"%.2f",a];
                [DataBaseManager insertCurrentSituationWithModel:m];
            }
        }
    }
}
//用于检测防抖动，如果两次抖动间隔暂停超过7秒，就会执行这个方法
- (void)resetStepcount{
    [timerCount invalidate];
    isRecord = FALSE;
}

/**
*  无效累加，重置中间变量
*/
- (void)checkIsRecord{
    [timerCheck invalidate];
    isRecord = FALSE;
    tempPace = 0;
}
                   
//返回NSDate对应的日期
- (NSString *)retureDay:(NSDate *)dayDate{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
     [formatter setDateFormat:@"yyyy年MM月dd日"];
     NSString *day = [formatter stringFromDate:dayDate];
     return day;
}
                   
//计算两个NSDate的间隔天数
-(NSInteger) calcDaysFromBegin:(NSDate *)inBegin end:(NSDate *)inEnd{
   NSInteger unitFlags = NSDayCalendarUnit| NSMonthCalendarUnit | NSYearCalendarUnit;
   NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
   NSDateComponents *comps = [cal components:unitFlags fromDate:inBegin];
   NSDate *newBegin  = [cal dateFromComponents:comps];
   NSCalendar *cal2 = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
   NSDateComponents *comps2 = [cal2 components:unitFlags fromDate:inEnd];
   NSDate *newEnd  = [cal2 dateFromComponents:comps2];
   NSTimeInterval interval = [newEnd timeIntervalSinceDate:newBegin];
   NSInteger beginDays=((NSInteger)interval)/(3600*24);
   return beginDays;
}
                   
- (void)onResp:(BaseResp*)resp
{
    NSLog(@"微信支付Pay");
    NSString *strMsg = [NSString stringWithFormat:@"errcode:%d", resp.errCode];
    NSString *strTitle;
    if([resp isKindOfClass:[PayResp class]]){
       //支付返回结果，实际支付结果需要去微信服务器端查询
       strTitle = [NSString stringWithFormat:@"支付结果"];
       switch (resp.errCode) {
           case WXSuccess:
               strMsg = @"支付结果：成功！";
               [[NSNotificationCenter defaultCenter] postNotificationName:PaySuccessNotification object:nil];
               NSLog(@"支付成功－PaySuccess，retcode = %d", resp.errCode);
               break;
               
           default:
               strMsg = [NSString stringWithFormat:@"支付结果：失败！retcode = %d, retstr = %@", resp.errCode,resp.errStr];
               NSLog(@"错误，retcode = %d, retstr = %@", resp.errCode,resp.errStr);
               break;
       }
    }
//    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:strTitle message:strMsg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
//    [alert show];
}
                   
                   
                   
                   
                   
                   
                   
                   
                   
@end
