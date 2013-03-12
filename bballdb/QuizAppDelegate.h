//
//  QuizAppDelegate.h
//  bballdb
//
//  Created by Joe Seeley on 11/5/12.
//  Copyright (c) 2012 Joe Seeley. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import "FMDatabase.h"
#import "UltraliteDB.h"
#import "GameDetails.h"

@class QuizViewController;

@interface QuizAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) QuizViewController *viewController;

@end
