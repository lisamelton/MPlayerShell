//
//  VideoRenderer.m
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import "VideoRenderer.h"

@interface VideoRenderer ()

- (void)connect;
- (void)disconnect;

@end

#pragma mark -

@implementation VideoRenderer {
    __weak id <VideoRendererDelegate> _delegate;
    NSString *_sharedBufferName;
    VideoLayer *_videoLayer;
    NSThread *_thread;
    size_t _bufferSize;
    unsigned char *_sharedBuffer;
    unsigned char *_privateBuffer;
    CVPixelBufferRef _pixelBuffer;
}

- (id)initWithDelegate:(id <VideoRendererDelegate>)aDelegate
      sharedBufferName:(NSString *)aName
            videoLayer:(VideoLayer *)aLayer
{
    if (!(self = [super init])) {
        return nil;
    }
    _delegate = aDelegate;
    _sharedBufferName = aName;
    _videoLayer = aLayer;

    _thread = [[NSThread alloc] initWithTarget:self
                                      selector:@selector(connect)
                                        object:nil];
    [_thread start];

    return self;
}

- (void)dealloc
{
    if ([_thread isExecuting]) {
        [self performSelector:@selector(disconnect)
                     onThread:_thread
                   withObject:nil
                waitUntilDone:YES];
    }
    while ([_thread isExecuting]) {
    }
}

- (void)connect
{
    @autoreleasepool {
        [NSConnection serviceConnectionWithName:_sharedBufferName
                                     rootObject:self];
 
        // There's no advantage using special run loop modes here. Everything
        // performs well with the default. Don't use `NSRunLoop` either since
        // the call to `CFRunLoopStop` in `disconnect` won't force an
        // AppKit-based run loop to exit.
        CFRunLoopRun();
   }
}

- (void)disconnect
{
    CFRunLoopStop(CFRunLoopGetCurrent());
    [self stop];
}

#pragma mark -
#pragma mark MPlayerOSXVOProto

- (int)startWithWidth:(bycopy int)width
           withHeight:(bycopy int)height
            withBytes:(bycopy int)bytes
           withAspect:(bycopy int)aspect
{
    // The `pixelBuffer` property of the video layer object is used as a
    // boolean to indicate whether rendering is in process. Due to the
    // unpredictable nature of callback sequencing in `mplayer`, the `stop`
    // method is called here if that property is "true."
    if (_videoLayer.pixelBuffer) {
        [self stop];
    }
    int sharedBufferFile = shm_open([_sharedBufferName UTF8String], O_RDONLY, S_IRUSR);

    if (sharedBufferFile == -1) {
        NSLog(@"Can't open shared buffer file for mplayer");
        exit(EXIT_FAILURE);
    }
    _bufferSize = width * height * bytes;

    if (_sharedBuffer) {
        munmap(_sharedBuffer, _bufferSize);
    }
    _sharedBuffer = mmap(NULL, _bufferSize, PROT_READ, MAP_SHARED, sharedBufferFile, 0);
    close(sharedBufferFile);

    if (_sharedBuffer == MAP_FAILED) {
        NSLog(@"Can't allocate shared buffer for mplayer");
        exit(EXIT_FAILURE);
    }
    if (_privateBuffer) {
        free(_privateBuffer);
    }
    _privateBuffer = malloc(_bufferSize);

    OSType pixelFormat;

    // Because `mplayer` only passes the size in `bytes` of each pixel, the
    // format must be guessed from that value. This guess can be wrong since
    // more than one format can apply to a single byte size. But most of the
    // time the format will be `kYUVSPixelFormat` anyway.
    switch (bytes) {
    case 3:
        pixelFormat = k24RGBPixelFormat;
        break;
    case 4:
        // Could be `k32BGRAPixelFormat` too, but we can only guess one.
        pixelFormat = k32ARGBPixelFormat;
        break;
    default:
        pixelFormat = kYUVSPixelFormat;
    }
    if (CVPixelBufferCreateWithBytes(NULL,
                                     width,
                                     height,
                                     pixelFormat,
                                     _privateBuffer,
                                     width * bytes,
                                     NULL,
                                     NULL,
                                     NULL,
                                     &_pixelBuffer)
    ) {
        NSLog(@"Can't allocate pixel buffer");
        exit(EXIT_FAILURE);
    }
    NSSize displaySize;

    // Use the same egregious algorithm as `mplayer` to derive an "aspect"
    // integer from the actual width and height, and then compare it to their
    // bogus display `aspect` value. If they're the same, then it's extremely
    // likely the image doesn't need to be transformed.
    if (((width * 100) / height) == aspect) {
        displaySize = NSMakeSize(
            width,
            height
        );
    } else {
        CGFloat aspectRatio;

        // The two most common `aspect` values are `133` and `177` because
        // they're used in DVD video. So special case those and convert them
        // to `4:3` and `16:9` in actual floating point. Otherwise, just
        // convert `aspect` into floating point and hope the resulting ratio
        // is close to being correct.
        switch (aspect) {
        case 133:
            aspectRatio = 4.0 / 3;
            break;
        case 177:
            aspectRatio = 16.0 / 9;
            break;
        default:
            aspectRatio = aspect / 100.0;
        }
        if (width <= (height * aspectRatio)) {
            displaySize = NSMakeSize(
                height * aspectRatio,
                height
            );
        } else {
            displaySize = NSMakeSize(
                width,
                width / aspectRatio
            );
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate startRenderingWithDisplaySize:displaySize];
    });

    return 0;
}

- (void)stop
{
    // `mplayer` can call `stop` before it calls `startWithWidth:`, so care is
    // taken here if that happens. Because `mplayer` is so cavalier about
    // callback sequencing, no additional checks are needed to allow
    // `disconnect` to call `stop` directly.
    if (_videoLayer.pixelBuffer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate stopRendering];
        });
        _videoLayer.pixelBuffer = NULL;
    }
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
    // `free` doesn't object to the occasional NULL pointer.
    free(_privateBuffer);
    _privateBuffer = NULL;

    if (_sharedBuffer) {
        munmap(_sharedBuffer, _bufferSize);
        _sharedBuffer = NULL;
    }
    _bufferSize = 0;
}

- (void)render
{
    if (!_pixelBuffer) {
        return;
    }
    memcpy(_privateBuffer, _sharedBuffer, _bufferSize);

    _videoLayer.pixelBuffer = _pixelBuffer;
    [_videoLayer display];
}

- (void)toggleFullscreen
{
    // Nothing to do here since this will never be called.
}

- (void)ontop
{
    // Nothing to do here since this will never be called either.
}

@end
