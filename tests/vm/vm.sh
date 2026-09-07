#!/bin/bash
# Manage the GNOME test VMs (libvirt/KVM) used for backend and desktop checks
# that Xvfb cannot cover. See tests/vm/README.md.
#
#   tests/vm/vm.sh <gnome|jammy> <command> [args]
#
#   create        build the VM from the Ubuntu cloud image with user-data
#   start         start it and wait for SSH and a GNOME Xorg session
#   sync          send the current git HEAD to the VM and build it there
#   snapshot      save the running, logged-in, built state as "ready"
#   revert        restore "ready" (seconds; replaces start+sync for a clean run)
#   ssh CMD...    run a command inside the desktop session environment
#   smoke [ffmpeg|gnome-shell]   run tests/ui-smoke.sh on the VM's real display
#   shot FILE     screenshot the VM display into FILE (png)
#   stop          shut the VM down
set -euo pipefail

VM_DIR=${PEEK_VM_DIR:-$HOME/vms/peek}
REPO=$(realpath "$(dirname "$0")/../..")
name=${1:?vm name: gnome or jammy}; shift
cmd=${1:?command}; shift

case $name in
  gnome) DOM=peek-gnome; SERIES=noble; OSV=ubuntu24.04 ;;
  jammy) DOM=peek-jammy; SERIES=jammy; OSV=ubuntu22.04 ;;
  *) echo "unknown vm $name"; exit 1 ;;
esac
virsh() { command virsh -c qemu:///system "$@"; }
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR)
# Environment of the autologin desktop session, so commands see the display,
# the session bus and the desktop name exactly like a launched app would.
SESSION_ENV='export DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus XDG_CURRENT_DESKTOP=ubuntu:GNOME XDG_SESSION_TYPE=x11;'

ip() { virsh domifaddr "$DOM" 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1 | head -1; }
vssh() { ssh "${SSH_OPTS[@]}" "peek@$(ip)" "$SESSION_ENV $*"; }
vscp() { scp "${SSH_OPTS[@]}" "$@"; }
wait_ready() {
  echo "waiting for $DOM ..."
  until [ -n "$(ip)" ] && vssh 'pgrep -x gnome-shell >/dev/null' 2>/dev/null; do sleep 5; done
  sleep 10
  echo "$DOM up at $(ip)"
}

case $cmd in
  create)
    mkdir -p "$VM_DIR"; cd "$VM_DIR"
    img=$SERIES-server-cloudimg-amd64.img
    [ -f "$img" ] || curl -sSL -o "$img" "https://cloud-images.ubuntu.com/$SERIES/current/$img"
    qemu-img create -q -f qcow2 -F qcow2 -b "$img" "$DOM.qcow2" 30G
    sed "s|@HOSTNAME@|$DOM|; s|@SSH_PUBKEY@|$(cat ~/.ssh/id_ed25519.pub)|" "$REPO/tests/vm/user-data" >"$DOM-user-data"
    virt-install --name "$DOM" --memory 6144 --vcpus 4 --cpu host-passthrough --os-variant "$OSV" \
      --disk "path=$VM_DIR/$DOM.qcow2,format=qcow2,bus=virtio" --import --cloud-init "user-data=$VM_DIR/$DOM-user-data" \
      --network network=default --graphics vnc,listen=127.0.0.1 --video virtio --sound none --noautoconsole
    echo "cloud-init is installing the desktop (~10 min); it powers off when done. Then: vm.sh $name start"
    ;;
  start)
    [ "$(virsh domstate "$DOM")" = running ] || virsh start "$DOM" >/dev/null
    wait_ready
    ;;
  sync)
    bundle=$(mktemp); git -C "$REPO" bundle create -q "$bundle" HEAD
    vscp "$bundle" "peek@$(ip):peek-ng.bundle"; rm -f "$bundle"
    vssh 'cd ~/peek-ng 2>/dev/null || { git init -q ~/peek-ng && cd ~/peek-ng; };
      git fetch -q ../peek-ng.bundle HEAD && git checkout -q -f --detach FETCH_HEAD && git log --oneline -1 &&
      { [ -d builddir ] || meson setup builddir >/dev/null; } && ninja -C builddir 2>&1 | grep -E "error:|FAILED|Linking target src/peek" || true'
    ;;
  snapshot)
    virsh snapshot-delete "$DOM" ready >/dev/null 2>&1 || true
    virsh snapshot-create-as "$DOM" ready >/dev/null && echo "snapshot 'ready' saved (running state)"
    ;;
  revert)
    virsh snapshot-revert "$DOM" ready --running >/dev/null && echo "reverted to 'ready'"; sleep 3
    ;;
  ssh)
    vssh "$@"
    ;;
  smoke)
    backend=${1:-ffmpeg}
    vscp "$REPO/tests/ui-smoke.sh" "peek@$(ip):peek-ng/tests/ui-smoke.sh"
    vssh "cd ~/peek-ng && PEEK_BACKEND=$backend UI_SMOKE_SHOT=/tmp/ui-smoke-fail.png tests/ui-smoke.sh" || {
      vscp "peek@$(ip):/tmp/ui-smoke-fail.png" "$VM_DIR/ui-smoke-fail.png" 2>/dev/null && echo "screenshot: $VM_DIR/ui-smoke-fail.png"; exit 1; }
    ;;
  shot)
    out=${1:?output file}
    vssh 'ffmpeg -loglevel error -y -f x11grab -i :0 -frames:v 1 /tmp/shot.png' && vscp "peek@$(ip):/tmp/shot.png" "$out"
    ;;
  stop)
    virsh shutdown "$DOM" >/dev/null && echo "$DOM shutting down"
    ;;
  *) echo "unknown command $cmd"; exit 1 ;;
esac
