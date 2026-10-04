#!/bin/bash
# T3 self-test: the guest booted its own kernel from the virtio disk.
set -u
echo "kernel=$(uname -r)"
echo "cmdline=$(cat /proc/cmdline)"
systemctl is-system-running || true
root_src=$(findmnt -n -o SOURCE /)
echo "root=$root_src $(findmnt -n -o FSTYPE /)"
# shellcheck source=/dev/null
. /etc/os-release
if test "$ID" = azurelinux && test "$root_src" = /dev/vda && test "$(cat /proc/1/comm)" = systemd; then
    echo TRIAGE_VERDICT=reproduced
else
    echo TRIAGE_VERDICT=not-reproduced
fi
