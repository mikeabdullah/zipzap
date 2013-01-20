//
//  ZZArchiveWrapper.h
//  zipzap
//
//  Created by Mike on 19/01/2013.
//
//

#import <Foundation/Foundation.h>


@class ZZArchiveEntry;

@interface ZZArchiveWrapper : NSFileWrapper

#pragma mark Creating an Archive Wrapper

- (id)initArchiveWithFileWrapper:(NSFileWrapper *)fileWrapper;

// If the URL turns out to hold a zip file, reports YES from -isArchive and therefore becomes editable
- (id)initWithURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError *__autoreleasing *)outError;


#pragma mark Testing for Archives
// If -isArchive returns YES (guaranteed to if you used -initArchiveWithFileWrapper:) allows full access to modifying -fileWrappers
- (BOOL)isArchive;

// Generating a zip file
- (BOOL)writeToURL:(NSURL *)url options:(NSFileWrapperWritingOptions)options originalContentsURL:(NSURL *)originalContentsURL error:(NSError *__autoreleasing *)outError;
- (NSData *)regularFileContents;    // unlike NSFileWrapper, doesn't cache


#pragma mark Archive Entries
// Existing entries can be included in archives more efficiently
- (id)initWithArchiveEntry:(ZZArchiveEntry *)entry __attribute__((nonnull(1)));


@end
