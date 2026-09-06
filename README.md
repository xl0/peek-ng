# Peek - an animated GIF recorder
[![GitHub release](https://img.shields.io/github/release/xl0/peek-ng.svg)](https://github.com/xl0/peek-ng/releases)
[![License: GPL v3+](https://img.shields.io/badge/license-GPL%20v3%2B-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Packaging status](https://repology.org/badge/tiny-repos/peek.svg)](https://repology.org/metapackage/peek/packages)
[![Translation Status](https://hosted.weblate.org/widgets/peek/-/svg-badge.svg)](https://hosted.weblate.org/engage/peek/?utm_source=widget)

> [!IMPORTANT]
> This is a maintained fork of [phw/peek](https://github.com/phw/peek), which was
> [declared deprecated](https://github.com/phw/peek/issues/1191) in 2023. The fork
> restores MP4 recording and fixes long-standing bugs; see the
> [issue tracker](https://github.com/xl0/peek-ng/issues) for what has been addressed.

![Peek recording itself](https://raw.githubusercontent.com/phw/peek/master/data/screenshots/peek-recording-itself.gif)

Simple screen recorder with an easy to use interface

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Contents

- [About](#about)
- [Requirements](#requirements)
  - [Runtime](#runtime)
  - [Development](#development)
- [Installation](#installation)
  - [Packages](#packages)
  - [From source](#from-source)
- [Frequently Asked Questions](#frequently-asked-questions)
  - [How can I capture mouse clicks and/or keystrokes?](#how-can-i-capture-mouse-clicks-andor-keystrokes)
  - [How can I improve the quality of recorded GIF files](#how-can-i-improve-the-quality-of-recorded-gif-files)
  - [Why are the GIF files so big?](#why-are-the-gif-files-so-big)
  - [If GIF is so bad why use it at all?](#if-gif-is-so-bad-why-use-it-at-all)
  - [What about WebM or MP4? Those are well supported on the web.](#what-about-webm-or-mp4-those-are-well-supported-on-the-web)
  - [What is the cause for "Could not start GNOME Shell recorder" errors?](#what-is-the-cause-for-could-not-start-gnome-shell-recorder-errors)
  - [Why can't I interact with the UI elements inside the recording area?](#why-cant-i-interact-with-the-ui-elements-inside-the-recording-area)
  - [My recorded GIFs flicker, what is wrong?](#my-recorded-gifs-flicker-what-is-wrong)
  - [On i3 the recording area is all black, how can I record anything?](#on-i3-the-recording-area-is-all-black-how-can-i-record-anything)
  - [Why no native Wayland support?](#why-no-native-wayland-support)
- [Contribute](#contribute)
  - [Development](#development-1)
  - [Translations](#translations)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## About
Peek makes it easy to create short screencasts of a screen area. It was built
for the specific use case of recording screen areas, e.g. for easily showing UI
features of your own apps or for showing a bug in bug reports. With Peek, you
simply place the Peek window over the area you want to record and press
"Record". Peek is optimized for generating animated GIFs, but you can also
directly record to WebM or MP4 if you prefer.

Peek is not a general purpose screencast app with extended features but
rather focuses on the single task of creating small, silent screencasts of
an area of the screen for creating GIF animations or silent WebM videos.

Peek runs on X11 or inside a GNOME Shell Wayland session using XWayland.
On X11 sessions Peek records with FFmpeg. In a GNOME Wayland session it uses
the GNOME Shell screen recorder instead, since X11 screen grabbing only sees
XWayland windows there. The backend can be forced with `peek -b ffmpeg` or
`peek -b gnome-shell`.


## Requirements
### Runtime

- GTK+ >= 3.22
- GLib >= 2.52
- [libkeybinder3](https://github.com/kupferlauncher/keybinder)
- FFmpeg >= 3
- GStreamer 'Good' plugins (for recording in GNOME Wayland sessions)
- [gifski](https://gif.ski/) (optional but recommended for improved GIF quality)

### Development

- Vala compiler >= 0.22
- Meson >= 0.47.0
- Gettext (>= 0.19 for localized .desktop entry)
- txt2man (optional for building man page)


## Installation
### Packages
Every release on the [releases page](https://github.com/xl0/peek-ng/releases)
ships packages built by CI:

- `.deb` for Ubuntu 22.04 and 24.04 and for Debian 12 and 13
- `.rpm` for Fedora (needs `ffmpeg` from [RPM Fusion](https://rpmfusion.org/Configuration),
  or `ffmpeg-free` for GIF and WebM only)

Download the file for your distribution and install it with
`sudo apt install ./peek_*.deb` or `sudo dnf install ./peek-*.rpm`.

The `peek` package in the distributions' own repositories is upstream 1.5.1
from 2020. It still has the bugs this fork fixes, most visibly the endless
"Rendering…" on long recordings and the GNOME Shell recorder timeouts on
Ubuntu 22.04 and later.

### From source
Install the build dependencies:

    # Debian / Ubuntu
    sudo apt install meson ninja-build valac gettext libxml2-utils \
      libgtk-3-dev libkeybinder-3.0-dev ffmpeg

    # Fedora (ffmpeg needs RPM Fusion, see https://rpmfusion.org/Configuration)
    sudo dnf install meson vala gettext libxml2 gtk3-devel keybinder3-devel ffmpeg

    # Arch Linux
    sudo pacman -S meson vala gettext libxml2 gtk3 libkeybinder3 ffmpeg

Then build and install:

    git clone https://github.com/xl0/peek-ng.git
    cd peek-ng
    meson setup --prefix=/usr/local builddir
    ninja -C builddir

    # Run directly from the build directory
    ./builddir/src/peek

    # Or install system-wide
    sudo ninja -C builddir install

For high quality GIFs additionally install [gifski](https://gif.ski/) and
enable it in the preferences. Recording in GNOME Wayland sessions needs the
GStreamer "good" plugins and a running PipeWire with its session manager.

## Frequently Asked Questions
### How can I capture mouse clicks and/or keystrokes?
Peek does not support this natively. But you could install an external tool
like [key-mon](https://github.com/critiqjo/key-mon) which is usually included
in most distributions, so you can easily install with your package manager.
Then start key-mon with `key-mon --visible_click`. The `--visible_click` option
is for drawing small circles around mouse clicks.

### How can I improve the quality of recorded GIF files
To get the best possible quality you should install the [gifski](https://gif.ski/)
GIF encoder. If it is installed the preferences dialog offers a gifski option
with a quality slider. The default value will give a
balanced result between quality and file size. Set the quality to maximum if you
want to get the highest possible quality even with thousands of colors. The file
size will increase significantly, though (see below).

### Why are the GIF files so big?
The GIF format is highly inefficient and not well suited for doing large
animations with a lot of changes and colors. Peek tries its best to reduce the
file size by using FFmpeg or [gifski](https://gif.ski/) to generate optimized
GIF files. For best results:

- Use a lower frame rate. 10fps is the default and works well, but in many
  cases you can even get good results with lower framerates.
- If you have [gifski](https://gif.ski/) installed you can adjust the GIF
  quality in the preferences. A lower quality gives a smaller file size at the
  expense of visual quality (see above).
- Avoid too much change. If there is heavy animation the frames will differ
  a lot.
- Record small areas or use the downsample option to scale the image. The GIF
  file format is not well suited for high resolution or full-screen recording.
- Avoid too many colors, since GIF is limited to a 256 color palette per frame.
  This one is not so much about file size but more about visual quality.
- If the above suggestions are not suitable for your use case, consider using
  WebM format (see below).

### If GIF is so bad why use it at all?
While GIF is a very old format, it has seen some rise in usage again in recent
years. One reason is its easy usage in the Web. GIF files are supported nearly
everywhere, which means you can add animations easily to everywhere where you
can upload images. With real video files you are still more limited. Typical use
cases for Peek are recording small user interactions for showing UI features
of an app you developed, for making short tutorials or for reporting bugs.

### What about WebM or MP4? Those are well supported on the web.
Peek allows you to record in WebM or MP4 format, just choose your preferred
output format in the preferences. Both are well supported by modern browsers,
even though they are still not as universally supported by tools and online
services as GIFs.

> [!NOTE]
> Upstream removed MP4 support in 2024. This fork restores it.

### What is the cause for "Could not start GNOME Shell recorder" errors?

Since GNOME 42 the GNOME Shell recorder captures through PipeWire. If PipeWire
is not running the recorder fails with this error right away; if PipeWire runs
without a session manager (`pipewire-media-session` or `wireplumber`) the
start call never returns and Peek reports "Timeout was reached" after a 25 s
freeze. Peek therefore only uses the GNOME Shell recorder in Wayland sessions
and records with FFmpeg on X11. If you start Peek with `-b gnome-shell` on
X11, drop that option; in a Wayland session make sure PipeWire and its session
manager are running.

Otherwise this usually indicates an error while starting the built-in GNOME shell
recorder. Unfortunately Peek does not receive any error details, to find out
more about this issues look at the GNOME Shell log output in `journalctl`.

A common cause for this is that the GNOME Shell recorder is already running,
either because it was started via the GNOME Shell keyboard shortcut or by
another application.

If this error is shown when trying to record MP4 a common cause is that you are
missing the [GStreamer ugly](https://gstreamer.freedesktop.org/modules/gst-plugins-ugly.html)
plugins, which provide MP4 encoding. Please refer to the documentation of your
distribution on how to install these.
Do note that you have to logout and login for Peek to recognize the new
installed libraries if you are running the Wayland display server.

See also issue [#287](https://github.com/phw/peek/issues/287) for related discussion.

### Why can't I interact with the UI elements inside the recording area?
You absolutely should be able to click the UI elements inside the area you are
recording. If you use i3 you should stack Peek with the window you intend to
record or make sure all windows are floating and uncheck "Always on top" from
the Peek settings. If you want to be able to control the area when recording
in i3 you can move Peek to the Scratchpad it will keep recording the area once
you hide the window. If this does not work for you on any other window manager
please open an [issue on GitHub](https://github.com/phw/peek/issues).

### My recorded GIFs flicker, what is wrong?
Some users have experienced recorded windows flicker or other strange visual
artifacts only visible in the recorded GIF. This is most likely a video driver
issue. If you are using Intel video drivers switching between the SNA and UXA
acceleration methods can help. For NVIDIA drivers changing the "Allow Flipping"
setting in the NVIDIA control panel
[was reported to help](https://github.com/phw/peek/issues/86).

### On i3 the recording area is all black, how can I record anything?
i3 does not support the X shape extension. In order to get a transparent
recording area, you have to run a compositor such as Compton.

### Why no native Wayland support?
Wayland has two restrictions that make it hard for Peek to support Wayland
natively:

1. The Wayland protocol does not define a standard way for applications to
   obtain a screenshot. That is intentional, as taking an arbitrary screenshot
   essentially means any application can read the contents of the whole display,
   and Wayland strives to offer improved security by isolating applications. It
   is up to the compositors to provide screenshot capability, and most do. GNOME
   Shell also provides a public interface for applications to use which Peek
   does support.

2. The Wayland protocol does not provide absolute screen coordinates to the
   applications. There is not even a coordinate system for windows at all. Again
   this is intentional, as they are not needed in many cases and you do not need
   to follow restrictions imposed by the traditional assumption that the screen
   is a rectangular area (e.g. you can have circular screens or [layout windows
   in 3D space](https://www.youtube.com/watch?v=_FjuPn7MXMs)).

Unfortunately, the whole concept of the Peek UI is that the window position
itself is used to obtain the recording coordinates. That means, for now, there
cannot be any fully native Wayland support without special support for this
use case by the compositor.

However, it is possible to use Peek in a GNOME Shell Wayland session using
XWayland by launching Peek with the X11 backend:

    GDK_BACKEND=x11 peek

Support for compositors other than GNOME Shell can be added if a suitable
screencasting interface is provided.


## Contribute
If you want to help make Peek better the easiest thing you can do is to
[report issues and feature requests](https://github.com/phw/peek/issues).
Or you can help in development and translation.

### Development
You are welcome to contribute code and provide pull requests for Peek. The
easiest way to start is looking at the open issues tagged with
[good first issue](https://github.com/phw/peek/labels/good%20first%20issue).
Those are open issues which are not too difficult to solve and can be started
without too much knowledge about the code.

Another good starting point are issues tagged with
[help wanted](https://github.com/phw/peek/labels/help%20wanted). Those issues are
probably harder to solve, but for some reason I cannot work on it for now and
would love to see somebody jump in.

In any case, just leave a note on the issue itself that you are working on it,
to avoid multiple people working on the same issue.


### Translations
You can help translate Peek into your language. Peek is using
[Weblate](https://weblate.org/) for translation management.

Go to the [Peek localization project](https://hosted.weblate.org/projects/peek/translations/)
to start translating. If the language you want to translate into is not already
available, you [can add it here](https://hosted.weblate.org/projects/peek/translations/#newlang).

If you want to be credited for your translation, please add your name to the
[translator-credits](https://hosted.weblate.org/search/peek/translations/?q=translator-credits&search=exact&source=on&type=all&ignored=False)
for your language. The translator credits are shown in Peek's About dialog.


## License
Peek Copyright © 2015-2024 by Philipp Wolfer <ph.wolfer@gmail.com>

Peek is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Peek is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Peek.  If not, see <https://www.gnu.org/licenses/>.
