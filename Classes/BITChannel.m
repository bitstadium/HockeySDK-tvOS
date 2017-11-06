#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "HockeySDKPrivate.h"
#import "BITChannelPrivate.h"
#import "BITHockeyHelper.h"
#import "BITTelemetryContext.h"
#import "BITTelemetryData.h"
#import "BITEnvelope.h"
#import "BITData.h"
#import "BITDevice.h"
#import "BITPersistencePrivate.h"
#import "BITSender.h"

static char *const BITDataItemsOperationsQueue = "net.hockeyapp.senderQueue";
char *BITSafeJsonEventsString;

NSString *const BITChannelBlockedNotification = @"BITChannelBlockedNotification";

static NSInteger const BITDefaultMaxBatchSize  = 50;
static NSInteger const BITDefaultBatchInterval = 15;
static NSInteger const BITSchemaVersion = 2;

static NSInteger const BITDebugMaxBatchSize = 5;
static NSInteger const BITDebugBatchInterval = 3;

NS_ASSUME_NONNULL_BEGIN

@interface BITChannel ()

@property (nonatomic, weak, nullable) id appDidEnterBackgroundObserver;
@property (nonatomic, weak, nullable) id persistenceSuccessObserver;
@property (nonatomic, weak, nullable) id senderFinishSendingDataObserver;

@property (nonatomic, nonnull) dispatch_group_t senderGroup;

@end


@implementation BITChannel

@synthesize persistence = _persistence;
@synthesize channelBlocked = _channelBlocked;

#pragma mark - Initialisation

- (instancetype)init {
  if ((self = [super init])) {
    bit_resetSafeJsonStream(&BITSafeJsonEventsString);
    _dataItemCount = 0;
    if (bit_isDebuggerAttached()) {
      _maxBatchSize = BITDebugMaxBatchSize;
      _batchInterval = BITDebugBatchInterval;
    } else {
      _maxBatchSize = BITDefaultMaxBatchSize;
      _batchInterval = BITDefaultBatchInterval;
    }
    dispatch_queue_t serialQueue = dispatch_queue_create(BITDataItemsOperationsQueue, DISPATCH_QUEUE_SERIAL);
    _dataItemsOperations = serialQueue;

    _senderGroup = dispatch_group_create();

    [self registerObservers];
  }
  return self;
}

- (instancetype)initWithTelemetryContext:(BITTelemetryContext *)telemetryContext persistence:(BITPersistence *)persistence {
  if ((self = [self init])) {
    _telemetryContext = telemetryContext;
    _persistence = persistence;
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
  [self invalidateTimer];
}

#pragma mark - Observers
- (void) registerObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;

  if (nil == self.appDidEnterBackgroundObserver) {
    void (^notificationBlock)(NSNotification *note) = ^(NSNotification __unused *note) {
      typeof(self) strongSelf = weakSelf;
      BITHockeyLogDebug(@"Received background notification.");

      if ([strongSelf timerIsRunning]) {
        BITHockeyLogDebug(@"Timer running, which means we have unpersisted events. PERSISTING THEM.");

        /**
         * From the documentation for applicationDidEnterBackground:
         * It's likely any background tasks you start in applicationDidEnterBackground: will not run until after that method exits,
         * you should request additional background execution time before starting those tasks. In other words,
         * first call beginBackgroundTaskWithExpirationHandler: and then run the task on a dispatch queue or secondary thread.
         */
        UIApplication *application = [UIApplication sharedApplication];
        [strongSelf persistDataItemQueueWithBackgroundTask: application];
      }
      else {
        BITHockeyLogDebug(@"Timer is not running, no events in the queue. Not persisting stuff.");
      }
    };
    self.appDidEnterBackgroundObserver = [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                             object:nil
                                                              queue:NSOperationQueue.mainQueue
                                                         usingBlock:notificationBlock];
  }
  if (nil == self.persistenceSuccessObserver) {
    self.persistenceSuccessObserver =
    [center addObserverForName:BITPersistenceSuccessNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification __unused *notification) {
                      typeof(self) strongSelf = weakSelf;
                      dispatch_group_enter(strongSelf.senderGroup);
                    }];
  }
  if (nil == self.senderFinishSendingDataObserver) {
    self.senderFinishSendingDataObserver =
    [center addObserverForName:BITSenderFinishSendingDataNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification __unused *notification) {
                      typeof(self) strongSelf = weakSelf;
                      dispatch_group_leave(strongSelf.senderGroup);
                    }];
  }
}

- (void) unregisterObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  id appDidEnterBackgroundObserver = self.appDidEnterBackgroundObserver;
  if (appDidEnterBackgroundObserver) {
    [center removeObserver:appDidEnterBackgroundObserver];
    self.appDidEnterBackgroundObserver = nil;
  }
  id persistenceSuccessObserver = self.persistenceSuccessObserver;
  if (persistenceSuccessObserver) {
    [center removeObserver:persistenceSuccessObserver];
    self.persistenceSuccessObserver = nil;
  }
  id senderFinishSendingDataObserver = self.senderFinishSendingDataObserver;
  if (senderFinishSendingDataObserver) {
    [center removeObserver:senderFinishSendingDataObserver];
    self.senderFinishSendingDataObserver = nil;
  }
}

#pragma mark - Queue management

- (BOOL)isQueueBusy {
  if (!self.channelBlocked) {
    BOOL persistenceBusy = ![self.persistence isFreeSpaceAvailable];
    if (persistenceBusy) {
      self.channelBlocked = YES;
      [self sendBlockingChannelNotification];
    }
  }
  return self.channelBlocked;
}

- (void)persistDataItemQueue {
  [self invalidateTimer];
  if (!BITSafeJsonEventsString || strlen(BITSafeJsonEventsString) == 0) {
    return;
  }
  
  NSData *bundle = [NSData dataWithBytes:BITSafeJsonEventsString length:strlen(BITSafeJsonEventsString)];
  [self.persistence persistBundle:bundle];
  
  // Reset both, the async-signal-safe and item counter.
  [self resetQueue];
}

- (void)persistDataItemQueueWithBackgroundTask:(UIApplication *)application {
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.dataItemsOperations, ^{
    typeof(self) strongSelf = weakSelf;
    [strongSelf persistDataItemQueue];
  });
  [self createBackgroundTask:application withWaitingGroup:nil];
}

- (void)createBackgroundTask:(UIApplication *)application withWaitingGroup:(nullable dispatch_group_t)group {
  if (application == nil) {
    return;
  }
  NSArray *queues = @[
                      self.dataItemsOperations,           // For enqueue
                      self.persistence.persistenceQueue,  // For persist
                      dispatch_get_main_queue()           // For notification
                      ];
  BITHockeyLogVerbose(@"BITChannel: Start background task");
  __block UIBackgroundTaskIdentifier backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
    BITHockeyLogVerbose(@"BITChannel: Background task is expired");
    [application endBackgroundTask:backgroundTask];
    backgroundTask = UIBackgroundTaskInvalid;
  }];
  __block NSUInteger i = 0;
  __weak typeof(self) weakSelf = self;
  __block __weak void (^weakWaitBlock)();
  void (^waitBlock)();
  weakWaitBlock = waitBlock = ^{
    typeof(self) strongSelf = weakSelf;
    if (i < queues.count) {
      dispatch_queue_t queue = [queues objectAtIndex:i++];
      BITHockeyLogVerbose(@"BITChannel: Waiting queue: %@", [[NSString alloc] initWithUTF8String:dispatch_queue_get_label(queue)]);
      dispatch_async(queue, weakWaitBlock);
    } else {
      BITHockeyLogVerbose(@"BITChannel: Waiting sender");
      dispatch_group_notify(strongSelf.senderGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (backgroundTask != UIBackgroundTaskInvalid) {
          BITHockeyLogVerbose(@"BITChannel: Cancel background task");
          [application endBackgroundTask:backgroundTask];
          backgroundTask = UIBackgroundTaskInvalid;
        }
      });
    }
  };
  if (group != nil) {
    BITHockeyLogVerbose(@"BITChannel: Waiting group");
    dispatch_group_notify((dispatch_group_t)group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), waitBlock);
  } else {
    waitBlock();
  }
}


- (void)resetQueue {
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  self.dataItemCount = 0;
}

#pragma mark - Adding to queue

- (void)enqueueTelemetryItem:(BITTelemetryData *)item {
  
  if (!item) {
    // Case 1: Item is nil: Do not enqueue item and abort operation
    BITHockeyLogWarning(@"WARNING: TelemetryItem was nil.");
    return;
  }
  
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.dataItemsOperations, ^{
    typeof(self) strongSelf = weakSelf;
    
    if (strongSelf.isQueueBusy) {
      // Case 2: Channel is in blocked state: Trigger sender, start timer to check after again after a while and abort operation.
      BITHockeyLogDebug(@"INFO: The channel is saturated. %@ was dropped.", item.debugDescription);
      if (![strongSelf timerIsRunning]) {
        [strongSelf startTimer];
      }
      return;
    }
    
    // Enqueue item
    NSDictionary *dict = [self dictionaryForTelemetryData:item];
    [strongSelf appendDictionaryToJsonStream:dict];

    UIApplication *application = [UIApplication sharedApplication];
    if (strongSelf.dataItemCount >= strongSelf.maxBatchSize ||
        (application && application.applicationState == UIApplicationStateBackground)) {
      // Case 3: Max batch count has been reached or the app is running in the background, so write queue to disk and delete all items.
      [strongSelf persistDataItemQueue];
      
    } else if (strongSelf.dataItemCount == 1) {
      // Case 4: It is the first item, let's start the timer.
      if (![strongSelf timerIsRunning]) {
        [strongSelf startTimer];
      }
    }
  });
}

#pragma mark - Envelope telemerty items

- (NSDictionary *)dictionaryForTelemetryData:(BITTelemetryData *) telemetryData {
  
  BITEnvelope *envelope = [self envelopeForTelemetryData:telemetryData];
  NSDictionary *dict = [envelope serializeToDictionary];
  return dict;
}

- (BITEnvelope *)envelopeForTelemetryData:(BITTelemetryData *)telemetryData {
  telemetryData.version = @(BITSchemaVersion);
  
  BITData *data = [BITData new];
  data.baseData = telemetryData;
  data.baseType = telemetryData.dataTypeName;
  
  BITEnvelope *envelope = [BITEnvelope new];
  envelope.time = bit_utcDateString([NSDate date]);
  envelope.iKey = self.telemetryContext.appIdentifier;
  
  envelope.tags = self.telemetryContext.contextDictionary;
  envelope.data = data;
  envelope.name = telemetryData.envelopeTypeName;
  
  return envelope;
}

#pragma mark - Serialization Helper

- (NSString *)serializeDictionaryToJSONString:(NSDictionary *)dictionary {
  NSError *error;
  NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:(NSJSONWritingOptions)0 error:&error];
  if (!data) {
    BITHockeyLogError(@"ERROR: JSONSerialization error: %@", error.localizedDescription);
    return @"{}";
  } else {
    return (NSString *)[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  }
}

#pragma mark JSON Stream

- (void)appendDictionaryToJsonStream:(NSDictionary *)dictionary {
  if (dictionary) {
    NSString *string = [self serializeDictionaryToJSONString:dictionary];
    
    // Since we can't persist every event right away, we write it to a simple C string.
    // This can then be written to disk by a signal handler in case of a crash.
    bit_appendStringToSafeJsonStream(string, &(BITSafeJsonEventsString));
    self.dataItemCount += 1;

    BITHockeyLogVerbose(@"VERBOSE: Appended data to buffer:\n%@", string);
  }
}

void bit_appendStringToSafeJsonStream(NSString *string, char **jsonString) {
  if (jsonString == NULL) { return; }
  
  if (!string) { return; }
  
  if (*jsonString == NULL || strlen(*jsonString) == 0) {
    bit_resetSafeJsonStream(jsonString);
  }
  
  if (string.length == 0) { return; }
  
  char *new_string = NULL;
  // Concatenate old string with new JSON string and add a comma.
  asprintf(&new_string, "%s%.*s\n", *jsonString, (int)MIN(string.length, (NSUInteger)INT_MAX), string.UTF8String);
  free(*jsonString);
  *jsonString = new_string;
}

void bit_resetSafeJsonStream(char **string) {
  if (!string) { return; }
  free(*string);
  *string = strdup("");
}

#pragma mark - Batching

- (NSUInteger)maxBatchSize {
  if(_maxBatchSize <= 0){
    return BITDefaultMaxBatchSize;
  }
  return _maxBatchSize;
}

- (void)invalidateTimer {
  if ([self timerIsRunning]) {
    dispatch_source_cancel((dispatch_source_t)self.timerSource);
    self.timerSource = nil;
  }
}

-(BOOL)timerIsRunning {
  return self.timerSource != nil;
}

- (void)startTimer {
  // Reset timer, if it is already running
  if ([self timerIsRunning]) {
    [self invalidateTimer];
  }
  
  self.timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.dataItemsOperations);
  dispatch_source_set_timer((dispatch_source_t)self.timerSource, dispatch_walltime(NULL, NSEC_PER_SEC * self.batchInterval), 1ull * NSEC_PER_SEC, 1ull * NSEC_PER_SEC);
  
  __weak typeof(self) weakSelf = self;
  dispatch_source_set_event_handler((dispatch_source_t)self.timerSource, ^{
    typeof(self) strongSelf = weakSelf;
    
    if(strongSelf) {
      if (strongSelf.dataItemCount > 0) {
        [strongSelf persistDataItemQueue];
      } else {
        strongSelf.channelBlocked = NO;
      }
      [strongSelf invalidateTimer];
    }
  });
  
  dispatch_resume((dispatch_source_t)self.timerSource);
}

/**
 * Send a BITHockeyBlockingChannelNotification to the main thread to notify observers that channel can't enqueue new items.
 * This is typically used to trigger sending.
 */
- (void)sendBlockingChannelNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    BITHockeyLogDebug(@"Sending notification: %@", BITChannelBlockedNotification);
    [[NSNotificationCenter defaultCenter] postNotificationName:BITChannelBlockedNotification
                                                        object:nil
                                                      userInfo:nil];
  });
}

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
