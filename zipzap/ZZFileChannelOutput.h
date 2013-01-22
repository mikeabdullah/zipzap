//
//  ZZFileChannelOutput.h
//  zipzap
//
//  Created by Glen Low on 12/01/13.
//
//

#import <Foundation/Foundation.h>

#import "ZZChannelOutput.h"

@interface ZZFileChannelOutput : NSObject <ZZChannelOutput>

@property (nonatomic) uint32_t offset;

- (id)initWithURL:(NSURL*)URL
	   offsetBias:(uint32_t)offsetBias;
- (void)write:(NSData*)data;
- (void)close;

@end
