#!/bin/bash
# T2 self-test: systemd is PID 1 and can manage a unit.
set -u
echo "pid1=$(cat /proc/1/comm)"
systemctl is-system-running || true
systemctl start systemd-journald.service
if test "$(cat /proc/1/comm)" = systemd && systemctl is-active -q systemd-journald.service; then
    echo TRIAGE_VERDICT=reproduced
else
    echo TRIAGE_VERDICT=not-reproduced
fi
