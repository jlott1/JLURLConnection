//
//  NSDictionary+JSON.m
//  JLURLConnectionExample
//
//  Created by Jonathan Lott on 5/17/14.
//  Copyright (c) 2014 A Lott Of Ideas. All rights reserved.
//

#import "NSDictionary+JSON.h"
#import "NSData+JSON.h"

@implementation NSDictionary (JSON)

- (NSString*)jsonStringValue
{
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:self options:0 error:&error];

    return data.stringValue;
}

- (NSString*)jsonPrettyStringValue
{
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error:&error];
    if(error)
        NSLog(@"error in serializing json data = %@", error);
    return data.stringValue;
}

@end
