
#import "MRAppDelegate.h"
#import "MRWorker.h"
#import "MRWorkerOperation.h"
#import "UAGithubEngine.h"
#import "GoogleDocsServiceLayer.h"
#import "GDBSheet.h"
#import "GDBModel.h"


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
    
    
    UAGithubEngine *engine = [[UAGithubEngine alloc] initWithUsername:@"objc2swift" password:@"s2oconverter" withReachability:YES];
    
//    [engine repositoriesWithSuccess:^(id response) {
//        NSLog(@"Got an array of repos: %@", response);
//    } failure:^(NSError *error) {
//        NSLog(@"Oops: %@", error.localizedDescription);
//    }];
    
    [GoogleDocsServiceLayer sheetsForWorksheetKey:@"1xNdvydLEzvGfi9-d2FLpmSR98IKZiVEAaMGfauGZ0pU"  callback:^(NSArray *objects, NSError *error) {
        if (error) {
            NSLog(@"error:%@",error.localizedDescription);
        } else {
            //choosing to sort returned values by an NSDate attribute
            NSLog(@"objects:%@",objects);
            [objects enumerateObjectsUsingBlock:^(GDBSheet *sheet, NSUInteger idx, BOOL * _Nonnull stop) {
                
                [GoogleDocsServiceLayer objectsForWorksheetKey:sheet.worksheetId sheetId:sheet.sheetId modelClass:[RepoModel class] callback:^(NSArray *objects2, NSError *error) {
                    if (error) {
                        NSLog(@"error:%@",error.localizedDescription);
                    } else {
                        //choosing to sort returned values by an NSDate attribute
                        NSLog(@"objects2:%@",objects2);
                        [objects2 enumerateObjectsUsingBlock:^(RepoModel *repo, NSUInteger idx, BOOL * _Nonnull stop) {
                            
                            // TODO detect branch
                            NSMutableString *name = repo.urlName.mutableCopy;
                            [name replaceOccurrencesOfString:@"https://github.com" withString:@"" options:0 range:NSMakeRange(0, name.length)];
                            [name replaceOccurrencesOfString:@".git" withString:@"" options:0 range:NSMakeRange(0, name.length)];
                            [name replaceCharactersInRange:NSMakeRange(0, 1) withString:@""]; // strip leading backslash
                            
                            NSLog(@"url:%@",name);
                            [engine forkRepository:name  success:^(NSArray* objects) {
                                NSArray *arr = (NSArray*)objects;
                                
                                NSDictionary *dict = (NSDictionary *)[arr objectAtIndex:0];
                                NSLog(@"success:%@", objects);
                                NSString *cloneUrl = [dict valueForKey:@"clone_url"];
                                MRWorkerOperation *operation = [MRWorkerOperation workerOperationWithLaunchPath:@"/usr/bin/git" arguments:@[@"clone", cloneUrl] outputBlock:^(NSString *output) {
                                                                    // buffer/process program output
                                         NSLog(@"output:%@",output);
                                
                                    } completionBlock:^(int terminationStatus) {
                                                                    // respond to program termination
                                            NSLog(@"terminationStatus:%d",terminationStatus);
                                                NSLog(@"TODO - fire up translator here...");
                                        
                                        // find $PWD  -name *.[hm] | xargs clang-format -i -style=file
                                        
                                        MRWorkerOperation *subop = [MRWorkerOperation workerOperationWithLaunchPath:@"/usr/bin/git" arguments:@[@"clone", cloneUrl] outputBlock:^(NSString *output) {
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
                                        //ls MyProject/*.[hm] | xargs clang-format -i -style=file
                                }];
                                [operation start];
                              // [[MRWorker sharedWorker] addOperation:operation];
                                
                            } failure:^(NSError *error){
                                NSLog(@"D'oh: %@", error.localizedDescription);
                            }];

 
                            
                        }];
                    }
                }];
                
            }];
            
            
        }
    }];
    

    

}







@end
