//
//  MMNLaunchAtLoginController.m
//  Mute Me
//
//  Created by Dmitry Rodionov on 17/06/2017.
//  Copyright © 2017 Pixel Point. All rights reserved.
//

#import "MMNLaunchAtLoginController.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString *const kLauncherBundleID = @"Pixel-Point.Mute-Me-Now-Launcher";

@implementation MMNLaunchAtLoginController

+ (instancetype)sharedController
{
    static id shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });

    return shared;
}

- (BOOL)shouldLaunchOnLogin
{
    // SMCopyAllJobDictionaries() was deprecated back in 10.10, but as Apple says in
    // their own documentation:
    //
    // > For the specific use of testing the state of a login item that may have been
    // > enabled with SMLoginItemSetEnabled() in order to show that state to the
    // > user, this function remains the recommended API. A replacement API for this
    // > specific use will be provided before this function is removed.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    NSArray <NSDictionary *> *jobs = (__bridge NSArray<NSDictionary *> *)(SMCopyAllJobDictionaries(kSMDomainUserLaunchd));
#pragma clang diagnostic pop
    if (jobs.count == 0) {
        return NO;
    }
    // Look for a launchd job with the same bundle ID as our launcher application
    NSUInteger idx = [jobs indexOfObjectPassingTest:^BOOL(NSDictionary *job, NSUInteger idx, BOOL *stop) {
        return [job[@"Label"] isEqualToString:kLauncherBundleID];
    }];
    return (idx != NSNotFound);
}


- (void)setShouldLaunchOnLogin:(BOOL)state
{
    BOOL set = SMLoginItemSetEnabled((__bridge CFStringRef)(kLauncherBundleID), state);
    if (!set) {
        NSLog(@"Unable to toggle the login item");
    }
}

@end
