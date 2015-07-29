//
//  DDFileReader.m
//  PBX2OPML
//
//  Created by michael isbell on 11/6/11.
//  Copyright (c) 2011 BlueSwitch. All rights reserved.
//

//DDFileReader.m

#import "DDFileReader.h"
#import <Chime/SCKClangSourceFile.h>
#import <Chime/SCKSyntaxHighlighter.h>
#import <Chime/SCKSourceCollection.h>


@interface NSData (DDAdditions)

- (NSRange)rangeOfData_dd:(NSData *)dataToFind;

@end

@implementation NSData (DDAdditions)

- (NSRange)rangeOfData_dd:(NSData *)dataToFind {
    const void *bytes = [self bytes];
    NSUInteger length = [self length];
    
    const void *searchBytes = [dataToFind bytes];
    NSUInteger searchLength = [dataToFind length];
    NSUInteger searchIndex = 0;
    
    NSRange foundRange = { NSNotFound, searchLength };
    for (NSUInteger index = 0; index < length; index++) {
        if (((char *)bytes)[index] == ((char *)searchBytes)[searchIndex]) {
            //the current character matches
            if (foundRange.location == NSNotFound) {
                foundRange.location = index;
            }
            searchIndex++;
            if (searchIndex >= searchLength) {
                return foundRange;
            }
        }
        else {
            searchIndex = 0;
            foundRange.location = NSNotFound;
        }
    }
    return foundRange;
}

@end

@implementation DDFileReader
@synthesize lineDelimiter, chunkSize;



- (id)initWithFilePath:(NSString *)aPath {
    if (self = [super init]) {
        fileHandle = [NSFileHandle fileHandleForReadingAtPath:aPath];
        filePath = [NSMutableString stringWithString:aPath];
        if (fileHandle == nil) {
            return nil;
        }
        
        lineDelimiter = @"\n";
        currentOffset = 0ULL; // ???
        chunkSize = 128;
        [fileHandle seekToEndOfFile];
        totalFileLength = [fileHandle offsetInFile];
        //we don't need to seek back, since readLine will do that.
        
        
        patterns =  [NSMutableArray array];
        //        NSURL *URL = [NSURL fileURLWithPath:aPath];
        //        NSError *error;
        //        NSMutableString *stringFromFileAtURL = [[NSMutableString alloc]
        //                                                initWithContentsOfURL:URL
        //                                                encoding:NSUTF8StringEncoding
        //                                                error:&error];
        //
        
        swiftSource = [[NSMutableString alloc]init];
    }
    return self;
}

- (void)createSwiftFileFrom:(SCKClangSourceFile *)file sourceCollection:(SCKSourceCollection *)sourceCollection {
    // TODO - reach out to the header file and grab the lets and vars
    if ([filePath containsString:@".m"]) {
        
        // Parse the header file 1st so we can build swift vars for each interface detected
        
        NSMutableString *headerPath = filePath.mutableCopy;
        [headerPath replaceOccurrencesOfString:@".m" withString:@".h" options:0 range:NSMakeRange(0, headerPath.length)];
        
        SCKSyntaxHighlighter *highlighter = [[SCKSyntaxHighlighter alloc]init];
        SCKClangSourceFile *headerfile = [sourceCollection.files valueForKey:headerPath];

        @try {
            [highlighter buildInterfaceSwiftVarsForHeaderFile:headerfile]; // headerfile includes a static dictionary with ivars for each interface
        }
        @catch (NSException *exception)
        {
            NSLog(@"exception:%@", exception);
        }
        @finally
        {
        }
       
        
        //transformString
        @try {
            
            swiftSource = [NSMutableString string];
            [swiftSource appendString:  [highlighter convertToSwiftSource:file sourceCollection:sourceCollection isHeader:NO]];
            
            NSData *data = [swiftSource dataUsingEncoding:NSUTF8StringEncoding];
            
            [filePath replaceOccurrencesOfString:@".m" withString:@".swift" options:0 range:NSMakeRange(0, filePath.length)];
            NSURL *url = [NSURL fileURLWithPath:filePath];
            [data writeToURL:url options:NSDataWritingAtomic error:NULL];
        }
        @catch (NSException *exception)
        {
            NSLog(@"exception:%@", exception);
        }
        @finally
        {
        }
    }
}

- (void)dealloc {
    [fileHandle closeFile];
    currentOffset = 0ULL;
}

- (NSString *)readLine {
    if (currentOffset >= totalFileLength) {
        return nil;
    }
    
    NSData *newLineData = [lineDelimiter dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle seekToFileOffset:currentOffset];
    NSMutableData *currentData = [[NSMutableData alloc] init];
    BOOL shouldReadMore = YES;
    
    @autoreleasepool {
        while (shouldReadMore) {
            if (currentOffset >= totalFileLength) {
                break;
            }
            NSData *chunk = [fileHandle readDataOfLength:chunkSize];
            NSRange newLineRange = [chunk rangeOfData_dd:newLineData];
            if (newLineRange.location != NSNotFound) {
                //include the length so we can include the delimiter in the string
                chunk = [chunk subdataWithRange:NSMakeRange(0, newLineRange.location + [newLineData length])];
                shouldReadMore = NO;
            }
            [currentData appendData:chunk];
            currentOffset += [chunk length];
        }
    }
    
    NSString *line = [[NSString alloc] initWithData:currentData encoding:NSUTF8StringEncoding];
    return line;
}

// used in conjunction with peekline to fetch ahead contents without impacting current read line
- (NSMutableString *)nextLine {
    // initialise it
    if (runningCurrentOffset <= currentOffset || runningCurrentOffset == 0) {
        runningCurrentOffset = currentOffset;
    }
    
    
    NSData *newLineData = [lineDelimiter dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle seekToFileOffset:runningCurrentOffset];
    NSMutableData *currentData = [[NSMutableData alloc] init];
    BOOL shouldReadMore = YES;
    
    @autoreleasepool {
        while (shouldReadMore) {
            if (runningCurrentOffset >= totalFileLength) {
                break;
            }
            NSData *chunk = [fileHandle readDataOfLength:chunkSize];
            NSRange newLineRange = [chunk rangeOfData_dd:newLineData];
            if (newLineRange.location != NSNotFound) {
                //include the length so we can include the delimiter in the string
                chunk = [chunk subdataWithRange:NSMakeRange(0, newLineRange.location + [newLineData length])];
                shouldReadMore = NO;
            }
            [currentData appendData:chunk];
            runningCurrentOffset += [chunk length];
        }
    }
    
    NSString *line = [[NSString alloc] initWithData:currentData encoding:NSUTF8StringEncoding];
    return [NSMutableString stringWithString:line];
}

- (NSString *)peekLine {
    if (currentOffset >= totalFileLength) {
        return nil;
    }
    
    NSData *newLineData = [lineDelimiter dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle seekToFileOffset:currentOffset];
    NSMutableData *currentData = [[NSMutableData alloc] init];
    BOOL shouldReadMore = YES;
    
    @autoreleasepool {
        while (shouldReadMore) {
            if (currentOffset >= totalFileLength) {
                break;
            }
            NSData *chunk = [fileHandle readDataOfLength:chunkSize];
            NSRange newLineRange = [chunk rangeOfData_dd:newLineData];
            if (newLineRange.location != NSNotFound) {
                //include the length so we can include the delimiter in the string
                chunk = [chunk subdataWithRange:NSMakeRange(0, newLineRange.location + [newLineData length])];
                shouldReadMore = NO;
            }
            [currentData appendData:chunk];
            //currentOffset += [chunk length]; // just peek - don't offset
        }
    }
    
    NSString *line = [[NSString alloc] initWithData:currentData encoding:NSUTF8StringEncoding];
    return line;
}

- (NSString *)skipBlankLines {
    while ([[self peekLine]isEqualToString:@""]) {
        return [self readLine];
    }
    
    return @"";
}

//# If `line` doesn't end in a semicolon, reads & discards lines up to & including the next that does.
- (void)skipTillSemicolon:(NSString *)searchedString {
    NSError *error = nil;
    NSString *pattern = @";\\s*$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSArray *matches = [regex matchesInString:searchedString options:0 range:NSMakeRange(0, [searchedString length])];
    
    if (!matches.count) {
        [self readLine];
    }
}

//# Reads a line, processes it, and outputs it.
- (BOOL)convertNextLine {
    NSString *comment = @"";
    NSString *line = [self readLine];
    if ([line isEqualToString:@""]) {
        return NO;
    }
    NSError *error = nil;
    NSString *pattern = @"(.*)(\\s*\\/\\/.*)$"; // find back spaces / commented code
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSArray *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
    for (NSTextCheckingResult *match in matches) {
        NSString *matchText = [line substringWithRange:[match range]];
        NSLog(@"match: %@", matchText);
    }
    if (matches.count > 1) {
        line = [matches objectAtIndex:0];
        comment = [matches objectAtIndex:1];
    }
    if (line.length) {
        line = [self convertTopLevel:line];
    }
    if (currentOffset >= totalFileLength) {
        return NO;
    }
    return YES;
}

// helper
- (NSArray *)matchesRegExpression:(NSString *)pattern searchString:(NSString *)line {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSArray *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
    
    for (NSTextCheckingResult *match in matches) {
        NSString *matchText = [line substringWithRange:[match range]];
        NSLog(@">: %@", matchText);
    }
    if (matches.count) {
        return matches;
    }
    return nil;
}

- (void)parseImplementation:(NSArray *)matches line:(NSString *)line {
    NSString *className = [[line componentsSeparatedByString:@" "] objectAtIndex:1];
    NSString *swift = [NSString stringWithFormat:@"class %@ {\r", className];
    [swiftSource appendString:swift];
    [matches enumerateObjectsUsingBlock: ^(NSTextCheckingResult *match, NSUInteger idx, BOOL *__nonnull stop) {
        NSString *matchText = [line substringWithRange:[match range]];
        NSLog(@">: %@", matchText);
    }];
    
    if ([[self peekLine]isEqualToString:@"{"]) {
        NSMutableString *nextLine = [self nextLine];
        while (![nextLine isEqualToString:@"}"]) {
            //  strip out _ variable names
            [nextLine replaceOccurrencesOfString:@"_" withString:@"" options:0 range:NSMakeRange(0, nextLine.length)];
            NSArray *params = [line componentsSeparatedByString:@" "];
            NSArray *arr = [self matchesRegExpression:@"^\\s*(\\w.*)\\s+(\\w+)\\s*;/" searchString:nextLine];
            if (arr.count) {
                NSString *name = [params objectAtIndex:1];
                NSString *type = [params objectAtIndex:0];
                NSString *bla = [NSString stringWithFormat:@"private var %@: %@\r", name, type];
                [swiftSource appendString:bla];
            }
            nextLine = [self nextLine];
        }
    }
}

//# Parses an @interface block. (Currently just skips it.)
- (void)parseInterface:(NSString *)name superclass:(NSString *)superClass categoryName:(NSString *)categoryName {
    //    while nextLine() != "@end" do
    //        end
    //        skipBlankLines()
    NSLog(@"name:%@", name);
    NSLog(@"superClass:%@", superClass);
    NSLog(@"categoryName:%@", categoryName);
    
    while (![[self nextLine] isEqualToString:@"@end"]) {
    }
}

- (NSString *)convertTopLevel:(NSString *)line {
    NSArray *arr = nil;
    
    NSArray *params = [line componentsSeparatedByString:@" "];
    arr = [self matchesRegExpression:@"^\\s*#import\\s+(.*)$" searchString:line];
    if (arr.count) {
        NSLog(@"should parse import ");
    }
    arr = [self matchesRegExpression:@"^@implementation\\s+(\\w+)" searchString:line];
    if (arr.count) {
        NSLog(@"should parse implementation");
        [self parseImplementation:arr line:line];
    }
    
    arr = [self matchesRegExpression:@"^@interface\\s+(\\w+)\\s*:\\s*(\\w+)" searchString:line];
    if (arr.count) {
        NSLog(@"should parse interface");
        [self parseInterface:params[1] superclass:params[2] categoryName:nil];
    }
    arr = [self matchesRegExpression:@"^@interface\\s+(\\w+)(?:\\s*\((\\w*)\\))" searchString:line];
    if (arr.count) {
        NSLog(@"should parse interface");
        [self parseInterface:params[0] superclass:nil categoryName:params[1]];
    }
    arr = [self matchesRegExpression:@"^@end" searchString:line];
    if (arr.count) {
        NSLog(@"should parse end");
    }
    arr = [self matchesRegExpression:@"^@synthesize" searchString:line];
    if (arr.count) {
        NSLog(@"should parse synthesize");
    }
    arr = [self matchesRegExpression:@"^[+-]" searchString:line];
    if (arr.count) {
        NSLog(@"should parse +-");
    }
    
    /*
     [patterns addObject:@"^(\\s+)(}?\\s*(?:else\\s+)?if)\\s*\((.*)\\)\\s*({?)"];
     [patterns addObject:@"^(\\s+)(}?\\s*else)\\s*({?)"];
     [patterns addObject:@"^(\\s+)self\\s*=\\s*\[\\s*(.*)\\s*\\]"];
     [patterns addObject:@"^(\\s+)(\\w+)(?:\\s|\\*)+(\\w+)\\s*(?:\\=\\s*(.*))?$"];*/
    
    
    return @"";
}

- (NSString *)readTrimmedLine {
    return [[self readLine] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#if NS_BLOCKS_AVAILABLE
- (void)enumerateLinesUsingBlock:(void (^)(NSString *, BOOL *))block {
    NSString *line = nil;
    BOOL stop = NO;
    while (stop == NO && (line = [self readLine])) {
        block(line, &stop);
    }
}

#endif

@end
