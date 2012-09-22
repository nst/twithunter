//
//  STTwitterRequest.m
//  STTwitterRequests
//
//  Created by Nicolas Seriot on 9/5/12.
//  Copyright (c) 2012 Nicolas Seriot. All rights reserved.
//

#import "STOAuth.h"
#import "STHTTPRequest.h"

#include <CommonCrypto/CommonHMAC.h>

@interface STOAuth ()

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

@property (nonatomic, retain) NSString *oauthConsumerKey;
@property (nonatomic, retain) NSString *oauthConsumerSecret;
@property (nonatomic, retain) NSString *oauthToken;
@property (nonatomic, retain) NSString *oauthTokenSecret;

@property (nonatomic, retain) NSString *oauthAuthorizeURLString;
@property (nonatomic, retain) NSString *oauthRequestTokenURLString;
@property (nonatomic, retain) NSString *oauthAccessTokenURLString;

@end

@implementation STOAuth

/*
 Based on the following documentation
 http://oauth.net/core/1.0/
 https://dev.twitter.com/docs/auth/authorizing-request
 https://dev.twitter.com/docs/auth/implementing-sign-twitter
 https://dev.twitter.com/docs/auth/creating-signature
 https://dev.twitter.com/docs/api/1/post/oauth/request_token
 https://dev.twitter.com/docs/oauth/xauth
 ...
 */

+ (STOAuth *)twitterServiceWithConsumerKey:(NSString *)consumerKey consumerSecret:(NSString *)consumerSecret {

    STOAuth *to = [[STOAuth alloc] init];
    
    to.oauthAuthorizeURLString = @"https://api.twitter.com/oauth/authorize";
    to.oauthRequestTokenURLString = @"https://api.twitter.com/oauth/request_token";
    to.oauthAccessTokenURLString = @"https://api.twitter.com/oauth/access_token";
    
    to.oauthConsumerKey = consumerKey;
    to.oauthConsumerSecret = consumerSecret;
    
    return [to autorelease];
}

+ (STOAuth *)twitterServiceWithConsumerKey:(NSString *)consumerKey consumerSecret:(NSString *)consumerSecret oauthToken:(NSString *)oauthToken oauthTokenSecret:(NSString *)oauthTokenSecret {
    
    STOAuth *to = [self twitterServiceWithConsumerKey:consumerKey consumerSecret:consumerSecret];
    
    to.oauthToken = oauthToken;
    to.oauthTokenSecret = oauthTokenSecret;
    
    return to;
}

+ (STOAuth *)twitterServiceWithConsumerKey:(NSString *)consumerKey consumerSecret:(NSString *)consumerSecret username:(NSString *)username password:(NSString *)password {
    
    STOAuth *to = [self twitterServiceWithConsumerKey:consumerKey consumerSecret:consumerSecret];
    to.username = username;
    to.password = password;
    
    return to;
}

+ (NSArray *)encodedParametersDictionaries:(NSArray *)parameters {
    
    NSMutableArray *encodedParameters = [NSMutableArray array];
    
    for(NSDictionary *d in parameters) {
        
        NSString *key = [[d allKeys] lastObject];
        NSString *value = [[d allValues] lastObject];
        
        NSString *encodedKey = [key urlEncodedString];
        NSString *encodedValue = [value urlEncodedString];
        
        //NSString *s = [NSString stringWithFormat:@"%@=\"%@\"", encodedKey, encodedValue];
        
        [encodedParameters addObject:@{encodedKey : encodedValue}];
    }
    
    return encodedParameters;
}

+ (NSString *)stringFromParametersDictionaries:(NSArray *)parametersDictionaries {
    
    NSMutableArray *parameters = [NSMutableArray array];
    
    for(NSDictionary *d in parametersDictionaries) {
        
        NSString *encodedKey = [[d allKeys] lastObject];
        NSString *encodedValue = [[d allValues] lastObject];
        
        NSString *s = [NSString stringWithFormat:@"%@=\"%@\"", encodedKey, encodedValue];
        
        [parameters addObject:s];
    }
    
    return [parameters componentsJoinedByString:@", "];
}

+ (NSString *)oauthHeaderValueWithParameters:(NSArray *)parametersDictionaries {
    
    NSArray *encodedParametersDictionaries = [self encodedParametersDictionaries:parametersDictionaries];
    
    NSString *encodedParametersString = [self stringFromParametersDictionaries:encodedParametersDictionaries];
    
    NSString *headerValue = [NSString stringWithFormat:@"OAuth %@", encodedParametersString];
    
    NSLog(@"-- %@", headerValue);
    
    return headerValue;
}

+ (NSArray *)parametersDictionariesSortedByKey:(NSArray *)parametersDictionaries {
    
    return [parametersDictionaries sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDictionary *d1 = (NSDictionary *)obj1;
        NSDictionary *d2 = (NSDictionary *)obj2;
        
        NSString *key1 = [[d1 allKeys] lastObject];
        NSString *key2 = [[d2 allKeys] lastObject];
        
        return [key1 compare:key2];
    }];
    
}

- (NSString *)oauthNonce {
    /*
     The oauth_nonce parameter is a unique token your application should generate for each unique request. Twitter will use this value to determine whether a request has been submitted multiple times. The value for this request was generated by base64 encoding 32 bytes of random data, and stripping out all non-word characters, but any approach which produces a relatively random alphanumeric string should be OK here.
     */
    
    if(_testOauthNonce) return _testOauthNonce;
    
    return [NSString random32Characters];
}

- (NSString *)includeEntities {
    return @"true";
}

+ (NSString *)signatureBaseStringWithHTTPMethod:(NSString *)httpMethod url:(NSURL *)url parameters:(NSArray *)parameters {
    NSMutableArray *allParameters = [NSMutableArray arrayWithArray:parameters];
    
    NSArray *getParameters = [url getParametersDictionaries];
    
    [allParameters addObjectsFromArray:getParameters];
    
    NSArray *encodedParametersDictionaries = [self encodedParametersDictionaries:allParameters];
    
    NSArray *sortedEncodedParametersDictionaries = [self parametersDictionariesSortedByKey:encodedParametersDictionaries];
    
    /**/
    
    NSMutableArray *encodedParameters = [NSMutableArray array];
    
    for(NSDictionary *d in sortedEncodedParametersDictionaries) {
        NSString *encodedKey = [[d allKeys] lastObject];
        NSString *encodedValue = [[d allValues] lastObject];
        
        NSString *s = [NSString stringWithFormat:@"%@=%@", encodedKey, encodedValue];
        
        [encodedParameters addObject:s];
    }
    
    NSString *encodedParametersString = [encodedParameters componentsJoinedByString:@"&"];
    
    NSLog(@"-- encodedParametersString: %@", encodedParametersString);
    
    NSLog(@"-- normalizedURL: %@", [url normalizedForOauthSignatureString]);
    
    NSString *signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@",
                                     [httpMethod uppercaseString],
                                     [[url normalizedForOauthSignatureString] urlEncodedString],
                                     [encodedParametersString urlEncodedString]];
    
    NSLog(@"-- signatureBaseString: %@", signatureBaseString);
    
    return signatureBaseString;
}

+ (NSString *)oauthSignatureWithHTTPMethod:(NSString *)httpMethod url:(NSURL *)url parameters:(NSArray *)parameters consumerSecret:(NSString *)consumerSecret tokenSecret:(NSString *)tokenSecret {
    /*
     The oauth_signature parameter contains a value which is generated by running all of the other request parameters and two secret values through a signing algorithm. The purpose of the signature is so that Twitter can verify that the request has not been modified in transit, verify the application sending the request, and verify that the application has authorization to interact with the user's account.
     
     The process for calculating the oauth_signature for this request is described in Creating a signature.
     https://dev.twitter.com/docs/auth/creating-signature
     */
    
    NSString *signatureBaseString = [[self class] signatureBaseStringWithHTTPMethod:httpMethod url:url parameters:parameters];
    
    NSLog(@"-- signatureBaseString: %@", signatureBaseString);
    
    /*
     Note that there are some flows, such as when obtaining a request token, where the token secret is not yet known. In this case, the signing key should consist of the percent encoded consumer secret followed by an ampersand character '&'.
     */
    
    NSString *encodedConsumerSecret = [consumerSecret urlEncodedString];
    NSString *encodedTokenSecret = [tokenSecret urlEncodedString];
    
    NSString *signingKey = [NSString stringWithFormat:@"%@&", encodedConsumerSecret];
    
    NSLog(@"-- signing key: %@", signingKey);
    
    if(encodedTokenSecret) {
        signingKey = [signingKey stringByAppendingString:encodedTokenSecret];
    }
    
    NSString *oauthSignature = [signatureBaseString signHmacSHA1WithKey:signingKey];
    
    return oauthSignature;
}

- (void)verifyCredentialsWithSuccessBlock:(void(^)(NSString *username))successBlock errorBlock:(void(^)(NSError *error))errorBlock {
    
    // three cases
    
    // 1. username / password -> xauth
    
    if(_username && _password) {
        [self postXAuthAccessTokenRequestWithUsername:_username password:_password successBlock:^(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName) {
            successBlock(screenName);
        } errorBlock:^(NSError *error) {
            errorBlock(error);
        }];
    }
    
    // 2. oauth tokens -> verify
    // 3. nothing -> url PIN
    
}

- (NSString *)oauthSignatureMethod {
    /*
     The oauth_signature_method used by Twitter is HMAC-SHA1. This value should be used for any authorized request sent to Twitter's API.
     */
    return @"HMAC-SHA1";
}

- (NSString *)oauthTimestamp {
    /*
     The oauth_timestamp parameter indicates when the request was created. This value should be the number of seconds since the Unix epoch at the point the request is generated, and should be easily generated in most programming languages. Twitter will reject requests which were created too far in the past, so it is important to keep the clock of the computer generating requests in sync with NTP.
     */
    
    if(_testOauthTimestamp) return _testOauthTimestamp;
    
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
    
    return [NSString stringWithFormat:@"%d", (int)timeInterval];
}

- (NSString *)oauthVersion {
    /*
     The oauth_version parameter should always be 1.0 for any request sent to the Twitter API.
     */
    
    return @"1.0";
}

- (void)postTokenRequest:(void(^)(NSURL *url, NSString *oauthToken))successBlock errorBlock:(void(^)(NSError *error))errorBlock {
    
    __block STHTTPRequest *r = [STHTTPRequest requestWithURLString:_oauthRequestTokenURLString];
    
    r.POSTDictionary = @{};
    
    NSMutableArray *parametersDictionaries = [NSMutableArray arrayWithObjects:
                                              @{@"oauth_consumer_key"     : [self oauthConsumerKey]},
                                              @{@"oauth_nonce"            : [self oauthNonce]},
                                              @{@"oauth_signature_method" : [self oauthSignatureMethod]},
                                              @{@"oauth_timestamp"        : [self oauthTimestamp]},
                                              @{@"oauth_version"          : [self oauthVersion]}, nil];
    
    NSString *httpMethod = r.POSTDictionary ? @"POST" : @"GET";
    
    NSString *signature = [[self class] oauthSignatureWithHTTPMethod:httpMethod url:r.url parameters:parametersDictionaries consumerSecret:_oauthConsumerSecret tokenSecret:_oauthTokenSecret];
    [parametersDictionaries addObject:@{@"oauth_signature" : signature}];
    
    NSString *s = [[self class] oauthHeaderValueWithParameters:parametersDictionaries];
    
    [r setHeaderWithName:@"Authorization" value:s];
    
    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
        
        NSDictionary *d = [body parametersDictionary];
        
        NSString *s = [NSString stringWithFormat:@"%@?%@", _oauthAuthorizeURLString, body];
        
        NSURL *url = [NSURL URLWithString:s];
        
        successBlock(url, d[@"oauth_token"]);
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- body: %@", r.responseString);
        errorBlock(error);
    };
    
    [r startAsynchronous];
}

- (void)postXAuthAccessTokenRequestWithUsername:(NSString *)username
                                       password:(NSString *)password
                                   successBlock:(void(^)(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName))successBlock
                                     errorBlock:(void(^)(NSError *error))errorBlock {
    
    // TODO: generalize this for all requests
    
    STHTTPRequest *r = [STHTTPRequest requestWithURLString:_oauthAccessTokenURLString];
    
    NSArray *postParameters = @[@{@"x_auth_username" : [username urlEncodedString]},
    @{@"x_auth_password" : [password urlEncodedString]},
    @{@"x_auth_mode"     : @"client_auth"}];
    
    NSMutableArray *oauthParameters = [NSMutableArray arrayWithObjects:
                                       @{@"oauth_consumer_key"     : [self oauthConsumerKey]},
                                       @{@"oauth_nonce"            : [self oauthNonce]},
                                       @{@"oauth_signature_method" : [self oauthSignatureMethod]},
                                       @{@"oauth_timestamp"        : [self oauthTimestamp]},
                                       @{@"oauth_version"          : [self oauthVersion]}, nil];
    
    NSMutableArray *postAndOAuthParameters = [NSMutableArray array];
    [postAndOAuthParameters addObjectsFromArray:postParameters];
    [postAndOAuthParameters addObjectsFromArray:oauthParameters];
    
    NSString *signature = [[self class] oauthSignatureWithHTTPMethod:@"POST" url:r.url parameters:postAndOAuthParameters consumerSecret:_oauthConsumerSecret tokenSecret:_oauthTokenSecret];
    [oauthParameters addObject:@{@"oauth_signature" : signature}];
    
    NSMutableDictionary *md = [NSMutableDictionary dictionary];
    
    for(NSDictionary *d in postParameters) {
        NSString *k = [[d allKeys] lastObject];
        NSString *v = [[d allValues] lastObject];
        
        [md setObject:v forKey:k];
    }
    
    NSMutableDictionary *postParametersDictionary = [NSMutableDictionary dictionary];
    
    for(NSDictionary *d in postParameters) {
        [postParametersDictionary setValuesForKeysWithDictionary:d];
    }
    
    r.POSTDictionary = postParametersDictionary;
    
    NSString *s = [[self class] oauthHeaderValueWithParameters:oauthParameters];
    
    [r setHeaderWithName:@"Authorization" value:s];
    
    NSLog(@"-- Authorization: %@", s);
    
    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
        
        NSDictionary *d = [body parametersDictionary];
        
        // https://api.twitter.com/oauth/authorize?oauth_token=15111995-jLCbamjXzetP2r2IXsRmeJsDCI7Yl7hq1szLLJ2Y0&oauth_token_secret=0fi5ciLrZHO07iJ9hdzWqLvVlPRFIcEqltEWF3RDxI&user_id=15111995&screen_name=nst021
        
        self.oauthToken = d[@"oauth_token"];
        self.oauthTokenSecret = d[@"oauth_token_secret"];
        
        successBlock(_oauthToken, _oauthTokenSecret, d[@"user_id"], d[@"screen_name"]);
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- body: %@", r.responseString);
        errorBlock(error);
    };
    
    [r startAsynchronous];
}

//- (void)postXAuthAccessTokenRequestTweepyWithUsername:(NSString *)username
//                                   password:(NSString *)password
//                               successBlock:(void(^)(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName, NSDictionary *postParametersDictionary))successBlock
//                                 errorBlock:(void(^)(NSError *error))errorBlock {
//
//    STHTTPRequest *r = [STHTTPRequest requestWithURLString:@"https://twitter.com/oauth/access_token"];
//
//    NSMutableArray *postParameters = [NSMutableArray arrayWithObjects:
//    @{@"x_auth_username"        : [username urlEncodedString]},
//    @{@"x_auth_password"        : [password urlEncodedString]},
//    @{@"x_auth_mode"            : @"client_auth"},
//    @{@"oauth_consumer_key"     : [self oauthConsumerKey]},
//    @{@"oauth_nonce"            : [self oauthNonce]},
//    @{@"oauth_signature_method" : [self oauthSignatureMethod]},
//    @{@"oauth_timestamp"        : [self oauthTimestamp]},
//    @{@"oauth_version"          : [self oauthVersion]}, nil];
//
//    NSString *signature = [[self class] oauthSignatureWithHTTPMethod:@"POST" url:r.url parameters:postParameters consumerSecret:_oauthConsumerSecret tokenSecret:_oauthTokenSecret];
//    [postParameters addObject:@{@"oauth_signature" : signature}];
//
//    NSMutableDictionary *postParametersDictionary = [NSMutableDictionary dictionary];
//
//    for(NSDictionary *d in postParameters) {
//        [postParametersDictionary setValuesForKeysWithDictionary:d];
//    }
//
//    r.POSTDictionary = postParametersDictionary;
//
//    NSLog(@"-- POST dictionary: %@", postParametersDictionary);
//
//    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
//
//        NSDictionary *d = [body parametersDictionary];
//
//        // https://api.twitter.com/oauth/authorize?oauth_token=15111995-jLCbamjXzetP2r2IXsRmeJsDCI7Yl7hq1szLLJ2Y0&oauth_token_secret=0fi5ciLrZHO07iJ9hdzWqLvVlPRFIcEqltEWF3RDxI&user_id=15111995&screen_name=nst021
//
//        successBlock(d[@"oauth_token"], d[@"oauth_token_secret"], d[@"user_id"], d[@"screen_name"], postParametersDictionary);
//    };
//
//    r.errorBlock = ^(NSError *error) {
//        NSLog(@"-- body: %@", r.responseString);
//        errorBlock(error);
//    };
//
//    [r startAsynchronous];
//}

- (void)postAccessTokenRequestWithPIN:(NSString *)pin
                           oauthToken:(NSString *)oauthToken
                         successBlock:(void(^)(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName))successBlock
                           errorBlock:(void(^)(NSError *error))errorBlock {
    
    NSParameterAssert(pin);
    
    STHTTPRequest *r = [STHTTPRequest requestWithURLString:_oauthAccessTokenURLString];
    
    r.POSTDictionary = @{@"oauth_verifier" : pin};
    
    NSMutableArray *parametersDictionaries = [NSMutableArray arrayWithObjects:
                                              @{@"oauth_token"     : oauthToken},
                                              @{@"oauth_consumer_key"     : [self oauthConsumerKey]},
                                              @{@"oauth_nonce"            : [self oauthNonce]},
                                              @{@"oauth_signature_method" : [self oauthSignatureMethod]},
                                              @{@"oauth_timestamp"        : [self oauthTimestamp]},
                                              @{@"oauth_version"          : [self oauthVersion]}, nil];
    
    NSString *httpMethod = r.POSTDictionary ? @"POST" : @"GET";
    
    NSString *signature = [[self class] oauthSignatureWithHTTPMethod:httpMethod url:r.url parameters:parametersDictionaries consumerSecret:_oauthConsumerSecret tokenSecret:_oauthTokenSecret];
    [parametersDictionaries addObject:@{@"oauth_signature" : signature}];
    
    NSString *s = [[self class] oauthHeaderValueWithParameters:parametersDictionaries];
    
    [r setHeaderWithName:@"Authorization" value:s];
    
    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
        
        NSDictionary *d = [body parametersDictionary];
        
        // https://api.twitter.com/oauth/authorize?oauth_token=15111995-jLCbamjXzetP2r2IXsRmeJsDCI7Yl7hq1szLLJ2Y0&oauth_token_secret=0fi5ciLrZHO07iJ9hdzWqLvVlPRFIcEqltEWF3RDxI&user_id=15111995&screen_name=nst021
        
        successBlock(d[@"oauth_token"], d[@"oauth_token_secret"], d[@"user_id"], d[@"screen_name"]);
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- body: %@", r.responseString);
        errorBlock(error);
    };
    
    [r startAsynchronous];
}

- (void)signRequest:(STHTTPRequest *)r {
    
    NSParameterAssert(_oauthConsumerKey);
    NSParameterAssert(_oauthConsumerSecret);
    
    NSParameterAssert(_oauthToken);
    //    NSParameterAssert(_oauthTokenSecret);
    
    NSMutableArray *parametersDictionaries = [NSMutableArray arrayWithObjects:
                                              @{@"oauth_token"            : [self oauthToken]},
                                              @{@"oauth_consumer_key"     : [self oauthConsumerKey]},
                                              @{@"oauth_nonce"            : [self oauthNonce]},
                                              @{@"oauth_signature_method" : [self oauthSignatureMethod]},
                                              @{@"oauth_timestamp"        : [self oauthTimestamp]},
                                              @{@"oauth_version"          : [self oauthVersion]}, nil];
    
    NSString *httpMethod = r.POSTDictionary ? @"POST" : @"GET";
    
    if(r.POSTDictionary) {
        [r.POSTDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [parametersDictionaries addObject:@{ key : obj }];
        }];
    }
    
    NSString *signature = [[self class] oauthSignatureWithHTTPMethod:httpMethod url:r.url parameters:parametersDictionaries consumerSecret:_oauthConsumerSecret tokenSecret:_oauthTokenSecret];
    [parametersDictionaries addObject:@{@"oauth_signature" : signature}];
    
    NSString *s = [[self class] oauthHeaderValueWithParameters:parametersDictionaries];
    
    [r setHeaderWithName:@"Authorization" value:s];
}

//- (void)getUserTimelineWithSuccessBlock:(void(^)(NSString *jsonString))successBlock errorBlock:(void(^)(NSError *error))errorBlock {
//
//    STHTTPRequest *r = [STHTTPRequest requestWithURLString:@"https://api.twitter.com/1.1/statuses/home_timeline.json"];
//
//    [self signRequest:r];
//
//    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
//        successBlock(body);
//    };
//
//    r.errorBlock = ^(NSError *error) {
//        NSLog(@"-- body: %@", r.responseString);
//        errorBlock(error);
//    };
//
//    [r startAsynchronous];
//}

//- (void)getFollowersWithScreenName:(NSString *)screenName successBlock:(void(^)(NSString *jsonString))successBlock errorBlock:(void(^)(NSError *error))errorBlock {
//
//    NSString *urlString = [NSString stringWithFormat:@"https://api.twitter.com/1.1/followers/ids.json?screen_name=%@", screenName];
//
//    STHTTPRequest *r = [STHTTPRequest requestWithURLString:urlString];
//
//    [self signRequest:r];
//
//    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
//        successBlock(body);
//    };
//
//    r.errorBlock = ^(NSError *error) {
//        NSLog(@"-- body: %@", r.responseString);
//        errorBlock(error);
//    };
//
//    [r startAsynchronous];
//}

- (void)getResource:(NSString *)resource
         parameters:(NSDictionary *)params
       successBlock:(void(^)(id json))successBlock
         errorBlock:(void(^)(NSError *error))errorBlock {
    
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"https://api.twitter.com/1.1/%@", resource];
    
    NSMutableArray *parameters = [NSMutableArray array];
    
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *s = [NSString stringWithFormat:@"%@=%@", key, obj];
        [parameters addObject:s];
    }];
    
    if([parameters count]) {
        NSString *parameterString = [parameters componentsJoinedByString:@"&"];
        
        [urlString appendFormat:@"?%@", parameterString];
    }
    
    __block STHTTPRequest *r = [STHTTPRequest requestWithURLString:urlString];
    
    [self signRequest:r];
    
    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
        
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:r.responseData options:NSJSONReadingMutableLeaves error:&jsonError];
        NSLog(@"-- jsonError: %@", [jsonError localizedDescription]);
        
        if(json == nil) {
            errorBlock(jsonError);
            return;
        }
        
        NSLog(@"** %@", json);
        
        successBlock(json);
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- body: %@", r.responseString);
        errorBlock(error);
    };
    
    [r startAsynchronous];
}

- (void)postResource:(NSString *)resource
          parameters:(NSDictionary *)params
        successBlock:(void(^)(id json))successBlock
          errorBlock:(void(^)(NSError *error))errorBlock {
    
    NSString *urlString = [NSString stringWithFormat:@"https://api.twitter.com/1.1/%@", resource];
    
    STHTTPRequest *r = [STHTTPRequest requestWithURLString:urlString];
    
    r.POSTDictionary = params ? params : @{};
    
    [self signRequest:r];
    
    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
        successBlock(body);
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- body: %@", r.responseString);
        errorBlock(error);
    };
    
    [r startAsynchronous];
}

@end

@implementation NSURL (STTwitterOAuth)

- (NSArray *)getParametersDictionaries {
    
    NSString *q = [self query];
    
    NSArray *getParameters = [q componentsSeparatedByString:@"&"];
    
    NSMutableArray *ma = [NSMutableArray array];
    
    for(NSString *s in getParameters) {
        NSArray *kv = [s componentsSeparatedByString:@"="];
        NSAssert([kv count] == 2, @"-- bad length");
        if([kv count] != 2) continue;
        [ma addObject:@{kv[0] : kv[1]}];
    }
    
    return ma;
}

- (NSString *)normalizedForOauthSignatureString {
    
    //    NSArray *domainComponents  = [[self host] componentsSeparatedByString:@"."];
    //    NSRange range = NSMakeRange(1, [domainComponents count]-1);
    //    NSArray *subComponents = [domainComponents subarrayWithRange:range];
    //    NSString *subdomain = [subComponents componentsJoinedByString:@"."];
    
    return [NSString stringWithFormat:@"%@://%@%@", [self scheme], [self host], [self path]];
}

@end

@implementation NSString (STTwitterOAuth)

+ (NSString *)randomString {
    CFUUIDRef cfuuid = CFUUIDCreate (kCFAllocatorDefault);
    NSString *uuid = (NSString *)CFUUIDCreateString (kCFAllocatorDefault, cfuuid);
    CFRelease (cfuuid);
    return [uuid autorelease];
}

+ (NSString *)random32Characters {
    NSString *randomString = [self randomString];
    
    NSAssert([randomString length] >= 32, @"");
    
    return [randomString substringToIndex:32];
}

- (NSString *)signHmacSHA1WithKey:(NSString *)key {
    
    unsigned char buf[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, [key UTF8String], [key length], [self UTF8String], [self length], buf);
    NSData *data = [NSData dataWithBytes:buf length:CC_SHA1_DIGEST_LENGTH];
    
    return [data base64EncodedString];
}

- (NSDictionary *)parametersDictionary {
    
    NSArray *parameters = [self componentsSeparatedByString:@"&"];
    
    NSMutableDictionary *md = [NSMutableDictionary dictionary];
    
    for(NSString *parameter in parameters) {
        NSArray *keyValue = [parameter componentsSeparatedByString:@"="];
        if([keyValue count] != 2) {
            NSLog(@"-- bad parameter: %@", parameter);
            continue;
        }
        
        [md setObject:keyValue[1] forKey:keyValue[0]];
    }
    
    return md;
}

- (NSString *)urlEncodedString {
    // https://dev.twitter.com/docs/auth/percent-encoding-parameters
    
    NSString *s = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                      (CFStringRef)self,
                                                                      NULL,
                                                                      CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                      kCFStringEncodingUTF8);
    return [s autorelease];
}

@end

@implementation NSData (STTwitterOAuth)

- (NSString *)base64EncodedString {
    
    CFDataRef retval = NULL;
    SecTransformRef encodeTrans = SecEncodeTransformCreate(kSecBase64Encoding, NULL);
    if (encodeTrans == NULL) return nil;
    
    if (SecTransformSetAttribute(encodeTrans, kSecTransformInputAttributeName, (CFDataRef)self, NULL)) {
        retval = SecTransformExecute(encodeTrans, NULL);
    }
    CFRelease(encodeTrans);
    
    return [[[NSString alloc] initWithData:(NSData *)retval encoding:NSUTF8StringEncoding] autorelease];
}

@end