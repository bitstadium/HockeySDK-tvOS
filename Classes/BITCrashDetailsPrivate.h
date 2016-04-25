extern NSString *const __attribute__((unused)) kBITCrashKillSignal;

@interface BITCrashDetails () {
  
}

- (instancetype)initWithIncidentIdentifier:(NSString *)incidentIdentifier
                               reporterKey:(NSString *)reporterKey
                                    signal:(NSString *)signal
                             exceptionName:(NSString *)exceptionName
                           exceptionReason:(NSString *)exceptionReason
                              appStartTime:(NSDate *)appStartTime
                                 crashTime:(NSDate *)crashTime
                                 osVersion:(NSString *)osVersion
                                   osBuild:(NSString *)osBuild
                                appVersion:(NSString *)appVersion
                                  appBuild:(NSString *)appBuild
                      appProcessIdentifier:(NSUInteger)appProcessIdentifier;

@end
