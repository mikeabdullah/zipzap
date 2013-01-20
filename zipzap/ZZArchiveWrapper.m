//
//  ZZArchiveWrapper.m
//  zipzap
//
//  Created by Mike on 19/01/2013.
//
//

#import "ZZArchiveWrapper.h"

#import "ZZArchive.h"
#import "ZZArchiveEntry.h"


@implementation NSFileWrapper (ZZArchiveWrapper)

- (void)zz_addArchiveEntriesToMutableArray:(NSMutableArray *)array filename:(NSString *)filename;
{
    if ([self isDirectory])
    {
        // Entry for the directory itself. Skip for root directory
        if (filename)
        {
            if (![filename hasSuffix:@"/"]) filename = [filename stringByAppendingString:@"/"];
            [array addObject:[ZZArchiveEntry archiveEntryWithDirectoryName:filename]];
        }
        else
        {
            filename = @"";
        }
        
        // Entries for any child wrappers
        [[self fileWrappers] enumerateKeysAndObjectsUsingBlock:^(NSString *aFilename, NSFileWrapper *aWrapper, BOOL *stop) {
            
            [aWrapper zz_addArchiveEntriesToMutableArray:array filename:[filename stringByAppendingString:aFilename]];
        }];
    }
    else
    {
        [array addObject:[ZZArchiveEntry archiveEntryWithFileName:filename compress:YES dataBlock:^NSData *{
            return [self regularFileContents];
        }]];
    }
}

- (void)zz_setFilename:(NSString *)filename recursive:(BOOL)recursive;
{
    [self setFilename:filename];
    
    if (recursive && [self isDirectory])
    {
        [[self fileWrappers] enumerateKeysAndObjectsUsingBlock:^(NSString *aFilename, NSFileWrapper *aWrapper, BOOL *stop) {
            [aWrapper zz_setFilename:aFilename recursive:recursive];
        }];
    }
}

@end


#pragma mark -


@interface ZZArchiveWrapper ()

// Internally hold a wrapper that represents the root of the archive, for adding and removing wrappers from
@property(readonly) NSFileWrapper *rootWrapper;

// The entry that directly corresponds to this file wrapper, if there is one
@property(readonly) ZZArchiveEntry *archiveEntry;

@end


@implementation ZZArchiveWrapper

#pragma mark Creating an Archive Wrapper

- (id)initArchiveWithFileWrapper:(NSFileWrapper *)fileWrapper;
{
    if (self = [self init])
    {
        _rootWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil];
        if (fileWrapper) [self addFileWrapper:fileWrapper];
    }
    return self;
}

#pragma mark Archive Status

- (BOOL)isArchive; { return _rootWrapper != nil; }

#pragma mark Modifying Archive Contents

- (NSDictionary *)fileWrappers;
{
	return ([self isArchive] ? [[self rootWrapper] fileWrappers] : [super fileWrappers]);
}

- (NSString *)addFileWrapper:(NSFileWrapper *)child;
{
	return ([self isArchive] ? [[self rootWrapper] addFileWrapper:child] : [super addFileWrapper:child]);
}

- (void)removeFileWrapper:(NSFileWrapper *)child;
{
	return ([self isArchive] ? [[self rootWrapper] removeFileWrapper:child] : [super removeFileWrapper:child]);
}

#pragma mark Generating a Zip File

- (BOOL)writeToURL:(NSURL *)url options:(NSFileWrapperWritingOptions)options originalContentsURL:(NSURL *)originalContentsURL error:(NSError *__autoreleasing *)outError;
{
    if (![self isArchive]) return [super writeToURL:url options:options originalContentsURL:originalContentsURL error:outError];
    
    
    // TODO: Implement atomic writing for ourselves rather than relying on super
    BOOL result;
    if (options & NSFileWrapperWritingWithNameUpdating)
    {
        result = [super writeToURL:url options:options originalContentsURL:originalContentsURL error:outError];
    }
    else
    {
        // Use ZZMutableArchive to do the dirty work
        ZZMutableArchive *archive = [[ZZMutableArchive alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding];
        if (!archive)
        {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
            return NO;
        }
        
        [archive setEntries:[self entries]];
        
        // TODO: report back if this failed!
        result = YES;
    }
    
    
    if (result && options & NSFileWrapperWritingWithNameUpdating)
    {
        // Go through and update all descendant wrappers
        [[self rootWrapper] zz_setFilename:nil recursive:YES];
    }
    
    
    return result;
}

- (NSData *)regularFileContents;
{
    if (![self isArchive])
	{
		ZZArchiveEntry *entry = [self archiveEntry];
		return (entry ? [entry data] : [super regularFileContents]);
	}
    
    // Use ZZMutableArchive to do the dirty work
    NSMutableData *result = [NSMutableData data];
    ZZMutableArchive *archive = [[ZZMutableArchive alloc] initWithData:result encoding:NSUTF8StringEncoding];
    NSAssert(archive, @"I thought -[ZZMutableArchive initWithData:encoding: would never fail");
    
    [archive setEntries:[self entries]];
    
    return result;
}

#pragma mark Archive Entries

- (id)initWithArchiveEntry:(ZZArchiveEntry *)entry;
{
	NSParameterAssert(entry);
	
	// Assume it's a regular file for now
	if (self = [self init])
	{
		_archiveEntry = entry;
		
		NSString *filename = [[entry fileName] lastPathComponent];	// entry might be nested inside a directory, so grab just last component
		[self setFilename:filename];
		[self setPreferredFilename:filename];
	}
	return self;
}

- (void)zz_addArchiveEntriesToMutableArray:(NSMutableArray *)array filename:(NSString *)filename;
{
	// Re-use existing entry when possible
	ZZArchiveEntry *entry = [self archiveEntry];
	if (entry && [self isRegularFile] && [filename isEqualToString:[entry fileName]])
	{
		[array addObject:entry];
	}
	else
	{
		[super zz_addArchiveEntriesToMutableArray:array filename:filename];
	}
}

- (NSArray *)entries;
{
    NSMutableArray *result = [NSMutableArray array];
    [[self rootWrapper] zz_addArchiveEntriesToMutableArray:result filename:nil];
    return result;
}

@end
