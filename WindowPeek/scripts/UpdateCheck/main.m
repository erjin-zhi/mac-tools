#import <AppKit/AppKit.h>
#import <Sparkle/Sparkle.h>

// Isolated fixture application. It never uses Window Peek's bundle ID or permissions.
@interface UpdateCheck : NSObject <NSApplicationDelegate, SPUUserDriver>
@property SPUUpdater *updater;
@end
@implementation UpdateCheck
- (void)finish:(NSString *)result {
    NSString *path = NSBundle.mainBundle.infoDictionary[@"TestResultPath"];
    [result writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [NSApp terminate:nil];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if ([NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] isEqual:@"2"]) {
        [self finish:@"installed-and-relaunched"];
        return;
    }
    self.updater = [[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle
        applicationBundle:NSBundle.mainBundle userDriver:self delegate:nil];
    NSError *error = nil;
    if (![self.updater startUpdater:&error]) { [self finish:error.description]; return; }
    [self.updater checkForUpdates];
}
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply {
    [self finish:@"unexpected-permission-request"];
}
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancel {}
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply { reply(SPUUserUpdateChoiceInstall); }
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error { [self finish:error.description]; }
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))ack { ack(); [self finish:@"no-update"]; }
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))ack {
    NSString *result = [NSString stringWithFormat:@"error:%ld:%@", (long)error.code, error.description];
    ack(); [self finish:result];
}
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancel {}
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate {}
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply { reply(SPUUserUpdateChoiceInstall); }
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry {}
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))ack { ack(); }
- (void)dismissUpdateInstallation {}
@end
int main(void) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        UpdateCheck *delegate = [UpdateCheck new];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
