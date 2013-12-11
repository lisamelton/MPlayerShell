//
//  VideoLayer.h
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

@interface VideoLayer : CAOpenGLLayer

@property CVPixelBufferRef pixelBuffer;

@end
