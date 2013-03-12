//
//  GameDetails.h
//  bballdb
//
//  Created by Joe Seeley on 11/14/12.
//  Copyright (c) 2012 Joe Seeley. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GameDetails : NSObject

@property (nonatomic, strong) NSNumber *key;
@property (nonatomic, strong) NSNumber *user_id;
@property (nonatomic, strong) NSNumber *game_id;
@property (nonatomic, strong) NSNumber *game_option_type_id;
@property (nonatomic, strong) NSNumber *team_id;
@property (nonatomic, strong) NSNumber *player_id;
@property (nonatomic, strong) NSString *detail;
@property (nonatomic, strong) NSNumber *period;
@property NSString *period_time;
@property (nonatomic, strong) NSNumber *x;
@property (nonatomic, strong) NSNumber *y;
@property (nonatomic, strong) NSNumber *team_score;
@property (nonatomic, strong) NSNumber *other_team_score;
@property (nonatomic, strong) NSNumber *pot;
@property (nonatomic, strong) NSNumber *layup;
@property (nonatomic, strong) NSNumber *pip;
@property (nonatomic, strong) NSNumber *related_event;
@property (nonatomic, strong) NSDate *created_date;
@property (nonatomic, strong) NSString *modified_date;
@property (nonatomic, strong) NSNumber *modified_by;


@end
