//
//  MPlayerOSXVOProto.h
//  MPlayerShell
//
//  Copyright (c) 2013-2024 Lisa Melton
//

@protocol MPlayerOSXVOProto
- (int)startWithWidth:(bycopy int)width
           withHeight:(bycopy int)height
            withBytes:(bycopy int)bytes
           withAspect:(bycopy int)aspect;
- (void)stop;
- (void)render;
- (void)toggleFullscreen;
- (void)ontop;
@end
