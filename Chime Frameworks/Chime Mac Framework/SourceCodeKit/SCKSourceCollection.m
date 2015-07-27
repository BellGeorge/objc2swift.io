#import "SourceCodeKit.h"
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
//#import "SCKClangeSourceFile.h"


/**
 * Mapping from source file extensions to SCKSourceFile subclasses.
 */
static NSDictionary *fileClasses;

@interface SCKClangIndex : NSObject
@end

@implementation SCKSourceCollection

@synthesize bundles;

+ (void)initialize
{
	Class clang = NSClassFromString(@"SCKClangSourceFile");
	fileClasses = @{@"m": clang,
                    @"cc": clang,
                    @"c": clang,
                    @"h": clang,
                    @"cpp": clang};
}

- (id)init
{
	self = [super init];
	indexes = [NSMutableDictionary new];
	// A single clang index instance for all of the clang-supported file types
	id index = [SCKClangIndex new];
	[indexes setObject:index forKey:@"m"];
	[indexes setObject:index forKey:@"c"];
	[indexes setObject:index forKey:@"h"];
	[indexes setObject:index forKey:@"cpp"];
	[indexes setObject:index forKey:@"cc"];
	self.files = [NSMutableDictionary new];
	bundles = [NSMutableDictionary new];
	self.bundleClasses = [NSMutableDictionary new];
	int count = objc_getClassList(NULL, 0);
	Class *classList = (__unsafe_unretained Class *)calloc(sizeof(Class), count);
	objc_getClassList(classList, count);
	for (int i = 0 ; i < count; i++)
	{
		SCKClass *cls = [[SCKClass alloc] initWithClass:classList[i]];
		[self.bundleClasses setObject:cls forKey:[cls name]];
		NSBundle *b = [NSBundle bundleForClass:classList[i]];
		if (nil == b)
		{
			continue;
		}
		SCKBundle *bundle = [bundles objectForKey:[b bundlePath]];
		if (nil  == bundle)
		{
			bundle = [SCKBundle new];
			bundle.name = [b bundlePath];
			[bundles setObject:bundle forKey:[b bundlePath]];
		}
		[bundle.classes addObject:cls];
	}
	free(classList);
	return self;
}

- (NSMutableDictionary*)programComponentsFromFilesForKey:(NSString *)key
{
	NSMutableDictionary *components = [NSMutableDictionary new];
	for (SCKSourceFile *file in [self.files objectEnumerator])
	{
		[components addEntriesFromDictionary:[file valueForKey:key]];
	}
	return components;
}

- (NSDictionary*)classes
{
	NSMutableDictionary* classes = [self programComponentsFromFilesForKey: @"classes"];
	[classes addEntriesFromDictionary: self.bundleClasses];
	return classes;
}

- (NSDictionary*)functions
{
	return [self programComponentsFromFilesForKey: @"functions"];
}

- (NSDictionary*)enumerationValues
{
	return [self programComponentsFromFilesForKey: @"enumerationValues"];
}

- (NSDictionary*)enumerations
{
	return [self programComponentsFromFilesForKey: @"enumerations"];
}

- (NSDictionary*)globals
{
	return [self programComponentsFromFilesForKey: @"globals"];
}

- (SCKIndex*)indexForFileExtension:(NSString *)extension
{
	return [indexes objectForKey:extension];
}

- (SCKSourceFile*)sourceFileForPath:(NSString *)aPath
{
	NSString *path = [aPath stringByStandardizingPath];

	SCKSourceFile *file = [self.files objectForKey:path];
	if (nil != file)
	{
		return file;
	}

	NSString *extension = [path pathExtension];
	file = [[fileClasses objectForKey:extension] fileUsingIndex: [indexes objectForKey:extension]];
	file.fileName = path;
	file.collection = self;

    NSURL *URL = [NSURL fileURLWithPath:aPath];
    NSError *error;
    NSMutableString *stringFromFileAtURL = [[NSMutableString alloc]
                                     initWithContentsOfURL:URL
                                     encoding:NSUTF8StringEncoding
                                     error:&error];
    if (stringFromFileAtURL) {
        NSMutableAttributedString *source = [[NSMutableAttributedString alloc]initWithString:stringFromFileAtURL];
        file.source = source;
        [file reparse];
        [file syntaxHighlightFile];
    }
    
    

    
	if (nil != file)
	{
		[self.files setObject:file forKey:path];
	}
	else
	{
		NSLog(@"Failed to load %@", path);
	}
	return file;
}


@end
