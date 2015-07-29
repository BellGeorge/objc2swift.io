ShimmyShimmy
===================================


Intention of project
===================================
This attached sourcecode is a stop gap until Xcode has a button to convert an objective-c project over to swift. 
There are potential commercial opportunities worth exploring. To discuss.


Conversion Process from Objective-C syntax to Swift 
===================================
The most important first step is to run Apple's "Convert to Modern Objective-C Syntax" refactoring, so that you're 
using array/dictionary literals and bracket-accesses; these will then be usable in Swift. 


| When you see this pattern                                     | Replace with this                                                                                                  | STATUS |
|---------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|--------|
| Module                                                        |                                                                                                                    |        |
| @interface *newType* : *superType* <*protocol1*, *protocol2*> | class *newType* : *superType*, *protocol1*, *protocol2*                                                            | OK     |
| @implementation OR @synthesize OR @end                        | Delete                                                                                                             | OK     |
| Properties                                                    |                                                                                                                    |        |
| property(…) TypeName * varName;                               | var varName:TypeName                                                                                               | OK     |
| property (readonly...) TypeName * varName;                    | let varName:TypeName                                                                                               | OK     |
| property(…) TypeName * IBOutlet varName;                      | @IBOutlet var varName:TypeName                                                                                     | TODO   |
| _property                                                     | self.property                                                                                                      |        |
| Compiler Directives                                           |                                                                                                                    |        |
| #import module.h                                              | Obj-C modules: Include in ...-Bridging-Header.h Project modules: DeleteFrameworks: import module                   | OK     |
| #define macroName value                                       | let macroName = value                                                                                              | TODO   |
| More complex#define / #ifdef / #ifndef                        | N/A                                                                                                                | OK     |
| #elif value                                                   | #elseif value                                                                                                      | OK     |
| #pragma mark sectionName                                      | // MARK: sectionName (not implemented yet)                                                                         | OK     |
| NSAssert(conditon,description)                                | assert(condition, description)                                                                                     | TODO   |
| Types                                                         |                                                                                                                    |        |
| NSString *                                                    | String                                                                                                             | TODO   |
| NSArray * arrayName = arrayValue                              | let arrayName = arrayValue ORlet arrayName: Array<TypeName> = arrayValue OR let arrayName: TypeName[] = arrayValue | DRAFTED|
| NSDictionary *                                                | Dictionary                                                                                                         | TODO   |
| NSMutableArray OR NSMutableDictionary ...                     | var arrayName...                                                                                                   | OK     |
| id                                                            | AnyObject                                                                                                          | OK     |
| TypeName *                                                    | TypeName                                                                                                           | OK     |
| c types, e.g. uint32 OR float                                 | Titlecase , e.g. UInt32 or Float                                                                                   | OK     |
| NSInteger OR NSUInteger                                       | Int OR UInt                                                                                                        | OK     |
| Method Definitions                                            |                                                                                                                    | OK     |
| -(void) methodName                                            | func methodName()                                                                                                  | OK     |
| -(TypeName) methodName                                        | func methodName() -> TypeName                                                                                      | OK     |
| -(IBAction) methodName                                        | @IBAction func methodName                                                                                          | TODO   |
| #ERROR!                                                       | class func methodName() -> TypeName                                                                                | OK     |
| ...methodName: (Type1) param1 b: (Type2) param2               | ...methodName(param: Type1 b param2: Typ2)                                                                         | DRAFTED|
| method overriden from superclass                              | add override                                                                                                       | TODO   |
| Variables                                                     |                                                                                                                    |        |
| TypeName varName = value                                      | var (OR let) name = value OR var (OR let) name: TypeName if necessary                                              |  OK    |
| Object Creation                                               |                                                                                                                    |        |
| TypeName * varName = [[TypeName alloc] init]                  | varName = TypeName()                                                                                               |  OK    |
| [[TypeName alloc] initWithA: value1 B: value2]                | TypeName(a: value1, b: value2)                                                                                     | DRAFTED|
| [TypeName TypeNameWithA: value]                               | TypeName(a: value)                                                                                                 |  OK    |
| Statements                                                    |                                                                                                                    |        |
| break in switch statements                                    | not necessary, except for empty cases,but add fallthrough where needed                                             |        |
| if/while (expr)                                               | if/while expr, parentheses optional,but expr must now be a boolean                                                 |        |
| for ( ... )                                                   | for ..., optional                                                                                                  | TODO   |
| Method Calls                                                  |                                                                                                                    |        |
| [object method]                                               | object.method()                                                                                                    | OK     |
| [object method: param1 b: param2 …]                           | object.method(param1, b: param2, …)                                                                                | DRAFTED|
| Expressions                                                   |                                                                                                                    |        |
| YES                                                           | TRUE                                                                                                               | OK     |
| NO                                                            | FALSE                                                                                                              | OK     |
| (TypeName) value to recast                                    | value as TypeName OR TypeName(value)                                                                               | TODO   |
| stringName.length                                             | stringName.utf16 ORstringName.countElements                                                                        | TODO   |
| stringName isEqualToString: string2Name                       | stringName == string2Name                                                                                          | TODO   |
| NSString stringWithFormat@"...%@..%d",obj,int)                | ...\(obj)...\(int)                                                                                                 | TODO   |
| Miscellaneous                                                 |                                                                                                                    |        |
| semicolons at end of line                                     | Optionally delete                                                                                                  |  OK    |
| @ for literals                                                | Delete                                                                                                             |  OK    |

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
