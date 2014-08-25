//
//  NSString+JSON.h
//  
//
//  Created by Jonathan Lott on 7/1/12.
//  Copyright (c) 2014 A Lott Of Ideas. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (NumericCompare)
- (NSComparisonResult)numericCompare:(NSString *)string;
@end

@interface NSString (JSON)
- (NSData*)dataValue;
- (NSMutableDictionary *)jsonDictionaryValue;

@end
