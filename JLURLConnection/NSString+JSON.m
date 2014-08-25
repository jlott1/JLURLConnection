//
//  NSString+JSON.m
//  
//
//  Created by Jonathan Lott on 7/1/12.
//  Copyright (c) 2014 A Lott Of Ideas. All rights reserved.
//

#import "NSString+JSON.h"

@implementation NSString (NumericCompare)
- (NSComparisonResult)numericCompare:(NSString *)string
{
    return [self compare:string options:NSNumericSearch];
}
@end

@implementation NSString (JSON)

- (NSData*)dataValue
{
    return [self dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSMutableDictionary *)jsonDictionaryValue
{
    NSError *parseError = nil;
    NSMutableDictionary *outputDictionary =
    [NSJSONSerialization JSONObjectWithData:self.dataValue
                                    options:NSJSONReadingMutableContainers
                                      error:&parseError];
    if(parseError)
        NSLog(@"error parsing json from data = %@", parseError);
    
    return outputDictionary;
}

@end