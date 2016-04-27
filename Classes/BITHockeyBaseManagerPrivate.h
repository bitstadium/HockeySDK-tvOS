#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BITHockeyManager.h"

@class BITHockeyBaseManager;
@class BITHockeyBaseViewController;

@interface BITHockeyBaseManager()

@property (nonatomic, strong) NSString *appIdentifier;

@property (nonatomic, assign, readonly) BITEnvironment appEnvironment;

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier appEnvironment:(BITEnvironment)environment;

- (void)startManager;

/** 
 * by default, just logs the message
 *
 * can be overridden by subclasses to do their own error handling,
 * e.g. to show UI
 *
 * @param error NSError
 */
- (void)reportError:(NSError *)error;

/** url encoded version of the appIdentifier
 
 where appIdentifier is either the value this object was initialized with,
 or the main bundles CFBundleIdentifier if appIdentifier is nil
 */
- (NSString *)encodedAppIdentifier;

// device / application helpers
- (NSString *)getDevicePlatform;
- (NSString *)executableUUID;

// UI helpers
- (UIWindow *)findVisibleWindow;
 - (void)showView:(UIViewController *)viewController;

// Date helpers
- (NSDate *)parseRFC3339Date:(NSString *)dateString;

// keychain helpers
- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key;
- (BOOL)addStringValueToKeychainForThisDeviceOnly:(NSString *)stringValue forKey:(NSString *)key;
- (NSString *)stringValueFromKeychainForKey:(NSString *)key;
- (BOOL)removeKeyFromKeychain:(NSString *)key;

@end
