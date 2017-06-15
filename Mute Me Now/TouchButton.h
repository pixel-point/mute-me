//
//  CustomButton.h
//  Mute Me Now
//
//  Created by nikita on 13/06/2017.
//  Copyright © 2017 Pixel Point. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TouchDelegate.h"

@interface TouchButton : NSButton

@property (nonatomic, weak) id<TouchDelegate> delegate;

@end
