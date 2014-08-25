//
//  NSData+JSON.m
//  
//
//  Created by Jonathan Lott on 7/1/12.
//  Copyright (c) 2014 A Lott Of Ideas. All rights reserved.
//

#import "NSData+JSON.h"

@implementation NSData (JSON)

- (NSString*)stringValue
{
    NSString *str = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
    return str;
}

- (NSMutableDictionary *)jsonDictionaryValue
{
    NSError *parseError = nil;
    NSMutableDictionary *outputDictionary =
    [NSJSONSerialization JSONObjectWithData:self
                                    options:NSJSONReadingMutableContainers
                                      error:&parseError];
    if(parseError)
        NSLog(@"error parsing json from data = %@", parseError);
    
    return outputDictionary;
}

@end
