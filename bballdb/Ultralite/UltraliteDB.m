//
//  UltraliteDB.m
//  bballdb
//
//  Created by Joe Seeley on 11/11/12.
//  Copyright (c) 2012 Joe Seeley. All rights reserved.
//

//#pragma GCC diagnostic ignored "-WIncomplete implementation"
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"
#pragma GCC diagnostic ignored "-Wunused-variable"

#import "UltraliteDB.h"
#import <objc/runtime.h>

@implementation UltraliteDB

static UltraliteDB *gInstance = nil;
static NSMutableDictionary *classMappings;
static NSMutableDictionary *tableMappings;
static NSMutableString *pk;

static FMDatabase *fmdb = nil;

+(UltraliteDB*)defaultDBWithName:(NSString *)dbName{
    @synchronized(self){
        if(gInstance==nil)
            gInstance = [[self alloc]initWithName:dbName];
    }
    return gInstance;
}

-(id)initWithName:(NSString *)dbName{
    if(self = [super init]){
        NSString *resPath = [[NSBundle mainBundle] resourcePath];
        pk = [[NSMutableString alloc] initWithCapacity:50];
        [pk appendString:@"key"]; //Ideally this should load from a config file so it can be replaced with something else
        
        // Copy database to iPhone Apps directory if it doesn't already exist.
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString * docsPath = [fileManager applicationSupportDirectory];

        NSString *path = [docsPath stringByAppendingPathComponent:dbName];
        
        if(![fileManager fileExistsAtPath:path]){
            NSString *databasePathFromResources = [resPath stringByAppendingPathComponent:dbName];
            [fileManager copyItemAtPath:databasePathFromResources toPath:path error:nil];        }
        
        fmdb = [FMDatabase databaseWithPath:path];
        
        // Setup the Class to table mappings
        NSString *dbclassmapPath = [resPath stringByAppendingPathComponent:@"dbclassmap.plist"];
        classMappings = [[NSMutableDictionary alloc] initWithContentsOfFile:dbclassmapPath];
        tableMappings = [NSMutableDictionary dictionaryWithCapacity:25];
    }
    return self;
}

- (NSDictionary *)classMappings
{
	return classMappings;
}

-(FMResultSet*)executeQuery:(NSString *)query{
    if([fmdb open]){
        FMResultSet *results = [fmdb executeQuery:query];
        return results;    
    }
    return nil;
}

-(BOOL)executeUpdate:(NSString *)query{
    if([fmdb open]){
        BOOL success = [fmdb executeUpdate:query];
        return success;
    }
    return NO;
}

-(BOOL)create:(id)record{
    BOOL didInit = [self initTableMappingFromRecord:record];

    NSString *recClassNSString = NSStringFromClass([record class]);
    id recClass = NSClassFromString(recClassNSString);
    NSString *tableName = [classMappings objectForKey:recClassNSString];

    // BUILD THE INSERT STRING
    NSMutableDictionary *tableMetaData = [tableMappings objectForKey:tableName];
    NSMutableString *columns = [NSMutableString stringWithCapacity:25];
    NSMutableString *values = [NSMutableString stringWithCapacity:25];
    for(NSString *key in tableMetaData){
        
        NSString *value = [tableMetaData objectForKey:key];
        
        SEL getter = NSSelectorFromString(key);
        id myProperty = [record performSelector:getter];
        
        if (!myProperty) {
            continue; // Don't bother if the property is nil
        }else if([key isEqualToString:pk]){
            NSLog(@"Attempt to create duplicate record failed. Class Type : %@", recClassNSString);
            return NO;
        }
        
        NSString *propClassString = NSStringFromClass([myProperty class]);
        if([propClassString rangeOfString:@"Number"].length > 0){
            [values appendFormat:@"%@,", myProperty];
        }else if([propClassString rangeOfString:@"String"].length > 0){
            NSString *newString = [myProperty stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
            [values appendFormat:@"'%@',", newString];
        }else if([propClassString rangeOfString:@"Date"].length > 0){
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            [values appendFormat:@"'%@',", [dateFormatter stringFromDate:myProperty]];
        }else{
            [NSException raise:@"Unsupported datatype exception." format:@"Type received was : %@", propClassString];
        }
        
        [columns appendFormat:@"%@,", value];
    }
    // Trim the trailing commas
    [columns deleteCharactersInRange:NSMakeRange([columns length]-1, 1)];
    [values deleteCharactersInRange:NSMakeRange([values length]-1, 1)];

    NSMutableString *query = [NSMutableString stringWithCapacity:50];
    [query appendFormat:@"INSERT INTO %@ (%@) VALUES(%@);", tableName, columns, values];
    [self executeUpdate:query];
    
    // Record created successfully... Now let's update back to the incoming object
    // Be careful using this; pretty fucking sure it won't work on multiple threads
    NSMutableString *newRecordQuery = [NSMutableString stringWithCapacity:50];
    [newRecordQuery appendFormat:@"SELECT * FROM %@ ORDER BY %@ DESC LIMIT 1",tableName, pk];
    FMResultSet *currRecord = [self executeQuery:newRecordQuery];
    
    while([currRecord next]){
        
        NSString *pkUpcased =
        [pk stringByReplacingCharactersInRange:NSMakeRange(0,1)
            withString:[[pk substringToIndex:1] capitalizedString]];
        
        NSString *pkSetter = [[NSString alloc] initWithFormat:@"set%@:",pkUpcased];
        SEL setter = NSSelectorFromString(pkSetter);
        [record performSelector:setter withObject:[NSNumber numberWithInt:[currRecord intForColumn:pk]]];
    }
    return YES;
}

-(id)read:(id)record{
    BOOL didInit = [self initTableMappingFromRecord:record];
    
    NSString *recClassNSString = NSStringFromClass([record class]);
    id recClass = NSClassFromString(recClassNSString);
    NSString *tableName = [classMappings objectForKey:recClassNSString];

    NSString *pkLookup = [[tableMappings objectForKey:tableName] objectForKey:pk];
    
    SEL getter = NSSelectorFromString(pk);
    NSNumber *pkPropValue = [record performSelector:getter];

    NSMutableString *query = [NSMutableString stringWithCapacity:50];
    [query appendFormat:@"SELECT * FROM %@ WHERE %@=%@", tableName, pkLookup, pkPropValue];
    FMResultSet *results = [self executeQuery:query];
        
    NSMutableDictionary *classPropsDict = [NSMutableDictionary dictionaryWithCapacity:25];

    unsigned int outCount, i;
	
    Class superClass = recClass;
	//we need properties for this class and all superclasses
	while ( superClass != nil && ! [superClass isEqual:[NSObject class]] )
	{
		objc_property_t *properties = class_copyPropertyList(superClass, &outCount);
		for (i=0; i<outCount; i++){
			objc_property_t property = properties[i];
			NSString *propNSString = [NSString stringWithUTF8String:property_getName(property)];
			NSString *attrNSString = [NSString stringWithUTF8String:property_getAttributes(property)];
			[classPropsDict setObject:attrNSString forKey:propNSString];
		}
		superClass = class_getSuperclass( superClass );
	}
    
    while([results next]){
        for(NSString *key in [tableMappings objectForKey:tableName]){
            
            id value = [[tableMappings objectForKey:tableName] objectForKey:key];
            
            NSString *propUpcased =
            [key stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                        withString:[[key substringToIndex:1] capitalizedString]];
            NSString *setterString = [[NSString alloc] initWithFormat:@"set%@:",propUpcased];
            SEL setter = NSSelectorFromString(setterString);
            
            NSString *propClassString = [classPropsDict objectForKey:key];
            
            if([propClassString rangeOfString:@"Number"].length > 0){
                [record performSelector:setter withObject:[results objectForColumnName:value]];
            }else if([propClassString rangeOfString:@"String"].length > 0){
                NSString *str = [results stringForColumn:value];
                [record performSelector:setter withObject:str];
            }else if([propClassString rangeOfString:@"Date"].length > 0){
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
                NSDate *str = [dateFormatter dateFromString:[results stringForColumn:value]];
                [record performSelector:setter withObject:str];
            }else{
                [NSException raise:@"Unsupported datatype exception." format:@"Type received was : %@", propClassString];
            }
        }
    }
    return record;
}

-(BOOL)update:(id)record{
    BOOL didInit = [self initTableMappingFromRecord:record];
    
    NSString *recClassNSString = NSStringFromClass([record class]);
    NSString *tableName = [classMappings objectForKey:recClassNSString];
    
    // BUILD THE UPDATE STRING
    NSMutableDictionary *tableMetaData = [tableMappings objectForKey:tableName];
    NSMutableString *query = [NSMutableString stringWithCapacity:50];
    [query appendFormat:@"UPDATE %@ SET ", tableName];
    
    NSNumber *pkValue;
    for(NSString *key in tableMetaData){
        NSString *value = [tableMetaData objectForKey:key];
        
        SEL getter = NSSelectorFromString(key);
        id myProperty = [record performSelector:getter];

        if (!myProperty) {
            continue; // Don't bother if the property is nil
        }else if([key isEqualToString:pk]){
            pkValue = myProperty;
        }else{
            NSString *propClassString = NSStringFromClass([myProperty class]);
            // Now we have the property name, I think we can do a partial string match here to handle typing differences
            if([propClassString rangeOfString:@"Number"].length > 0){
                [query appendFormat:@"%@=%@,", value, myProperty];
            }else if([propClassString rangeOfString:@"String"].length > 0){
                NSString *newString = [myProperty stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                [query appendFormat:@"%@='%@',", value, newString];
            }else if([propClassString rangeOfString:@"Date"].length > 0){
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
                [query appendFormat:@"%@='%@',", value, [dateFormatter stringFromDate:myProperty]];
            }else{
                [NSException raise:@"Unsupported datatype exception." format:@"Type received was : %@", propClassString];
            }
        }
    }
    // Trim the trailing commas
    [query deleteCharactersInRange:NSMakeRange([query length]-1, 1)];
    [query appendFormat:@" WHERE %@ = %@;", pk, pkValue];
    [self executeUpdate:query];
    
    return YES;
}

-(BOOL)delete:(id)record{
    BOOL didInit = [self initTableMappingFromRecord:record];
    
    NSString *recClassNSString = NSStringFromClass([record class]);
    NSString *tableName = [classMappings objectForKey:recClassNSString];
    
    SEL getter = NSSelectorFromString(pk);
    NSNumber *key = [record performSelector:getter];

    NSMutableString *query = [NSMutableString stringWithCapacity:50];
    [query appendFormat:@"DELETE FROM %@ WHERE %@=%@;", tableName, pk, key];
    [self executeUpdate:query];
    return YES;
}

-(BOOL)initTableMappingFromRecord:(id)record{
    NSString *recClassNSString = NSStringFromClass([record class]);
    id recClass = NSClassFromString(recClassNSString);
    // Get table name
    NSString *table = [classMappings objectForKey:recClassNSString];
    
    // Check if table has been mapped yet
    id tableMap = [tableMappings objectForKey:table];
    if(tableMap == nil){
        // Check if file exists
		
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *generatedDocsPath = [fileManager applicationSupportDirectory];
        NSString *generatedPath = [generatedDocsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", table] ];
		
        NSString *builtInPath = [[NSBundle mainBundle] pathForResource:table ofType:@"plist"];
        
        if([fileManager fileExistsAtPath:builtInPath]){
            // If the file exists we will load from this
            NSMutableDictionary *tableDefinition = [[NSMutableDictionary alloc] initWithContentsOfFile:builtInPath];
            [tableMappings setObject:tableDefinition forKey:table];
        }
		else if([fileManager fileExistsAtPath:generatedPath]){
            // If the file exists we will load from this
            NSMutableDictionary *tableDefinition = [[NSMutableDictionary alloc] initWithContentsOfFile:generatedPath];
            [tableMappings setObject:tableDefinition forKey:table];
        }
        else{
            NSMutableDictionary *propDictIncoming = [[NSMutableDictionary alloc]initWithCapacity:25];
            NSMutableDictionary *propDictOutgoing = [[NSMutableDictionary alloc]initWithCapacity:25];
            
            unsigned int outCount, i;
            objc_property_t *properties = class_copyPropertyList(recClass, &outCount);
            for (i=0; i<outCount; i++){
                objc_property_t property = properties[i];
                //                fprintf(stdout, "%s %s\n", property_getName(property), property_getAttributes(property));
                NSString *propNSString = [NSString stringWithUTF8String:property_getName(property)];
                
                [propDictIncoming setObject:propNSString forKey:propNSString];
            }
            
            NSString *pragma = [NSString stringWithFormat:@"PRAGMA table_info(%@)", table];
            FMResultSet *table_details = [self executeQuery:pragma];
            
            // Here we match which properties on the class are also columns in the table
            // by default we are using a very simple columnname = propertyname setup,
            // If the user wants a different mapping a plist file will need to be created ahead of time
            while([table_details next]){
                NSString *name = [table_details stringForColumn:@"name"];
                
                if([propDictIncoming objectForKey:name]){
                    [propDictOutgoing setObject:name forKey:name];
                }
            }
            [propDictOutgoing writeToFile:generatedPath atomically:YES];
            [tableMappings setObject:propDictOutgoing forKey:table];
        }
    }
    return YES; // Oh sweetness, we made it this far!
}

// TODO :
// Add a method missing functionality to return a find/read on foreign key basis
// Add a find_by functionality to do lookup of object based on columns
/////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSMutableArray*)read:(id)record byColumns:(NSMutableDictionary*)dict{
    BOOL didInit = [self initTableMappingFromRecord:record];
    
    NSString *recClassNSString = NSStringFromClass([record class]);
    id recClass = NSClassFromString(recClassNSString);
    NSString *tableName = [classMappings objectForKey:recClassNSString];
    
    NSMutableString *where = [NSMutableString stringWithCapacity:50];
    [where appendFormat:@"WHERE "];
    unsigned int i=0;
    for(NSString *key in dict) {
        if(i!=0){
            [where appendFormat:@" AND "];
        }

        NSString *columnDataType = NSStringFromClass([[dict valueForKey:key] class]);
        if([columnDataType rangeOfString:@"Number"].length > 0){
            [where appendFormat:@"%@=%@",key, [dict valueForKey:key]];
        }else if([columnDataType rangeOfString:@"String"].length > 0){
            NSString *newString = [[dict valueForKey:key] stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
            [where appendFormat:@"%@='%@'",key, newString];
        }else if([columnDataType rangeOfString:@"Date"].length > 0){
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            [where appendFormat:@"%@='%@'", key, [dateFormatter stringFromDate:[dict valueForKey:key]]];
        }else{
            [NSException raise:@"Unsupported datatype exception." format:@"Type received was : %@", columnDataType];
        }
        i++;
    }
    
    NSMutableString *query = [NSMutableString stringWithCapacity:50];
    [query appendFormat:@"SELECT * FROM %@ %@", tableName, where];          // TODO : This query looks good now, but it needs to be pushed into a dictionary and returned back to the caller
    FMResultSet *results = [self executeQuery:query];
    
    NSMutableDictionary *classPropsDict = [NSMutableDictionary dictionaryWithCapacity:25];
    
    unsigned int outCount;
	
    Class superClass = recClass;
	//we need properties for this class and all superclasses
	while ( superClass != nil && ! [superClass isEqual:[NSObject class]] )
	{
		objc_property_t *properties = class_copyPropertyList(superClass, &outCount);
		for (i=0; i<outCount; i++){
			objc_property_t property = properties[i];
			NSString *propNSString = [NSString stringWithUTF8String:property_getName(property)];
			NSString *attrNSString = [NSString stringWithUTF8String:property_getAttributes(property)];
			[classPropsDict setObject:attrNSString forKey:propNSString];
		}
		superClass = class_getSuperclass( superClass );
	}

    NSMutableArray *recordsArray = [[NSMutableArray alloc] init];
    while([results next]){
        id foundRecord = [[recClass alloc] init];
        for(NSString *key in [tableMappings objectForKey:tableName]){
            
            id value = [[tableMappings objectForKey:tableName] objectForKey:key];
            
            NSString *propUpcased =
            [key stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                         withString:[[key substringToIndex:1] capitalizedString]];
            NSString *setterString = [[NSString alloc] initWithFormat:@"set%@:",propUpcased];
            SEL setter = NSSelectorFromString(setterString);
             NSString *propClassString = [classPropsDict objectForKey:key];
            
            if([propClassString rangeOfString:@"Number"].length > 0){
                [foundRecord performSelector:setter withObject:[results objectForColumnName:value]];
            }else if([propClassString rangeOfString:@"String"].length > 0){
                NSString *str = [results stringForColumn:value];
                [foundRecord performSelector:setter withObject:str];
            }else if([propClassString rangeOfString:@"Date"].length > 0){
                NSDate *str = [results dateForColumn:value];
                [foundRecord performSelector:setter withObject:str];
            }else{
                [NSException raise:@"Unsupported datatype exception." format:@"Type received was : %@", propClassString];
            }
        }
        [recordsArray addObject:foundRecord];
    }
    return recordsArray;
}

-(BOOL)upsert:(id)record{
    BOOL success = [gInstance create: record];
    if(success == NO){
        success = [gInstance update: record];
    }
    return success;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
@end
