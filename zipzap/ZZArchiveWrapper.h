//
//  ZZArchiveWrapper.h
//  zipzap
//
//  Created by Mike on 19/01/2013.
//
//

#import <Foundation/Foundation.h>


@interface ZZArchiveWrapper : NSFileWrapper

// Creating an Archive Wrapper
- (id)initArchiveWithFileWrapper:(NSFileWrapper *)fileWrapper;

// If -isArchive returns YES (guaranteed to if you used -initArchiveWithFileWrapper:) allows full access to modifying -fileWrappers
- (BOOL)isArchive;

// Generating a zip file
- (BOOL)writeToURL:(NSURL *)url options:(NSFileWrapperWritingOptions)options originalContentsURL:(NSURL *)originalContentsURL error:(NSError *__autoreleasing *)outError;
- (NSData *)regularFileContents;    // unlike NSFileWrapper, doesn't cache

@end
