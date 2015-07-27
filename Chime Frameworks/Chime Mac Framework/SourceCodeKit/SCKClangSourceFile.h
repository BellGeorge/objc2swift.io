#include <Foundation/Foundation.h>
#include "SCKSourceFile.h"


@class SCKClangIndex;
@class NSMutableArray;
@class NSMutableAttributedString;

/**
 * SCKSourceFile implementation that uses clang to perform handle
 * [Objective-]C[++] files.
 */
@interface SCKClangSourceFile : SCKSourceFile
@property (nonatomic, readonly) NSMutableDictionary *classes;
@property (nonatomic, readonly) NSMutableDictionary *functions;
@property (nonatomic, readonly) NSMutableDictionary *globals;
@property (nonatomic, readonly) NSMutableDictionary *enumerations;
@property (nonatomic, readonly) NSMutableDictionary *enumerationValues;
@end
