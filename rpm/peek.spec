Name:           peek
Version:        1.6.0
Release:        1%{?dist}
Summary:        Simple screen recorder with an easy to use interface

License:        GPL-3.0-or-later
URL:            https://github.com/xl0/peek-ng
Source0:        https://github.com/xl0/peek-ng/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson
BuildRequires:  vala
BuildRequires:  gettext
BuildRequires:  pkgconfig(gtk+-3.0) >= 3.22
BuildRequires:  pkgconfig(glib-2.0) >= 2.52
BuildRequires:  pkgconfig(keybinder-3.0)
BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib
BuildRequires:  libxml2
BuildRequires:  txt2man
BuildRequires:  gzip
# Needs the RPM Fusion build: GIF/APNG use libx264rgb and MP4 uses libx264,
# neither of which is in Fedora's ffmpeg-free.
Requires:       ffmpeg
Recommends:     gstreamer1-plugins-good
Recommends:     pipewire-gstreamer
Suggests:       gstreamer1-plugins-ugly
Suggests:       gifski

%description
Peek makes it easy to create short screencasts of a screen area. It was built
for the specific use case of recording screen areas, e.g. for easily showing UI
features of your own apps or for showing a bug in bug reports. With Peek you
simply place the Peek window over the area you want to record and press
"Record". Peek is optimized for generating animated GIFs, but you can also
directly record to WebM or MP4 if you prefer.

This is the maintained peek-ng fork of the deprecated upstream project.

%prep
%autosetup -n %{name}-ng-%{version}

%build
%meson
%meson_build

%install
%meson_install
desktop-file-validate %{buildroot}/%{_datadir}/applications/com.uploadedlobster.%{name}.desktop
appstream-util validate-relax --nonet %{buildroot}/%{_datadir}/metainfo/*.appdata.xml
%find_lang %{name}

%files -f %{name}.lang
%license LICENSE
%doc README.md AUTHORS CHANGES.md
%{_bindir}/%{name}
%{_datadir}/applications/com.uploadedlobster.%{name}.desktop
%{_datadir}/metainfo/com.uploadedlobster.%{name}.appdata.xml
%{_datadir}/dbus-1/services/com.uploadedlobster.%{name}.service
%{_datadir}/glib-2.0/schemas/com.uploadedlobster.%{name}.gschema.xml
%{_datadir}/icons/hicolor/scalable/apps/com.uploadedlobster.%{name}.svg
%{_datadir}/icons/hicolor/symbolic/apps/com.uploadedlobster.%{name}-symbolic.svg
%{_mandir}/man1/%{name}.1*

%changelog
* Sun Sep 06 2026 Alexey Zaytsev <alexey.zaytsev@gmail.com> - 1.6.0-1
- peek-ng fork: rendering hang, MP4, GNOME 42+ timeouts, GIF frame drops,
  gifski size, countdown capture and many smaller fixes. Build with meson.

* Thu Mar 29 2018 Philipp Wolfer <ph.wolfer@gmail.com> - 1.3.1
- fix: Use yuv420p for VP9 encoding (#299)
- fix: Disable animations and transitions on recording view overlays (#208)
- i18n: Updated French and Russian translations
