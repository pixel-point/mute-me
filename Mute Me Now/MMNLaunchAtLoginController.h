//
//  MMNLaunchAtLoginController.h
//  Mute Me
//
//  Created by Dmitry Rodionov on 17/06/2017.
//  Copyright © 2017 Pixel Point. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMNLaunchAtLoginController : NSObject
@property (readwrite) BOOL shouldLaunchOnLogin;

+ (instancetype)sharedController;

@end
