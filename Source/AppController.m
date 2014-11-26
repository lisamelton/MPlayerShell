//
//  AppController.m
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import "AppController.h"

static NSString * const kAppName = @"MPlayerShell";

@interface AppController ()

- (void)determineLaunchPath;
- (void)determineArguments;
- (void)determineVideoOutputDriver;
- (void)startTask;
- (void)didTerminateTask;

@end

#pragma mark -

@implementation AppController {
    NSString *_launchPath;
    NSArray *_arguments;
    NSString *_videoOutputDriver;
    NSString *_sharedBufferName;
    NSTask *_mplayerTask;
}

- (id)init
{
    if (!(self = [super init])) {
        return nil;
    }
    [self determineLaunchPath];
    [self determineArguments];
    [self determineVideoOutputDriver];

    // mplayer` will write video frames into a named shared buffer. Use the
    // process ID to make the buffer name unique.
    _sharedBufferName = [NSString stringWithFormat:
        @"%@_%d", kAppName, [[NSProcessInfo processInfo] processIdentifier]
    ];

    return self;
}

- (void)determineLaunchPath
{
    // The location of `mplayer` is required to launch it. That can't be
    // specified via normal command line arguments since options for this
    // program should be identical to `mplayer` for proper emulation.
    // 
    // Instead, allow the location to be passed via the `MPS_MPLAYER`
    // environment variable.
    // 
    // If no location is specified, look for `mplayer` in the `PATH`
    // environment variable by invoking the shell with a `which mplayer`
    // command and parsing its output.
    _launchPath = [[[NSProcessInfo processInfo] environment] valueForKey:@"MPS_MPLAYER"];

    if (_launchPath) {
        return;
    }
    NSTask *task = [NSTask new];

    [task setStandardInput:[NSPipe pipe]];
    [task setStandardOutput:[NSPipe pipe]];
    [task setStandardError:[NSPipe pipe]];

    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[@"-c", @"which mplayer"]];

    [task launch];
    [task waitUntilExit];

    if ([task terminationStatus]) {
        NSLog(@"Can't locate mplayer");
        exit(EXIT_FAILURE);
    }
    NSData *data = [[[task standardOutput] fileHandleForReading] availableData];
    NSUInteger length = [data length];

    if (length <= 1) {
        NSLog(@"Empty path to mplayer");
        exit(EXIT_FAILURE);
    }
    _launchPath = [[NSString alloc] initWithBytes:[data bytes]
                                           length:(length - 1)
                                         encoding:NSUTF8StringEncoding];
}

- (void)determineArguments
{
    // Some `mplayer` options are not compatible with this program. Ignore
    // idle mode, but fail if the user expects to read from stdin or specifies
    // a video output driver.
    _arguments = [[NSProcessInfo processInfo] arguments];
    _arguments = [_arguments subarrayWithRange:NSMakeRange(1, [_arguments count] - 1)];
    _arguments = [_arguments filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"(SELF != %@) AND (SELF != %@)", @"-idle", @"--idle"]
    ];

    if ([_arguments containsObject:@"-"]) {
        NSLog(@"Reading from stdin not allowed");
        exit(EXIT_FAILURE);
    }
    if ([_arguments containsObject:@"-vo"] || [_arguments containsObject:@"--vo"]) {
        NSLog(@"Video output driver option (-vo) not allowed");
        exit(EXIT_FAILURE);
    }
}

- (void)determineVideoOutputDriver
{
    // `mplayer` and `mplayer2` use different video output drivers to write to
    // the shared buffer. Parse the output of a "help" command here to
    // determine that driver.
    NSTask *task = [NSTask new];

    [task setStandardInput:[NSPipe pipe]];
    [task setStandardOutput:[NSPipe pipe]];
    [task setStandardError:[NSPipe pipe]];

    [task setLaunchPath:_launchPath];
    [task setArguments:@[@"-vo", @"help"]];

    [task launch];
    [task waitUntilExit];

    NSData *data = [[[task standardOutput] fileHandleForReading] availableData];

    if ([[[NSString alloc] initWithBytesNoCopy:(void *)[data bytes]
                                        length:[data length]
             encoding:NSUTF8StringEncoding
         freeWhenDone:NO]
        rangeOfString:@"\tsharedbuffer\t"
              options:NSLiteralSearch
    ].length) {
        _videoOutputDriver = @"sharedbuffer";
    } else {
        _videoOutputDriver = @"corevideo:shared_buffer";
    }
}

- (void)run
{
    [[NSApplication sharedApplication] setDelegate:self];

    // The `PresentationController` class exists mostly to prevent this class
    // from being one huge source file. It also puts all user interface and
    // interaction in one place.
    PresentationController *presentationController =
        [[PresentationController alloc] initWithDelegate:self
                                                 appName:kAppName
                                          fullScreenMode:[_arguments containsObject:@"-fs"] ||
                                                         [_arguments containsObject:@"--fs"]
                                          floatOnTopMode:[_arguments containsObject:@"-ontop"] ||
                                                         [_arguments containsObject:@"--ontop"]];

    (void)[[VideoRenderer alloc] initWithDelegate:presentationController
                                 sharedBufferName:_sharedBufferName
                                       videoLayer:presentationController.mediaView.videoLayer];

    [self startTask];

    [NSApp run];

    // Program control flow should never return here. If it does, something
    // went horribly wrong.
    exit(EXIT_FAILURE);
}

- (void)startTask
{
    // Communication with `mplayer` requires a pipe to `stdin`, but `stdout`
    // and `stderr` are left connected to the defaults so console output
    // appears like `mplayer` was invoked directly.
    // 
    // Because `mplayer` is placed in slave mode and `stdin` is used to send
    // commands, it can no longer be controlled via the keyboard when the
    // console is the frontmost application. The `PresentationController`
    // class mimics all that behavior when this application is frontmost, even
    // when there's no visible video playback window.
    // 
    // In addition to enabling slave mode and specifying a video output driver
    // capable of writing frames to a named shared buffer, arguments are also
    // passed to set a larger cache size and leverage multiple processor cores
    // for more threads. This significantly improves `mplayer` performance for
    // Blu-ray Disc-sized video.
    // 
    // With the larger cache size, another argument is passed to set a minimun
    // fill percentage to improve performance for network streams by ensuring
    // playback starts sooner.
    // 
    // Custom arguments are passed first allowing override of the new cache
    // size and thread count. It's not possible to override slave mode or the
    // video output driver.
    _mplayerTask = [NSTask new];

    [_mplayerTask setStandardInput:[NSPipe pipe]];

    [_mplayerTask setLaunchPath:_launchPath];
    [_mplayerTask setArguments:[@[
        @"-slave",
        @"-vo", [NSString stringWithFormat:@"%@:buffer_name=%@", _videoOutputDriver, _sharedBufferName],
        @"-cache",  @"8192",
        @"-cache-min", @"1",
        @"-lavdopts", [NSString stringWithFormat:@"threads=%lu", [[NSProcessInfo processInfo] processorCount]]
    ] arrayByAddingObjectsFromArray:_arguments]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didTerminateTask)
                                                 name:NSTaskDidTerminateNotification
                                               object:_mplayerTask];

    [_mplayerTask launch];
}

- (void)didTerminateTask
{
    // Quit this application when `mplayer` completes playback or if it
    // terminates in any other way.
    [NSApp terminate:nil];
}

#pragma mark -
#pragma mark PresentationControllerDelegate

- (void)sendCommand:(NSString *)command
{
    // mplayer` writes video frames into the named shared buffer and calls
    // methods elsewhere in the `VideoRender` class via the `NSDistantObject`
    // mechanism. But communication with `mplayer` also requires sending it
    // textual commands terminated with a carriage return via `stdin`.
    [[[_mplayerTask standardInput] fileHandleForWriting] writeData:[[NSString stringWithFormat:@"%@\n", command]
                                                 dataUsingEncoding:NSUTF8StringEncoding]];
}

#pragma mark -
#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    // Because activation policy has just been set to behave like a real
    // application, that policy must be reset on exit to prevent, among other
    // things, the menubar created here from remaining on screen.
    atexit_b(^ {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    });

    [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // If this application was quit intentionally then send `mplayer` the same
    // command and wait for it to complete. There is the risk that `mplayer`
    // may hang here, but in practice this never happens. Waiting is required
    // for `mplayer` to exit cleanly and write its normal output to the
    // console.
    if ([_mplayerTask isRunning]) {
        [self sendCommand:@"quit"];
        [_mplayerTask waitUntilExit];
    }
    // Since this program is actually a command line tool and not a real Cocoa
    // application, exit here with the result returned from `mplayer`. This
    // means any remaining objects are not "properly" deallocated. But there
    // are no undesirable side effects from such a policy, and it's quite
    // practical and speedy because this process simply goes away.
    exit([_mplayerTask terminationStatus]);
}

@end
