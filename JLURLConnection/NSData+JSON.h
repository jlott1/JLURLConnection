//
//  NSData+JSON.h
//  
//
//  Created by Jonathan Lott on 7/1/12.
//  Copyright (c) 2014 A Lott Of Ideas. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (JSON)
- (NSString*)stringValue;
- (NSMutableDictionary *)jsonDictionaryValue;
@end


