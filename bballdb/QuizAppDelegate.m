//
//  QuizAppDelegate.m
//  bballdb
//
//  Created by Joe Seeley on 11/5/12.
//  Copyright (c) 2012 Joe Seeley. All rights reserved.
//

#import "QuizAppDelegate.h"
#import <objc/runtime.h>
#import "QuizViewController.h"

@implementation QuizAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
// BEGIN DATABASE TEST
    
    UltraliteDB *DB = [UltraliteDB defaultDBWithName:@"bball"];
//    FMResultSet *results = [DB executeQuery:@"SELECT * FROM game_modes"];
    
//    while([results next]){
//        NSString *code = [results stringForColumn:@"code"];
//        NSString *description = [results stringForColumn:@"description"];
//        
//        NSLog(@"%@ %@", code, description);
//    }
    
    GameDetails *details = [[GameDetails alloc]init];
    
    GameDetails *t = [[GameDetails alloc]init];
    
    int i=0;
    unsigned int mc = 0;
    Method * mlist = class_copyMethodList(object_getClass(t), &mc);
    NSLog(@"%d methods", mc);
    for(i=0;i<mc;i++)
        NSLog(@"Method no #%d: %s", i, sel_getName(method_getName(mlist[i])));
    
    
//    details.key=[NSNumber numberWithInt:23];
    details.user_id=[NSNumber numberWithInt:73];
    details.game_id=[NSNumber numberWithInt:1];
    details.game_option_type_id=[NSNumber numberWithInt:1];
    details.team_id=[NSNumber numberWithInt:1];
    details.player_id=[NSNumber numberWithInt:1];
    details.detail = @"Swank\"Hands";
    details.period=[NSNumber numberWithInt:1];
    details.period_time = @"Some text";
    details.x=[NSNumber numberWithInt:1];
    details.y=[NSNumber numberWithInt:1];
    details.team_score=[NSNumber numberWithInt:1];
    details.other_team_score=[NSNumber numberWithInt:1];
    details.pot=[NSNumber numberWithInt:1];
    details.layup=[NSNumber numberWithInt:1];
    details.pip=[NSNumber numberWithInt:1];
    details.related_event=[NSNumber numberWithInt:1];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    
    details.created_date  = [dateFormatter dateFromString:@"2012-11-14 00:00:00.000"];
    details.modified_date = @"2012-11-14 00:00:00.000";
    details.modified_by   =[NSNumber numberWithInt:1];
    BOOL success = [DB upsert:details];
    
//    details.detail = @"Updated";
//    success = [DB update:details];
    [DB read:details];

    NSLog(@"%@", details.detail);
    
    NSMutableDictionary* columns = [NSMutableDictionary dictionaryWithCapacity:25];
    [columns setObject:details.detail forKey:@"detail"];
    [columns setObject:details.period_time forKey:@"period_time"];
    [columns setObject:details.created_date forKey:@"created_date"];
    
    NSMutableArray* dict = [DB read:details byColumns:columns];
    
//    success = [DB delete:details];

    // END DATABASE TEST
    
    
    
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[QuizViewController alloc] initWithNibName:@"QuizViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}       



- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
