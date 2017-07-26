#import <Foundation/Foundation.h>
#import "HockeySDKNullability.h"

NS_ASSUME_NONNULL_BEGIN
@interface BITOrderedDictionary : NSMutableDictionary
  @property (nonatomic, strong) NSMutableDictionary *dictionary;
  @property (nonatomic, strong) NSMutableArray *order;

- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey;

@end
NS_ASSUME_NONNULL_END
