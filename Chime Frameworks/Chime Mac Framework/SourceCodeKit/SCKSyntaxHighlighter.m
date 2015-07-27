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

@interface NSMutableAttributedString (addons)
-(NSMutableArray*)lines;
-(void)updateAttributeAtLine:(NSInteger)line attributeString:(NSMutableAttributedString*)attributeString;
-(void)removeRowAtIndex:(NSUInteger)rowIndex;
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

-(void)updateAttributeAtLine:(NSInteger)line attributeString:(NSMutableAttributedString*)aStr{
    NSMutableDictionary *d0 = [[self lines] objectAtIndex:line];
      [d0 setObject:aStr forKey:kAttributeString];

}
-(void)removeRowAtIndex:(NSUInteger)rowIndex{
    if (self.lines.count < rowIndex){
        NSMutableDictionary *d0 =  [self.lines objectAtIndex:rowIndex];
        [d0 setObject:[NSNumber numberWithInt:1] forKey:kIsLineDeleted];
    }
 
}

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
                *stop0 = YES;
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
                [swiftSource appendString:@"Import @"];
                [swiftSource appendString:str2];
                [d0 setObject: [[NSMutableAttributedString alloc]initWithString:swiftSource] forKey:kAttributeString];
    
       }else{
           [attStr removeRowAtIndex:currentLineOffset]; // eg. #import "AbstractOSXCell.h"
       }

  
}


- (NSString*)convertToSwiftSource:(SCKClangSourceFile *)file sourceCollection:(SCKSourceCollection *)sourceCollection
{
    NSMutableAttributedString *source = file.source;
    
    currentLineOffset = -1;
   
    [source.lines enumerateObjectsUsingBlock:^(NSMutableDictionary *d0 , NSUInteger idx, BOOL *stop0) {
        
        
        NSMutableAttributedString *line = d0[kAttributeString];
        NSMutableDictionary *superClassDictionnary;
        
        // CRUDE PASS
        if ([line.string containsString:@"#import"]){
            [self fixImportStatement:source lineNumber:idx];
        }
        
        if ([line.string containsString:@"@interface"]) {
            superClassDictionnary =   [self superClassAndIVarsForInterface:source.lines lineNumber:idx];
            NSLog(@"currentSuperclass:%@",superClassDictionnary);

        }
        if ([line.string containsString:@"@implementation"]) {
            NSString *superClass = [superClassDictionnary valueForKey:@"superClass"];
            NSMutableString* headerCode =   [self parseImplementation:source.lines lineNumber:idx currentSuperClass:superClass];
            [d0 setObject: [[NSMutableAttributedString alloc]initWithString:headerCode] forKey:kAttributeString];

        }
         if ([line.string containsString:@"#pragma mark"]) {
             [d0 setObject:[line destroyAttributesAndReplaceOccurrencesOfString:@"#pragma mark" withString:@"//MARK "]  forKey:kAttributeString];
         }
        
        
        
        // DROP INTO ATTRIBUTES FOR MORE GRANULARITY OF EACH TOKEN IN STRING
        [line  enumerateAttributesInRange:NSMakeRange(0, line.length) options:0  usingBlock:^(NSDictionary* attrs, NSRange range, BOOL *stop1) {
            NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
//            NSLog(@"SCKObjCImplementationDecl:%@",attrs);
//            NSLog(@"SCKObjCImplementationDecl:%@ string:%@",[line attributedSubstringFromRange:range] ,line.string);

            if ([semantic isEqualToString:SCKObjCClassMethodDecl]) {
               // NSLog(@"SCKObjCClassMethodDecl:%@",attrs);
               // NSLog(@"SCKObjCClassMethodDecl:%@ string:%@",[line attributedSubstringFromRange:range] ,line.string);
                [line deleteCharactersInRange:range];
            }
            if ([semantic isEqualToString:SCKObjCImplementationDecl]) {
                // RIP OUT import statements INTERFACE ->@implementation AudioController
                 [line deleteCharactersInRange:range];
            }
            if ([[attrs valueForKey:kSCKTextTokenType ] isEqualToString:SCKTextTypeDeclRef] ) { // remove type defs
                [line deleteCharactersInRange:range];
            }
            if ([[attrs valueForKey:kSCKTextTokenType ] isEqualToString:SCKTextTypePreprocessorDirective] ) {
                // remove preprocessor stuff - TODO - switch out PRAGRAM -> //MARK ->
                [line deleteCharactersInRange:range];
            }
        }];

    }];
    
    source = source.cookedAttributeText;

    
    if (source == nil) {
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
            [self ripOutStuffForPunctuation:attrs source:source range:r];
        }else{
              [source setAttributes:attrs range:r];
        }
        
        // Re-apply the diagnostic
        if (nil != diagnostic)
        {
            [source addAttribute:NSToolTipAttributeName
                           value:[diagnostic objectForKey: kSCKDiagnosticText]
                           range:r];
            [source addAttribute:NSUnderlineStyleAttributeName
                           value:[NSNumber numberWithInt: NSSingleUnderlineStyle]
                           range:r];
            [source addAttribute:NSUnderlineColorAttributeName
                           value:[NSColor redColor]
                           range:r];
        }
    } while (i < end);
    
    [[source  copy] enumerateAttributesInRange:NSMakeRange(0, source.length) options:NSAttributedStringEnumerationReverse  usingBlock:^(NSDictionary* attrs, NSRange range, BOOL *stop) {
        if ([[attrs valueForKey:kMyHiddenTextAttribute] boolValue]) {
            [source deleteCharactersInRange:range];
        }
    }];
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

