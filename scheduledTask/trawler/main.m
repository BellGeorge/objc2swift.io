//
//  main.m
//  EnumHarvester
//
//  Created by John Pope on 18/08/2015.
//  Copyright © 2015 Marc Ransome. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Chime/SCKClangSourceFile.h>
#import <Chime/Chime.h>
#import <Chime/SCKSyntaxHighlighter.h>

int main(int argc, const char * argv[]) {
    
    // keep building
    
    @autoreleasepool {
        //argc != 2 || argv[1] == NULL ||
        if (argv[1][0] == 0) {
            fprintf(stderr, "Usage: pass in full path to a translation unit as the only argument.\n\nThis should be a .m file with Objective-C classes that do not reference system frameworks like Foundation, only themselves and C primitives. For an example, see the MyClass.h and MyClass.m files included with the project.\n\nIf you're launching from Xcode, edit the scheme and go to Arguments tab of the Run section.\n");
            
            return 1;
        } else {
            NSURL *fileURL;
            
            NSMutableArray *totalTranslations = [[NSMutableArray alloc]init];
            
            NSMutableString *headerURL = [[NSMutableString alloc]
                                          initWithContentsOfURL: [NSURL fileURLWithPath:path]
                                          encoding:NSUTF8StringEncoding
                                          error:nil];
            NSMutableAttributedString *headers = [[NSMutableAttributedString alloc]initWithString:headerURL];
            
            
            //NSLog(@"headers:%@",headers);
            // break apart the array of lines
            NSUInteger numberOfLines, index, stringLength = [headers.string length];
            
            for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++) {
                NSRange range = [headers.string lineRangeForRange:NSMakeRange(index, 0)];
                NSMutableAttributedString *filePath = [[NSMutableAttributedString alloc]init];
                [filePath setAttributedString:[headers attributedSubstringFromRange:range]];
                //NSLog(@"header:%@",filePath);
                index = NSMaxRange(range);
                
                NSMutableString *fp = [filePath.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].mutableCopy;
                
                if (filePath != nil) {
                    fileURL = [NSURL fileURLWithPath:fp];
                }
                
                if (fileURL == nil) {
                    fprintf(stderr, "Error: file path \"%s\" does not appear to be valid.\n", argv[1]);
                    
                    return 1;
                } else {
                    
                    SCKClangSourceFile *headerfile = [[SCKClangSourceFile alloc]init];
                    SCKSyntaxHighlighter *highlighter = [[SCKSyntaxHighlighter alloc]init];
                    
                    
                    NSError *error;
                    NSMutableString *stringFromFileAtURL = [[NSMutableString alloc]
                                                            initWithContentsOfURL:fileURL
                                                            encoding:NSUTF8StringEncoding
                                                            error:&error];
                    if (stringFromFileAtURL) {
                        NSMutableAttributedString *source = [[NSMutableAttributedString alloc]initWithString:stringFromFileAtURL];
                        headerfile.source = source;
                        [headerfile reparse];
                        [headerfile syntaxHighlightFile];
                        @try {
                            NSMutableArray *translations = [highlighter detectNsEnums:headerfile]; // headerfile includes a static dictionary with ivars for each interface
                            if (translations.count) {
                                [totalTranslations addObjectsFromArray:translations];
                            }
                            //
                        }
                        @catch (NSException *exception)
                        {
                            NSLog(@"exception:%@", exception);
                        }
                        @finally
                        {
                        }
                        
                    }else{
                        NSLog(@"error:%@",error);
                    }
                    
                }
            }
            
        }
        
        
    }
    return 0;
    
}


//- (void)createSwiftFileFrom:(SCKClangSourceFile *)file sourceCollection:(SCKSourceCollection *)sourceCollection {
//    // TODO - reach out to the header file and grab the lets and vars
//    if ([filePath containsString:@".m"]) {
//        
//        // Parse the header file 1st so we can build swift vars for each interface detected
//        
//        NSMutableString *headerPath = filePath.mutableCopy;
//        [headerPath replaceOccurrencesOfString:@".m" withString:@".h" options:0 range:NSMakeRange(0, headerPath.length)];
//        
//        SCKSyntaxHighlighter *highlighter = [[SCKSyntaxHighlighter alloc]init];
//        SCKClangSourceFile *headerfile = [sourceCollection.files valueForKey:headerPath];
//        
//        @try {
//            [highlighter buildInterfaceSwiftVarsForHeaderFile:headerfile]; // headerfile includes a static dictionary with ivars for each interface
//        }
//        @catch (NSException *exception)
//        {
//            NSLog(@"exception:%@", exception);
//        }
//        @finally
//        {
//        }
//        
//        
//        //transformString
//        @try {
//            
//            swiftSource = [NSMutableString string];
//            [swiftSource appendString:  [highlighter convertToSwiftSource:file sourceCollection:sourceCollection isHeader:NO]];
//            
//            NSData *data = [swiftSource dataUsingEncoding:NSUTF8StringEncoding];
//            
//            [filePath replaceOccurrencesOfString:@".m" withString:@".swift" options:0 range:NSMakeRange(0, filePath.length)];
//            NSURL *url = [NSURL fileURLWithPath:filePath];
//            [data writeToURL:url options:NSDataWritingAtomic error:NULL];
//        }
//        @catch (NSException *exception)
//        {
//            NSLog(@"exception:%@", exception);
//        }
//        @finally
//        {
//        }
//    }
//}
