//
//  JLURLConnectionsCollection.h
//
//
//  Created by Jonathan Lott on 2/2/12.
//  Copyright (c) 2012 A Lott Of Ideas. All rights reserved.
//

#import <Foundation/Foundation.h>

@class JLURLConnection;

@interface JLURLConnectionsCollection : NSObject

@property (nonatomic, strong) NSMutableArray* connections;

+ (id)sharedInstance;
+ (JLURLConnectionsCollection*)collection;
- (void)addConnection:(JLURLConnection*)connection;
- (void)removeConnection:(JLURLConnection*)connection;
- (void)removeAllConnections;
@end


