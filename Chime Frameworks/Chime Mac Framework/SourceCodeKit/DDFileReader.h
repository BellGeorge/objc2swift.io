//DDFileReader.h
@class SCKClangSourceFile;
@class SCKSourceCollection;

@interface DDFileReader : NSObject {
    NSMutableString * filePath;
    
    NSFileHandle * fileHandle;
    unsigned long long currentOffset;
    unsigned long long totalFileLength;
    
    NSString * lineDelimiter;
    NSUInteger chunkSize;
    NSMutableArray *patterns;
    
    unsigned long long runningCurrentOffset;

    NSMutableString *swiftSource;
    NSMutableDictionary *classDictionary;
}

@property (nonatomic, copy) NSString * lineDelimiter;
@property (nonatomic) NSUInteger chunkSize;

- (id) initWithFilePath:(NSString *)aPath;

- (NSString *) peekLine;
- (NSString *) readLine;
- (NSString *) readTrimmedLine;
- (BOOL)convertNextLine;
- (void)createSwiftFile;
-(void)createSwiftFileFrom:(SCKClangSourceFile*)file sourceCollection:(SCKSourceCollection *)sourceCollection;

#if NS_BLOCKS_AVAILABLE
- (void) enumerateLinesUsingBlock:(void(^)(NSString*, BOOL *))block;
#endif

@end