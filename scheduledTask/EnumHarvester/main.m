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
            
            NSString *filePath = [NSString stringWithUTF8String:argv[1]];
            NSLog(@"filePath:%@",filePath);
            if (filePath != nil) {
                fileURL = [NSURL fileURLWithPath:filePath];
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
                }
                
                
                
                
                @try {
                    [highlighter detectNsEnums:headerfile]; // headerfile includes a static dictionary with ivars for each interface
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
    }
    return 0;
    return 0;
}
