//
//  VideoRenderer.h
//  MPlayerShell
//
//  Copyright (c) 2013-2024 Lisa Melton
//

#import <Cocoa/Cocoa.h>
#import "MPlayerOSXVOProto.h"
#import "VideoLayer.h"

@protocol VideoRendererDelegate;

@interface VideoRenderer : NSObject <MPlayerOSXVOProto>

- (id)initWithDelegate:(id <VideoRendererDelegate>)aDelegate
      sharedBufferName:(NSString *)aName
            videoLayer:(VideoLayer *)aLayer;

@end

@protocol VideoRendererDelegate
- (void)startRenderingWithDisplaySize:(NSSize)aSize;
- (void)stopRendering;
@end
