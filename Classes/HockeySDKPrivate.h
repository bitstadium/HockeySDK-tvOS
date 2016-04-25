#import <Foundation/Foundation.h>

#ifndef HockeySDK_HockeySDKPrivate_h
#define HockeySDK_HockeySDKPrivate_h

#define BITHOCKEY_NAME @"HockeySDK"
#define BITHOCKEY_IDENTIFIER @"net.hockeyapp.sdk.tvos"
#define BITHOCKEY_CRASH_SETTINGS @"BITCrashManager.plist"
#define BITHOCKEY_CRASH_ANALYZER @"BITCrashManager.analyzer"

#define BITHOCKEY_FEEDBACK_SETTINGS @"BITFeedbackManager.plist"

#define BITHOCKEY_USAGE_DATA @"BITUpdateManager.plist"

#define kBITHockeyMetaUserName  @"BITHockeyMetaUserName"
#define kBITHockeyMetaUserEmail @"BITHockeyMetaUserEmail"
#define kBITHockeyMetaUserID    @"BITHockeyMetaUserID"

#define kBITUpdateInstalledUUID              @"BITUpdateInstalledUUID"
#define kBITUpdateInstalledVersionID         @"BITUpdateInstalledVersionID"
#define kBITUpdateCurrentCompanyName         @"BITUpdateCurrentCompanyName"
#define kBITUpdateArrayOfLastCheck           @"BITUpdateArrayOfLastCheck"
#define kBITUpdateDateOfLastCheck            @"BITUpdateDateOfLastCheck"
#define kBITUpdateDateOfVersionInstallation  @"BITUpdateDateOfVersionInstallation"
#define kBITUpdateUsageTimeOfCurrentVersion  @"BITUpdateUsageTimeOfCurrentVersion"
#define kBITUpdateUsageTimeForUUID           @"BITUpdateUsageTimeForUUID"
#define kBITUpdateInstallationIdentification @"BITUpdateInstallationIdentification"

#define kBITStoreUpdateDateOfLastCheck       @"BITStoreUpdateDateOfLastCheck"
#define kBITStoreUpdateLastStoreVersion      @"BITStoreUpdateLastStoreVersion"
#define kBITStoreUpdateLastUUID              @"BITStoreUpdateLastUUID"
#define kBITStoreUpdateIgnoreVersion         @"BITStoreUpdateIgnoredVersion"

#define BITHOCKEY_INTEGRATIONFLOW_TIMESTAMP  @"BITIntegrationFlowStartTimestamp"

#define BITHOCKEYSDK_BUNDLE @"HockeySDKResources.bundle"
#define BITHOCKEYSDK_URL @"https://sdk.hockeyapp.net/"

#define BITHockeyLog(fmt, ...) do { if([BITHockeyManager sharedHockeyManager].isDebugLogEnabled && ([BITHockeyManager sharedHockeyManager].appEnvironment != BITEnvironmentAppStore)) { NSLog((@"[HockeySDK] %s/%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); }} while(0)

#define BIT_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]

NSBundle *BITHockeyBundle(void);
NSString *BITHockeyLocalizedString(NSString *stringToken);
NSString *BITHockeyMD5(NSString *str);

#define kBITButtonTypeSystem                UIButtonTypeSystem


#endif /* HockeySDK_HockeySDKPrivate_h */
