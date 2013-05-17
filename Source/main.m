//
//  main.m
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import "AppController.h"

int main()
{
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_7) {
        NSLog(@"OS X Lion (version 10.7) or later required");
        exit(EXIT_FAILURE);
    }
    @autoreleasepool {
        [[AppController new] run];
    }
    return 0;
}
