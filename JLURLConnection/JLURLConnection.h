//
//  JLURLConnection.h
//
//  Created by Jonathan Lott on 2/2/12.
//  Copyright (c) 2012 A Lott Of Ideas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSData+JSON.h"
#import "NSString+JSON.h"
#import "NSDictionary+JSON.h"
#import "JLError.h"
#import "JLFile.h"
#import "JLURLConnectionsCollection.h"

typedef enum {
    JLURLConnectionErrorCode_None = 0,
    JLURLConnectionErrorCode_GenericError = 2000,
    JLURLConnectionErrorCode_Connection,
	JLURLConnectionErrorCode_ConnectionNoData,
	JLURLConnectionErrorCode_ConnectionNoDataLength,
} JLURLConnectionErrorCode;

typedef enum {
    JLURLConnectionState_Ready       = 0,
    JLURLConnectionState_Running,
    JLURLConnectionState_Redirect,
    JLURLConnectionState_Paused,
    JLURLConnectionState_Stopped,
    JLURLConnectionState_Finished,
} JLURLConnectionState;

#define kJLURLConnection_Error_NoData @"No Data"
#define kJLURLConnection_Error_Unknown @"Unknown"
#define kJLURLConnection_Error_Domain @"JLURLConnectionDomain"

@class JLURLConnection;


typedef void(^JLURLConnectionProgressBlock)(JLURLConnection* urlConnection, JLURLConnectionState state, JLError* errorStatus);

@protocol JLURLConnectionDelegate <NSObject>
- (void)urlConnection:(JLURLConnection*)aConnection state:(JLURLConnectionState)state error:(JLError*)errorStatus;
@end

@protocol JLURLConnectionResponseValidation <NSObject>
/**
 * This is so that subclasses can validate the http response and throw an exception if
 *  if response is invalid
 */
- (BOOL)validateResponse:(NSURLResponse*)response isRedirect:(BOOL)isRedirectResponse;
@end

@interface JLURLConnection : NSObject <JLURLConnectionResponseValidation>

/**
 * The currentQueue is a reference to the originating queue that the 
 * the connection was created/started on.  For asynchronous connections, this will also be the queue that state change callbacks will occurr on.
 */
@property (nonatomic, weak, readonly) NSOperationQueue* currentQueue;

/**
 * The state is a flag for determining the progress of the connection
 */
@property (readonly, nonatomic) JLURLConnectionState state;

/**
 * The errorStatus contains any errors created by underlying urlConnection
 */
@property (readonly, nonatomic, copy) JLError* errorStatus;
@property (readonly, nonatomic, strong) NSURLConnection* urlConnection;

/**
 * The request and response properties are the original request and final response for the underlying urlConnection
 */
@property (readonly, nonatomic, strong) NSURLRequest* request;
@property (readonly, nonatomic, strong) NSHTTPURLResponse* response;

/**
 * The redirectRequest and redirectResponse properties are only used for investigating a redirect state change.  Only look at these properties if you received a JLURLConnectionState_Redirect state.  Otherwise use "request" and "response"
 */
@property (readonly, nonatomic, strong) NSURLRequest* redirectRequest;
@property (readonly, nonatomic, strong) NSURLResponse* redirectResponse;

/**
 * If using a filePath in creation, filePath will be set, otherwise nil.
 * filePath cannot be changed after connection is created
 */
@property (readonly, nonatomic) NSString* filePath;

/**
 * data contains the data for the connection
 */
@property (readonly, nonatomic, copy) NSMutableData * data;

@property (readonly, nonatomic) BOOL isAsynchronous;

/**
 * tracks number of bytes currently read during the progression of the download
 * bytesRead - the number of bytes read in single "chunk"
 * totalBytesRead - the number of total bytes as a sum of all chunks
 * totalBytesExpectedToRead - the number of bytes expected determined by expectedContentLength value of the underlying response object
 *  use the algorithm  of 100 * (totalBytesRead / totalBytesExpectedToRead) to determine the percentage of progress of the download
 */
@property (readonly, nonatomic, assign) NSUInteger bytesRead;
@property (readonly, nonatomic, assign) long long totalBytesRead;
@property (readonly, nonatomic, assign) long long totalBytesExpectedToRead;

@property (readonly, nonatomic, weak) id<JLURLConnectionDelegate> delegate;
@property (readonly, nonatomic, assign) double progress;

/**
 * userInfo - useful for passing any objects for tracking identification of the connection.
 *  For Example, you can pass in special hash keys, or metadata about what is being downloaded.  
 * you can later search for this data in the connection by using valueForKeyPath:@"userInfo.property" 
 */
@property (readwrite, nonatomic, strong) id userInfo;

/**
 * collection - this is a reference to a container collection that currently holds
 * a  reference to this collection.  This value will be set if you call the 
 * "startConnection.." or "startSynchronousConnection.." methods below. otherwise it will be nil.
 */
@property (nonatomic, strong) JLURLConnectionsCollection* collection;

/**
 * This creates a ASYNCHRONOUS connection and starts it. connection object is auto-retained by a collection
 * @param request NSURLRequest containing the url and headers for the conneciton
 * @param progressBlock a block that is used to for following the progress of the connection as it changes state
 * @return JLURLConnection object.  this method will retain the connection object for you
 * This method is the same as calling startConnectionWithRequest:toFileAtPath:progressBlock: with a  nil filePath
 */
+ (JLURLConnection*)startConnectionWithRequest:(NSURLRequest*)request progressBlock:(JLURLConnectionProgressBlock)progressBlock;
/**
 * This creates a SYNCHRONOUS connection and starts it. connection object is auto-retained by a collection
 * @param request NSURLRequest containing the url and headers for the conneciton
 * @param progressBlock a block that is used to for following the progress of the connection as it changes state
 * @return JLURLConnection object.  this method will retain the connection object for you
 * This method is the same as calling startSynchronousConnectionWithRequest:toFileAtPath:progressBlock: with a  nil filePath
 */
+ (JLURLConnection*)startSynchronousConnectionWithRequest:(NSURLRequest*)request progressBlock:(JLURLConnectionProgressBlock)progressBlock;

/**
 * This creates a ASYNCHRONOUS connection and starts it. connection object is auto-retained by a collection
 * @param request NSURLRequest containing the url and headers for the conneciton
 * @param filePath pass a full path to a file location OR pass nil if you do not wish to save to file
 * @param progressBlock a block that is used to for following the progress of the connection as it changes state
 * @return JLURLConnection object.  this method will retain the connection object for you
 */
+ (JLURLConnection*)startConnectionWithRequest:(NSURLRequest*)request toFileAtPath:(NSString*)filePath progressBlock:(JLURLConnectionProgressBlock)progressBlock;
/**
 * This creates a SYNCHRONOUS connection and starts it. connection object is auto-retained by a collection
 * @param request NSURLRequest containing the url and headers for the conneciton
 * @param filePath pass a full path to a file location OR pass nil if you do not wish to save to file
 * @param progressBlock a block that is used to for following the progress of the connection as it changes state
 * @return JLURLConnection object.  this method will retain the connection object for you
 */
+ (JLURLConnection*)startSynchronousConnectionWithRequest:(NSURLRequest*)request toFileAtPath:(NSString*)filePath progressBlock:(JLURLConnectionProgressBlock)progressBlock;

/**
 * This will pause only connection objects that were created and added to the JLURLConnectionsCollection.
 * All of the methods with the prefix "startConnection..." or "startSynchronousConnection.." will automatically be added to a shared JLURLConnectionsCollection
 NOTE: These methods only apply to connections WITH A FILE PATH.  YOU SHOULD NOT PAUSE IN-MEMORY CONNECTIONS 
    BUT JUST STOP and START TO PREVENT DATA CORRUPTION.
 */
+ (void)pauseAllConnections;
/**
 * This will resume connection objects that were created and added to the JLURLConnectionsCollection.
 * All of the methods with the prefix "startConnection..." will automatically be added to a shared JLURLConnectionsCollection
 * NOTE: connection objects will only resume properly if the server supports partial data downloads
 */
+ (void)resumeAllConnections;

/**
 * This creates a connection BUT does NOT start it. connection object is NOT auto-retained by a collection.
 * YOU MUST CALL start or startSynchronously to start the connection after calling this method.
 * @param request NSURLRequest containing the url and headers for the conneciton
 * @param filePath pass a full path to a file location OR pass nil if you do not wish to save to file
 * @param progressBlock a block that is used to for following the progress of the connection as it changes state
 * @return JLURLConnection object.  this method will retain the connection object for you
 */
+ (id)connectionWithRequest:(NSURLRequest*)request;

/**
 * This creates a connection BUT does NOT start it. connection object is NOT auto-retained by a collection.
 * YOU MUST CALL start or startSynchronously to start the connection after calling this method.
 * @param request NSURLRequest containing the url and headers for the conneciton
 * @param filePath pass a full path to a file location OR pass nil if you do not wish to save to file
 * @param progressBlock a block that is used to for following the progress of the connection as it changes state
 * @return JLURLConnection object.  this method will retain the connection object for you
 */
+ (id)connectionWithRequest:(NSURLRequest*)request filePath:(NSString*)filePath progressBlock:(JLURLConnectionProgressBlock)progressBlock;
/**
 * This creates a connection BUT does NOT start it. connection object is NOT auto-retained by a collection.
 * YOU MUST CALL start or startSynchronously to start the connection after calling this method.
 * @param request NSURLRequest containing the url and headers for the conneciton
 * @param delegate a delegate protocol that is used to for following the progress of the connection as it changes state
 * @return JLURLConnection object.  this method will retain the connection object for you
 */
- (id)initWithRequest:(NSURLRequest*)request delegate:(id<JLURLConnectionDelegate>)aDelegate;

/**
 * This will start the connection asynchronously. connection object is NOT auto-retained by a collection.
 * DO NOT CALL start or startSynchronously if connection was created using "startConnection.."  or "startSynchronousConnection.." methods.
 */
- (void)start;

/**
 * This will start the connection synchronously. connection object is NOT auto-retained by a collection.
 * DO NOT CALL start or startSynchronously if connection was created using "startConnection.."  or "startSynchronousConnection.." methods.
 */
- (void)startSynchronously;

/**
 * This will pause/resume the connection. This ACTUALLY cancels the underlying NSURLConnection but keeps a reference to 
 * file that was being downloaded to, so if when resumed, will append data to existing file.
 * DO NOT CALL call pause and resume for IN-MEMORY ONLY connections.  Use only when passing in a filePath argument
 */
- (void)pause;
- (void)resume;

/**
 * This will stop the connection. This ACTUALLY cancels the underlying NSURLConnection but keeps a reference to
 * file that was being downloaded to.
 * This will change the state to JLURLConnectionState_Stopped and eventually to JLURLConnectionState_Finished
 */
- (void)stop;

- (BOOL)isPaused;
- (BOOL)isReady;
- (BOOL)isRunning;
- (BOOL)isFinished;

@end