//
//  MediaView.h
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import <Cocoa/Cocoa.h>
#import "VideoLayer.h"

@interface MediaView : NSView

@property NSSize displaySize;
@property (readonly) VideoLayer *videoLayer;

@end
