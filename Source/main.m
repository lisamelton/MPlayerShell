//
//  main.m
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import "AppController.h"

int main()
{
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_6) {
        NSLog(@"Mac OS X Snow Leopard (version 10.6) or later required");
        exit(EXIT_FAILURE);
    }
    @autoreleasepool {
        [[AppController new] run];
    }
    return 0;
}
