
#import "MRAppDelegate.h"
#import "MRWorker.h"
#import "MRWorkerOperation.h"
#import "UAGithubEngine.h"
#import "GoogleDocsServiceLayer.h"
#import "GDBSheet.h"
#import "GDBModel.h"
#import <Chime/SCKClangSourceFile.h>

@interface RepoModel : GDBModel

@property (nonatomic, copy) NSString *urlName;
@property (nonatomic, copy) NSString *timestamp;
@property (nonatomic, copy) NSString *branch;
@property (nonatomic, copy) NSString *email;

@end
@implementation RepoModel
+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"urlName": @"URL",
             @"timestamp": @"Timestamp",
             @"branch": @"Branch",
             @"email": @"Email",
             };
}

+ (NSValueTransformer *)eventDateJSONTransformer {
    return [self googleDocsDateJSONTransformer];
}
@end


@implementation MRAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
//https://docs.google.com/spreadsheets/d/1xNdvydLEzvGfi9-d2FLpmSR98IKZiVEAaMGfauGZ0pU/edit?usp=sharing
    
    
  
    
    MRWorkerOperation *subop = [MRWorkerOperation workerOperationWithLaunchPath:@"/usr/bin/find" arguments:@[ @"-name", @"*.[hm]", @"$PWD" ] outputBlock:^(NSString *output) {
        // buffer/process program output
        NSLog(@"output:%@",output);
        
    } completionBlock:^(int terminationStatus) {
        // respond to program termination
        NSLog(@"terminationStatus:%d",terminationStatus);
        NSLog(@"TODO - fire up translator here...");
        
        //
        
        //ls *.[hm] | xargs clang-format -i -style=file
    }];
    [subop start];
    

    

}







@end
