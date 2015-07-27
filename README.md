ShimmyShimmy
===================================


Intention of project
===================================
This app is a stop gap until Xcode has a button to convert an objective-c project over to swift. 
There are potential commercial opportunities worth exploring. To discuss.


How it will work 
===================================
Fire up app - open existing workspace / project
Auto conversion of code into swift


Background
===================================
Jens Alfke  crafted this ruby hack  with regex code 
https://github.com/snej/swiftier
Be sure to point it to a wildcard  /project/*.m files and watch it fly.



Here's a more refined hack.  It's leveraging clang + and an objective-c wrapper called chime.
fire it up app - point it to an existing workspace / or project and it will start processing.

Any .m files a
 Currently it's creating swift files -> and ripping out every comment from objective-c file.
 It knows your classes / methods / functions / globals. 
The entire sourcecode file is being parsed - and I have all the variables / methods / types at disposal thanks to sourcecodekit + clang introspection.


You can step into more detail inside SCKSyntaxHighlighter

- (NSString*)convertToSwiftSource:(SCKClangSourceFile *)file;
// inside your .m file -> be sure to step through the attributes 

NSLog(@"attrs:%@",attrs);
NSLog(@"attributedSubstringFromRange:%@",[source attributedSubstringFromRange:range] );



There's two directions this project can take - 

1) Regex pattern matching  / ruby hack method in combitation with SourceCodeKit attributed string conversion 

2) ChimeTranslationUnit / clang parser


Inside IndexDocument

N.B. 

 
    BOOL useClangParser = NO;
    if(useClangParser){
        
      SCKSourceFile *implementation = [sourceCollection sourceFileForPath: fileURL.path]; //.m files
      NSMutableString *headerFile = [NSMutableString stringWithFormat:@"%@",fileURL.path];
      [headerFile replaceOccurrencesOfString:@".m" withString:@".h" options:0 range:NSMakeRange(0, headerFile.length)];
      SCKSourceFile *hFile = [sourceCollection sourceFileForPath: headerFile]; //.h files - 
        
    }else{
        ChimeTranslationUnit *tu = [[ChimeTranslationUnit alloc] initWithFileURL:fileURL arguments:arguments index:self.index];
        if (tu == nil) {
            // TODO: provide error
            NSLog(@"Couldn't create translation unit for file \"%@\"", [fileURL path]);
        } else {
            [result addObject:tu];
        }
    }


    [sourceCollection.files enumerateKeysAndObjectsUsingBlock:^(NSString *key, SCKClangSourceFile *file, BOOL * __nonnull stop) {

        if ([file isKindOfClass:[SCKClangSourceFile class]]) {

            DDFileReader *reader = [[DDFileReader alloc]initWithFilePath:file.fileName];


            NSLog(@"file.fileName:%@",file.fileName);

            [reader createSwiftFileFrom:file];


           }

    }];

C wrappers in clang ->

http://edgecasesshow.com/78



Obectivej-C to Swift Syntax Translation
https://gist.github.com/mackworth/81e81bcc0e2dc281e1a4
