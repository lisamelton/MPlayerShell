//
//  MediaView.h
//  MPlayerShell
//
//  Copyright (c) 2013-2024 Lisa Melton
//

#import <Cocoa/Cocoa.h>
#import "VideoLayer.h"

@interface MediaView : NSView

@property NSSize displaySize;
@property (readonly) VideoLayer *videoLayer;

@end
