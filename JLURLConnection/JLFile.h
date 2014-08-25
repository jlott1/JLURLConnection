//
//  JLFile.h
//
//  Created by Jonathan Lott on 2/2/12.
//  Copyright (c) 2012 A Lott Of Ideas. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef DEBUG
#define JLDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define JLDebugLog(fmt, ...)
#endif

#define kJLFileAttributesKey_ExpectedFileSize @"JLExpectedFileSize"

@interface JLFile : NSObject
@property (readonly, nonatomic, strong) NSFileHandle* writeFileHandle;
@property (readwrite, nonatomic, strong) NSError* fileError;
@property (readwrite, nonatomic, copy) NSString* filePath;


+ (id)fileWithFilePath:(NSString*)filePath;
// helper method for documents directory
+ (id)docuemntsFileWithFilePath:(NSString*)filePath;
//helper method for files in main NSBundle
+ (id)bundleFileWithFileName:(NSString*)fileName;

+ (NSArray*)deleteFiles:(NSArray*)filePaths;

- (id)initWithFilePath:(NSString*)filePath;
- (void)open;
- (void)close;
- (BOOL)fileExists;
- (BOOL)delete;
- (BOOL)isFileComplete;
- (NSFileManager*)fileManager;

- (unsigned long long)fileSize;
- (BOOL)setAttribute:(id)value forKey:(NSString*)key;
- (NSString*)attributeForKey:(NSString*)key;
- (void)setExpectedFileSize:(unsigned long long)size;
- (unsigned long long)expectedFileSize;
- (unsigned long long)fileWriteOffset;
- (unsigned long long)endOfFile;
- (void)updateFileHandle;
- (BOOL)appendData:(NSData*)data;
@end
