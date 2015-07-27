#import "TestCommon.h"

@implementation TestCommon

static SCKSourceCollection *sourceCollection = nil;

- (id)init
{
    self = [super init];
    /* Prevent reparsing the source files each time a test method is run */
    BOOL parsed = (sourceCollection != nil);
    if (parsed == NO)
    {
        sourceCollection = [SCKSourceCollection new];
        //	[sourceCollection setIgnoresIncludedSymbols: YES];
        [self parseSourceFilesIntoCollection: sourceCollection];
    }
    return self;
}

- (NSArray*)parsingTestFiles
{
	NSBundle *bundle = [NSBundle bundleForClass: [self class]];
	NSArray *testFiles = [bundle pathsForResourcesOfType: @"h" inDirectory: nil];
	testFiles = [testFiles arrayByAddingObjectsFromArray:
		[bundle pathsForResourcesOfType: @"m" inDirectory: nil]];
//	ETAssert([testFiles count] >= 2);
	return testFiles;
}

- (void)parseSourceFilesIntoCollection: (SCKSourceCollection*)aSourceCollection
{
	NSParameterAssert(aSourceCollection != nil);
	
//	[aSourceCollection clear];
	
	for (NSString *path in [self parsingTestFiles])
	{
		[aSourceCollection sourceFileForPath: path];
	}
}
						
@end
