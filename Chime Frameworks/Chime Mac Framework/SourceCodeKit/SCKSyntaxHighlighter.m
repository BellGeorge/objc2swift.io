#import "SCKSyntaxHighlighter.h"
#import <Cocoa/Cocoa.h>
#import "SCKTextTypes.h"
#include <time.h>
#import "SCKClangSourceFile.h"
#import "SCKIntrospection.h"
#include <objc/runtime.h>
#import <Chime/SCKSourceCollection.h>


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

// TODO - revisit this monster.
// We need to keep around the entire source file with all NSMutableAttributedString row /lines in tact
// to  manipulate the highlighted content and not lose any introspected data as the highlight syntax is a one shot process.
// it's safer to hide the rows than to delete content or alter ranges.
-(NSMutableArray*)lines{

     NSMutableArray *arr1;
    static NSMutableDictionary *d0 =nil;
    
    if (d0 == nil ) {
        d0 = [NSMutableDictionary dictionary];
        arr1 =[[NSMutableArray alloc]init];
         [d0 setObject:arr1 forKey:self.string];
    }else{
        arr1 =   [d0 valueForKey:self.string];
        if (arr1 ==nil) {
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



-(NSMutableString*)parseImplementation:(NSArray*)_lines lineNumber:(NSUInteger)lineNumber{
     lines = _lines;
    currentLineOffset = lineNumber;
    NSMutableString *swiftSource = [[NSMutableString alloc]init];
    NSMutableDictionary *d0 = [lines objectAtIndex:lineNumber];
    NSMutableAttributedString *line = d0[kAttributeString];
    NSString *className = [[line.string componentsSeparatedByString:@" "] objectAtIndex:1];
    className = [className stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    
    
    // delete every line / import statements above this class {
    [lines enumerateObjectsUsingBlock:^(NSMutableDictionary *d1, NSUInteger idx, BOOL *stop) {
        if (idx < lineNumber) {
           [d1 setObject:[NSNumber numberWithInt:1] forKey:kIsLineDeleted];
        }
    }];
    NSString *swift = [NSString stringWithFormat:@"class %@ {\r",className];
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


- (NSString*)convertToSwiftSource:(SCKClangSourceFile *)file sourceCollection:(SCKSourceCollection *)sourceCollection
{
    NSMutableAttributedString *source = file.source;
    
    //    Class class =NSClassFromString(className);
    //SCKClass *cls = [sourceCollection.bundleClasses objectForKey:@"AudioController"] ;
//    SCKClass *cls = [[SCKClass alloc] initWithClass:class];
//    [cls.methods enumerateKeysAndObjectsUsingBlock:^(SCKMethod *method, id obj, BOOL *stop) {
//        NSLog(@"method:%@",method);
//    }];

    currentLineOffset = -1;
    NSMutableArray *arrSourceLines =source.lines;
    [arrSourceLines enumerateObjectsUsingBlock:^(NSMutableDictionary *d0 , NSUInteger idx, BOOL *stop0) {
        NSMutableAttributedString *line = d0[kAttributeString];
        
//         NSLog(@"currentLineOffset:%d",(int)currentLineOffset);
//        NSLog(@"idx:%d",(int)idx);
        
//        if (idx < currentLineOffset) {
//               [d0 setObject:[NSNumber numberWithInt:1] forKey:kIsLineDeleted];
//           // [source removeRowAtIndex:idx]; // blow the line away   as we  processed these lines below by parseimplementation
//        }
//RegExCategories
        [line  enumerateAttributesInRange:NSMakeRange(0, line.length) options:0  usingBlock:^(NSDictionary* attrs, NSRange range, BOOL *stop1) {
            NSString *semantic = [attrs objectForKey:kSCKTextSemanticType];
            if ([semantic isEqualToString:SCKObjCClassMethodDecl]) {
                  [line deleteCharactersInRange:range];
            }
            if ([semantic isEqualToString:SCKObjCImplementationDecl]) { // RIP OUT import statements INTERFACE ->@implementation AudioController
                if ([line.string containsString:@"@implementation"]) {
                    NSLog(@"SCKObjCImplementationDecl:%@",attrs);
                    NSLog(@"SCKObjCImplementationDecl:%@ string:%@",[line attributedSubstringFromRange:range] ,line.string);
                  NSMutableString* headerCode =   [self parseImplementation:arrSourceLines lineNumber:idx];
                 // [source updateAttributeAtLine:idx attributeString:];
                       [d0 setObject: [[NSMutableAttributedString alloc]initWithString:headerCode] forKey:kAttributeString];
                    *stop1 = YES;
                }
            }
            if ([[attrs valueForKey:kSCKTextTokenType ] isEqualToString:SCKTextTypeDeclRef] ) { // remove type defs
                [line deleteCharactersInRange:range];
            }
            if ([[attrs valueForKey:kSCKTextTokenType ] isEqualToString:SCKTextTypePreprocessorDirective] ) { // remove preprocessor stuff - TODO - switch out PRAGRAM -> //MARK ->
                [line deleteCharactersInRange:range];
            }
        }];

    }];
    
    source = source.cookedAttributeText;
 //   NSLog(@"source.cookedText:%@",source.cookedText);
    
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

