# MPlayerShell

MPlayerShell is an improved visual experience for MPlayer on OS X.

## About

Hi, I'm Don Melton. I wrote MPlayerShell because I was unhappy with the visual experience built into MPlayer on OS X, specifically playing video via the [`mplayer`](http://mplayerhq.hu/) and [`mplayer2`](http://www.mplayer2.org/) command line utilities.

I love the flexibility and power of MPlayer, but here are some of the problems I was having:

* Video playback halted during mouse down through the menubar
* White "turds" at the bottom corners of the window and full-screen views (`mplayer` only)
* Incorrect handling of application activation policy on exit (e.g. menubar not being updated)
* Clumsy window sizing not constrained to the video display aspect ratio (`mplayer` only)
* Clumsy window zooming not centered horizontally when invoked the first time
* Inconsistent menu commands (e.g. "Double Size" which only fits the window to the screen)
* Menubar inaccessible within full-screen mode (`mplayer2` only)

MPlayerShell fixes all of these and other problems by launching MPlayer as a background process, capturing its output, and presenting a whole new application user interface. Its command line interface is essentially identical to MPlayer.

MPlayerShell also adds explicit menu commands for full-screen and float-on-top modes. Those new menu commands, as well as those for window sizing, are more consistent in appearance and behavior with the standard QuickTime Player application than with MPlayer.

However, full-screen mode in MPlayerShell doesn't use the animated transition behavior introduced in OS X Lion. It's "instant on" and similar to the mode built into MPlayer itself.

When MPlayerShell launches MPlayer, it's configured to use a larger cache and leverage multiple processor cores for more threads. This significantly improves performance for Blu-ray Disc-sized video. But even this sensible extra configuration can always be overridden at the command line.

MPlayerShell is not particularly innovative. It's a small, derivative work meant to scratch my own OCD-driven itch. My hope in publishing MPlayerShell is that 1) it's useful to someone else and 2) both MPlayer development teams incorporate what I've done here into their projects and make mine completely obsolete and unnecessary.

I also wrote MPlayerShell to relearn Objective-C and Cocoa programming. It's been awhile and I was a little rusty. Since my current plan is to create a real media player application, writing MPlayerShell was great practice to get ready for that project.

## Installation

Until someone provides a [Homebrew](http://brew.sh/) formula or distributes binaries themselves, MPlayerShell must be built from the Open Source project code here.

MPlayerShell is written in Objective-C as an [Xcode](http://developer.apple.com/tools/xcode/) project. You can build it from the command line like this:

    git clone https://github.com/donmelton/MPlayerShell.git
    cd MPlayerShell
    xcodebuild

The MPlayerShell executable, `mps`, should then be available at:

    build/Release/mps

And it's manual page at:

    Source/mps.1

You can then then copy those files to wherever your want.

Or, you can install them into `/usr/local/bin` and `/usr/share/man/man1/` like this:

    xcodebuild install

## Usage

    mps [ mplayer arguments ]...

    MPS_MPLAYER=/path/to/mplayer mps [ mplayer arguments ]...

MPlayerShell takes almost all the same options as MPlayer, but there are a few important exceptions:

* Reading from `STDIN` via the `-` option isn't allowed because MPlayerShell launches MPlayer in "slave" mode and uses `STDIN` to send commands to MPlayer.
* Specifying a video output driver via the `-vo` option isn't allowed because MPlayerShell must use a specific driver with certain parameters to capture video from MPlayer.
* The `-idle` option is ignored since MPlayerShell is the process controlling MPlayer.
* The `-rootwin` option isn't implemented since it's not particularly useful in MPlayerShell.

MPlayerShell first examines the `MPS_MPLAYER` environment variable for the location of `mplayer`. This allows using `mplayer2` or other `mplayer` executables elsewhere in the file system. If the `MPS_MPLAYER` environment variable is undefined or empty, MPlayerShell searches the directories in the `PATH` environment variable for `mplayer`.

Of course, `MPS_MPLAYER` can be defined in `~/.bash_profile`, `~/.bashrc`, etc.

As long as MPlayerShell is the frontmost application, all the standard MPlayer keyboard shortcuts work even if only audio is playing.

## Requirements

OS X Lion (version 10.7) or later is required to run MPlayerShell.

Obviously, MPlayerShell also requires [`mplayer`](http://mplayerhq.hu/) or [`mplayer2`](http://www.mplayer2.org/). But not all versions are compatible with MPlayerShell. Custom builds embedded within MPlayerX.app and mplayer2.app should be avoided. I recommend installation via [Homebrew](http://brew.sh/).

The stable version of `mplayer` is available like this:

    brew install mplayer

Or, you can install the bleeding-edge version of `mplayer` this way:

    brew remove ffmpeg
    brew remove mplayer
    brew install --HEAD ffmeg
    brew install --HEAD mplayer

For `mplayer2`, installation instructions via Homebrew are available [here](https://github.com/pigoz/homebrew-mplayer2).

## Acknowledgements

Thanks to Matt Gallagher for his "[Minimalist Cocoa programming](http://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html)" blog post which got me thinking about doing this in the first place.

A big "thank you" to the developers of "[MPlayer OSX Extended](http://www.mplayerosx.ch/)" and "[MPlayerX](http://mplayerx.org/)" whose work gave me some key insights on how to handle the various APIs in MPlayer.

Of course, tremendous thanks to the MPlayer and mplayer2 development teams for creating such flexible and powerful software.

Finally, many thanks to former Apple colleague Ricci Adams of [musictheory.net](http://www.musictheory.net/) for taking me to school on modern Objective-C programming. What a stupid I am.

## License

MPlayerShell is copyright Don Melton and available under a [MIT license](https://github.com/donmelton/MPlayerShell/blob/master/LICENSE).
