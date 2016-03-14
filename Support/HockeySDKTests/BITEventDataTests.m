#import <XCTest/XCTest.h>
#import "BITEventData.h"
#import "BITOrderedDictionary.h"

@interface BITEventDataTests : XCTestCase

@end

@implementation BITEventDataTests

- (void)testverPropertyWorksAsExpected {
    NSNumber *expected = @42;
    BITEventData *item = [BITEventData new];
    item.version = expected;
    NSNumber *actual = item.version;
    XCTAssertTrue([actual isEqual:expected]);
    
    expected = @13;
    item.version = expected;
    actual = item.version;
    XCTAssertTrue([actual isEqual:expected]);
}

- (void)testnamePropertyWorksAsExpected {
    NSString *expected = @"Test string";
    BITEventData *item = [BITEventData new];
    item.name = expected;
    NSString *actual = item.name;
    XCTAssertTrue([actual isEqualToString:expected]);
    
    expected = @"Other string";
    item.name = expected;
    actual = item.name;
    XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testPropertiesPropertyWorksAsExpected {
    BITEventData *item = [BITEventData new];
    BITOrderedDictionary *actual = (BITOrderedDictionary *)item.properties;
    XCTAssertNotNil(actual, @"Pass");
}

- (void)testSerialize {
    BITEventData *item = [BITEventData new];
    item.version = @42;
    item.name = @"Test string";
    item.properties = [BITOrderedDictionary dictionaryWithObjectsAndKeys: @"test value 1", @"key1", @"test value 2", @"key2", nil];
  
    NSString *actual = [item serializeToString];
    NSString *expected = @"{\"ver\":42,\"name\":\"Test string\",\"properties\":{\"key1\":\"test value 1\",\"key2\":\"test value 2\"}}";
    XCTAssertTrue([actual isEqualToString:expected]);
}

@end
