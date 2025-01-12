//
//  KeychainStorage.m
//  ios-base
//
//  Created by Aaron Geisler on 3/12/14.
//  Copyright (c) 2014 Aaron Geisler. All rights reserved.
//

#import "KeychainStorage.h"
#import <SSKeychain.h>
#import <CocoaLumberjack.h>

@implementation KeychainStorage

#define kGLTokenService @"GistListTokenServiceKey"
#define kGLUserLoginService @"GistListUserLoginServiceKey"
#define kGLUserStarsServiceKey @"GistListUserStarsServiceKey"
#define kGLShareServiceKey @"GistListShareServiceKey"
#define kGLAccount @"GistListAccountKey"

+ (BOOL) shared{
    NSString* shareString = [SSKeychain passwordForService:kGLShareServiceKey account:kGLAccount];
    if (shareString.length == 0){
        DDLogError(@"'share' not found in keychain");
        return NO;
    }
    int intValue = shareString.intValue;
    return intValue > 0;
}

+ (void) setShared:(BOOL) shared{
    BOOL saveShared = [SSKeychain setPassword:[NSString stringWithFormat:@"%i", shared ? 1 : 0] forService:kGLShareServiceKey account:kGLAccount];
    if (!saveShared){
        DDLogError(@"failed to save 'share' in keychain");
    }
}

+ (NSInteger) stars{
    NSString* starsString = [SSKeychain passwordForService:kGLUserStarsServiceKey account:kGLAccount];
    if (starsString.length == 0){
        DDLogError(@"stars not found in KeyChain");
        return 0;
    }
    return starsString.intValue;
}

+ (void) setStars:(NSInteger) stars{
    BOOL saveStars = [SSKeychain setPassword:[NSString stringWithFormat:@"%i", (int)stars] forService:kGLUserStarsServiceKey account:kGLAccount];
    if (!saveStars){
        DDLogError(@"failed to save 'stars' in keychain");
    }
}

+ (NSString*) token{
    NSString* token = [SSKeychain passwordForService:kGLTokenService account:kGLAccount];
    if (token.length == 0){
        DDLogError(@"valid 'token' not found in keychain: %@", token);
    }
    return token;
}

+ (NSString*) userLogin{
    NSString* userLogin = [SSKeychain passwordForService:kGLUserLoginService account:kGLAccount];
    if (userLogin.length == 0){
        DDLogError(@"valid 'userLogin' not found in keychain: %@", userLogin);
    }
    return userLogin;
}

+ (void) setToken:(NSString*) token userLogin:(NSString*) userLogin{
    BOOL saveToken = [SSKeychain setPassword:token forService:kGLTokenService account:kGLAccount];
    BOOL saveUserLogin = [SSKeychain setPassword:userLogin forService:kGLUserLoginService account:kGLAccount];
    if (!saveToken || !saveUserLogin){
        DDLogError(@"failed to save 'token' / 'userLogin' in keychain");
    }
}

@end
