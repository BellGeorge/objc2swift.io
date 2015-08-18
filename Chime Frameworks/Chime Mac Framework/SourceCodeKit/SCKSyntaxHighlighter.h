#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>
#import "SCKClangSourceFile.h"

@class NSMutableDictionary;
@class NSMutableAttributedString;

/**
 * The SCKSyntaxHighlighter class is responsible for mapping from the semantic
 * attributes defined by an SCKSourceFile subclass to (configurable)
 * presentation attributes.
 */
@interface SCKSyntaxHighlighter : NSObject
{
    NSUInteger currentLineOffset;
    NSArray *lines; //TODO - get rid of this.
    
    NSString *filename;
}
/**
 * Attributes to be applied to token types.
 */
@property (retain, nonatomic) NSMutableDictionary *tokenAttributes;
/**
 * Attributes to be applied to semantic types.
 */
@property (retain, nonatomic) NSMutableDictionary *semanticAttributes;
/**
 * Transforms a source string, replacing the semantic attributes with
 * presentation attributes.
 */
- (void)transformString: (NSMutableAttributedString*)source;

/**
 BEGIN HACK
 */
- (void)buildInterfaceSwiftVarsForHeaderFile:(SCKClangSourceFile *)file;

- (NSString *)convertToSwiftSource:(SCKClangSourceFile *)file sourceCollection:(SCKSourceCollection *)sourceCollection isHeader:(BOOL)bHeader;
- (NSMutableArray *)detectNsEnums:(SCKClangSourceFile *)file;


@end
