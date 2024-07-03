//
//  VideoLayer.h
//  MPlayerShell
//
//  Copyright (c) 2013-2024 Lisa Melton
//

#import <Cocoa/Cocoa.h>

@interface VideoLayer : CAOpenGLLayer

@property CVPixelBufferRef pixelBuffer;

@end
