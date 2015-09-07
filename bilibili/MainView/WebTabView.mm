//
//  WebTabView.m
//  bilibili
//
//  Created by TYPCN on 2015/9/3.
//  Copyright (c) 2015 TYPCN. All rights reserved.
//

#import "WebTabView.h"
#import "ToolBar.h"
#import "Analytics.h"

@implementation WebTabView {
    NSString* WebScript;
    NSString* WebUI;
    NSString* WebCSS;
    NSView* HudView;
    bool ariainit;
    long acceptAnalytics;
}

-(id)initWithBaseTabContents:(CTTabContents*)baseContents {
    if (!(self = [super initWithBaseTabContents:baseContents])) return nil;
    double height = [[NSUserDefaults standardUserDefaults] doubleForKey:@"webheight"];
    double width = [[NSUserDefaults standardUserDefaults] doubleForKey:@"webwidth"];
    NSLog(@"lastWidth: %f Height: %f",width,height);
    if(width < 300 || height < 300){
        NSRect rect = [[NSScreen mainScreen] visibleFrame];
        [self.view setFrame:rect];
    }else{
        NSRect frame = [self.view.window frame];
        frame.size = NSMakeSize(width, height);
        [self.view setFrame:frame];
    }
    
    [self.view.window makeKeyAndOrderFront:NSApp];
    [self.view.window makeMainWindow];
    
    NSURL *u = [NSURL URLWithString:@"http://www.bilibili.com"];
    
    return [self initWithRequest:[NSURLRequest requestWithURL:u] andConfig:nil];
}

-(id)initWithRequest:(NSURLRequest *)req andConfig:(id)cfg{
    webView = [[TWebView alloc] initWithRequest:req andConfig:cfg setDelegate:self];
    [self loadStartupScripts];
    [self setIsWaitingForResponse:YES];
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [sv setHasVerticalScroller:NO];
    [webView addToView:sv];
    self.view = sv;
    return self;
}

-(void)viewFrameDidChange:(NSRect)newFrame {
    // We need to recalculate the frame of the NSTextView when the frame changes.
    // This happens when a tab is created and when it's moved between windows.
    [super viewFrameDidChange:newFrame];
    NSRect frame = NSZeroRect;
    frame.size = [(NSScrollView*)(view_) contentSize];
    [webView setFrameSize:frame];
    HudView = [[webView GetWebView] subviews][0];
    dispatch_async(dispatch_get_global_queue(0, 0), ^(void){
        [[NSUserDefaults standardUserDefaults] setDouble:frame.size.width forKey:@"webwidth"];
        [[NSUserDefaults standardUserDefaults] setDouble:frame.size.height forKey:@"webheight"];
    });
}

-(id)GetWebView{
    return [webView GetWebView];
}

-(TWebView *)GetTWebView{
    return webView;
}


- (void)loadStartupScripts
{
    NSError *err;
    
    
    
    NSUserDefaults *s = [NSUserDefaults standardUserDefaults];
    acceptAnalytics = [s integerForKey:@"acceptAnalytics"];
    
    if(!acceptAnalytics || acceptAnalytics == 1 || acceptAnalytics == 2){
        screenView("NewTab");
    }

    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"webpage/inject" ofType:@"js"];
    WebScript = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    if(err){
        [self showError];
    }
    
    path = [[NSBundle mainBundle] pathForResource:@"webpage/webui" ofType:@"html"];
    WebUI = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    if(err){
        [self showError];
    }
    
    path = [[NSBundle mainBundle] pathForResource:@"webpage/webui" ofType:@"css"];
    WebCSS = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    if(err){
        [self showError];
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
    }
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
    }
    return NO;
}

+ (BOOL)autosavesInPlace {
    return YES;
}

- (BOOL) shouldStartDecidePolicy: (NSURLRequest *) request
{
    NSString *url = [request.URL absoluteString];
    if([url containsString:@"about:blank"]){
        return NO;
    }
    return YES;
}

- (void) didStartNavigation
{
    //NSLog(@"start load");
}

- (void) didCommitNavigation{
    [self setTitle:[webView getTitle]];
    [self setIsWaitingForResponse:NO];
    [self setIsLoading:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLChangeURL" object:[webView getURL]];
    [webView runJavascript:WebScript];
    
    if(acceptAnalytics == 1 || acceptAnalytics == 2){
        screenView("WebView");
    }else{
        NSLog(@"Analytics disabled ! won't upload.");
    }
    NSString *lastPlay = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastPlay"];
    if([lastPlay length] > 1){
        [webView setURL:lastPlay];
        NSLog(@"Opening last play url %@",lastPlay);
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"LastPlay"];
    }
}

- (void) failLoadOrNavigation: (NSURLRequest *) request withError: (NSError *) error
{
    NSLog(@"load failed");
}

- (void) finishLoadOrNavigation: (NSURLRequest *) request
{
    [self setIsLoading:NO];
    [self setTitle:[webView getTitle]];
}

- (void) invokeJSEvent:(NSString *)action withData:(NSString *)data{
    if([action isEqualToString:@"playVideoByCID"]){
        [self playVideoByCID:data];
    }else if([action isEqualToString:@"downloadVideoByCID"]){
        [self downloadVideoByCID:data];
    }else if([action isEqualToString:@"checkforUpdate"]){
        [self checkForUpdates];
    }else if([action isEqualToString:@"showNotification"]){
        [self showNotification:data];
    }else if([action isEqualToString:@"setcookie"]){
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"cookie"];
    }
}

- (void)onTitleChange:(NSString *)str{
    [self setTitle:str];
    [webView runJavascript:WebScript];
}


- (void)showNotification:(NSString *)content{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:HudView animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = content;
    hud.removeFromSuperViewOnHide = YES;
    [hud hide:YES afterDelay:3];
}

- (void)checkForUpdates
{
//    [[SUUpdater sharedUpdater] checkForUpdates:nil];
//    if(acceptAnalytics == 1 || acceptAnalytics == 2){
//        action("App","CheckForUpdate","CheckForUpdate");
//    }else{
//        NSLog(@"Analytics disabled ! won't upload.");
//    }
}

- (void)showPlayGUI
{
    [webView runJavascript:[NSString stringWithFormat:@"$('#bofqi').html('%@');$('head').append('<style>%@</style>');",WebUI,WebCSS]];
}
- (void)playVideoByCID:(NSString *)cid
{
//    if(parsing){
//        return;
//    }
//    WebTabView *tv = (WebTabView *)[browser activeTabContents];
//    TWebView *wv = [tv GetTWebView];
//    NSArray *fn = [[wv getTitle] componentsSeparatedByString:@"_"];
//    NSString *mediaTitle = [fn objectAtIndex:0];
//    parsing = true;
//    vCID = cid;
//    vUrl = [wv getURL];
//    if([mediaTitle length] > 0){
//        vTitle = [fn objectAtIndex:0];
//    }else{
//        vTitle = NSLocalizedString(@"未命名", nil);
//    }
//    
//    [[NSUserDefaults standardUserDefaults] setObject:vUrl forKey:@"LastPlay"];
//    NSLog(@"Video detected ! CID: %@",vCID);
//    if(acceptAnalytics == 1){
//        action("video", "play", [vCID cStringUsingEncoding:NSUTF8StringEncoding]);
//        screenView("PlayerView");
//    }else if(acceptAnalytics == 2){
//        screenView("PlayerView");
//    }else{
//        NSLog(@"Analytics disabled ! won't upload.");
//    }
//    dispatch_async(dispatch_get_main_queue(), ^(void){
//        NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
//        playerWindowController = [storyBoard instantiateControllerWithIdentifier:@"playerWindow"];
//        [playerWindowController showWindow:self];
//    });
}
- (void)downloadVideoByCID:(NSString *)cid
{
//    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:HudView animated:YES];
//    hud.mode = MBProgressHUDModeIndeterminate;
//    hud.labelText = NSLocalizedString(@"正在启动下载引擎", nil);
//    hud.removeFromSuperViewOnHide = YES;
//    
//    if(!DL){
//        DL = new Downloader();
//    }
//    
//    if(acceptAnalytics == 1){
//        action("video", "download", [cid cStringUsingEncoding:NSUTF8StringEncoding]);
//        screenView("PlayerView");
//    }else if(acceptAnalytics == 2){
//        screenView("PlayerView");
//    }else{
//        NSLog(@"Analytics disabled ! won't upload.");
//    }
//    
//    WebTabView *tv = (WebTabView *)[browser activeTabContents];
//    TWebView *wv = [tv GetTWebView];
//    
//    NSArray *fn = [[wv getTitle] componentsSeparatedByString:@"_"];
//    NSString *filename = [fn objectAtIndex:0];
//    
//    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        hud.labelText = NSLocalizedString(@"正在解析视频地址", nil);
//        BOOL s = DL->newTask([cid intValue], filename);
//        dispatch_async(dispatch_get_main_queue(), ^(void){
//            if(s){
//                hud.labelText = NSLocalizedString(@"成功开始下载", nil);
//            }else{
//                hud.labelText = NSLocalizedString(@"下载失败，请点击帮助 - 反馈", nil);
//            }
//            hud.mode = MBProgressHUDModeText;
//            [hud hide:YES afterDelay:3];
//            id ct = [browser createTabBasedOn:nil withUrl:@"http://static.tycdn.net/downloadManager/"];
//            [browser addTabContents:ct inForeground:YES];
//        });
//    });
}


- (void)showError
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"文件读取失败，您可能无法正常使用本软件，请向开发者反馈。", nil)];
    [alert runModal];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems{
    NSMenuItem *copy = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"复制页面地址", nil) action:@selector(CopyLink:) keyEquivalent:@""];
    [copy setTarget:self];
    [copy setEnabled:YES];
    NSMenuItem *play = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"强制显示播放界面", nil) action:@selector(ShowPlayer) keyEquivalent:@""];
    [play setTarget:self];
    [play setEnabled:YES];
    NSMenuItem *contact = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"呼叫程序猿", nil) action:@selector(Contact) keyEquivalent:@""];
    [contact setTarget:self];
    [contact setEnabled:YES];
    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
    [mutableArray addObjectsFromArray:defaultMenuItems];
    [mutableArray addObject:copy];
    [mutableArray addObject:play];
    [mutableArray addObject:contact];
    return mutableArray;
}

- (IBAction)CopyLink:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:[webView getURL]  forType:NSStringPboardType];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:HudView animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = NSLocalizedString(@"当前页面地址已经复制到剪贴板", nil);
    hud.removeFromSuperViewOnHide = YES;
    [hud hide:YES afterDelay:3];
}

- (void)ShowPlayer{
    [webView runJavascript:WebScript];
}

- (void)Contact{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:typcncom@gmail.com"]];
}

- (IBAction)openAv:(id)sender {
    NSString *avNumber = [sender stringValue];
    if([[sender stringValue] length] > 2 ){
        if ([[avNumber substringToIndex:2] isEqual: @"av"]) {
            avNumber = [avNumber substringFromIndex:2];
        }
        
        
        [webView setURL:[NSString stringWithFormat:@"http://www.bilibili.com/video/av%@",avNumber]];
        [sender setStringValue:@""];
    }
}

@end
