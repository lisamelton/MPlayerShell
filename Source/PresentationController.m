//
//  PresentationController.m
//  MPlayerShell
//
//  Copyright (c) 2013 Don Melton
//

#import <Carbon/Carbon.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "PresentationController.h"

enum {
    kDisplayMinWidth = 160,
    kDisplayMinHeight = 90,
};

static NSString *fullScreenMenuItemTitle(BOOL inMode)
{
    return [NSString stringWithFormat:@"%@ Full Screen", (inMode ? @"Exit" : @"Enter")];
}

#pragma mark -

@interface PresentationController ()

- (void)setupMenus;
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
- (void)about;
- (void)toggleFullScreenView:(id)sender;
- (void)toggleFloatOnTopView:(id)sender;
- (void)viewHalfSize;
- (void)viewActualSize;
- (void)viewDoubleSize;
- (void)viewFitToScreen;
- (NSEvent *)handleEvent:(NSEvent *)theEvent;
- (void)hideCursor;
- (void)setFullScreenMode:(BOOL)flag;
- (void)setFloatOnTopMode:(BOOL)flag;
- (void)adjustWindowToSize:(NSSize)aSize
                    center:(BOOL)centerFlag
                   animate:(BOOL)animateFlag;
- (NSRect)optimalFrameRectForContentSize:(NSSize)aSize
                                  center:(BOOL)centerFlag;
- (BOOL)isFrameVisbleForContentSize:(NSSize)aSize;

@end

#pragma mark -

@implementation PresentationController {
    __weak id <PresentationControllerDelegate> _delegate;
    NSString *_appName;
    BOOL _inFullScreenMode;
    BOOL _inFloatOnTopMode;
    NSWindow *_mediaWindow;
    NSMenuItem *_fullScreenMenuItem;
    NSMenuItem *_floatOnTopMenuItem;
    NSSize _displaySize;
    NSSize _contentSize;
    IOPMAssertionID _assertionID;
    NSTimer *_cursorTimer;
}

- (id)initWithDelegate:(id <PresentationControllerDelegate>)aDelegate
               appName:(NSString *)aString
        fullScreenMode:(BOOL)fullScreenFlag
        floatOnTopMode:(BOOL)floatOnTopFlag
{
    if (!(self = [super init])) {
        return nil;
    }
    _delegate = aDelegate;
    _appName = aString;
    _inFullScreenMode = fullScreenFlag;
    _inFloatOnTopMode = floatOnTopFlag;

    NSSize screenSize = [[NSScreen mainScreen] frame].size;
    NSRect contentRect = NSMakeRect(
        0,
        0,
        screenSize.width,
        screenSize.height
    );

    _mediaView = [[MediaView alloc] initWithFrame:contentRect];

    _mediaWindow = [[NSWindow alloc] initWithContentRect:contentRect
                                               styleMask:NSTitledWindowMask |
                                                         NSClosableWindowMask |
                                                         NSMiniaturizableWindowMask |
                                                         NSResizableWindowMask
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];

    [_mediaWindow setDelegate: self];
    [_mediaWindow setContentMinSize:NSMakeSize(
        kDisplayMinWidth,
        kDisplayMinHeight
    )];
    [_mediaWindow setContentView:_mediaView];
    [_mediaWindow setTitle: _appName];

    [self setupMenus];

    // Install a local monitor because there's not always a visible media
    // window to handle events if the user plays only audio.
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSMouseMovedMask | NSKeyDownMask)
                                          handler:^(NSEvent *theEvent) {
        return [self handleEvent:theEvent];
    }];

    return self;
}

- (void)setupMenus
{
    // Because nib files are for sissies (and real application bundles).
    NSMenu *menubar = [NSMenu new];

    // App menu

    NSMenuItem *menuItem = [NSMenuItem new];
    [menubar addItem:menuItem];

    NSMenu *menu = [NSMenu new];
    [menuItem setSubmenu:menu];

    menuItem = [[NSMenuItem alloc] initWithTitle:[@"About " stringByAppendingString:_appName]
                                          action:@selector(about)
                                   keyEquivalent:@""];
    [menuItem setTarget:self];
    [menu addItem:menuItem];

    [menu addItem:[NSMenuItem separatorItem]];

    menuItem = [[NSMenuItem alloc] initWithTitle:[@"Hide " stringByAppendingString:_appName]
                                          action:@selector(hide:)
                                   keyEquivalent:@"h"];
    [menu addItem:menuItem];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                          action:@selector(hideOtherApplications:)
                                   keyEquivalent:@"h"];
    [menuItem setKeyEquivalentModifierMask:(NSAlternateKeyMask | NSCommandKeyMask)];
    [menu addItem:menuItem];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Show All"
                                          action:@selector(unhideAllApplications:)
                                   keyEquivalent:@""];
    [menu addItem:menuItem];

    [menu addItem:[NSMenuItem separatorItem]];

    menuItem = [[NSMenuItem alloc] initWithTitle:[@"Quit " stringByAppendingString:_appName]
                                          action:@selector(terminate:)
                                   keyEquivalent:@"q"];
    [menu addItem:menuItem];

    // View menu

    menuItem = [NSMenuItem new];
    [menubar addItem:menuItem];

    menu = [[NSMenu alloc] initWithTitle:@"View"];
    [menuItem setSubmenu:menu];

    // Start with the title blank since `validateMenuItem` will change it soon
    // anyway.
    menuItem = [[NSMenuItem alloc] initWithTitle:@""
                                          action:@selector(toggleFullScreenView:)
                                   keyEquivalent:@"f"];
    [menuItem setTarget:self];
    [menuItem setKeyEquivalentModifierMask:(NSControlKeyMask | NSCommandKeyMask)];
    [menu addItem:menuItem];
    _fullScreenMenuItem = menuItem;

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Float on Top"
                                          action:@selector(toggleFloatOnTopView:)
                                   keyEquivalent:@""];
    [menuItem setTarget:self];
    [menu addItem:menuItem];
    _floatOnTopMenuItem = menuItem;

    [menu addItem:[NSMenuItem separatorItem]];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Half Size"
                                          action:@selector(viewHalfSize)
                                   keyEquivalent:@"0"];
    [menuItem setTarget:self];
    [menu addItem:menuItem];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Actual Size"
                                          action:@selector(viewActualSize)
                                   keyEquivalent:@"1"];
    [menuItem setTarget:self];
    [menu addItem:menuItem];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Double Size"
                                          action:@selector(viewDoubleSize)
                                   keyEquivalent:@"2"];
    [menuItem setTarget:self];
    [menu addItem:menuItem];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Fit to Screen"
                                          action:@selector(viewFitToScreen)
                                   keyEquivalent:@"3"];
    [menuItem setTarget:self];
    [menu addItem:menuItem];

    // Window menu

    menuItem = [NSMenuItem new];
    [menubar addItem:menuItem];

    menu = [[NSMenu alloc] initWithTitle:@"Window"];
    [menuItem setSubmenu:menu];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Minimize"
                                          action:@selector(performMiniaturize:)
                                   keyEquivalent:@"m"];
    [menu addItem:menuItem];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom"
                                          action:@selector(performZoom:)
                                   keyEquivalent:@""];
    [menu addItem:menuItem];

    [menu addItem:[NSMenuItem separatorItem]];

    menuItem = [[NSMenuItem alloc] initWithTitle:@"Bring All to Front"
                                          action:@selector(arrangeInFront:)
                                   keyEquivalent:@""];
    [menu addItem:menuItem];

    // Let NSApp handle the "Windows" menu.
    [NSApp setWindowsMenu: menu];

    [NSApp setMainMenu:menubar];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    // "About" is always a valid command.
    if (action == @selector(about)) {
        return YES;
    }
    // All other menu items validated here require the media window be visible.
    BOOL visible = [_mediaWindow isVisible];

    if (action == @selector(toggleFullScreenView:)) {
        [menuItem setTitle:fullScreenMenuItemTitle(_inFullScreenMode && visible)];

    } else if (action == @selector(toggleFloatOnTopView:)) {
        [menuItem setState:((_inFloatOnTopMode && visible) ? NSOnState : NSOffState)];

    // Only validate viewing in half, actual and double sizes if the media
    // window at those sizes would still fit on the screen.
    } else if (action == @selector(viewHalfSize)) {
        return visible && !_inFullScreenMode && [self isFrameVisbleForContentSize:NSMakeSize(
            _displaySize.width / 2,
            _displaySize.height / 2
        )];

    } else if (action == @selector(viewActualSize)) {
        return visible && !_inFullScreenMode && [self isFrameVisbleForContentSize:_displaySize];

    } else if (action == @selector(viewDoubleSize)) {
        return visible && !_inFullScreenMode && [self isFrameVisbleForContentSize:NSMakeSize(
            _displaySize.width * 2,
            _displaySize.height * 2
        )];

    } else if (action == @selector(viewFitToScreen)) {
        return visible && !_inFullScreenMode;
    }
    return visible;
}

- (void)about
{
    // Exit full-screen and float-on-top modes for the "About" command because
    // both require the media window to float above all others, obscuring the
    // "About" window.
    if ([_mediaWindow isVisible]) {

        if (_inFullScreenMode) {
            [self toggleFullScreenView:_fullScreenMenuItem];
        }
        if (_inFloatOnTopMode) {
            [self toggleFloatOnTopView:_floatOnTopMenuItem];
        }
    }
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        @"ApplicationName" : _appName,
        @"Copyright" : @"Copyright (c) 2013 Don Melton",
        @"ApplicationVersion" : @"0.9.2",
    }];
}

- (void)toggleFullScreenView:(id)sender
{
    if (![_mediaWindow isVisible]) {
        _inFullScreenMode = !_inFullScreenMode;
        return;
    }
    [self setFullScreenMode:!_inFullScreenMode];
    [sender setTitle:fullScreenMenuItemTitle(_inFullScreenMode)];
}

- (void)toggleFloatOnTopView:(id)sender
{
    if (![_mediaWindow isVisible]) {
        _inFloatOnTopMode = !_inFloatOnTopMode;
        return;
    }
    [self setFloatOnTopMode:!_inFloatOnTopMode];
    [sender setState:(_inFloatOnTopMode ? NSOnState : NSOffState)];
}

- (void)viewHalfSize
{
    [self adjustWindowToSize:NSMakeSize(
                                 _displaySize.width / 2,
                                 _displaySize.height / 2
                             )
                      center:NO
                     animate:YES];
}

- (void)viewActualSize
{
    [self adjustWindowToSize:_displaySize
                      center:NO
                     animate:YES];
}

- (void)viewDoubleSize
{
    [self adjustWindowToSize:NSMakeSize(
                                 _displaySize.width * 2,
                                 _displaySize.height * 2
                             )
                      center:NO
                     animate:YES];
}

- (void)viewFitToScreen
{
    [self adjustWindowToSize:[[NSScreen mainScreen] frame].size
                      center:YES
                     animate:YES];
}

- (NSEvent *)handleEvent:(NSEvent *)theEvent
{
    if ([theEvent type] == NSMouseMoved) {

        // Show the cursor if in full-screen mode and then set a timer to hide
        // it again in 5 seconds.
        if (_inFullScreenMode) {
            CGDisplayShowCursor(kCGDirectMainDisplay);
            [_cursorTimer invalidate];
            _cursorTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                            target:self
                                                          selector:@selector(hideCursor)
                                                          userInfo:nil
                                                           repeats:NO];
        }
        // Always pass on mouse moved events.
        return theEvent;
    }
    NSString *characters = [theEvent charactersIgnoringModifiers];
    NSWindow *keyWindow = [NSApp keyWindow];

    if ([theEvent modifierFlags] & NSCommandKeyMask) {

        // Handle command-w key down equivalent here rather than creating a
        // "File" menu with a single "Close" item.
        if ([characters isEqualToString:@"w"]) {
            [keyWindow performClose:nil];
            return nil;
        }
        // Ignore remaining command key down events.
        return theEvent;
    }
    // Ignore remaining key down events if a non-media window is key, and
    // full-screen or float-on-top modes are not active.
    if (keyWindow && (keyWindow != _mediaWindow) && !(_inFullScreenMode || _inFloatOnTopMode)) {
        return theEvent;
    }
    unsigned short keyCode = [theEvent keyCode];

    // Handle "quit" and "stop" commands here to ensure quitting the
    // application uses a control flow consistent with selecting the
    // equivalent menu command.
    if ([characters isEqualToString:@"q"] || (keyCode == kVK_Escape) || [characters isEqualToString:@"U"]) {
        [NSApp terminate:nil];
        return nil;
    }
    // Handle "vo_fullscreen" and "vo_ontop" commands here to bypass sending
    // them to `mplayer` which would just send them back via the
    // `toggleFullscreen` or `ontop` selectors in the `VideoRenderer` class.
    if ([characters isEqualToString:@"f"]) {
        [self toggleFullScreenView:_fullScreenMenuItem];
        return nil;
    }
    if ([characters isEqualToString:@"T"]) {
        [self toggleFloatOnTopView:_floatOnTopMenuItem];
        return nil;
    }
    // Handle "@" input here to avoid a key value coding-compliant error when
    // the `characters` string is passed to `valueForKey:` later.
    if ([characters isEqualToString:@"@"]) {
        [_delegate sendCommand:@"seek_chapter 1"];
        return nil;
    }
    NSString *command;

    // Handle the remaining keyboard commands for `mplayer`. Even though a
    // particular command might not function in one `mplayer` implementation,
    // it could in another.
    switch (keyCode) {
    case kVK_ANSI_Keypad8:      command = @"dvdnav up";                     break;
    case kVK_ANSI_Keypad2:      command = @"dvdnav down";                   break;
    case kVK_ANSI_Keypad4:      command = @"dvdnav left";                   break;
    case kVK_ANSI_Keypad6:      command = @"dvdnav right";                  break;
    case kVK_ANSI_Keypad5:      command = @"dvdnav menu";                   break;
    case kVK_ANSI_KeypadEnter:  command = @"dvdnav select";                 break;
    case kVK_ANSI_Keypad7:      command = @"dvdnav prev";                   break;
    case kVK_RightArrow:        command = @"seek 10";                       break; // 10 seconds forward
    case kVK_LeftArrow:         command = @"seek -10";                      break; // 10 seconds backward
    case kVK_UpArrow:           command = @"seek 60";                       break; // 1 minute forward
    case kVK_DownArrow:         command = @"seek -60";                      break; // 1 minute backward
    case kVK_PageUp:            command = @"seek 600";                      break; // 10 minutes forward
    case kVK_PageDown:          command = @"seek -600";                     break; // 10 minutes backward
    case kVK_Delete:            command = @"speed_set 1.0";                 break;
//     case kVK_Escape:            command = @"quit";                          break;
    case kVK_Home:              command = @"pt_up_step 1";                  break;
    case kVK_End:               command = @"pt_up_step -1";                 break;
    case kVK_Return:            command = @"pt_step 1 1";                   break;
    case kVK_F13:               command = @"alt_src_step 1";                break; // Best equivalent for insert key?
    case kVK_ForwardDelete:     command = @"alt_src_step -1";               break;
    case kVK_Tab:               command = @"step_property switch_program";  break;
    default:
        command = [@{
            @"+" : @"audio_delay 0.100",
            @"-" : @"audio_delay -0.100",
            @"[" : @"speed_mult 0.9091",
            @"]" : @"speed_mult 1.1",
            @"{" : @"speed_mult 0.5",
            @"}" : @"speed_mult 2.0",
//             @"q" : @"quit",
            @"p" : @"pause",
            @" " : @"pause",
            @"." : @"frame_step",
            @">" : @"pt_step 1",
            @"<" : @"pt_step -1",
            @"o" : @"osd",
            @"I" : @"osd_show_property_text \"${filename}\"",
            @"P" : @"osd_show_progression",
            @"z" : @"sub_delay -0.1",
            @"x" : @"sub_delay +0.1",
            @"g" : @"sub_step -1",
            @"y" : @"sub_step +1",
            @"9" : @"volume -1",
            @"/" : @"volume -1",
            @"0" : @"volume 1",
            @"*" : @"volume 1",
            @"(" : @"balance -0.1",
            @")" : @"balance 0.1",
            @"m" : @"mute",
            @"1" : @"contrast -1",
            @"2" : @"contrast 1",
            @"3" : @"brightness -1",
            @"4" : @"brightness 1",
            @"5" : @"hue -1",
            @"6" : @"hue 1",
            @"7" : @"saturation -1",
            @"8" : @"saturation 1",
            @"d" : @"frame_drop",
            @"D" : @"step_property deinterlace",
            @"r" : @"sub_pos -1",
            @"t" : @"sub_pos +1",
            @"a" : @"sub_alignment",
            @"v" : @"sub_visibility",
            @"j" : @"sub_select",
            @"J" : @"sub_select -3",
            @"F" : @"forced_subs_only",
            @"#" : @"switch_audio",
            @"_" : @"step_property switch_video",
            @"i" : @"edl_mark",
            @"h" : @"tv_step_channel 1",
            @"k" : @"tv_step_channel -1",
            @"n" : @"tv_step_norm",
            @"u" : @"tv_step_chanlist",
            @"X" : @"step_property teletext_mode 1",
            @"W" : @"step_property teletext_page 1",
            @"Q" : @"step_property teletext_page -1",
//             @"T" : @"vo_ontop",
//             @"f" : @"vo_fullscreen",
            @"c" : @"capturing",
            @"s" : @"screenshot 0",
            @"S" : @"screenshot 1",
            @"w" : @"panscan -0.1",
            @"e" : @"panscan +0.1",
            @"!" : @"seek_chapter -1",
//             @"@" : @"seek_chapter 1",
            @"A" : @"switch_angle 1",
//             @"U" : @"stop",
        } valueForKey:characters];
    }
    if (command) {
        [_delegate sendCommand:command];
        return nil;
    }
    return theEvent;
}

- (void)hideCursor
{
    if (_inFullScreenMode) {
        CGDisplayHideCursor(kCGDirectMainDisplay);
    }
    _cursorTimer = nil;
}

- (void)setFullScreenMode:(BOOL)flag
{
    BOOL wasInFullScreenMode = self.mediaView.isInFullScreenMode;

    if (flag) {

        if (!wasInFullScreenMode) {
            _contentSize = [self.mediaView frame].size;

            [_mediaWindow setLevel:kCGNormalWindowLevel];

            [self.mediaView enterFullScreenMode:[NSScreen mainScreen]
                                    withOptions:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithInt:NSFloatingWindowLevel],
                                                     NSFullScreenModeWindowLevel,
                                                     [NSNumber numberWithUnsignedInt:
                                                         (NSApplicationPresentationHideDock |
                                                          NSApplicationPresentationAutoHideMenuBar)],
                                                     NSFullScreenModeApplicationPresentationOptions,
                                                     nil]
            ];

            CGDisplayHideCursor(kCGDirectMainDisplay);
        }
    } else {

        if (wasInFullScreenMode) {
            [self.mediaView exitFullScreenModeWithOptions:nil];

            // The window level is reset to a normal level when exiting
            // full-screen mode. Restore it to floating level if still in
            // float-on-top mode. Both modes use the same window level and are
            // not mutually exclusive.
            if (_inFloatOnTopMode) {
                [_mediaWindow setLevel:kCGFloatingWindowLevel];
            }
            CGDisplayShowCursor(kCGDirectMainDisplay);
        }
    }
    // Set the full-screen mode flag based on the view state and not the flag
    // that was passed into this method.
    _inFullScreenMode = self.mediaView.isInFullScreenMode;

    // If previously in full-screen mode, it's possible the media window size
    // changed when opening a different video in the playlist. Call
    // `adjustWindowToSize:` again using the value of `_contentSize`, which
    // was calculated the last time that method was invoked.
    if (wasInFullScreenMode && !_inFullScreenMode) {
        [self adjustWindowToSize:_contentSize
                          center:NO
                         animate:NO];
    }
}

- (void)setFloatOnTopMode:(BOOL)flag
{
    if (flag) {

        if (!_inFullScreenMode) {
            [_mediaWindow setLevel:kCGFloatingWindowLevel];
        }
    } else {
        [_mediaWindow setLevel:kCGNormalWindowLevel];
    }
    _inFloatOnTopMode = flag;
}

- (void)adjustWindowToSize:(NSSize)aSize
                    center:(BOOL)centerFlag
                   animate:(BOOL)animateFlag
{
    // Start with the optimal size for the media window on screen.
    NSRect frameRect = [self optimalFrameRectForContentSize:aSize
                                                     center:centerFlag];
    BOOL visible = [_mediaWindow isVisible];

    if (visible) {
        // Save the content size now in case of early return when in
        // full-screen mode.
        _contentSize = [_mediaWindow contentRectForFrameRect:frameRect].size;

        if (_inFullScreenMode) {
            // Force the video view to recalculate its size. Otherwise the
            // display aspect ratio of the video may be wrong when in
            // full-screen mode.
            [self.mediaView setFrameSize:[self.mediaView frame].size];

            return;
        }
        if (!centerFlag)
        {
            // If the window is not already centered on screen, attempt to
            // center it over it's previous position instead.
            // 
            // However, if the window was previously the full height of the
            // visible screen, center its content over that screen instead.
            // This prevents a newly smaller window from being centered
            // slightly lower than the middle of the screen due to the menubar.
            NSScreen *screen = [NSScreen mainScreen];
            NSRect screenRect = [screen frame];
            NSRect visibleRect = [screen visibleFrame];
            NSRect oldRect = [_mediaWindow frame];

            frameRect.origin.x = oldRect.origin.x + ((oldRect.size.width - frameRect.size.width) / 2);

            if ((oldRect.origin.y == visibleRect.origin.y) &&
                (oldRect.size.height == visibleRect.size.height) &&
                (frameRect.size.height < visibleRect.size.height)) {
                frameRect.origin.y = screenRect.origin.y + ((screenRect.size.height - _contentSize.height) / 2);
            } else {
                frameRect.origin.y = oldRect.origin.y + ((oldRect.size.height - frameRect.size.height) / 2);
            }
            // Call `constrainFrameRect:` again in case the window was just
            // moved offscreen or tucked under the menubar.
            frameRect = [_mediaWindow constrainFrameRect:frameRect toScreen:screen];
        }
    }
    // Reshape and reposition the window, animating between the old and the
    // new as necessary.
    [_mediaWindow setFrame:frameRect
                   display:visible
                   animate:(visible && animateFlag)];

    // Save the real content size for use later when switching out of
    // full-screen mode.
    _contentSize = [self.mediaView frame].size;
}

- (NSRect)optimalFrameRectForContentSize:(NSSize)aSize
                                  center:(BOOL)centerFlag
{
    // Constrain width and height to a minimum size.
    NSSize adjustedSize = NSMakeSize(
        aSize.width > kDisplayMinWidth ? aSize.width : kDisplayMinWidth,
        aSize.height > kDisplayMinHeight ? aSize.height : kDisplayMinHeight
    );
    NSScreen *screen = [NSScreen mainScreen];
    NSRect screenRect = [screen frame];
    // Constrain width and height to the screen size, otherwise the call to
    // `constrainFrameRect:` below may not behave as desired for display
    // aspect ratios shorter than the screen.
    adjustedSize = NSMakeSize(
        adjustedSize.width < screenRect.size.width ? adjustedSize.width : screenRect.size.width,
        adjustedSize.height < screenRect.size.height ? adjustedSize.height : screenRect.size.height
    );
    NSRect frameRect = [_mediaWindow frameRectForContentRect:NSMakeRect(
        0,
        0,
        adjustedSize.width,
        adjustedSize.height
    )];
    // Use AppKit to constrain the window frame to the visible area of the
    // screen and, if necessary, reshape the window to the correct aspect
    // ratio which was previously set in `startRenderingWithDisplaySize:`
    // below.
    frameRect = [_mediaWindow constrainFrameRect:frameRect
                                        toScreen:screen];

    if (centerFlag) {
        // Don't rely on `constrainFrameRect:` to center the window since its
        // positioning behavior is a bit capricious.
        NSRect visibleRect = [screen visibleFrame];
        NSRect contentRect = [_mediaWindow contentRectForFrameRect:frameRect];

        if (frameRect.size.width < visibleRect.size.width) {
            frameRect.origin.x = (frameRect.origin.x - contentRect.origin.x) +
                screenRect.origin.x + ((screenRect.size.width - contentRect.size.width) / 2);
        }
        if (frameRect.size.height < visibleRect.size.height) {
            frameRect.origin.y = (frameRect.origin.y - contentRect.origin.y) +
                screenRect.origin.y + ((screenRect.size.height - contentRect.size.height) / 2);
        }
    }
    return frameRect;
}

- (BOOL)isFrameVisbleForContentSize:(NSSize)aSize
{
    NSSize frameSize = [_mediaWindow frameRectForContentRect:NSMakeRect(
        0,
        0,
        aSize.width,
        aSize.height
    )].size;
    NSSize visibleSize = [[NSScreen mainScreen] visibleFrame].size;
    
    return (frameSize.width <= visibleSize.width) && (frameSize.height <= visibleSize.height);
}

#pragma mark -
#pragma mark VideoRendererDelegate

- (void)startRenderingWithDisplaySize:(NSSize)aSize
{
    _displaySize = aSize;

    // Inform the media view of the true display size in case the window or
    // full-screen view is a different shape.
    self.mediaView.displaySize = _displaySize;

    // Constrain window sizing to the display shape. The also makes sure any
    // later calls to `constrainFrameRect:` do the right thing.
    [_mediaWindow setContentAspectRatio:_displaySize];

    // Center the window on screen if it's not yet visible, otherwise try to
    // center it over its previous position.
    [self adjustWindowToSize:_displaySize
                      center:YES
                     animate:YES];

    [self setFullScreenMode:_inFullScreenMode];
    [self setFloatOnTopMode:_inFloatOnTopMode];

    // Bring the window forward and make it visible (if not so already).
    [_mediaWindow makeKeyAndOrderFront:nil];

    if (!_assertionID &&
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep,
            kIOPMAssertionLevelOn,
            CFSTR("Playing video"),
            &_assertionID)
    ) {
        _assertionID = 0;
    }
}

- (void)stopRendering
{
    if (_assertionID) {
        IOPMAssertionRelease(_assertionID);
        _assertionID = 0;
    }
    // Force the video layer to erase the last frame.
    [self.mediaView.videoLayer setNeedsDisplay];
}

#pragma mark -
#pragma mark NSWindowDelegate

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
    // The default zoomed window frame is often off-center, so return the same
    // window frame here used for the "Fit to Screen" command.
    return [self optimalFrameRectForContentSize:[[NSScreen mainScreen] frame].size
                                         center:YES];
}

- (void)windowWillClose:(NSNotification *)notification
{
    // Closing the media window will quit this application.
    [NSApp terminate:nil];
}

@end
