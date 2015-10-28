/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import "BITHockeyHelper.h"
#import "BITKeychainUtils.h"
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#pragma mark NSString helpers

NSString *bit_URLEncodedString(NSString *inputString) {
  
  // Requires iOS 7
  if ([inputString respondsToSelector:@selector(stringByAddingPercentEncodingWithAllowedCharacters:)]) {
    return [inputString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"!*'();:@&=+$,/?%#[]"].invertedSet];
    
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                     (__bridge CFStringRef)inputString,
                                                                     NULL,
                                                                     CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                     kCFStringEncodingUTF8)
                             );
#pragma clang diagnostic pop
  }
}

NSString *bit_base64String(NSData * data, unsigned long length) {
  SEL base64EncodingSelector = NSSelectorFromString(@"base64EncodedStringWithOptions:");
  if ([data respondsToSelector:base64EncodingSelector]) {
    return [data base64EncodedStringWithOptions:0];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [data base64Encoding];
#pragma clang diagnostic pop
  }
}

NSString *bit_settingsDir(void) {
  static NSString *settingsDir = nil;
  static dispatch_once_t predSettingsDir;
  
  dispatch_once(&predSettingsDir, ^{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    // temporary directory for crashes grabbed from PLCrashReporter
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    settingsDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:BITHOCKEY_IDENTIFIER];
    
    if (![fileManager fileExistsAtPath:settingsDir]) {
      NSDictionary *attributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: 0755] forKey: NSFilePosixPermissions];
      NSError *theError = NULL;
      
      [fileManager createDirectoryAtPath:settingsDir withIntermediateDirectories: YES attributes: attributes error: &theError];
    }
  });
  
  return settingsDir;
}

BOOL bit_validateEmail(NSString *email) {
  NSString *emailRegex =
  @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
  @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
  @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
  @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
  @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
  @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
  @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
  NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegex];
  
  return [emailTest evaluateWithObject:email];
}

NSString *bit_keychainHockeySDKServiceName(void) {
  static NSString *serviceName = nil;
  static dispatch_once_t predServiceName;
  
  dispatch_once(&predServiceName, ^{
    serviceName = [NSString stringWithFormat:@"%@.HockeySDK", bit_mainBundleIdentifier()];
  });
  
  return serviceName;
}

NSComparisonResult bit_versionCompare(NSString *stringA, NSString *stringB) {
  // Extract plain version number from self
  NSString *plainSelf = stringA;
  NSRange letterRange = [plainSelf rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainSelf = [plainSelf substringToIndex: letterRange.location];
	
  // Extract plain version number from other
  NSString *plainOther = stringB;
  letterRange = [plainOther rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainOther = [plainOther substringToIndex: letterRange.location];
	
  // Compare plain versions
  NSComparisonResult result = [plainSelf compare:plainOther options:NSNumericSearch];
	
  // If plain versions are equal, compare full versions
  if (result == NSOrderedSame)
    result = [stringA compare:stringB options:NSNumericSearch];
	
  // Done
  return result;
}

NSString *bit_mainBundleIdentifier(void) {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}

NSString *bit_encodeAppIdentifier(NSString *inputString) {
  return (inputString ? bit_URLEncodedString(inputString) : bit_URLEncodedString(bit_mainBundleIdentifier()));
}

NSString *bit_appName(NSString *placeHolderString) {
  NSString *appName = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
  if (!appName)
    appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  if (!appName)
    appName = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleName"];
  if (!appName)
    appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: placeHolderString;
  
  return appName;
}

NSString *bit_UUIDPreiOS6(void) {
  // Create a new UUID
  CFUUIDRef uuidObj = CFUUIDCreate(nil);
  
  // Get the string representation of the UUID
  NSString *resultUUID = (NSString*)CFBridgingRelease(CFUUIDCreateString(nil, uuidObj));
  CFRelease(uuidObj);
  
  return resultUUID;
}

NSString *bit_UUID(void) {
  NSString *resultUUID = nil;
  
  id uuidClass = NSClassFromString(@"NSUUID");
  if (uuidClass) {
    resultUUID = [[NSUUID UUID] UUIDString];
  } else {
    resultUUID = bit_UUIDPreiOS6();
  }
  
  return resultUUID;
}

NSString *bit_appAnonID(BOOL forceNewAnonID) {
  static NSString *appAnonID = nil;
  static dispatch_once_t predAppAnonID;
  __block NSError *error = nil;
  NSString *appAnonIDKey = @"appAnonID";
  
  if (forceNewAnonID) {
    appAnonID = bit_UUID();
    // store this UUID in the keychain (on this device only) so we can be sure to always have the same ID upon app startups
    if (appAnonID) {
      // add to keychain in a background thread, since we got reports that storing to the keychain may take several seconds sometimes and cause the app to be killed
      // and we don't care about the result anyway
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [BITKeychainUtils storeUsername:appAnonIDKey
                            andPassword:appAnonID
                         forServiceName:bit_keychainHockeySDKServiceName()
                         updateExisting:YES
                          accessibility:kSecAttrAccessibleAlwaysThisDeviceOnly
                                  error:&error];
      });
    }
  } else {
    dispatch_once(&predAppAnonID, ^{
      // first check if we already have an install string in the keychain
      appAnonID = [BITKeychainUtils getPasswordForUsername:appAnonIDKey andServiceName:bit_keychainHockeySDKServiceName() error:&error];
      
      if (!appAnonID) {
        appAnonID = bit_UUID();
        // store this UUID in the keychain (on this device only) so we can be sure to always have the same ID upon app startups
        if (appAnonID) {
          // add to keychain in a background thread, since we got reports that storing to the keychain may take several seconds sometimes and cause the app to be killed
          // and we don't care about the result anyway
          dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [BITKeychainUtils storeUsername:appAnonIDKey
                                andPassword:appAnonID
                             forServiceName:bit_keychainHockeySDKServiceName()
                             updateExisting:YES
                              accessibility:kSecAttrAccessibleAlwaysThisDeviceOnly
                                      error:&error];
          });
        }
      }
    });
  }
  
  return appAnonID;
}

BOOL bit_isPreiOS7Environment(void) {
  static BOOL isPreiOS7Environment = YES;
  static dispatch_once_t checkOS;
  
  dispatch_once(&checkOS, ^{
    // NSFoundationVersionNumber_iOS_6_1 = 993.00
    // We hardcode this, so compiling with iOS 6 is possible while still being able to detect the correct environment
    
    // runtime check according to
    // https://developer.apple.com/library/prerelease/ios/documentation/UserExperience/Conceptual/TransitionGuide/SupportingEarlieriOS.html
    if (floor(NSFoundationVersionNumber) <= 993.00) {
      isPreiOS7Environment = YES;
    } else {
      isPreiOS7Environment = NO;
    }
  });
  
  return isPreiOS7Environment;
}

BOOL bit_isPreiOS8Environment(void) {
  static BOOL isPreiOS8Environment = YES;
  static dispatch_once_t checkOS8;
  
  dispatch_once(&checkOS8, ^{
    // NSFoundationVersionNumber_iOS_7_1 = 1047.25
    // We hardcode this, so compiling with iOS 7 is possible while still being able to detect the correct environment

    // runtime check according to
    // https://developer.apple.com/library/prerelease/ios/documentation/UserExperience/Conceptual/TransitionGuide/SupportingEarlieriOS.html
    if (floor(NSFoundationVersionNumber) <= 1047.25) {
      isPreiOS8Environment = YES;
    } else {
      isPreiOS8Environment = NO;
    }
  });
  
  return isPreiOS8Environment;
}

BOOL bit_isAppStoreReceiptSandbox(void) {
#if TARGET_OS_SIMULATOR
  return NO;
#else
  NSURL *appStoreReceiptURL = NSBundle.mainBundle.appStoreReceiptURL;
  NSString *appStoreReceiptLastComponent = appStoreReceiptURL.lastPathComponent;
  
  BOOL isSandboxReceipt = [appStoreReceiptLastComponent isEqualToString:@"sandboxReceipt"];
  return isSandboxReceipt;
#endif
}

BOOL bit_hasEmbeddedMobileProvision(void) {
  BOOL hasEmbeddedMobileProvision = !![[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
  return hasEmbeddedMobileProvision;
}

BOOL bit_isRunningInTestFlightEnvironment(void) {
#if TARGET_OS_SIMULATOR
  return NO;
#else
  if (bit_isAppStoreReceiptSandbox() && !bit_hasEmbeddedMobileProvision()) {
    return YES;
  }
  return NO;
#endif
}

BOOL bit_isRunningInAppStoreEnvironment(void) {
#if TARGET_OS_SIMULATOR
  return NO;
#else
  if (bit_isAppStoreReceiptSandbox() || bit_hasEmbeddedMobileProvision()) {
    return NO;
  }
  return YES;
#endif
}

BOOL bit_isRunningInAppExtension(void) {
  static BOOL isRunningInAppExtension = NO;
  static dispatch_once_t checkAppExtension;
  
  dispatch_once(&checkAppExtension, ^{
    isRunningInAppExtension = ([[[NSBundle mainBundle] executablePath] rangeOfString:@".appex/"].location != NSNotFound);
  });
  
  return isRunningInAppExtension;
}
