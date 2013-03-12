//
//  UltraliteDB.h
//  bballdb
//
//  Created by Joe Seeley on 11/11/12.
//  Copyright (c) 2012 Joe Seeley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "NSFileManager+DirectoryLocations.h"

@interface UltraliteDB : NSObject
// Our singleton access
+(UltraliteDB*)defaultDBWithName:(NSString*)dbName;

// Our external interface
-(FMResultSet*)executeQuery:(NSString*)query; 
-(BOOL)executeUpdate:(NSString*)query;

-(BOOL)create:(id)record;
-(id)read:(id)record;
-(BOOL)update:(id)record;
-(BOOL)delete:(id)record;       

-(BOOL)upsert:(id)record;


// TODO: The following method is broken....
-(NSMutableArray*)read:(id)record byColumns:(NSMutableDictionary*)dict;


@property (nonatomic, readonly) NSDictionary *classMappings;

// Our private internal methods - Well, not really, but you get the idea...
-(BOOL)initTableMappingFromRecord:(id)record;
@end
