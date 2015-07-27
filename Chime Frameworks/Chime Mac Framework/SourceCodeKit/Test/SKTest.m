//
//  SKTest.m
//  Chime Mac Framework
//
//  Created by John Pope on 23/07/2015.
//  Copyright © 2015 Andrew Pontious. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestCommon.h"

@interface SKTest : XCTestCase

@end

@implementation SKTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    TestCommon *t = [[TestCommon alloc]init];
    [t parsingTestFiles];
    //[t parseSourceFilesIntoCollection];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
