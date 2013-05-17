//
//  AppController.h
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import <Cocoa/Cocoa.h>
#import "PresentationController.h"

@interface AppController : NSObject <PresentationControllerDelegate, NSApplicationDelegate>

- (void)run;

@end
