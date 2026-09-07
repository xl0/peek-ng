# Peek build and packaging notes
This file contains information about building and packaging Peek. The
information here is mainly for developers and packagers, end users should
refer to the installation instructions in README.md.

## Building

### Building from source

From inside the Peek source folder run:

    meson setup --prefix=/usr builddir
    cd builddir
    ninja

`ninja` might be called `ninja-build` on some distributions.

### Run tests

    ninja test

### UI smoke test

`tests/ui-smoke.sh` starts the built `peek`, records, cancels and saves
through the real window using `xdotool`, and checks the log and the output
and cache folders. It grabs the global hotkey and records the screen, so run
it on a throwaway display:

    xvfb-run -a -s "-screen 0 1280x800x24" dbus-run-session -- \
      bash -c 'openbox & sleep 1; tests/ui-smoke.sh'

CI runs exactly this. It needs `xvfb`, `openbox`, `xdotool` and `ffmpeg`.

### Running Peek with debug output

    G_MESSAGES_DEBUG=all ./peek

### Long-recording rendering hang

CLI recording and post-processing must drain merged stdout/stderr while
the child runs. Waiting for exit first lets FFmpeg's progress output fill
the pipe: FFmpeg then blocks before it can read the `q` stop command or
finalize the MP4. This matches the symptoms reported in upstream #339.

`Utils.wait_with_output_async` drains byte chunks asynchronously, preserves
stdin for stop commands, and retains the last 64 KiB for error dialogs.
Byte reads avoid buffering entire CR-delimited FFmpeg progress streams as
one line. Invalid UTF-8 is repaired only after collection.

Regression tests write 4 MiB of merged output before waiting for `q` or
exiting. Both recording-stop and post-processing-success tests time out
on the unpatched code. Tests also cover failed commands, cancellation,
bounded diagnostics, and invalid UTF-8.

    meson test -C builddir --print-errorlogs

This checkout uses the 2023-01-14 upstream snapshot (`caf7676`), matching
Ubuntu 24.04's package. Later upstream versions removed MP4 support.

### Update translations

    ninja peek-update-po
    ninja peek-pot


## Packaging

### Debian package

#### Build requirements
 - meson (>= 0.47.0)
 - valac (>= 0.22)
 - libgtk-3-dev (>= 3.20)
 - libkeybinder-3.0-dev
 - libxml2-utils
 - gettext (>= 0.19 for localized .desktop entry)
 - txt2man (optional for building man page)
 - gzip (optional for building man page)

#### Runtime requirements
 - libgtk-3-0 (>= 3.20)
 - libglib2.0 (>= 2.52)
 - libkeybinder-3.0-0
 - ffmpeg >= 3

### Flatpak

Install the GNOME runtime and SDK as described in
http://docs.flatpak.org/en/latest/getting-setup.html

**Note:** Flatpak >= 0.9.3 is required for the build.

Build Flatpak and place it in flatpak-repo repository:

    flatpak-builder --repo=flatpak-repo com.uploadedlobster.peek \
      --gpg-sign=B539AD7A5763EE9C1C2E4DE24C14923F47BF1A02 \
      flatpak-stable.json --force-clean

You can build for different architecture with the `--arch` parameter, e.g.
`--arch=x86_64` or `--arch=i386`.

Generate a `.flatpak` file for single file distribution:

    flatpak build-bundle flatpak-repo peek-1.0.0-0.flatpak \
      com.uploadedlobster.peek stable
