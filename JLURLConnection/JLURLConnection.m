//
//  JLURLConnection.m
//
//
//  Created by Jonathan Lott on 2/2/12.
//  Copyright (c) 2012 A Lott Of Ideas. All rights reserved.
//

#import "JLURLConnection.h"

@implementation NSURLRequest (HeaderValues)
- (NSString*)allHeaderValuesString
{
    NSString* returnStr = @"";
    
    for(NSString* field in self.allHTTPHeaderFields)
    {
        NSString* value = [self valueForHTTPHeaderField:field];
        returnStr = [returnStr stringByAppendingFormat:@"%@ : %@ \n", field, value];
    }
    return returnStr;
}
@end

@implementation NSOutputStream (FileOffsets)
- (unsigned long long)fileOffset
{
    unsigned long long offset = 0;
    if ([self propertyForKey:NSStreamFileCurrentOffsetKey]) {
        offset = [[self propertyForKey:NSStreamFileCurrentOffsetKey] unsignedLongLongValue];
    }
    return offset;
}

- (void)setFileOffset:(unsigned long long)offset
{
    if ([self propertyForKey:NSStreamFileCurrentOffsetKey]) {
        [self setProperty:[NSNumber numberWithUnsignedLongLong:offset] forKey:NSStreamFileCurrentOffsetKey];
    }
}
@end


@interface JLURLConnection ()

@property (readwrite, nonatomic, copy) JLError* errorStatus;
@property (readwrite, nonatomic, strong) NSURLConnection * urlConnection;
@property (readwrite, nonatomic, strong) NSURLRequest* redirectRequest;
@property (readwrite, nonatomic, strong) NSHTTPURLResponse* redirectResponse;

@property (readwrite, nonatomic, copy) NSMutableData * data;
@property (readwrite, nonatomic) NSString* filePath;
@property (readwrite, nonatomic, weak) id<JLURLConnectionDelegate> delegate;

@property (readwrite, nonatomic) BOOL done;
@property (readwrite, nonatomic) BOOL isAsynchronous;
@property (readwrite, nonatomic, strong) JLFile* outputFile;
@property (readwrite, nonatomic, strong) NSHTTPURLResponse* response;
@property (readwrite, nonatomic, strong) NSURLRequest* request;
@property (readwrite, nonatomic, assign) NSUInteger bytesRead;
@property (readwrite, nonatomic, assign) long long totalBytesRead;
@property (readwrite, nonatomic, assign) long long totalBytesExpectedToRead;
@property (readwrite, nonatomic, assign) long long totalBytesExpectedToReadAfterResume;
@property (readwrite, nonatomic, assign) long long totalContentLength;

@property (readwrite, nonatomic, assign) long long bytesOffset;
@property (readwrite, nonatomic, copy) JLURLConnectionProgressBlock downloadProgressBlock;

@property (nonatomic, weak, readwrite) NSOperationQueue* currentQueue;
@end

@implementation JLURLConnection

+ (NSOperationQueue*)operationQueue
{
    static NSOperationQueue* _operationQueue = nil;
    @synchronized(self) {
        if(!_operationQueue)
        {
            _operationQueue = [[NSOperationQueue alloc] init];
            [_operationQueue setMaxConcurrentOperationCount:10];
        }
    }
    return _operationQueue;
}

+ (JLURLConnection*)startConnectionWithRequest:(NSURLRequest*)request toFileAtPath:(NSString*)filePath progressBlock:(JLURLConnectionProgressBlock)progressBlock
{
    JLURLConnection* connection = nil;
    if(request.URL.absoluteString.length)
    {
        connection = [JLURLConnection connectionWithRequest:request filePath:filePath progressBlock:progressBlock];
        
        connection.currentQueue = [NSOperationQueue currentQueue];
        
        if(connection)
        {
            NSBlockOperation* blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                [connection startSynchronously];
            }];
            [[JLURLConnectionsCollection sharedInstance] addConnection:connection];
            [[JLURLConnection operationQueue] addOperation:blockOperation];
        }
    }
    return connection;
}

+ (JLURLConnection*)startSynchronousConnectionWithRequest:(NSURLRequest*)request toFileAtPath:(NSString*)filePath progressBlock:(JLURLConnectionProgressBlock)progressBlock
{
    JLURLConnection* connection = nil;
    
    if(request.URL.absoluteString.length)
    {
        connection = [JLURLConnection connectionWithRequest:request filePath:filePath progressBlock:progressBlock];
        
        if(connection)
        {
            [connection startSynchronously];
            [[JLURLConnectionsCollection sharedInstance] addConnection:connection];
        }
    }
    
    return connection;
}

+ (JLURLConnection*)startConnectionWithRequest:(NSURLRequest*)request progressBlock:(JLURLConnectionProgressBlock)progressBlock
{
    return [self startConnectionWithRequest:request toFileAtPath:nil progressBlock:progressBlock];
}

+ (JLURLConnection*)startSynchronousConnectionWithRequest:(NSURLRequest*)request progressBlock:(JLURLConnectionProgressBlock)progressBlock
{
    return [self startSynchronousConnectionWithRequest:request toFileAtPath:nil progressBlock:progressBlock];
}

+ (void)pauseAllConnections
{
    [[[JLURLConnectionsCollection sharedInstance] connections] makeObjectsPerformSelector:@selector(pause)];
}

+ (void)resumeAllConnections
{
    [[[JLURLConnectionsCollection sharedInstance] connections] makeObjectsPerformSelector:@selector(resume)];
}


+ (id)connectionWithRequest:(NSURLRequest*)request
{
    JLURLConnection* connection = [[JLURLConnection alloc] initWithRequest:request delegate:nil];
    return connection;
}

+ (id)connectionWithRequest:(NSURLRequest*)request filePath:(NSString*)filePath progressBlock:(JLURLConnectionProgressBlock)progressBlock
{
    JLURLConnection* connection = [[JLURLConnection alloc] initWithRequest:request filePath:filePath progressBlock:progressBlock];
    return connection;
}

- (id)initWithRequest:(NSURLRequest*)request delegate:(id<JLURLConnectionDelegate>)aDelegate
{
	self = [super init];
	if(self)
	{
		self.delegate = aDelegate;
        self.request = request;
		// This connection will automatically start
		_urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        self.state = JLURLConnectionState_Ready;
	}
	return self;
}

- (id)initWithRequest:(NSURLRequest*)request filePath:(NSString*)filePath delegate:(id<JLURLConnectionDelegate>)aDelegate
{
	self = [super init];
	if(self)
	{
		self.delegate = aDelegate;
        self.request = request;
        self.filePath = filePath;
        self.state = JLURLConnectionState_Ready;
	}
	return self;
}

- (id)initWithRequest:(NSURLRequest*)request filePath:(NSString*)filePath progressBlock:(JLURLConnectionProgressBlock)progressBlock
{
	self = [super init];
	if(self)
	{
		self.downloadProgressBlock = progressBlock;
        self.request = request;
        self.filePath = filePath;
        
        self.state = JLURLConnectionState_Ready;
	}
	return self;
}

- (void)dealloc
{
    self.downloadProgressBlock = nil;
	self.data = nil;
	self.urlConnection = nil;
	self.errorStatus = nil;
	self.delegate = nil;
    self.request = nil;
    self.response = nil;
    self.filePath = nil;
    self.outputFile = nil;
}

- (void)start
{
    self.done = NO;

	if([self isReady])
    {
        if(self.filePath.length)
        {
            if(self.outputFile)
            {
                [self.outputFile close];
                self.outputFile = nil;
            }
            //set up output stream and update request if file already contains data
            self.outputFile = [JLFile fileWithFilePath:self.filePath];
            unsigned long long offset = self.outputFile.endOfFile;
            unsigned long long expectedSize = self.outputFile.expectedFileSize;
            
            if(offset != expectedSize)
            {
                NSMutableURLRequest *mutableURLRequest = [self.request mutableCopy];
                if ([[self.response allHeaderFields] valueForKey:@"ETag"]) {
                    [mutableURLRequest setValue:[[self.response allHeaderFields] valueForKey:@"ETag"] forHTTPHeaderField:@"If-Range"];
                }
                
                if(offset) {
                    [mutableURLRequest setValue:[NSString stringWithFormat:@"bytes=%llu-", offset] forHTTPHeaderField:@"Range"];
                    self.request = mutableURLRequest;
                }
                
                NSLog(@"starting connection with request headers = %@", self.request.allHeaderValuesString);
                if(self.outputFile.fileExists)
                    [self.outputFile open];
            }
            else if(expectedSize != 0 && offset == expectedSize)
            {
                NSLog(@"file already completed download");
                self.totalContentLength = offset;
                self.totalBytesRead = offset;
                [self finish];
            }

        }
        else
        {
            if(!_data) {
                _data = [[NSMutableData alloc] init];
            }
            
            //[self.data setLength:0];
        }
        
        _urlConnection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        self.state = JLURLConnectionState_Running;
        
		[self.urlConnection start];
    
        if(!self.isAsynchronous)
        {
            do {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            } while (!self.done);
        }
    }
}

- (void)startSynchronously
{
    self.isAsynchronous = NO;
    [self start];
}

- (void)pause {
    if ([self isPaused] || [self isFinished]) {
        return;
    }
    
    if ([self isRunning]) {
        
        NSMutableURLRequest *mutableURLRequest = [self.request mutableCopy];
        if ([[self.response allHeaderFields] valueForKey:@"ETag"]) {
            [mutableURLRequest setValue:[[self.response allHeaderFields] valueForKey:@"ETag"] forHTTPHeaderField:@"If-Range"];
        }
        
        [self.urlConnection cancel];
        [self.outputFile close];
    }
    
    self.state = JLURLConnectionState_Paused;
}

- (void)resume {
    if (![self isPaused]) {
        return;
    }
    
    self.state = JLURLConnectionState_Ready;
    
    [self start];
}

- (void)stop
{
    if([self isFinished])
        return;
    
    self.state = JLURLConnectionState_Stopped;

    [self cancel];
}

- (void)finish {
    
    if(self.outputFile) {
        [self.outputFile close];
        self.outputFile = nil;
    }
    
    if(self.urlConnection
       ) {
        self.urlConnection = nil;
    }
    
    self.state = JLURLConnectionState_Finished;
    
    self.bytesRead = 0;
    self.totalBytesRead = 0;
    
    self.done = YES;
    
    [self.collection removeConnection:self];
}

- (void)cancel {
    [self cancelConnection];
}

- (void)cancelConnection {
    
    if (self.urlConnection) {
        [self.urlConnection cancel];
    }
    
    [self finish];
}

- (void)updateProgressMainThread
{
    if(![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(updateProgressMainThread) withObject:nil waitUntilDone:NO];
    }
    else
    {
        self.downloadProgressBlock(self, self.state, self.errorStatus);
    }
}

- (void)updateProgress
{
    // if running asynchronously, then send status on queue the start was triggered on
    if(self.currentQueue)
    {
        // must wait so that state is consistent after operation completes, and to prevent
        // connection from getting autoreleased before it sent finished state
        [self.currentQueue addOperations:@[[NSBlockOperation blockOperationWithBlock:^{
            if (self.downloadProgressBlock)
            {
                self.downloadProgressBlock(self, self.state, self.errorStatus);
            }
            
            if(self.delegate && [self.delegate respondsToSelector:@selector(urlConnection:state:error:)])
            {
                [self.delegate urlConnection:self state:self.state error:self.errorStatus];
            }
        }]] waitUntilFinished:YES];
    }
    else
    {
        if (self.downloadProgressBlock)
        {
            self.downloadProgressBlock(self, self.state, self.errorStatus);
        }
        
        if(self.delegate && [self.delegate respondsToSelector:@selector(urlConnection:state:error:)])
        {
            [self.delegate urlConnection:self state:self.state error:self.errorStatus];
        }
    }
}

- (void)setFilePath:(NSString *)filePath
{
    if(_filePath != filePath)
    {
        _filePath = filePath;
        
    }
}

- (void)setState:(JLURLConnectionState)state
{
    if(_state != state)
    {
        _state = state;
        
        [self updateProgress];
    }
}

- (BOOL)isPaused {
    return self.state == JLURLConnectionState_Paused;
}

- (BOOL)isReady {
    return self.state == JLURLConnectionState_Ready;
}

- (BOOL)isRunning {
    return self.state == JLURLConnectionState_Running;
}

- (BOOL)isFinished {
    return self.state == JLURLConnectionState_Finished;
}

- (double)progress
{
    double progress = 0.0;
    if(self.totalContentLength > 0)
    {
        double bytesRead = (double)self.totalBytesRead;
        double contentLength = (double)self.totalContentLength;
        progress = (bytesRead / contentLength);
    }

    return progress;
}

#pragma mark -
#pragma mark NSURLConnection Delegate

- (BOOL)validateResponse:(NSURLResponse *)response isRedirect:(BOOL)isRedirectResponse
{
    return YES;
}

- (BOOL)hasAcceptableResponse:(NSURLResponse*)response
{
	BOOL result = [self validateResponse:response isRedirect:NO];
	
	if(result && [response isKindOfClass:[NSHTTPURLResponse class]] )
	{
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        // only care about no data issues if a file is being used
		if(self.outputFile && [httpResponse expectedContentLength] == 0)
		{
			JLDebugLog(@"error - content length = 0");
			self.errorStatus =  [JLError errorWithDomain:kJLURLConnection_Error_Domain code:JLURLConnectionErrorCode_ConnectionNoDataLength userInfo:@{NSLocalizedFailureReasonErrorKey : kJLURLConnection_Error_NoData}];

			result = FALSE;
		}
        else if(httpResponse.statusCode >= 400)
        {
            self.errorStatus = [JLError errorWithDomain:kJLURLConnection_Error_Domain code:httpResponse.statusCode userInfo:@{NSLocalizedFailureReasonErrorKey : [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode]}];
            
            JLDebugLog(@"We got an error status code = %d", httpResponse.statusCode);
            result = FALSE;
        }
	}
	
	return result;
}

- (NSURLRequest *) connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response {
    
    self.redirectRequest = request;
	
    JLDebugLog(@"request URL = %@, response URL = %@", request.URL, [response URL]);

    self.redirectResponse = response;
    
    [self validateResponse:response isRedirect:YES];

    [self updateProgress];

    return self.redirectRequest;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	BOOL responseOk = [self hasAcceptableResponse:response];
    
	if( !responseOk )
	{
        // only care about no data issues if a file is being used
		if(self.outputFile && !self.data.length )
        {
            self.errorStatus = [JLError errorWithDomain:kJLURLConnection_Error_Domain code:JLURLConnectionErrorCode_ConnectionNoData userInfo:@{NSLocalizedFailureReasonErrorKey : kJLURLConnection_Error_NoData}];
        }
        
        [self finish];
		return;
	}
    
    self.response = (NSHTTPURLResponse *)response;
    
    // only care about bytes size or content size if using file
    if(self.outputFile)
    {
        self.totalBytesExpectedToReadAfterResume = self.response.expectedContentLength;

        // Set Content-Range header if status code of response is 206 (Partial Content)
        // See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.2.7
        self.totalContentLength = self.totalBytesExpectedToReadAfterResume;

        long long fileOffset = 0;
        NSUInteger statusCode = ([self.response isKindOfClass:[NSHTTPURLResponse class]]) ? (NSUInteger)[self.response statusCode] : 200;
        JLDebugLog(@"status code %d for file %@", statusCode, self.filePath.lastPathComponent);
        if (statusCode == 206) {
            NSString *contentRange = [self.response.allHeaderFields valueForKey:@"Content-Range"];
            if ([contentRange hasPrefix:@"bytes"]) {
                NSArray *byteRanges = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
                if ([byteRanges count] == 4) {
                    fileOffset = [[byteRanges objectAtIndex:1] longLongValue];
                    
                    self.totalContentLength = [[byteRanges objectAtIndex:2] longLongValue] ?: -1; // if this is "*", it's converted to 0, but -1 is default.
                    
                    JLDebugLog(@"expectedContentLength = %lld, totalContentLength = %lld,  totalBytesExpectedToRead = %lld, totalBytesExpectedToReadAfterResume = %lld", self.response.expectedContentLength, self.totalContentLength, self.totalBytesExpectedToRead, self. totalBytesExpectedToReadAfterResume);
                }
            }
        }
        
        self.bytesOffset = MAX(fileOffset, 0);
        
        if(!self.totalBytesExpectedToRead)
        {
            // file is incomplete after app quit, restart from where resume is
            self.totalBytesExpectedToRead = self.totalContentLength;
            self.totalBytesRead = self.outputFile.endOfFile;
        }
        
        if(self.outputFile)
        {
            unsigned long long expectedFileSize = [self.outputFile expectedFileSize];

            //open/create file now that we know we have data to download
            [self.outputFile open];

            if(expectedFileSize != self.totalContentLength)
            {
                // file may be corrupted or content may have changed format (ie. re-encoded, re-uploaded, etc.)
                JLDebugLog(@"expectedFileSize (%lld) DOES NOT match totalContentLength(%lld) ", expectedFileSize, self.totalContentLength);
                if(expectedFileSize == 0)
                {
                    [self.outputFile setExpectedFileSize:self.totalContentLength];
                }
            }
            else {
                JLDebugLog(@"expectedFileSize (%lld) DOES match totalContentLength(%lld) ", expectedFileSize, self.totalContentLength);
            }
        }
    }
    else
    {
        self.totalBytesExpectedToRead = self.response.expectedContentLength;
        self.totalContentLength = self.response.expectedContentLength;
        
        JLDebugLog(@"expected Bytes Size (%lld)", self.totalBytesExpectedToRead);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if(data.length)
	{
        self.totalBytesRead += [data length];
        self.bytesRead = [data length];
        
		if( self.data )
		{
			[self.data appendData:data];
		}
        else if(self.outputFile)
        {
            [self.outputFile appendData:data];
        }
        
        [self updateProgress];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(JLError *)error
{
	JLDebugLog(@"error = %@", error);
	self.errorStatus = error;
    
    [self finish];
}
@end
