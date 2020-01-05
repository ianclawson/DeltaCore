//
//  DeltaCore.h
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for DeltaCore.
FOUNDATION_EXPORT double DeltaCoreVersionNumber;

//! Project version string for DeltaCore.
FOUNDATION_EXPORT const unsigned char DeltaCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <DeltaCore/PublicHeader.h>

// HACK: Needed because the generated DeltaCore-Swift header file uses @import syntax, which isn't supported in Objective-C++ code.
#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>
#if TARGET_OS_TV
#import <GameController/GameController.h> // for GCEventViewController
#endif

// Extensible Enums
typedef NSString *GameType NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *CheatType NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *GameControllerInputType NS_TYPED_EXTENSIBLE_ENUM;

extern NSNotificationName const DeltaRegistrationRequestNotification;
