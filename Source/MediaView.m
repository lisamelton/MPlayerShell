//
//  MediaView.m
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import "MediaView.h"

@implementation MediaView {
    NSView *_videoView;
}

- (id)initWithFrame:(NSRect)frameRect
{
    if (!(self = [super initWithFrame:frameRect])) {
        return nil;
    }
    _displaySize = frameRect.size;

    _videoLayer = [VideoLayer new];

    _videoView = [[NSView alloc] initWithFrame:frameRect];
    [_videoView setWantsLayer:YES];
    [_videoView setLayer:_videoLayer];

    [self addSubview:_videoView];

    return self;
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];

    NSRect frameRect;

    CGFloat widthScale = newSize.width / self.displaySize.width;
    CGFloat heightScale = newSize.height / self.displaySize.height;

    if (widthScale <= heightScale) {
        CGFloat height = self.displaySize.height * widthScale;
        frameRect = NSMakeRect(
            0,
            (newSize.height - height) / 2,
            self.displaySize.width * widthScale,
            height
        );
    } else {
        CGFloat width = self.displaySize.width * heightScale;
        frameRect = NSMakeRect(
            (newSize.width - width) / 2,
            0,
            width,
            self.displaySize.height * heightScale
        );
    }
    [_videoView setFrame:frameRect];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor blackColor] set];
    [NSBezierPath fillRect:dirtyRect];
}

- (BOOL)isOpaque
{
    return YES;
}

@end
