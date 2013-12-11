//
//  VideoLayer.m
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import <OpenGL/gl.h>
#import "VideoLayer.h"
#import <OpenGL/gl.h>

@implementation VideoLayer {
    CVOpenGLTextureCacheRef _textureCache;
}

-(CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pixelFormat
{
    CGLContextObj glContext = [super copyCGLContextForPixelFormat:pixelFormat];

    CGLLockContext(glContext);

    if (_textureCache) {
        CVOpenGLTextureCacheRelease(_textureCache);
    }
    if (CVOpenGLTextureCacheCreate(NULL, NULL, glContext, pixelFormat, NULL, &_textureCache)) {
        _textureCache = NULL;
    }
    CGLUnlockContext(glContext);

    return glContext;
}

- (void)drawInCGLContext:(CGLContextObj)glContext
             pixelFormat:(CGLPixelFormatObj)pixelFormat
            forLayerTime:(CFTimeInterval)timeInterval
             displayTime:(const CVTimeStamp *)timeStamp
{
    CGLLockContext(glContext);
    CGLSetCurrentContext(glContext);

    CVOpenGLTextureRef texture;

    if (self.pixelBuffer &&
        !CVOpenGLTextureCacheCreateTextureFromImage(NULL,
                                                    _textureCache,
                                                    self.pixelBuffer,
                                                    NULL,
                                                    &texture)
    ) {
        GLenum target = CVOpenGLTextureGetTarget(texture);

        glEnable(target);
        glBindTexture(target, CVOpenGLTextureGetName(texture));
        glBegin(GL_QUADS);

        GLfloat width = CVPixelBufferGetWidth(self.pixelBuffer);
        GLfloat height = CVPixelBufferGetHeight(self.pixelBuffer);

        glTexCoord2f(    0,      0);    glVertex2f(-1,  1);
        glTexCoord2f(    0, height);    glVertex2f(-1, -1);
        glTexCoord2f(width, height);    glVertex2f( 1, -1);
        glTexCoord2f(width,      0);    glVertex2f( 1,  1);

        glEnd();
        glDisable(target);

        CVOpenGLTextureRelease(texture);
    } else {
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    [super drawInCGLContext:glContext
                pixelFormat:pixelFormat
               forLayerTime:timeInterval
                displayTime:timeStamp];

    CGLUnlockContext(glContext);
}

-(void)releaseCGLContext:(CGLContextObj)glContext
{
    if (_textureCache) {
        CVOpenGLTextureCacheRelease(_textureCache);
        _textureCache = NULL;
    }
    [super releaseCGLContext:glContext];
}

@end
