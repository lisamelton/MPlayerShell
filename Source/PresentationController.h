//
//  PresentationController.h
//  MPlayerShell
//
//  Copyright (c) 2013-2024 Lisa Melton
//

#import <Cocoa/Cocoa.h>
#import "VideoRenderer.h"
#import "MediaView.h"

@protocol PresentationControllerDelegate;

@interface PresentationController : NSObject <VideoRendererDelegate, NSWindowDelegate>

- (id)initWithDelegate:(id <PresentationControllerDelegate>)aDelegate
               appName:(NSString *)aString
        fullScreenMode:(BOOL)fullScreenFlag
        floatOnTopMode:(BOOL)floatOnTopFlag;

@property (readonly) MediaView *mediaView;

@end

@protocol PresentationControllerDelegate
- (void)sendCommand:(NSString *)command;
@end
