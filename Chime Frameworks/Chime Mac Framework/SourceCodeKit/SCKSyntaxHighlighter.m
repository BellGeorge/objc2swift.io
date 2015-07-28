#import "SCKSyntaxHighlighter.h"
#import <Cocoa/Cocoa.h>
#import "SCKTextTypes.h"
#include <time.h>
#import "SCKClangSourceFile.h"
#import "SCKIntrospection.h"
#include <objc/runtime.h>
#import <Chime/SCKSourceCollection.h>
#import <Chime/RegExCategories.h>



static NSDictionary *noAttributes;

#define kMyHiddenTextAttribute @"kMyHiddenTextAttribute"
#define kTextFormatNameStem @"com.mackerron.fmt."

#define kIsLineDeleted @"kIsLineDeleted"
#define kAttributeString @"kAttributeString"
#define kCachedString @"kCachedString"


@interface NSMutableDictionary (addon)
-(void)setTranslatedText:(NSString*)text forKey:(NSString*)key;
@end
@implementation NSMutableDictionary (addon)

-(void)setTranslatedText:(NSString*)text forKey:(NSString*)key{
    
}

@end
@interface NSMutableAttributedString (addons)
-(NSMutableArray*)lines;
//-(void)updateAttributeAtLine:(NSInteger)line attributeString:(NSMutableAttributedString*)attributeString;
//-(void)removeRowAtIndex:(NSUInteger)rowIndex;
-(NSMutableString*)replaceOccurrencesOfString:(NSString*)str0 withString:(NSString*)str1;
@property (nonatomic, strong) id associatedObject;
@end

@implementation NSMutableAttributedString  (addons)

// so you change a line - and want the modified lines back as one string ....
-(NSMutableAttributedString*)cookedAttributeText{
    NSMutableAttributedString *newStr =[[NSMutableAttributedString alloc]init];

    [self.lines enumerateObjectsUsingBlock:^(NSMutableDictionary *d0 , NSUInteger idx, BOOL *stop) {
        NSMutableAttributedString *line = [d0 valueForKey:kAttributeString];
        if (![[d0 valueForKey:kIsLineDeleted] boolValue]) {
            [newStr appendAttributedString:line];
        }
    }];
    return newStr;
}

//-(void)updateAttributeAtLine:(NSInteger)line attributeString:(NSMutableAttributedString*)aStr{
//    NSMutableDictionary *d0 = [[self lines] objectAtIndex:line];
//      [d0 setObject:aStr forKey:kAttributeString];
//
//}
// has a bug
//-(void)removeRowAtIndex:(NSUInteger)rowIndex{
//    if (self.lines.count < rowIndex){
//        NSMutableDictionary *d0 =  [self.lines objectAtIndex:rowIndex];
//        [d0 setObject:@1 forKey:kIsLineDeleted];
//    }
// 
//}

// warning - this will strip out the attributes.
-(NSMutableAttributedString*)destroyAttributesAndReplaceOccurrencesOfString:(NSString*)str0 withString:(NSString*)str1{
 
    NSMutableString *mStr = [[NSMutableString alloc]initWithString:self.string];
    [mStr replaceOccurrencesOfString:str0 withString:str1 options:0 range:NSMakeRange(0, self.string.length)];
    NSMutableAttributedString *newStr =[[NSMutableAttributedString alloc]initWithString:mStr];
    return newStr;
 
}
// TODO - revisit this fragile category monster.
// The intention was to allow an array cursor for every line in source file.
// We need to keep around the entire source file with all NSMutableAttributedString row /lines in tact
// to  manipulate the highlighted content and not lose any introspected data as the highlight syntax is a one shot process.
// it's safer to hide the rows than to delete content or alter ranges.
//
-(NSMutableArray*)lines{

     NSMutableArray *arr1;
    static NSMutableDictionary *d0 =nil;
    static NSString *lastAttribute = nil;
    
    if (d0 == nil ) {
        d0 = [NSMutableDictionary dictionary];
        arr1 =[[NSMutableArray alloc]init];
        lastAttribute = self.string;
         [d0 setObject:arr1 forKey:self.string];
    }else{
        if ([lastAttribute isEqualToString:self.string]){
             arr1 = [d0 valueForKey:self.string];
             NSLog(@"line count:%d",(int)arr1.count);
            return arr1;
            
        }else{
            // we're switching attributes / flush out previous lines.
            [d0 removeObjectForKey:lastAttribute];
            lastAttribute = self.string;
            arr1 =[[NSMutableArray alloc]init];
            [d0 setObject:arr1 forKey:self.string];
        }
    }
    
    // break apart the array of lines
    NSUInteger numberOfLines, index, stringLength = [self.string length];
    
    for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++){
        NSRange range = [self.string lineRangeForRange:NSMakeRange(index, 0)];
        NSMutableAttributedString *newStr =[[NSMutableAttributedString alloc]init];
        [newStr setAttributedString: [self attributedSubstringFromRange:range]];
        NSMutableDictionary *d0 = [NSMutableDictionary dictionary];
        [d0 setObject:newStr forKey:kAttributeString];
        [d0 setObject:[NSNumber numberWithInt:0] forKey:kIsLineDeleted];
        [arr1 addObject:d0];
         index = NSMaxRange(range);
    }
    
    NSLog(@"line count:%d",(int)arr1.count);
    return arr1;

}
@end

@implementation SCKSyntaxHighlighter

@synthesize tokenAttributes, semanticAttributes;

+ (void)initialize
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        noAttributes = [NSDictionary dictionary];
    });
}

- (id)init
{
	self = [super init];

	NSDictionary *comment = @{NSForegroundColorAttributeName: [NSColor grayColor]};
	NSDictionary *keyword = @{NSForegroundColorAttributeName: [NSColor redColor]};
	NSDictionary *literal = @{NSForegroundColorAttributeName: [NSColor redColor]};
    	NSDictionary *decl = @{NSForegroundColorAttributeName: [NSColor redColor]};
	tokenAttributes = [@{
                       SCKTextTokenTypeComment: comment,
                       SCKTextTokenTypePunctuation: noAttributes,
                       SCKTextTokenTypeKeyword: keyword,
                       SCKObjCImplementationDecl:decl,
                       SCKTextTokenTypeLiteral: literal}
                       mutableCopy];

	semanticAttributes = [@{
                          SCKTextTypeDeclRef: @{NSForegroundColorAttributeName: [NSColor blueColor]},
                          SCKTextTypeMessageSend: @{NSForegroundColorAttributeName: [NSColor brownColor]},
                          SCKTextTypeDeclaration: @{NSForegroundColorAttributeName: [NSColor greenColor]},
                          SCKTextTypeMacroInstantiation: @{NSForegroundColorAttributeName: [NSColor magentaColor]},
                          SCKTextTypeMacroDefinition: @{NSForegroundColorAttributeName: [NSColor magentaColor]},
                          SCKTextTypePreprocessorDirective: @{NSForegroundColorAttributeName: [NSColor orangeColor]},
                          SCKTextTypeReference: @{NSForegroundColorAttributeName: [NSColor purpleColor]}}
                          mutableCopy];
	return self;
}

// helper
-(NSArray*)matchesRegExpression:(NSString*)pattern searchString:(NSString*)line{
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSArray* matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
    
    for ( NSTextCheckingResult* match in matches )
    {
        NSString* matchText = [line substringWithRange:[match range]];
        NSLog(@">: %@", matchText);
    }
    if (matches.count) {
        return matches;
    }
    return nil;
    
}



-(NSMutableString*)parseImplementation:(NSArray*)_lines lineNumber:(NSUInteger)lineNumber currentSuperClass:(NSString*)superClass{
     lines = _lines;
    currentLineOffset = lineNumber;
    NSMutableString *swiftSource = [[NSMutableString alloc]init];
    NSMutableDictionary *d0 = [lines objectAtIndex:lineNumber];
    NSMutableAttributedString *line = d0[kAttributeString];
    
    
//    @implementation
    NSString *className = [[line.string componentsSeparatedByString:@" "] objectAtIndex:1];
    className = [className stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];


     NSString *swift = @"";
    if (superClass) {
        swift = [NSString stringWithFormat:@"class %@ : %@ {\r",className,superClass];
    }else{
         swift = [NSString stringWithFormat:@"class %@ {\r",className];
    }
    [swiftSource appendString:swift];

    // process the subsequent lines for vars.
    [lines enumerateObjectsUsingBlock:^(NSMutableDictionary *d0, NSUInteger idx0, BOOL *stop0) {
        if (idx0 >lineNumber) {
            NSMutableAttributedString *line = d0[kAttributeString];
            if ([line.string containsString:@"-"]) {
                *stop0 = YES; // we hit the implementation
//               eg.  @implementation CircleView
//                - (id)initWithFrame:(CGRect)frame {
                return;
                
            }
             if ([line.string containsString:@"@synthesize"]) {
                  [d0 setObject:@1 forKey:kIsLineDeleted];
             }
            if ([line.string isEqualToString:@""]) {
                [d0 setObject:@1 forKey:kIsLineDeleted];
            }
            
            if ([line.string containsString:@"{"]) {
                
                 [lines enumerateObjectsUsingBlock:^(NSMutableDictionary *d1, NSUInteger idx1, BOOL *stop1) {
                     if (idx1 > idx0) {
                         NSMutableAttributedString *aStr = d1[kAttributeString];
                         NSMutableString *nextLine = [[NSMutableString alloc]init];
                         nextLine.string = aStr.string;
                         
                        //  strip out _ variable names
                        [nextLine replaceOccurrencesOfString:@"_" withString:@"" options:0 range:NSMakeRange(0, nextLine.length)];
                         
                         NSArray *params = [nextLine componentsSeparatedByString:@" "];
                         NSArray *arr =[self matchesRegExpression:@"^\\s*(\\w.*)\\s+(\\w+)\\s*;/" searchString:nextLine];
                         if (arr.count) {
                             NSString *name = params[1];
                             NSString *type = params[0];
                             NSString *bla = [NSString stringWithFormat:@"private var %@: %@\r",name,type];
                             [swiftSource appendString:bla];
                         }
                         
                         
                         if ([nextLine isEqualToString:@"}"])  {
                             *stop0 = YES;
                             *stop1 = YES;
                         }
                     }
                     
                 }];
            }
        }
            
    }];
    
    return swiftSource;
  
}

/*
 @interface JPTableView:NSTableView
 @end
 */
-(NSMutableDictionary*)superClassAndIVarsForInterface:(NSArray*)_lines lineNumber:(NSUInteger)lineNumber{
    lines = _lines;
    currentLineOffset = lineNumber;

    NSMutableDictionary *d0 = [lines objectAtIndex:lineNumber];
    NSMutableAttributedString *line = d0[kAttributeString];
    NSMutableString *swiftSource = [[NSMutableString alloc]init];
    NSMutableDictionary *d1 = [[NSMutableDictionary alloc]init];
    
    //  @interface
    @try {
        NSString *superClass = [[line.string componentsSeparatedByString:@":"] objectAtIndex:1];
        superClass = [superClass stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; //JPTableView:NSTableView -> NSTableView
        [d0 setObject:@1 forKey:kIsLineDeleted]; // delete this line
        [d1 setObject:superClass forKey:@"superClass"];
    }
    @catch (NSException *exception) {
        [d0 setObject:@1 forKey:kIsLineDeleted]; // delete this line
    }
    @finally {
        
    }
   
    // process the subsequent lines for vars.
    [lines enumerateObjectsUsingBlock:^(NSMutableDictionary *dc, NSUInteger idx0, BOOL *stop0) {
        if (idx0 >lineNumber) {
            NSMutableAttributedString *line = dc[kAttributeString];
        
            if ([line.string isEqualToString:@""]) {
                [dc setObject:@1 forKey:kIsLineDeleted];
            }
            
            if ([line.string containsString:@"@implementation"]) {
                *stop0 = YES; //don't delete it will be handle by subsequnt methods
            }
            if ([line.string containsString:@"@end"]) {
                [dc setObject:@1 forKey:kIsLineDeleted];
                *stop0 = YES;
            }
           
            
            
            
            if ([line.string containsString:@"{"]) {
                
                [lines enumerateObjectsUsingBlock:^(NSMutableDictionary *dd, NSUInteger idx1, BOOL *stop1) {
                    if (idx1 > idx0) {
                        NSMutableAttributedString *aStr = dd[kAttributeString];
                        NSMutableString *nextLine = [[NSMutableString alloc]init];
                        nextLine.string = aStr.string;
                        
                        //  strip out _ variable names
                        [nextLine replaceOccurrencesOfString:@"_" withString:@"" options:0 range:NSMakeRange(0, nextLine.length)];
                        
                        NSArray *params = [nextLine componentsSeparatedByString:@" "];
                        NSArray *arr =[self matchesRegExpression:@"^\\s*(\\w.*)\\s+(\\w+)\\s*;/" searchString:nextLine];
                        if (arr.count) {
                            NSString *name = params[1];
                            NSString *type = params[0];
                            NSString *bla = [NSString stringWithFormat:@"private var %@: %@\r",name,type];
                            [swiftSource appendString:bla];
                        }
                        
                        
                        if ([nextLine isEqualToString:@"}"])  {
                            *stop0 = YES;
                            *stop1 = YES;
                        }
                    }
                    
                }];
            }
        }
        
    }];
    
    [d1 setObject:swiftSource forKey:@"swiftSource"];
    return d1;
    
}



// Rebuild Import Statements / strip out any <Cocoa/Cocoa> patterns -> import Cocoa
-(void)fixImportStatement:(NSMutableAttributedString*)attStr lineNumber:(NSUInteger)lineNumber{
    lines = attStr.lines;
    currentLineOffset = lineNumber;
    
    NSMutableString *swiftSource = [[NSMutableString alloc]init];
    NSMutableDictionary *d0 = [lines objectAtIndex:lineNumber];
    NSMutableAttributedString *line = d0[kAttributeString];
    
        //@"#import <QuartzCore/QuartzCore.h>" -> Import @QuartzCore

       if ([line.string containsString:@"<"]) {
                NSArray *arr0 = [line.string componentsSeparatedByString:@"<"];  //   #import <,  QuartzCore/QuartzCore.h>"
                NSString *str = arr0[1];  //QuartzCore/QuartzCore.h>"
                NSArray *arr1 = [str componentsSeparatedByString:@"/"]; //  QuartzCore ,QuartzCore.h>
                NSString *str2 = arr1[0];
                [swiftSource appendString:@"Import @\r\r"];
                [swiftSource appendString:str2];
                [d0 setObject: [[NSMutableAttributedString alloc]initWithString:swiftSource] forKey:kAttributeString];
    
       }else{

           [d0 setObject:@1 forKey:kIsLineDeleted];// eg. #import "AbstractOSXCell.h"
       }

  
}

-(NSMutableString *)convertDefinitions:(NSMutableAttributedString*)attStr lineNumber:(NSUInteger)lineNumber {
    currentLineOffset = lineNumber;
    NSMutableString *swiftSource = [[NSMutableString alloc]init];
    NSMutableDictionary *d0 = [lines objectAtIndex:lineNumber];
    NSMutableAttributedString *line = d0[kAttributeString];
    //NSArray *
    if ([line.string containsString:@"="]) {
        NSArray *arr = [line.string componentsSeparatedByString:@"="];
        NSString *def = arr[0];
        if ([def containsString:@"*"]) {
            NSArray *arr1 = [def componentsSeparatedByString:@"*"];
            NSString *type = [arr1[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *var = [arr1[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *swiftDef = [NSString stringWithFormat:@"let %@:%@ =",var,type];
            [swiftSource appendString:swiftDef];
        }
    }
    
    return swiftSource;
}
// TODO  - if the method is on the same line - we're good - otherwise we are going to have to iterate subsequent lines....
-(NSMutableString*)convertMessageSends:(NSMutableAttributedString*)attStr lineNumber:(NSUInteger)lineNumber matches:(NSArray*)matches{
    

    currentLineOffset = lineNumber;
    NSMutableString *swiftSource = [[NSMutableString alloc]init];
    NSMutableDictionary *d0 = [lines objectAtIndex:lineNumber];
    NSMutableAttributedString *line = d0[kAttributeString];
    //NSArray *
    if ([line.string containsString:@"="]) {
        NSArray *arr = [line.string componentsSeparatedByString:@"="];
        NSString *def = arr[0];
        if ([def containsString:@"*"]) {
            NSArray *arr1 = [def componentsSeparatedByString:@"*"];
            NSString *type = arr1[0];
            NSString *var = arr1[1];
            NSString *swiftDef = [NSString stringWithFormat:@"let %@:%@ =",var,type];
            [swiftSource appendString:swiftDef];
        }
        
        
    }
    
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL * __nonnull stop) {
        NSMutableString* matchText = [NSMutableString stringWithString:[line.string substringWithRange:[match range]]];
        NSLog(@">: %@", matchText);
        [matchText replaceOccurrencesOfString:@"[" withString:@"" options:0 range:NSMakeRange(0, matchText.length)];
        [matchText replaceOccurrencesOfString:@"]" withString:@"" options:0 range:NSMakeRange(0, matchText.length)];
        NSArray *params = [matchText componentsSeparatedByString:@":"];
        //TODO
        
        NSArray *arr = [matchText componentsSeparatedByString:@" "];
        if([matchText containsString:@"alloc"]){
            NSString *str = arr[0];  // NSTrackingArea alloc -> NSTrackingArea,alloc  //[Foo alloc] --> Foo
            [swiftSource appendString:str];
        }else  if([matchText containsString:@"init"]){
            NSString *str = [NSString stringWithFormat:@"%@()\r",arr[0]]; //[Foo init]  --> Foo()
            [swiftSource appendString:str];
        }else{ // [Foo bar] --> Foo.bar()
            if (arr.count>1) {
                NSString *str = [NSString stringWithFormat:@"%@.%@()\r",arr[0],arr[1]]; //[Foo init]  --> Foo()
                [swiftSource appendString:str];
            }
           
        }
        
        
    }];
    
    return swiftSource;
    

}


-(NSString*)convertType:(NSString*)type{
    
    if ([type containsString:@"BOOL"]) {
        return @"Bool";
    }
    if ([type containsString:@"char"]) {
        return @"UInt8";
    }
    
    if ([type containsString:@"float"]) {
        return @"Float";
    }
    if ([type containsString:@"float"]) {
        return @"Float";
    }
    if ([type containsString:@"double"]) {
        return @"Double";
    }
    if ([type containsString:@"NSString"]) {
        return @"String";
    }
    if ([type containsString:@"id"]) {
        return @"[AnyObject]";
    }
    if ([type containsString:@"instancetype"]) {
        return @"[AnyObject]";
    }
    
    if ([type containsString:@"void"]) {
        return @"Void";
    }
    if ([type containsString:@"int"]) {
        return @"Int";
    }
    if ([type containsString:@"unsigned"]) {
        return @"UInt";
    }
    if ([type containsString:@"NSInteger"]) {
        return @"Int";
    }
    if ([type containsString:@"NSUInteger"]) {
        return @"UInt";
    }
    if ([type containsString:@"NSUInteger"]) {
        return @"UInt";
    }
    if ([type containsString:@"SInt8"]) {
        return @"Int8";
    }
    
    if ([type containsString:@"int8_t"]) {
        return @"Int8";
    }
    if ([type containsString:@"uint8_t"]) {
        return @"UInt8";
    }
    if ([type containsString:@"SInt16"]) {
        return @"Int16";
    }
    if ([type containsString:@"int16_t"]) {
        return @"Int16";
    }
    if ([type containsString:@"uint16_t"]) {
        return @"UInt16";
    }
    if ([type containsString:@"SInt32"]) {
        return @"Int32";
    }
    if ([type containsString:@"int32_t"]) {
        return @"Int32";
    }
    if ([type containsString:@"uint32_t"]) {
        return @"UInt32";
    }
    if ([type containsString:@"SInt64"]) {
        return @"Int64";
    }

    if ([type containsString:@"uint64_t"]) {
        return @"UInt64";
    }

    return type;
    
}



-(NSMutableString*)convertMethod:(NSMutableAttributedString*)attStr lineNumber:(NSUInteger)lineNumber matches:(NSArray*)matches{
    
    
    currentLineOffset = lineNumber;
    NSMutableString *swiftSource = [[NSMutableString alloc]init];
    NSMutableDictionary *d0 = [lines objectAtIndex:lineNumber];
    NSMutableAttributedString *line = d0[kAttributeString];
    NSMutableString *mStr = [NSMutableString stringWithString:line.string];
    [mStr replaceOccurrencesOfString:@"*" withString:@"" options:0 range:NSMakeRange(0, mStr.length)];
    //[mStr replaceOccurrencesOfString:@":" withString:@"" options:0 range:NSMakeRange(0, mStr.length)];
    
    
  
    NSMutableArray *t = [NSMutableArray array];
    __block NSString *returnType = @"";
    NSArray *types =[self matchesRegExpression:@"\\([^()]*\\)" searchString:mStr];   // REGEX = \([^()]*\)
    //- (BOOL)tableView:(NSTableView )tableView isGroupRow:(NSInteger)row ->  returnType BOOL  [NSTableView,NSInteger]
    [types enumerateObjectsUsingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL * __nonnull stop) {
        NSMutableString* matchText = [NSMutableString stringWithString:[mStr substringWithRange:[match range]]];
       
         [matchText replaceOccurrencesOfString:@"(" withString:@"" options:0 range:NSMakeRange(0, matchText.length)];
        [matchText replaceOccurrencesOfString:@")" withString:@"" options:0 range:NSMakeRange(0, matchText.length)];
        NSString *type = [self convertType:matchText];
        
        if (idx == 0) {
            returnType = type;
        }else{
           [t addObject:type]; //(NSTableView ) ->  NSTableView
        }
      //   NSLog(@"type:%@",type);
    }];
    
    // TODO - make this pretty.
    NSMutableArray *vars = [NSMutableArray arrayWithArray:[mStr componentsSeparatedByString:@")"]];
    [vars enumerateObjectsUsingBlock:^(NSString *var, NSUInteger idx, BOOL * __nonnull stop) {
        if (idx ==0) {
            return; // return type
        }
        NSArray *mVar = [var componentsSeparatedByString:@" "];
        if (mVar.count) {
            [vars addObject:[mVar objectAtIndex:0]];
            NSLog(@"mVar%@",[mVar objectAtIndex:0]);
        }else{
            [vars addObject:var];
              NSLog(@"mVar%@",var);
        }
    }];
    
    
    
    if([[mStr substringToIndex:1]isEqualToString:@"+"]){
        [swiftSource appendString:@"class func "];
    }else{
        [swiftSource appendString:@"func "];
    }
    
    if ([mStr containsString:@"initWith"]) {
        //init(frame: CGRect, person: Person, options: MDCSwipeToChooseViewOptions)
        
        NSArray *arr = [mStr componentsSeparatedByString:@"initWith"]; //Frame:(NSRect()
        NSString *str =arr[1];
        NSString *firstLetter = [str substringToIndex:1];
        firstLetter = [firstLetter lowercaseString]; // F -> f
        NSArray *arr1 = [str componentsSeparatedByString:@":"];
        
        NSString *str1 = arr1[0]; // Frame
        NSMutableString *param0 = [NSMutableString stringWithString:str1];
        [param0 replaceCharactersInRange:NSMakeRange(0, 1) withString:firstLetter]; // Frame -> frame
        if (t.count == 1) {
            NSString *init = [NSString stringWithFormat:@"init(%@:%@)\r",param0,t[0]];
            [swiftSource appendString:init];
        }else{
            NSMutableString *init = [NSMutableString stringWithFormat:@"init(%@:%@",param0,t[0]];
            [t enumerateObjectsUsingBlock:^(NSString *type, NSUInteger idx, BOOL * __nonnull stop) {
                NSString *str = [NSString stringWithFormat:@",%@:%@",vars[idx],type];
                [init appendString:str];
            }];
            
            [swiftSource appendString:init];
            [swiftSource appendString:@")\r"];
            
        }
    }else{
        
        
        
        // find a method
        /*NSArray *arr =[self matchesRegExpression:@"[+-]\\s*\\(([^)]+)\\)(?:\\s*(\\w+):\\s*\\(([^)]+)\\)\\s*(\\w+))+" searchString:mStr];
        [arr enumerateObjectsUsingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL * __nonnull stop) {
            NSMutableString* matchText = [NSMutableString stringWithString:[mStr substringWithRange:[match range]]];
            NSLog(@"1| %@", matchText);
            NSArray *arr1 = [matchText componentsSeparatedByString:@")"];
            NSString *str1 = arr1[1];
            if ([arr1[0] containsString:@"void"]) {
                NSString *str = [NSString stringWithFormat:@"%@\r{\r",str1];
                [swiftSource appendString:str];
            }else{
                NSString *type = [self convertType:arr1[0]];
                NSString *str = [NSString stringWithFormat:@"%@() -> %@\r{\r",str1,type];
                [swiftSource appendString:str];
            }
            
            
        }];
        if (!arr.count){
            
            // we should just add () for this condition    - (void)dealloc -> func dealloc()
            arr =[self matchesRegExpression:@"[+-]\\s*\\(([^)]+)\\)\\s*(\\w+)" searchString:mStr];
            [arr enumerateObjectsUsingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL * __nonnull stop) {
                NSMutableString* matchText = [NSMutableString stringWithString:[mStr substringWithRange:[match range]]];
                NSLog(@"2| %@", matchText);
                NSArray *arr1 = [matchText componentsSeparatedByString:@")"];
                NSString *str1 = arr1[1];
                if ([arr1[0] containsString:@"void"]) {
                    NSString *str = [NSString stringWithFormat:@"%@()\r{\r",str1];
                    [swiftSource appendString:str];
                }else{
                    NSString *type = [self convertType:arr1[0]];
                    NSString *str = [NSString stringWithFormat:@"%@() -> %@\r{\r",str1,type];
                    [swiftSource appendString:str];
                }
                
            }];
            
        }*/
        
        
        // TODO INSPECT NEXT LINE FOR //\s+(\w+):\s*\((.+)\)\s*(\w+) - find parameters on next line
    }
    
  
    
    return swiftSource;
    
    
}


- (NSString*)convertToSwiftSource:(SCKClangSourceFile *)file sourceCollection:(SCKSourceCollection *)sourceCollection
{
    NSMutableAttributedString *source = file.source;
    
    currentLineOffset = -1;
   
    [source.lines enumerateObjectsUsingBlock:^(NSMutableDictionary *d0 , NSUInteger idx, BOOL *stop0) {
        
        NSMutableAttributedString *line = d0[kAttributeString];
        
        @try {
            
            // 1st Pass -  WASH CLEAN CODE BEFORE WE PARSE IT
            [line  enumerateAttributesInRange:NSMakeRange(0, line.length) options:0  usingBlock:^(NSDictionary* attrs, NSRange range, BOOL *stop1) {
               // NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
                NSString *token = [attrs objectForKey:kSCKTextTokenType];
                
                if(range.length == 0){
                    return;
                }
                if ([token isEqualToString:SCKTextTypePreprocessorDirective] )
                    [line deleteCharactersInRange:range];
                if ([token isEqualToString:SCKTextTypeMacroInstantiation] )
                    [line deleteCharactersInRange:range];
                 if ([token isEqualToString:SCKTextTokenTypeComment] )
                    [line deleteCharactersInRange:range];
                
            }];
        }
        @catch (NSException *exception) {
            NSLog(@"exception:%@",exception);
        }
        @finally {
            
        }

        
        
        
        NSMutableDictionary *superClassDictionnary;
        
        // CRUDE 1st PASS
        if ([line.string containsString:@"#import"]){
            [self fixImportStatement:source lineNumber:idx];
            return;
        }
        //
        if ([line.string containsString:@"@class"]) {
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        if ([line.string containsString:@"@protocol"]) {
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        if ([line.string containsString:@"#define"]) {
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        if ([line.string containsString:@"@end"]){
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        
        if ([line.string containsString:@"if (self"]){
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        
        
        // TODO - call super / parse message sends
        if ([line.string containsString:@"self ="]){
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        if ([line.string containsString:@"return self"]){
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        
        // TODO handle with regex to rip ivars
        if ([line.string containsString:@"@property"]){
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        
        
        if ([[line.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]){
            [d0 setObject:@1 forKey:kIsLineDeleted];
            return;
        }
        
        // DETECT INTERFACE / IMPLEMENTATION.
        if ([line.string containsString:@"@interface"]) {
            superClassDictionnary =   [self superClassAndIVarsForInterface:source.lines lineNumber:idx];
            NSLog(@"currentSuperclass:%@",superClassDictionnary);
            return;
            
        }
        if ([line.string containsString:@"@implementation"]) {
            NSString *superClass = [superClassDictionnary valueForKey:@"superClass"];
            NSMutableString* headerCode =   [self parseImplementation:source.lines lineNumber:idx currentSuperClass:superClass];
            [d0 setObject: [[NSMutableAttributedString alloc]initWithString:headerCode] forKey:kAttributeString];
            return;
            
        }
        
        
        // BEGIN BROAD TRANSLATIONS
        
        if ([line.string containsString:@"#pragma mark"]) {
            [d0 setObject:[line destroyAttributesAndReplaceOccurrencesOfString:@"#pragma mark" withString:@"//MARK "]  forKey:kAttributeString];
            return;
        }
        
        if ([line.string containsString:@";"]) {
            [d0 setObject:[line destroyAttributesAndReplaceOccurrencesOfString:@";" withString:@""]  forKey:kAttributeString];
            return;
        }
        
        if ([line.string containsString:@" YES"]) {
            [d0 setObject:[line destroyAttributesAndReplaceOccurrencesOfString:@" YES" withString:@" true"]  forKey:kAttributeString];
            return;
        }
        if ([line.string containsString:@" NO"]) {
            [d0 setObject:[line destroyAttributesAndReplaceOccurrencesOfString:@" NO" withString:@" false"]  forKey:kAttributeString];
            return;
        }
        if ([line.string containsString:@"NSLog"]) {
            [d0 setObject:[line destroyAttributesAndReplaceOccurrencesOfString:@"NSLog" withString:@"print"]  forKey:kAttributeString];
            return;
        }
        if ([line.string containsString:@"@"]) {
            [d0 setObject:[line destroyAttributesAndReplaceOccurrencesOfString:@"@" withString:@""]  forKey:kAttributeString];
            return;
        }
        

        // introduce let / var
        
        if ([line.string containsString:@"="]){
            [self convertDefinitions:line lineNumber:idx];
        }
        
        
        // process methods
        NSArray * arr =[self matchesRegExpression:@"^[+-]" searchString:line.string];
        if (arr.count) {
            NSMutableString* msg =   [self convertMethod:source lineNumber:idx matches:arr];
            [d0 setObject: [[NSMutableAttributedString alloc]initWithString:msg] forKey:kAttributeString];
            return;
        }

        // convert message sends
        arr =[self matchesRegExpression:@"\\[\\s*([^\\[\\]]*)\\s*\\]" searchString:line.string];
        if (arr.count) {
            NSMutableString* msg =   [self convertMessageSends:source lineNumber:idx matches:arr];
            [d0 setObject: [[NSMutableAttributedString alloc]initWithString:msg] forKey:kAttributeString];
            return;
        }

        
       
        
        
        
        
        @try {
            
            // 2nd Pass - CYCLE ATTRIBUTES ON SINGLE LINE
            [line  enumerateAttributesInRange:NSMakeRange(0, line.length) options:0  usingBlock:^(NSDictionary* attrs, NSRange range, BOOL *stop1) {
                NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
                NSString *token = [attrs objectForKey:kSCKTextTokenType];
                
                if(range.length == 0){
                    return;
                }
                if ([semantic isEqualToString:SCKObjCClassMethodDecl]) {
                    // NSLog(@"SCKObjCClassMethodDecl:%@",attrs);
                    // NSLog(@"SCKObjCClassMethodDecl:%@ string:%@",[line attributedSubstringFromRange:range] ,line.string);
                    [line deleteCharactersInRange:range];
                }
                if ([semantic isEqualToString:SCKObjCImplementationDecl]) {
                    // RIP OUT import statements INTERFACE ->@implementation AudioController
                    [line deleteCharactersInRange:range];
                }
                if ([token isEqualToString:SCKTextTypeDeclRef] ) { // remove type defs
                    [line deleteCharactersInRange:range];
                }else if ([token isEqualToString:SCKTextTypePreprocessorDirective] ) {
                    [line deleteCharactersInRange:range];
                }else  if ([token isEqualToString:SCKTextTokenTypePunctuation] ) {
                    // TODO perform regex here -
                   // [self ripOutStuffForPunctuation:attrs source:source range:range]; // this is currently destroying the alloc]init] brackets.
                }else   if ([token isEqualToString:SCKTextTokenTypeLiteral] ) {
                    [self ripOutAtSymbol:attrs source:source range:range];
                }else  if ([token isEqualToString:SCKTextTypeMacroDefinition] ) {
                    [line deleteCharactersInRange:range];
                }else  if ([token isEqualToString:SCKTextTokenTypePunctuation] ) {
                  //  [line deleteCharactersInRange:range];
                }
                
            }];
        }
        @catch (NSException *exception) {
            NSLog(@"exception:%@",exception);
        }
        @finally {
            
        }
        

    }];
    
    source = source.cookedAttributeText; // using the category helper - we have preserved original source - but ripped out some text. It's been cooked.
   // NSLog(@"cooked Text:%@",source);
    
    
    
    
    
    // THIS CODE IS PROCESSING ENTIRE CHUNK OF SOURCE CODE - IT'S NOT LINE BY LINE.....
   /* if (source == nil) {
        return @"";
    }
    
    NSUInteger end = [source length];
    if (end == 0) {
        return @"";
    }
    NSUInteger i = 0;

    NSRange r;
    do
    {
        NSRange range = NSMakeRange(i, end-i);
        
        NSDictionary *attrs = [source attributesAtIndex:i    longestEffectiveRange:&r   inRange:range];
        i = r.location + r.length;
        
        NSString *token = [attrs objectForKey:kSCKTextTokenType];
        NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
        NSDictionary *diagnostic = [attrs objectForKey:kSCKDiagnostic];
        
      // NSLog(@"attrs:%@",attrs);
    //   NSLog(@"attributedSubstringFromRange:%@",[source attributedSubstringFromRange:range] );
        // Skip ranges that have attributes other than semantic markup
        if ((nil == semantic) && (nil == token)) continue;
        if (semantic == SCKTextTypePreprocessorDirective)
        {
            attrs = [semanticAttributes objectForKey: semantic];
        }
        else if (token == nil || token != SCKTextTokenTypeIdentifier)
        {
            attrs = [tokenAttributes objectForKey: token];
        }
        else
        {
            NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
            attrs = [semanticAttributes objectForKey:semantic];
        }
        
        if (nil == attrs)
        {
            attrs = noAttributes;
        }
        
        if ([token isEqualToString:SCKTextTokenTypeLiteral]) {
            [self ripOutAtSymbol:attrs source:source range:r];
        }else   if ([token isEqualToString:SCKTextTypeMacroInstantiation]) {
            [self ripOutStuff:attrs source:source range:r];
        }else  if ([token isEqualToString:SCKTextTypeMacroDefinition]) {
            [self ripOutStuff:attrs source:source range:r];
        }else   if ([token isEqualToString:SCKTextTypePreprocessorDirective]) {
            [self ripOutStuff:attrs source:source range:r];
        }else if ([token isEqualToString:SCKTextTokenTypeComment]) {
            [self ripOutStuff:attrs source:source range:r];
        }else if ([token isEqualToString:SCKTextTokenTypePunctuation]) {
            // TODO perform regex here -
            [self ripOutStuffForPunctuation:attrs source:source range:r]; // this is currently destroying the alloc]init] brackets.
        }else{
              [source setAttributes:attrs range:r];
        }
        
        // Re-apply the diagnostic
//        if (nil != diagnostic)
//        {
//            [source addAttribute:NSToolTipAttributeName
//                           value:[diagnostic objectForKey: kSCKDiagnosticText]
//                           range:r];
//            [source addAttribute:NSUnderlineStyleAttributeName
//                           value:[NSNumber numberWithInt: NSSingleUnderlineStyle]
//                           range:r];
//            [source addAttribute:NSUnderlineColorAttributeName
//                           value:[NSColor redColor]
//                           range:r];
//        }
    } while (i < end);
    
    [[source  copy] enumerateAttributesInRange:NSMakeRange(0, source.length) options:NSAttributedStringEnumerationReverse  usingBlock:^(NSDictionary* attrs, NSRange range, BOOL *stop) {
        if ([[attrs valueForKey:kMyHiddenTextAttribute] boolValue]) {
            [source deleteCharactersInRange:range];
        }
    }];*/
    NSString *src = source.string;
    NSLog(@"src:%@",src);
    return src;
}
-(void)ripOutStuff:(NSDictionary*)attrs source:(NSMutableAttributedString*)source range:(NSRange)r{
    NSMutableDictionary *d0 = [NSMutableDictionary dictionaryWithDictionary:attrs];
    [d0 setObject:@1 forKey:kMyHiddenTextAttribute];
    [source setAttributes:d0 range:r];
}
-(void)ripOutStuffForPunctuation:(NSDictionary*)attrs source:(NSMutableAttributedString*)source range:(NSRange)r0{
    
    NSAttributedString *str = [source attributedSubstringFromRange:r0];
   // NSLog(@"attributedSubstringFromRange:%@", str);

    if ([str.string isEqualToString:@";"]) {
        [self ripOutStuff:attrs source:source range:r0];
    }
    NSRange r1 = NSMakeRange(0, str.length);
    [str enumerateAttributesInRange:r1 options:0 usingBlock:^(NSDictionary *attrs0, NSRange range, BOOL *stop) {
       // NSLog(@"attrs:%@",attrs0);
        if ([[attrs0 valueForKey:kSCKTextSemanticType] isEqualToString:SCKTextTypeMessageSend] ) {
            [self ripOutStuff:attrs source:source range:r0];
        }
    }];
   
}


-(void)ripOutAtSymbol:(NSDictionary*)attrs source:(NSMutableAttributedString*)source range:(NSRange)r0{
    
    NSAttributedString *str = [source attributedSubstringFromRange:r0];
    NSRange range = [str.string rangeOfString:@"@"];
    if (range.location != NSNotFound) {
     //   NSLog(@"position %lu", (unsigned long)range.location);
           [self ripOutStuff:attrs source:source range:range];
    }

}


@end

