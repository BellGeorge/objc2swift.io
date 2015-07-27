#import <Foundation/Foundation.h>

#import "SCKSourceCollection.h"
#import "SCKIntrospection.h"

#define SA(x) [NSSet setWithArray: x]

@interface TestCommon : NSObject 
{

}

- (NSArray*)parsingTestFiles;
- (void)parseSourceFilesIntoCollection: (SCKSourceCollection*)aSourceCollection;

@end
