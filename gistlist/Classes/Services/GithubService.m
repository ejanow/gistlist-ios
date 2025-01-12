//
//  GitHubService.m
//  ios-base
//
//  Created by Aaron Geisler on 3/12/14.
//  Copyright (c) 2014 Aaron Geisler. All rights reserved.
//

#import <CocoaLumberjack.h>
#import <ObjectiveSugar.h>
#import <AFNetworking.h>
#import "TaskList.h"
#import "MarkdownHelper.h"
#import "GithubService.h"
#import "KeychainStorage.h"
#import "TokensAndKeys.h"
#import "OCTClient+FetchDatedGist.h"
#import "Errors.h"

@implementation GithubService

#pragma mark - Constants and Keys

#define GITHUB_SCOPES OCTClientAuthorizationScopesUser | OCTClientAuthorizationScopesGist | OCTClientAuthorizationScopesRepository

#pragma mark - State

static OCTClient* _client;
static NSString* _cachedLogin;

#pragma mark - Initialization

+ (void) initialize{
    [OCTClient setClientID:GITHUB_CLIENT_ID clientSecret:GITHUB_CLIENT_SECRET];
    _client = nil;
    _cachedLogin = nil;
}

#pragma mark - Public

+ (BOOL) userIsAuthenticated{
    return (BOOL)(_client != nil && [_client isAuthenticated]);
}

+ (BOOL) authenticateWithStoredCredentials{
    NSString* savedToken = [KeychainStorage token];
    NSString* savedUserLogin = [KeychainStorage userLogin];
    if (savedToken.length > 0 && savedUserLogin.length > 0){
        OCTUser* user = [OCTUser userWithRawLogin:savedUserLogin server:OCTServer.dotComServer];
        _client = [OCTClient authenticatedClientWithUser:user token:savedToken];
        _cachedLogin = savedUserLogin;
    }
    return [_client isAuthenticated];
}

+ (RACSignal*) authenticateUsername:(NSString*) user withPassword:(NSString*) password withAuth:(NSString*) auth{
    if ([_client isAuthenticated]){
        return [RACSignal error:Errors.alreadyAuthenticated];
    }

    OCTUser *u = [OCTUser userWithRawLogin:user server:OCTServer.dotComServer];
    RACSignal* signal = [OCTClient signInAsUser:u password:password oneTimePassword:auth scopes:GITHUB_SCOPES note:nil noteURL:nil fingerprint:nil];
    return [[signal deliverOn:RACScheduler.mainThreadScheduler] doNext:^(OCTClient* authenticatedClient) {
        _client = authenticatedClient;
        [KeychainStorage setToken:_client.token userLogin:_client.user.rawLogin];
        _cachedLogin = [KeychainStorage userLogin];
    }];
}

+ (RACSignal*) createViralGist{
    
    OCTGistFileEdit* gistFileEdit = [[OCTGistFileEdit alloc] init];
    gistFileEdit.filename = [MarkdownHelper viralFilename];
    gistFileEdit.content = [MarkdownHelper viralContent];
    
    OCTGistEdit* gistEdit = [[OCTGistEdit alloc] init];
    gistEdit.gistDescription = [MarkdownHelper viralDescription];
    gistEdit.filesToAdd = @[gistFileEdit];
    gistEdit.publicGist = YES;
    
    RACSignal *request = [_client createGist:gistEdit];
    return [request deliverOn:RACScheduler.mainThreadScheduler];
}


+ (RACSignal*) createGistWithContent:(NSString*) content username:(NSString*) username{
    
    OCTGistFileEdit* gistFileEdit = [[OCTGistFileEdit alloc] init];
    gistFileEdit.filename = [MarkdownHelper filenameForTodaysDate];
    gistFileEdit.content = [MarkdownHelper addHeaderToContent:content];
    
    OCTGistEdit* gistEdit = [[OCTGistEdit alloc] init];
    gistEdit.filesToAdd = @[gistFileEdit];
    gistEdit.publicGist = NO;
    gistEdit.gistDescription = [MarkdownHelper descriptionForUsername:username];
    
    RACSignal *request = [_client createGist:gistEdit];
    return [request deliverOn:RACScheduler.mainThreadScheduler];
}

+ (RACSignal*) updateGist:(OCTGist*) gist withContent:(NSString*) content username:(NSString*) username{
    
    NSString* filename = [gist.files.allKeys firstObject];
    OCTGistFileEdit* gistFileEdit = [[OCTGistFileEdit alloc] init];
    gistFileEdit.filename = filename;
    gistFileEdit.content = [MarkdownHelper addHeaderToContent:content];
    
    OCTGistEdit* gistEdit = [[OCTGistEdit alloc] init];
    gistEdit.gistDescription = [MarkdownHelper descriptionForUsername:username];
    gistEdit.filesToModify = @{filename: gistFileEdit};
    
    RACSignal *request = [_client applyEdit:gistEdit toGist:gist];
    return [request deliverOn:RACScheduler.mainThreadScheduler];
}

+ (RACSignal*) retrieveGistWithRawUrl:(NSURL*) url{
    return [RACSignal createSignal:^RACDisposable *(id <RACSubscriber> subscriber) {
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
        NSOperationQueue *queue = [NSOperationQueue mainQueue];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:queue
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                                   if (error){
                                       DDLogError(@"failed to retrieve gist from url: %@", url);
                                       [subscriber sendError:error];
                                   }else{
                                       NSString* gistContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                       DDLogInfo(@"-----------------------------------------");
                                       DDLogInfo(@"%@", gistContent);
                                       DDLogInfo(@"-----------------------------------------");
                                      [subscriber sendNext:gistContent];
                                   }
                               }];
        return nil;
    }];
}

+ (RACSignal*) retrieveUserInfo{
    RACSignal *request = [_client fetchUserInfo];
    return [request deliverOn:RACScheduler.mainThreadScheduler];
}

+ (RACSignal*) retrieveGistsSince:(NSDate*) since{
    RACSignal *request = [_client fetchGistsUpdatedSince:since];
    return [[[request collect] map:^id(NSArray* gists) {
        return [self filterGists:gists];
    }] deliverOn:RACScheduler.mainThreadScheduler];
}

#pragma mark - Helpers

+ (void) invalidateCachedLogin{
    [KeychainStorage setToken:@"" userLogin:@""];
    _client = nil;
    _cachedLogin = nil;
}

+ (BOOL) containsFilenameOfInterest:(OCTGist*) gist{
    NSArray* filenames = [[gist files] allKeys];
    NSArray* filteredFilenames = [filenames select:^BOOL(NSString* filename) {
        BOOL containsFileKey = [[filename lowercaseString] containsString:[[MarkdownHelper filenameKey] lowercaseString]];
        BOOL containsViralKey = [filename containsString:[MarkdownHelper viralFilename]];
        return containsFileKey && !containsViralKey;
    }];
    return filteredFilenames.count > 0;
}

+ (NSMutableArray*) filterGists:(NSArray*) gists{
    
    // Keep only Gists with a relevant filename
    NSArray* filteredGists = [gists select:^BOOL(OCTGist* gist) {
        return [self containsFilenameOfInterest:gist];
    }];
    
    // Sort on creation date (newest first)
    NSMutableArray* mutableFilteredGists = [NSMutableArray arrayWithArray:filteredGists];
    NSSortDescriptor* sortByDate = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO];
    [mutableFilteredGists sortUsingDescriptors:@[sortByDate]];
    
    // Return sorted and filtered list
    return mutableFilteredGists;
}

@end
