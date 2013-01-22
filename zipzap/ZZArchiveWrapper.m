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

#include <sys/stat.h>


@implementation NSFileWrapper (ZZArchiveWrapper)

- (void)zz_addArchiveEntriesToMutableArray:(NSMutableArray *)array filename:(NSString *)filename;
{
    NSDictionary *attributes = [self fileAttributes];
	NSDate *modDate = [attributes fileModificationDate];
	
	if ([self isDirectory])
    {
        // Entry for the directory itself. Skip for root directory
        if (filename)
        {
            if (![filename hasSuffix:@"/"]) filename = [filename stringByAppendingString:@"/"];
			
			ZZArchiveEntry *entry = [ZZArchiveEntry archiveEntryWithFileName:filename
																	fileMode:S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH	// cheat and match ZZNewArchiveEntry's internals for now
																lastModified:(modDate ? modDate : [NSDate date])
															compressionLevel:0		// directories can't be compressed
																   dataBlock:nil	// and of course have no data
																 streamBlock:nil
														   dataConsumerBlock:nil];
			
            [array addObject:entry];
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
		ZZArchiveEntry *entry = [ZZArchiveEntry archiveEntryWithFileName:filename
																fileMode:S_IFREG | S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH	// cheat and match ZZNewArchiveEntry's internals for now
															lastModified:(modDate ? modDate : [NSDate date])
														compressionLevel:-1			// always use compression for now
															   dataBlock:^NSData *{
																   return [self regularFileContents];
															   }
															 streamBlock:nil
													   dataConsumerBlock:nil];
		
        [array addObject:entry];
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

- (id)initWithURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError *__autoreleasing *)outError;
{
	if (self = [super initWithURL:url options:options error:outError])
	{
		if ([self isRegularFile] && ![self readFromURL:url options:options error:outError])
		{
			self = nil;
		}
	}
	return self;
}

- (id)initRegularFileWithContents:(NSData *)contents;
{
	if (self = [super initRegularFileWithContents:contents])
	{
		if (contents)
		{
			ZZArchive *archive = [ZZArchive archiveWithData:contents];
			[self readFromArchive:archive error:NULL];
		}
	}
	return self;
}

- (BOOL)readFromURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError *__autoreleasing *)outError;
{
	ZZArchive *archive = [ZZArchive archiveWithContentsOfURL:url];
	NSArray *entries = [archive entries];
	
	if (entries)
	{
		// Reset super's idea to match the archive on disk
		if (![super readFromURL:url
						options:0	// deliberately bypass options, particularly immediate reading
						  error:outError])
		{
			return NO;
		}
		
		// In the unlikely event that super and ZZArchive disagree about the contents of the file, assume it's no longer an archive
		if (![self isRegularFile]) return YES;
		
		// Load the entries
		return [self readFromArchive:archive error:outError];
	}
	else
	{
		// Fallback to regular reading
		return [super readFromURL:url options:options error:outError];
	}
}

- (BOOL)readFromArchive:(ZZArchive *)archive error:(NSError *__autoreleasing *)error;
{
	// Assemble the entries into a directory structure
	_rootWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:[archive fileWrappers]];
	return YES;
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
	
	mode_t mode = [entry fileMode];
	NSString *fileType = nil;
	
	if (S_ISREG(mode))
	{
		self = [self init];
		fileType = NSFileTypeRegular;
	}
	else if (S_ISDIR(mode))
	{
		self = [self initDirectoryWithFileWrappers:nil];
		fileType = NSFileTypeDirectory;
	}
	else
	{
		self = nil;
	}
	
	if (self)
	{
		_archiveEntry = entry;
		
		NSString *filename = [[entry fileName] lastPathComponent];	// entry might be nested inside a directory, so grab just last component
		[self setFilename:filename];
		[self setPreferredFilename:filename];
		
		NSDictionary *attributes = @{ NSFileType : fileType,
						  NSFilePosixPermissions : @(mode),
						  NSFileModificationDate : entry.lastModified,
									  NSFileSize : @(entry.uncompressedSize) };
		
		[self setFileAttributes:attributes];
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
