//
//  JLURLConnectionsCollection.m
//
//
//  Created by Jonathan Lott on 2/2/12.
//  Copyright (c) 2012 A Lott Of Ideas. All rights reserved.
//

#import "JLURLConnectionsCollection.h"
#import "JLURLConnection.h"

@implementation JLURLConnectionsCollection
@synthesize connections = _connections;

+ (id)sharedInstance
{
    static JLURLConnectionsCollection* sharedInstance = nil;
    if(sharedInstance == nil)
    {
        sharedInstance = [[JLURLConnectionsCollection alloc] init];
    }
    return sharedInstance;
}

+ (JLURLConnectionsCollection*)collection
{
    return [[JLURLConnectionsCollection alloc] init];
}

- (id)init {
    
    self = [super init];
    if(self)
    {
        _connections = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addConnection:(JLURLConnection*)connection
{
    @synchronized(self)
    {
        if(connection && ![self.connections containsObject:connection])
        {
            connection.collection = self;
            [self.connections addObject:connection];
        }
    }
}

- (void)removeConnection:(JLURLConnection*)connection
{
    @synchronized(self)
    {
        if(connection && [self.connections containsObject:connection])
        {
            connection.collection = nil;
            [self.connections removeObject:connection];
        }
    }
}

- (void)removeAllConnections
{
    @synchronized(self)
    {
        [self.connections makeObjectsPerformSelector:@selector(setCollection:) withObject:nil];
        [self.connections removeAllObjects];
    }
}
@end