//
//  BITCrashReportTextFormatterPrivate.h
//  HockeySDK
//
//  Created by Lukas Spieß on 27/01/16.
//
//

#import "BITCrashReportTextFormatter.h"

@interface BITCrashReportTextFormatter ()

+ (NSString *)anonymizedProcessPathFromProcessPath:(NSString *)processPath;

@end
