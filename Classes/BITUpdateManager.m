#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_UPDATES

#import <sys/sysctl.h>

#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITUpdateManagerPrivate.h"
#import "BITAppVersionMetaInfo.h"
#import "BITAlertController.h"

#if HOCKEYSDK_FEATURE_CRASH_REPORTER
#import "BITCrashManagerPrivate.h"
#endif

typedef NS_ENUM(NSInteger, BITUpdateAlertViewTag) {
  BITUpdateAlertViewTagDefaultUpdate = 0,
  BITUpdateAlertViewTagNeverEndingAlertView = 1,
  BITUpdateAlertViewTagMandatoryUpdate = 2,
};

@implementation BITUpdateManager {
  NSString *_currentAppVersion;
  
  BOOL _dataFound;
  BOOL _updateAlertShowing;
  BOOL _lastCheckFailed;
  
  NSFileManager  *_fileManager;
  NSString       *_updateDir;
  NSString       *_usageDataFile;
  
  id _appDidBecomeActiveObserver;
  id _appDidEnterBackgroundObserver;
  id _networkDidBecomeReachableObserver;
  
  BOOL _didStartUpdateProcess;
  BOOL _didEnterBackgroundState;
  
  BOOL _firstStartAfterInstall;
  
  NSNumber *_versionID;
  NSString *_versionUUID;
  NSString *_uuid;
  
  NSString *_blockingScreenMessage;
  NSDate *_lastUpdateCheckFromBlockingScreen;
}


#pragma mark - private

- (void)reportError:(NSError *)error {
  BITHockeyLogError(@"ERROR: %@", [error localizedDescription]);
  _lastCheckFailed = YES;
}


- (void)didBecomeActiveActions {
  if ([self isUpdateManagerDisabled]) return;
  
  // this is a special iOS 8 case for handling the case that the app is not moved to background
  // once the users accepts the iOS install alert button. Without this, the install process doesn't start.
  //
  // Important: The iOS dialog offers the user to deny installation, we can't find out which button
  // was tapped, so we assume the user agreed
  if (_didStartUpdateProcess) {
    _didStartUpdateProcess = NO;
    
    if ([self.delegate respondsToSelector:@selector(updateManagerWillExitApp:)]) {
      [self.delegate updateManagerWillExitApp:self];
    }
    
#if HOCKEYSDK_FEATURE_CRASH_REPORTER
    [[BITHockeyManager sharedHockeyManager].crashManager leavingAppSafely];
#endif
    
    // for now we simply exit the app, later SDK versions might optionally show an alert with localized text
    // describing the user to press the home button to start the update process
    exit(0);
  }
  
  if (!_didEnterBackgroundState) return;
  
  _didEnterBackgroundState = NO;
  
  [self checkExpiryDateReached];
  if ([self expiryDateReached]) return;
  
  [self startUsage];
  
  if ([self isCheckForUpdateOnLaunch] && [self shouldCheckForUpdates]) {
    [self checkForUpdate];
  }
}

- (void)didEnterBackgroundActions {
  _didEnterBackgroundState = NO;
  
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
    _didEnterBackgroundState = YES;
  }
}


#pragma mark - Observers
- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  if(nil == _appDidEnterBackgroundObserver) {
    _appDidEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                                                       object:nil
                                                                                        queue:NSOperationQueue.mainQueue
                                                                                   usingBlock:^(NSNotification *note) {
                                                                                     typeof(self) strongSelf = weakSelf;
                                                                                     [strongSelf didEnterBackgroundActions];
                                                                                   }];
  }
  if(nil == _appDidBecomeActiveObserver) {
    _appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf didBecomeActiveActions];
                                                                                }];
  }
  if(nil == _networkDidBecomeReachableObserver) {
    _networkDidBecomeReachableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:BITHockeyNetworkDidBecomeReachableNotification
                                                                                           object:nil
                                                                                            queue:NSOperationQueue.mainQueue
                                                                                       usingBlock:^(NSNotification *note) {
                                                                                         typeof(self) strongSelf = weakSelf;
                                                                                         [strongSelf didBecomeActiveActions];
                                                                                       }];
  }
}

- (void) unregisterObservers {
  if(_appDidEnterBackgroundObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidEnterBackgroundObserver];
    _appDidEnterBackgroundObserver = nil;
  }
  if(_appDidBecomeActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidBecomeActiveObserver];
    _appDidBecomeActiveObserver = nil;
  }
  if(_networkDidBecomeReachableObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_networkDidBecomeReachableObserver];
    _networkDidBecomeReachableObserver = nil;
  }
}


#pragma mark - Expiry

- (BOOL)expiryDateReached {
  if (self.appEnvironment != BITEnvironmentOther) return NO;
  
  if (_expiryDate) {
    NSDate *currentDate = [NSDate date];
    if ([currentDate compare:_expiryDate] != NSOrderedAscending)
      return YES;
  }
  
  return NO;
}

- (void)checkExpiryDateReached {
  if (![self expiryDateReached]) return;
  
  BOOL shouldShowDefaultAlert = YES;
  
  if ([self.delegate respondsToSelector:@selector(shouldDisplayExpiryAlertForUpdateManager:)]) {
    shouldShowDefaultAlert = [self.delegate shouldDisplayExpiryAlertForUpdateManager:self];
  }
  
  if (shouldShowDefaultAlert) {
    NSString *appName = bit_appName(BITHockeyLocalizedString(@"HockeyAppNamePlaceholder"));
    if (!_blockingScreenMessage)
      _blockingScreenMessage = [NSString stringWithFormat:BITHockeyLocalizedString(@"UpdateExpired"), appName];
    [self showBlockingScreen:_blockingScreenMessage image:@"authorize_denied.png"];
    
    if ([self.delegate respondsToSelector:@selector(didDisplayExpiryAlertForUpdateManager:)]) {
      [self.delegate didDisplayExpiryAlertForUpdateManager:self];
    }
    
    // the UI is now blocked, make sure we don't add our UI on top of it over and over again
    [self unregisterObservers];
  }
}

#pragma mark - Usage

- (void)loadAppVersionUsageData {
  self.currentAppVersionUsageTime = @0;
  
  if ([self expiryDateReached]) return;
  
  BOOL newVersion = NO;
  
  if (![[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForUUID]) {
    newVersion = YES;
  } else {
    if ([(NSString *)[[NSUserDefaults standardUserDefaults] valueForKey:kBITUpdateUsageTimeForUUID] compare:_uuid] != NSOrderedSame) {
      newVersion = YES;
    }
  }
  
  if (newVersion) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]] forKey:kBITUpdateDateOfVersionInstallation];
    [[NSUserDefaults standardUserDefaults] setObject:_uuid forKey:kBITUpdateUsageTimeForUUID];
    [self storeUsageTimeForCurrentVersion:[NSNumber numberWithDouble:0]];
  } else {
    if (![_fileManager fileExistsAtPath:_usageDataFile])
      return;
    
    NSData *codedData = [[NSData alloc] initWithContentsOfFile:_usageDataFile];
    if (codedData == nil) return;
    
    NSKeyedUnarchiver *unarchiver = nil;
    
    @try {
      unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
    }
    @catch (NSException *exception) {
      return;
    }
    
    if ([unarchiver containsValueForKey:kBITUpdateUsageTimeOfCurrentVersion]) {
      self.currentAppVersionUsageTime = [unarchiver decodeObjectForKey:kBITUpdateUsageTimeOfCurrentVersion];
    }
    
    [unarchiver finishDecoding];
  }
}

- (void)startUsage {
  if ([self expiryDateReached]) return;
  
  self.usageStartTimestamp = [NSDate date];
}

- (void)stopUsage {
  if (self.appEnvironment != BITEnvironmentOther) return;
  if ([self expiryDateReached]) return;
  
  double timeDifference = [[NSDate date] timeIntervalSinceReferenceDate] - [_usageStartTimestamp timeIntervalSinceReferenceDate];
  double previousTimeDifference = [self.currentAppVersionUsageTime doubleValue];
  
  [self storeUsageTimeForCurrentVersion:[NSNumber numberWithDouble:previousTimeDifference + timeDifference]];
}

- (void) storeUsageTimeForCurrentVersion:(NSNumber *)usageTime {
  if (self.appEnvironment != BITEnvironmentOther) return;
  
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  
  [archiver encodeObject:usageTime forKey:kBITUpdateUsageTimeOfCurrentVersion];
  
  [archiver finishEncoding];
  [data writeToFile:_usageDataFile atomically:YES];
  
  self.currentAppVersionUsageTime = usageTime;
}

- (NSString *)currentUsageString {
  double currentUsageTime = [self.currentAppVersionUsageTime doubleValue];
  
  if (currentUsageTime > 0) {
    // round (up) to 1 minute
    return [NSString stringWithFormat:@"%.0f", ceil(currentUsageTime / 60.0)*60];
  } else {
    return @"0";
  }
}

- (NSString *)installationDateString {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"MM/dd/yyyy"];
  double installationTimeStamp = [[NSUserDefaults standardUserDefaults] doubleForKey:kBITUpdateDateOfVersionInstallation];
  if (installationTimeStamp == 0.0f) {
    return [formatter stringFromDate:[NSDate date]];
  } else {
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:installationTimeStamp]];
  }
}


#pragma mark - Cache

- (void)checkUpdateAvailable {
  // check if there is an update available
  NSComparisonResult comparisonResult = bit_versionCompare(self.newestAppVersion.version, self.currentAppVersion);
  
  if (comparisonResult == NSOrderedDescending) {
    self.updateAvailable = YES;
  } else if (comparisonResult == NSOrderedSame) {
    // compare using the binary UUID and stored version id
    self.updateAvailable = NO;
    if (_firstStartAfterInstall) {
      if ([self.newestAppVersion hasUUID:_uuid]) {
        _versionUUID = [_uuid copy];
        _versionID = [self.newestAppVersion.versionID copy];
        [self saveAppCache];
      } else {
        [self.appVersions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
          if (idx > 0 && [obj isKindOfClass:[BITAppVersionMetaInfo class]]) {
            NSComparisonResult compareVersions = bit_versionCompare([(BITAppVersionMetaInfo *)obj version], self.currentAppVersion);
            BOOL uuidFound = [(BITAppVersionMetaInfo *)obj hasUUID:_uuid];
            
            if (uuidFound) {
              _versionUUID = [_uuid copy];
              _versionID = [[(BITAppVersionMetaInfo *)obj versionID] copy];
              [self saveAppCache];
              
              self.updateAvailable = YES;
            }
            
            if (compareVersions != NSOrderedSame || uuidFound) {
              *stop = YES;
            }
          }
        }];
      }
    } else {
      if ([self.newestAppVersion.versionID compare:_versionID] == NSOrderedDescending)
        self.updateAvailable = YES;
    }
  }
}

- (void)loadAppCache {
  _firstStartAfterInstall = NO;
  _versionUUID = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateInstalledUUID];
  if (!_versionUUID) {
    _firstStartAfterInstall = YES;
  } else {
    if ([_uuid compare:_versionUUID] != NSOrderedSame)
      _firstStartAfterInstall = YES;
  }
  _versionID = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateInstalledVersionID];
  _companyName = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateCurrentCompanyName];
  
  NSData *savedHockeyData = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateArrayOfLastCheck];
  NSArray *savedHockeyCheck = nil;
  if (savedHockeyData) {
    savedHockeyCheck = [NSKeyedUnarchiver unarchiveObjectWithData:savedHockeyData];
  }
  if (savedHockeyCheck) {
    self.appVersions = [NSArray arrayWithArray:savedHockeyCheck];
    [self checkUpdateAvailable];
  } else {
    self.appVersions = nil;
  }
}

- (void)saveAppCache {
  if (_companyName) {
    [[NSUserDefaults standardUserDefaults] setObject:_companyName forKey:kBITUpdateCurrentCompanyName];
  }
  if (_versionUUID) {
    [[NSUserDefaults standardUserDefaults] setObject:_versionUUID forKey:kBITUpdateInstalledUUID];
  }
  if (_versionID) {
    [[NSUserDefaults standardUserDefaults] setObject:_versionID forKey:kBITUpdateInstalledVersionID];
  }
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.appVersions];
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:kBITUpdateArrayOfLastCheck];
}


#pragma mark - Init

- (instancetype)init {
  if ((self = [super init])) {
    _delegate = nil;
    _expiryDate = nil;
    _checkInProgress = NO;
    _dataFound = NO;
    _updateAvailable = NO;
    _lastCheckFailed = NO;
    _currentAppVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    _blockingView = nil;
    _lastCheck = nil;
    _uuid = [[self executableUUID] copy];
    _versionUUID = nil;
    _versionID = nil;
    _sendUsageData = YES;
    _disableUpdateManager = NO;
    _firstStartAfterInstall = NO;
    _companyName = nil;
    _currentAppVersionUsageTime = @0;
    
    // set defaults
    self.alwaysShowUpdateReminder = YES;
    self.checkForUpdateOnLaunch = YES;
    self.updateSetting = BITUpdateCheckStartup;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateDateOfLastCheck]) {
      // we did write something else in the past, so for compatibility reasons do this
      id tempLastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:kBITUpdateDateOfLastCheck];
      if ([tempLastCheck isKindOfClass:[NSDate class]]) {
        self.lastCheck = tempLastCheck;
      }
    }
    
    if (!_lastCheck) {
      self.lastCheck = [NSDate distantPast];
    }
    
    if (!BITHockeyBundle()) {
      NSLog(@"[HockeySDK] WARNING: %@ is missing, make sure it is added!", BITHOCKEYSDK_BUNDLE);
    }
    
    _fileManager = [[NSFileManager alloc] init];
    
    _usageDataFile = [bit_settingsDir() stringByAppendingPathComponent:BITHOCKEY_USAGE_DATA];
    
    [self loadAppCache];
    
    _installationIdentification = [self stringValueFromKeychainForKey:kBITUpdateInstallationIdentification];
    
    [self loadAppVersionUsageData];
    [self startUsage];
    
    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillTerminateNotification object:nil];
    [dnc addObserver:self selector:@selector(stopUsage) name:UIApplicationWillResignActiveNotification object:nil];
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
  
  [_urlConnection cancel];
}

- (void)showCheckForUpdateAlert {
  if (self.appEnvironment != BITEnvironmentOther) return;
  if ([self isUpdateManagerDisabled]) return;
  
  if (!_updateAlertShowing) {
    NSString *title = BITHockeyLocalizedString(@"UpdateAvailable");
    NSString *messageKey = ([self hasNewerMandatoryVersion]) ? @"UpdateAlertMandatoryTextWithAppVersion" : @"UpdateAlertTextWithAppVersion";
    NSString *message = [NSString stringWithFormat:BITHockeyLocalizedString(messageKey), [self.newestAppVersion nameAndVersionString]];
    
    __weak typeof(self) weakSelf = self;
    BITAlertController *alertController = [BITAlertController alertControllerWithTitle:title message:message];
    [alertController addCancelActionWithTitle:BITHockeyLocalizedString(@"HockeyOK")
                                      handler:^(UIAlertAction * action) {
                                        typeof(self) strongSelf = weakSelf;
                                        _updateAlertShowing = NO;
                                        if ([strongSelf expiryDateReached] && !strongSelf.blockingView) {
                                          [strongSelf alertFallback:_blockingScreenMessage];
                                        }
                                      }];
    [alertController show];
    
    _updateAlertShowing = YES;
  }
}


// open an authorization screen
- (void)showBlockingScreen:(NSString *)message image:(NSString *)image {
  self.blockingView = nil;
  
  UIWindow *visibleWindow = [self findVisibleWindow];
  if (visibleWindow == nil) {
    [self alertFallback:message];
    return;
  }
  
  CGRect frame = [visibleWindow frame];
  
  self.blockingView = [[UIView alloc] initWithFrame:frame];
  UIImageView *backgroundView = [[UIImageView alloc] initWithImage:bit_imageNamed(@"bg.png", BITHOCKEYSDK_BUNDLE)];
  backgroundView.contentMode = UIViewContentModeScaleAspectFill;
  backgroundView.frame = frame;
  [self.blockingView addSubview:backgroundView];
  
  if (image != nil) {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:bit_imageNamed(image, BITHOCKEYSDK_BUNDLE)];
    imageView.contentMode = UIViewContentModeCenter;
    imageView.frame = frame;
    [self.blockingView addSubview:imageView];
  }
  
  if (!self.disableUpdateCheckOptionWhenExpired) {
    UIButton *checkForUpdateButton = [UIButton buttonWithType:kBITButtonTypeSystem];
    checkForUpdateButton.frame = CGRectMake((frame.size.width - 140) / 2.f, frame.size.height - 100, 140, 25);
    [checkForUpdateButton setTitle:BITHockeyLocalizedString(@"UpdateButtonCheck") forState:UIControlStateNormal];
    [checkForUpdateButton addTarget:self
                             action:@selector(checkForUpdateForExpiredVersion)
                   forControlEvents:UIControlEventTouchUpInside];
    [self.blockingView addSubview:checkForUpdateButton];
  }
  
  if (message != nil) {
    frame.origin.x = 20;
    frame.origin.y = frame.size.height - 180;
    frame.size.width -= 40;
    frame.size.height = 70;
    
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = message;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 3;
    label.adjustsFontSizeToFitWidth = YES;
    label.backgroundColor = [UIColor clearColor];
    
    [self.blockingView addSubview:label];
  }
  
  [visibleWindow addSubview:self.blockingView];
}

- (void)checkForUpdateForExpiredVersion {
  if (!self.checkInProgress) {
    
    if (!_lastUpdateCheckFromBlockingScreen ||
        fabs([NSDate timeIntervalSinceReferenceDate] - [_lastUpdateCheckFromBlockingScreen timeIntervalSinceReferenceDate]) > 60) {
      _lastUpdateCheckFromBlockingScreen = [NSDate date];
      [self sendCheckForUpdateRequest];
    }
  }
}

// nag the user with neverending alerts if we cannot find out the window for presenting the covering sheet
- (void)alertFallback:(NSString *)message {
  __weak typeof(self) weakSelf = self;
  
  BITAlertController *alertController = [BITAlertController alertControllerWithTitle:nil message:message];
  [alertController addDefaultActionWithTitle:BITHockeyLocalizedString(@"HockeyOK")
                                     handler:^(UIAlertAction * action) {
                                       typeof(self) strongSelf = weakSelf;
                                       [strongSelf alertFallback:_blockingScreenMessage];
                                     }];
  
  if (!self.disableUpdateCheckOptionWhenExpired && [message isEqualToString:_blockingScreenMessage]) {
    
    [alertController addDefaultActionWithTitle:BITHockeyLocalizedString(@"UpdateButtonCheck")
                                       handler:^(UIAlertAction * action) {
                                         typeof(self) strongSelf = weakSelf;
                                         [strongSelf checkForUpdateForExpiredVersion];
                                       }];
  }
  
  [alertController show];
}

#pragma mark - RequestComments

- (BOOL)shouldCheckForUpdates {
  BOOL checkForUpdate = NO;
  
  switch (self.updateSetting) {
    case BITUpdateCheckStartup:
      checkForUpdate = YES;
      break;
    case BITUpdateCheckDaily: {
      NSTimeInterval dateDiff = fabs([self.lastCheck timeIntervalSinceNow]);
      if (dateDiff != 0)
        dateDiff = dateDiff / (60*60*24);
      
      checkForUpdate = (dateDiff >= 1);
      break;
    }
    case BITUpdateCheckManually:
      checkForUpdate = NO;
      break;
    default:
      break;
  }
  
  return checkForUpdate;
}

- (void)checkForUpdate {
  if ((self.appEnvironment == BITEnvironmentOther) && ![self isUpdateManagerDisabled]) {
    if ([self expiryDateReached]) return;
    if (![self installationIdentified]) return;
    
    if (self.isUpdateAvailable && [self hasNewerMandatoryVersion]) {
      [self showCheckForUpdateAlert];
    }
    [self sendCheckForUpdateRequest];
  }
}

- (void)sendCheckForUpdateRequest {
  if (self.appEnvironment != BITEnvironmentOther) return;
  if (self.isCheckInProgress) return;
  
  self.checkInProgress = YES;
  
  // do we need to update?
  if (![self shouldCheckForUpdates] && _updateSetting != BITUpdateCheckManually) {
    BITHockeyLogDebug(@"INFO: Update not needed right now");
    self.checkInProgress = NO;
    return;
  }
  
  NSURLRequest *request = [self requestForUpdateCheck];
  
  
  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:(id<NSURLSessionDelegate>)self delegateQueue:nil];
  
  NSURLSessionDataTask *sessionTask = [session dataTaskWithRequest:request];
  if (!sessionTask) {
    self.checkInProgress = NO;
    [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                          code:BITUpdateAPIClientCannotCreateConnection
                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Url Connection could not be created.", NSLocalizedDescriptionKey, nil]]];
  }else{
    [sessionTask resume];
  }
}

- (NSURLRequest *)requestForUpdateCheck {
  NSString *path = [NSString stringWithFormat:@"api/2/apps/%@", self.appIdentifier];
  NSString *urlEncodedPath = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
  
  NSMutableString *parameters = [NSMutableString stringWithFormat:@"?format=json&extended=true&sdk=%@&sdk_version=%@&uuid=%@",
                                 BITHOCKEY_NAME,
                                 BITHOCKEY_VERSION,
                                 _uuid];
  
  // add installationIdentificationType and installationIdentifier if available
  if (self.installationIdentification && self.installationIdentificationType) {
    [parameters appendFormat:@"&%@=%@",
     self.installationIdentificationType,
     self.installationIdentification
     ];
  }
  
  // add additional statistics if user didn't disable flag
  if (_sendUsageData) {
    [parameters appendFormat:@"&app_version=%@&os=iOS&os_version=%@&device=%@&lang=%@&first_start_at=%@&usage_time=%@",
     [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
     [[UIDevice currentDevice] systemVersion],
     [self getDevicePlatform],
     [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0],
     [self installationDateString],
     [self currentUsageString]
     ];
  }
  NSString *urlEncodedParameters = [parameters stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
  
  // build request & send
  NSString *url = [NSString stringWithFormat:@"%@%@%@", self.serverURL, urlEncodedPath, urlEncodedParameters];
  BITHockeyLogDebug(@"INFO: Sending api request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                     timeoutInterval:10.0];
  [request setHTTPMethod:@"GET"];
  [request setValue:@"Hockey/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  return request;
}

// begin the startup process
- (void)startManager {
  if (self.appEnvironment == BITEnvironmentOther) {
    if ([self isUpdateManagerDisabled]) return;
    
    BITHockeyLogWarning(@"INFO: Starting UpdateManager");
    
    if ([self.delegate respondsToSelector:@selector(updateManagerShouldSendUsageData:)]) {
      self.sendUsageData = [self.delegate updateManagerShouldSendUsageData:self];
    }
    
    [self checkExpiryDateReached];
    if (![self expiryDateReached]) {
      if ([self isCheckForUpdateOnLaunch] && [self shouldCheckForUpdates]) {
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) return;
        
        [self performSelector:@selector(checkForUpdate) withObject:nil afterDelay:1.0f];
      }
    }
  }
  [self registerObservers];
}

#pragma mark - Handle responses

- (void)handleError:(NSError *)error {
  self.receivedData = nil;
  self.urlConnection = nil;
  self.checkInProgress = NO;
  if ([self expiryDateReached]) {
    if (!self.blockingView) {
      [self alertFallback:_blockingScreenMessage];
    }
  } else {
    [self reportError:error];
  }
}

- (void)finishLoading {
  {
    self.checkInProgress = NO;
    
    if ([self.receivedData length]) {
      NSString *responseString = [[NSString alloc] initWithBytes:[_receivedData bytes] length:[_receivedData length] encoding: NSUTF8StringEncoding];
      BITHockeyLogDebug(@"INFO: Received API response: %@", responseString);
      
      if (!responseString || ![responseString dataUsingEncoding:NSUTF8StringEncoding]) {
        self.receivedData = nil;
        self.urlConnection = nil;
        return;
      }
      
      NSError *error = nil;
      NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
      
      self.companyName = (([[json valueForKey:@"company"] isKindOfClass:[NSString class]]) ? [json valueForKey:@"company"] : nil);
      
      if (self.appEnvironment == BITEnvironmentOther) {
        NSArray *feedArray = (NSArray *)[json valueForKey:@"versions"];
        
        // remember that we just checked the server
        self.lastCheck = [NSDate date];
        
        // server returned empty response?
        if (![feedArray count]) {
          BITHockeyLogDebug(@"WARNING: No versions available for download on HockeyApp.");
          self.receivedData = nil;
          self.urlConnection = nil;
          return;
        } else {
          _lastCheckFailed = NO;
        }
        
        
        NSString *currentAppCacheVersion = [[self newestAppVersion].version copy];
        
        // clear cache and reload with new data
        NSMutableArray *tmpAppVersions = [NSMutableArray arrayWithCapacity:[feedArray count]];
        for (NSDictionary *dict in feedArray) {
          BITAppVersionMetaInfo *appVersionMetaInfo = [BITAppVersionMetaInfo appVersionMetaInfoFromDict:dict];
          if ([appVersionMetaInfo isValid]) {
            // check if minOSVersion is set and this device qualifies
            BOOL deviceOSVersionQualifies = YES;
            if ([appVersionMetaInfo minOSVersion] && ![[appVersionMetaInfo minOSVersion] isKindOfClass:[NSNull class]]) {
              NSComparisonResult comparisonResult = bit_versionCompare(appVersionMetaInfo.minOSVersion, [[UIDevice currentDevice] systemVersion]);
              if (comparisonResult == NSOrderedDescending) {
                deviceOSVersionQualifies = NO;
              }
            }
            
            if (deviceOSVersionQualifies)
              [tmpAppVersions addObject:appVersionMetaInfo];
          } else {
            [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                                  code:BITUpdateAPIServerReturnedInvalidData
                                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Invalid data received from server.", NSLocalizedDescriptionKey, nil]]];
          }
        }
        // only set if different!
        if (![self.appVersions isEqualToArray:tmpAppVersions]) {
          self.appVersions = [tmpAppVersions copy];
        }
        [self saveAppCache];
        
        [self checkUpdateAvailable];
        BOOL newVersionDiffersFromCachedVersion = ![self.newestAppVersion.version isEqualToString:currentAppCacheVersion];
        
        if (self.isUpdateAvailable && (self.alwaysShowUpdateReminder || newVersionDiffersFromCachedVersion || [self hasNewerMandatoryVersion])) {
          if (_updateAvailable) {
            [self showCheckForUpdateAlert];
          }
        }
      }
    } else if (![self expiryDateReached]) {
      [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                            code:BITUpdateAPIServerReturnedEmptyResponse
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned an empty response.", NSLocalizedDescriptionKey, nil]]];
    }
    
    if (!_updateAlertShowing && [self expiryDateReached] && !self.blockingView) {
      [self alertFallback:_blockingScreenMessage];
    }
    
    self.receivedData = nil;
    self.urlConnection = nil;
  }
}

#pragma mark - NSURLSession

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [session finishTasksAndInvalidate];
    if(error){
      [self handleError:error];
    }else{
      [self finishLoading];
    }
  });
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
  [_receivedData appendData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
  
  if ([response respondsToSelector:@selector(statusCode)]) {
    NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
    if (statusCode == 404) {
      [dataTask cancel];
      NSString *errorStr = [NSString stringWithFormat:@"Hockey API received HTTP Status Code %ld", (long)statusCode];
      [self reportError:[NSError errorWithDomain:kBITUpdateErrorDomain
                                            code:BITUpdateAPIServerReturnedInvalidStatus
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorStr, NSLocalizedDescriptionKey, nil]]];
      if (completionHandler) { completionHandler(NSURLSessionResponseCancel); }
      return;
    }
    if (completionHandler) { completionHandler(NSURLSessionResponseAllow);}
  }
  
  self.receivedData = [NSMutableData data];
  [_receivedData setLength:0];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
  NSURLRequest *newRequest = request;
  if (response) {
    newRequest = nil;
  }
  if (completionHandler) { completionHandler(newRequest); }
}

- (BOOL)hasNewerMandatoryVersion {
  BOOL result = NO;
  
  for (BITAppVersionMetaInfo *appVersion in self.appVersions) {
    if ([appVersion.version isEqualToString:self.currentAppVersion] || bit_versionCompare(appVersion.version, self.currentAppVersion) == NSOrderedAscending) {
      break;
    }
    
    if ([appVersion.mandatory boolValue]) {
      result = YES;
    }
  }
  
  return result;
}

#pragma mark - Properties

- (NSString *)currentAppVersion {
  return _currentAppVersion;
}

- (void)setLastCheck:(NSDate *)aLastCheck {
  if (_lastCheck != aLastCheck) {
    _lastCheck = [aLastCheck copy];
    
    [[NSUserDefaults standardUserDefaults] setObject:_lastCheck forKey:kBITUpdateDateOfLastCheck];
  }
}

- (void)setAppVersions:(NSArray *)anAppVersions {
  if (_appVersions != anAppVersions || !_appVersions) {
    [self willChangeValueForKey:@"appVersions"];
    
    // populate with default values (if empty)
    if (![anAppVersions count]) {
      BITAppVersionMetaInfo *defaultApp = [[BITAppVersionMetaInfo alloc] init];
      defaultApp.name = bit_appName(BITHockeyLocalizedString(@"HockeyAppNamePlaceholder"));
      defaultApp.version = _currentAppVersion;
      defaultApp.shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
      _appVersions = [NSArray arrayWithObject:defaultApp];
    } else {
      _appVersions = [anAppVersions copy];
    }
    [self didChangeValueForKey:@"appVersions"];
  }
}

- (BITAppVersionMetaInfo *)newestAppVersion {
  BITAppVersionMetaInfo *appVersion = [_appVersions objectAtIndex:0];
  return appVersion;
}

- (void)setBlockingView:(UIView *)anBlockingView {
  if (_blockingView != anBlockingView) {
    [_blockingView removeFromSuperview];
    _blockingView = anBlockingView;
  }
}

- (void)setInstallationIdentificationType:(NSString *)installationIdentificationType {
  if (![_installationIdentificationType isEqualToString:installationIdentificationType]) {
    // we already use "uuid" in our requests for providing the binary UUID to the server
    // so we need to stick to "udid" even when BITAuthenticator is providing a plain uuid
    if ([installationIdentificationType isEqualToString:@"uuid"]) {
      _installationIdentificationType = @"udid";
    } else {
      _installationIdentificationType = installationIdentificationType;
    }
  }
}

- (void)setInstallationIdentification:(NSString *)installationIdentification {
  if (![_installationIdentification isEqualToString:installationIdentification]) {
    if (installationIdentification) {
      [self addStringValueToKeychain:installationIdentification forKey:kBITUpdateInstallationIdentification];
    } else {
      [self removeKeyFromKeychain:kBITUpdateInstallationIdentification];
    }
    _installationIdentification = installationIdentification;
    
    // we need to reset the usage time, because the user/device may have changed
    [self storeUsageTimeForCurrentVersion:[NSNumber numberWithDouble:0]];
    self.usageStartTimestamp = [NSDate date];
  }
}

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
