//
//  JLFile.m
//
//  Created by Jonathan Lott on 2/2/12.
//  Copyright (c) 2012 A Lott Of Ideas. All rights reserved.
//

#import "JLFile.h"
#include "sys/xattr.h"

@implementation NSString (FileSize)

- (unsigned long long)unsignedLongLongValue
{
    unsigned long long ullvalue = 0;
    if(self.longLongValue)
        ullvalue = strtoull([self UTF8String], NULL, 0);
    
    return ullvalue;
}

@end

@interface JLFile ()
@property (readwrite, nonatomic, strong) NSFileHandle* writeFileHandle;
@property (readwrite, nonatomic, strong) NSFileManager* fileManager;

@end

@implementation JLFile

/**
 Returns the path to the application's Documents directory.
 */
+ (NSString *)applicationDocumentsDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

+ (id)fileWithFilePath:(NSString*)filePath
{
    return [[JLFile alloc] initWithFilePath:filePath];
}

+ (id)docuemntsFileWithFilePath:(NSString*)filePath
{
    NSString* documentsFilePath = [self applicationDocumentsDirectory];
    documentsFilePath = [documentsFilePath stringByAppendingPathComponent:filePath];
    return [self fileWithFilePath:documentsFilePath];
}

+ (id)bundleFileWithFileName:(NSString*)fileName
{
    NSString* path = [[NSBundle mainBundle] pathForResource:[fileName stringByDeletingPathExtension] ofType:[fileName pathExtension]];
    JLFile* file = nil;
    if(path)
    {
        file = [self fileWithFilePath:path];
    }
    return file;
}

+ (NSArray*)deleteFiles:(NSArray*)filePaths
{
    NSMutableArray* errorFiles = [NSMutableArray arrayWithCapacity:filePaths.count];
    
    for(NSString* filePath in filePaths)
    {
        JLFile* file = [JLFile fileWithFilePath:filePath];
        BOOL success = [file delete];
        if(!success)
        {
            [errorFiles addObject:filePath];
        }
        else {
            JLDebugLog(@"deleted file %@", filePath);
        }
    }
    return errorFiles;
}

- (id)initWithFilePath:(NSString*)filePath
{
    self = [super init];
    if(self)
    {
        self.filePath = filePath;
        self.fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (BOOL)createFile
{
    BOOL fileExists = YES;
    if(self.filePath.length)
    {
        BOOL isDirectory = NO;
        if(![self.fileManager fileExistsAtPath:self.filePath isDirectory:&isDirectory])
        {
            // create an empty file
            fileExists = [self.fileManager createFileAtPath:self.filePath contents:nil attributes:nil];
            if(!fileExists)
            {
                //check
                JLDebugLog(@"File Creation Failed");
            }
        }
    }
    return fileExists;
}

- (void)open
{
    BOOL fileExists = [self createFile];
    if(fileExists && !self.writeFileHandle) {
        [self updateFileHandle];
    }
}

- (void)close
{
    [self.writeFileHandle closeFile];
}

- (BOOL)fileExists
{
    return self.filePath.length && [self.fileManager fileExistsAtPath:self.filePath];
}

- (BOOL)delete
{
    BOOL fileDeleted = YES;
    if([self.fileManager fileExistsAtPath:self.filePath])
    {
        NSError* error = nil;
        fileDeleted = [self.fileManager removeItemAtPath:self.filePath error:&error];
        if(!fileDeleted)
        {
            self.fileError = error;
        }
        JLDebugLog(@"deleted file");
    }
    return fileDeleted;
}

- (BOOL)isFileComplete
{
    BOOL isFileComplete = NO;
    if(self.fileExists && self.expectedFileSize && self.expectedFileSize == self.fileSize)
    {
        isFileComplete = YES;
    }
    return isFileComplete;
}

- (NSFileManager*)fileManager
{
    if(!_fileManager)
        _fileManager = [NSFileManager defaultManager];
    
    return _fileManager;
}

- (unsigned long long)fileSize
{
    unsigned long long fileSize = 0;
    NSError* error = nil;
    NSDictionary *fileAttributes = nil;
    
    if(self.fileExists) {
        fileAttributes = [self.fileManager attributesOfItemAtPath:self.filePath error:&error];
        if(fileAttributes){
            //        NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
            //        if(fileSize){
            //            fileSize = [fileSizeNumber unsignedLongLongValue];
            //        }
            fileSize = [fileAttributes fileSize];
        }
        else{
            self.fileError = error;
        }
    }
    return fileSize;
}

- (BOOL)setAttribute:(id)value forKey:(NSString*)key
{
    BOOL success = YES;
    // http://www.cocoanetics.com/2012/03/reading-and-writing-extended-file-attributes/
    const char *attrName = [key UTF8String];
    const char *filePath = [self.filePath fileSystemRepresentation];
    
    const char *val = [[value description] UTF8String];
    
    int result = setxattr(filePath, attrName, val, strlen(val), 0, 0);
    
    if(result != 0)
    {
        JLDebugLog(@"error %d setting attributes, error code %s", result, strerror(errno));
        success = NO;
    }
    return success;
}

- (NSString*)attributeForKey:(NSString*)key
{
    NSError* error = nil;
    NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:self.filePath error:&error];
    NSString* attribute = [fileAttributes objectForKey:key];
    
    if(!attribute.length)
    {
        const char *attrName = [key UTF8String];
        const char *filePath = [self.filePath fileSystemRepresentation];
        
        // get size of needed buffer
        ssize_t bufferLength = getxattr(filePath, attrName, NULL, 0, 0, 0);
        
        if(bufferLength > 0) {
            // make a buffer of sufficient length
            char *buffer = malloc(bufferLength);
            
            // now actually get the attribute string
            getxattr(filePath, attrName, buffer, 255, 0, 0);
            
            // convert to NSString
            attribute = [[NSString alloc] initWithBytes:buffer length:bufferLength encoding:NSUTF8StringEncoding];
            
            // release buffer
            free(buffer);
        }
    }
    
    return attribute;
}

- (void)setExpectedFileSize:(unsigned long long)size
{
    NSString *numStr = [NSString stringWithFormat:@"%llu", size];
    
    [self setAttribute:numStr forKey:kJLFileAttributesKey_ExpectedFileSize];
}

- (unsigned long long)expectedFileSize
{
    NSString* number = [self attributeForKey:kJLFileAttributesKey_ExpectedFileSize];
    
    return number.unsignedLongLongValue;
}

- (unsigned long long)fileWriteOffset
{
    return self.writeFileHandle.offsetInFile;
}

- (unsigned long long)endOfFile
{
    return self.writeFileHandle.seekToEndOfFile;
}

- (void)updateFileHandle
{
    if(self.fileExists)
    {
        self.writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
    }
}

- (void)setFilePath:(NSString *)filePath
{
    if(![_filePath isEqualToString:filePath])
    {
        _filePath = [filePath copy];
        [self updateFileHandle];
    }
}

- (BOOL)appendData:(NSData*)data
{
    if(!self.writeFileHandle)
        return NO;
    
    [self.writeFileHandle seekToEndOfFile];
    if(data.length)
    {
        [self.writeFileHandle writeData:data];
    }
    
    return YES;
}
@end