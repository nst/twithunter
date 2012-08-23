//
//  MGTwitterEngine+TH.m
//  TwitHunter
//
//  Created by Nicolas Seriot on 5/1/10.
//  Copyright 2010 seriot.ch. All rights reserved.
//

#import "STTwitterEngine.h"
#import <Social/Social.h>
#import <Accounts/Accounts.h>

@implementation STTwitterEngine

- (NSString *)username {
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray *accounts = [accountStore accountsWithAccountType:accountType];
    NSAssert([accounts count] == 1, @"");
    ACAccount *twitterAccount = [accounts objectAtIndex:0];
    return twitterAccount.username;
}

- (void)requestAccessWithCompletionBlock:(void(^)(ACAccount *twitterAccount))completionBlock errorBlock:(void(^)(NSError *))errorBlock {
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if(granted) {
                
                NSArray *accounts = [accountStore accountsWithAccountType:accountType];
                
                NSAssert([accounts count] == 1, @"");
                
                ACAccount *twitterAccount = [accounts objectAtIndex:0];
                
                completionBlock(twitterAccount);
            } else {
                errorBlock(error);
            }
        }];
    }];
}

- (void)getFavoritesWithParameters:(NSDictionary *)params completionBlock:(STTE_completionBlock_t)completionBlock errorBlock:(STTE_errorBlock_t)errorBlock {
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        NSLog(@"-- granted: %d, error %@", granted, [error localizedDescription]);
        
        if(granted == NO) return;
        
        NSArray *accounts = [accountStore accountsWithAccountType:accountType];
        
        if ([accounts count] != 1) return;
        
        ACAccount *twitterAccount = [accounts objectAtIndex:0];
        
        //        NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1/statuses/update.json"];
        //        NSDictionary *params = [NSDictionary dictionaryWithObject:@"test" forKey:@"status"];
        //        SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:url parameters:params];
        //        request.account = twitterAccount;
        //
        //        [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        //            NSString *output = [NSString stringWithFormat:@"HTTP response status: %ld", [urlResponse statusCode]];
        //            NSLog(@"%@", output);
        //        }];
        
        NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1/statuses/favorites.json"];
        SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
        request.account = twitterAccount;
        
        [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
            NSString *output = [NSString stringWithFormat:@"HTTP response status: %ld", [urlResponse statusCode]];
            NSLog(@"%@", output);
            
            NSError *jsonError = nil;
            NSJSONSerialization *json = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:&jsonError];
            NSLog(@"-- json: %@", json);
            NSLog(@"-- error: %@", [jsonError localizedDescription]);
            
            if(json) {
                completionBlock((NSArray *)json);
            } else {
                errorBlock(jsonError);
            }
        }];
        
        
    }];
    
}

- (void)fetchFavoriteUpdatesForUsername:(NSString *)aUsername completionBlock:(STTE_completionBlock_t)completionBlock errorBlock:(STTE_errorBlock_t)errorBlock {
    
    NSAssert(aUsername != nil, @"no username");
    
    NSDictionary *params = @{@"screen_name":aUsername, @"count":@"200"};
    
    [self fetchHomeTimelineWithParameters:params completionBlock:completionBlock errorBlock:errorBlock];
}

- (void)fetchHomeTimelineWithParameters:(NSDictionary *)params completionBlock:(STTE_completionBlock_t)completionBlock errorBlock:(STTE_errorBlock_t)errorBlock {
    
    [self requestAccessWithCompletionBlock:^(ACAccount *twitterAccount) {
        NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1/statuses/home_timeline.json"];
        SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
        request.account = twitterAccount;
        
        [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
            NSString *output = [NSString stringWithFormat:@"HTTP response status: %ld", [urlResponse statusCode]];
            NSLog(@"%@", output);
            
            if(responseData == nil) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    errorBlock(nil);
                }];
                return;
            }
            
            NSError *jsonError = nil;
            NSJSONSerialization *json = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:&jsonError];
            NSLog(@"-- json: %@", json);
            NSLog(@"-- error: %@", [jsonError localizedDescription]);
            
            if(json) {
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionBlock((NSArray *)json);
                }];
                
            } else {
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    errorBlock(jsonError);
                }];
            }
        }];
        
    } errorBlock:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            errorBlock(error);
        }];
    }];
}

- (void)fetchHomeTimelineSinceID:(unsigned long long)sinceID count:(NSUInteger)nbTweets completionBlock:(STTE_completionBlock_t)completionBlock errorBlock:(STTE_errorBlock_t)errorBlock {
    
    NSDictionary *params = @{@"include_entities":@"1", @"since_id":[@(sinceID) description]};
    
    [self fetchHomeTimelineWithParameters:params completionBlock:completionBlock errorBlock:errorBlock];
}

- (void)fetchHomeTimeline:(NSUInteger)nbTweets completionBlock:(STTE_completionBlock_t)completionBlock errorBlock:(STTE_errorBlock_t)errorBlock {
    
    NSDictionary *params = @{@"include_entities":@"0"};
    
    [self fetchHomeTimelineWithParameters:params completionBlock:completionBlock errorBlock:errorBlock];
}

//        NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1/statuses/update.json"];
//        NSDictionary *params = [NSDictionary dictionaryWithObject:@"test" forKey:@"status"];
//        SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:url parameters:params];
//        request.account = twitterAccount;
//
//        [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
//            NSString *output = [NSString stringWithFormat:@"HTTP response status: %ld", [urlResponse statusCode]];
//            NSLog(@"%@", output);
//        }];

@end
