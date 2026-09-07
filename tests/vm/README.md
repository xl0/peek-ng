# GNOME test VMs

Two libvirt VMs with an autologin GNOME **Xorg** session, for everything the
Xvfb smoke test cannot see: the GNOME Shell recorder backend, PipeWire
states, Yaru theme sizing, real notifications. They are also the reliable
place to run the smoke test itself.

- `gnome`: Ubuntu 24.04, GNOME Shell 46
- `jammy`: Ubuntu 22.04, GNOME Shell 42 (the configuration behind most
  upstream "Timeout was reached" reports)

Requirements on the host: libvirt with KVM, `virt-install`, `qemu-img`,
an SSH key at `~/.ssh/id_ed25519.pub`. Images live in `$PEEK_VM_DIR`
(default `~/vms/peek`, about 6 GB per VM).

## Workflow

    tests/vm/vm.sh gnome create      # once; cloud-init installs the desktop, ~10 min
    tests/vm/vm.sh gnome start       # boots and waits for the session
    tests/vm/vm.sh gnome sync        # ships git HEAD, builds it in the VM
    tests/vm/vm.sh gnome snapshot    # freeze this clean, built, logged-in state

From then on a clean run is:

    tests/vm/vm.sh gnome revert      # back to the snapshot in seconds
    tests/vm/vm.sh gnome sync        # incremental build of the current HEAD
    tests/vm/vm.sh gnome smoke gnome-shell   # or: smoke ffmpeg

`smoke` runs `tests/ui-smoke.sh` on the VM's real display and, on failure,
copies a screenshot to `$PEEK_VM_DIR/ui-smoke-fail.png`. For anything
custom, `ssh` runs a command inside the session environment (display,
session bus, `XDG_CURRENT_DESKTOP` set), and `shot FILE` grabs the screen:

    tests/vm/vm.sh jammy ssh 'systemctl --user stop pipewire-media-session'
    tests/vm/vm.sh jammy ssh 'cd peek-ng && ./builddir/src/peek -b gnome-shell &'
    tests/vm/vm.sh jammy shot /tmp/jammy.png

Snapshots include memory, so `revert` lands in a running session without a
reboot, and any state a previous run left (stuck screencast service, files
in `~/Videos`) is gone.
