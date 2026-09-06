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

The fork is based on upstream `main` with the MP4 removal (`763766f`)
reverted.

### Update translations

    ninja peek-update-po
    ninja peek-pot


## Packaging

Release packages are built by `.github/workflows/release.yml` on every `v*`
tag (and on pull requests touching `debian/`, `rpm/` or the workflow). The
same steps work locally; each package type must be built on its own
distribution family.

### Debian / Ubuntu `.deb`

`debian/` is real Debian packaging (debhelper 13, meson build system). Install
the build dependencies once:

    sudo apt install build-essential debhelper devscripts \
      desktop-file-utils gettext libglib2.0-dev libgtk-3-dev \
      libkeybinder-3.0-dev libxml2-utils meson python3 txt2man valac

Then, from the source directory:

    dpkg-buildpackage -us -uc -b

The package lands in the parent directory as `../peek_<version>_amd64.deb`
together with a `-dbgsym` package, `.buildinfo` and `.changes`. Install it
with `sudo apt install ../peek_*.deb`.

Notes:

- `-us -uc` skips signing, `-b` builds binaries only, so no orig tarball is
  needed even though `debian/source/format` says `3.0 (quilt)`.
- Add `-d` to ignore missing build dependencies, for example when `txt2man`
  is not installed; the man page is then simply omitted.
- The version comes from the top entry of `debian/changelog`, not from
  `meson.build`. Bump both for a release: `dch -v 1.6.1-1` (from devscripts)
  adds a changelog entry.
- `lintian ../peek_*.changes` checks the result if lintian is installed.
- Build intermediates go to `obj-*/` and `debian/peek/`; `debuild clean` or
  `fakeroot debian/rules clean` removes them.

### Fedora `.rpm`

`rpm/peek.spec` expects a tarball named `peek-<version>.tar.gz` that unpacks
to `peek-ng-<version>/`, which is what a GitHub tag archive produces. On
Fedora:

    sudo dnf install rpm-build rpmdevtools git gcc meson vala gettext \
      gtk3-devel glib2-devel keybinder3-devel desktop-file-utils \
      libappstream-glib libxml2 txt2man gzip
    rpmdev-setuptree
    version=$(sed -n 's/^Version:\s*//p' rpm/peek.spec)
    git archive --prefix="peek-ng-$version/" \
      -o ~/rpmbuild/SOURCES/peek-$version.tar.gz HEAD
    rpmbuild -bb rpm/peek.spec

The packages land in `~/rpmbuild/RPMS/x86_64/`: `peek-<version>.rpm` plus
debuginfo and debugsource packages. The spec requires RPM Fusion's `ffmpeg`;
Fedora's `ffmpeg-free` has no libx264 and cannot record GIF or MP4.

Without a Fedora machine, the same commands run in a container:

    podman run --rm -it -v "$PWD:/src:Z" fedora:latest

Bump `Version:` and add a `%changelog` entry for a release.

### Releasing

1. Bump the version in `meson.build`, `debian/changelog`, `rpm/peek.spec`
   and add a `<release>` to `data/com.uploadedlobster.peek.appdata.xml.in`
   and an entry to `CHANGES.md`.
2. Merge, then tag the merge commit `v<version>` and push the tag.
3. The Packages workflow builds the `.deb` files for Ubuntu 22.04/24.04 and
   Debian 12/13 and the Fedora `.rpm`, and attaches them to a new GitHub
   release with generated notes.

### Flatpak, Snap, AppImage

The manifests under `build-aux/` are upstream's and have not been updated
or tested for the fork.
