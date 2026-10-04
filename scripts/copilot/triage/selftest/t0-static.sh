#!/bin/bash
# T0 self-test: inspect the image filesystem without executing it.
set -u
# shellcheck source=/dev/null
. "$ROOTFS/etc/os-release"
echo "ID=$ID VERSION_ID=$VERSION_ID"
count=$(rpm --root "$ROOTFS" -qa | wc -l)
echo "packages=$count"
if test "$ID" = azurelinux && test "${VERSION_ID%%.*}" = 4 && test "$count" -gt 0; then
    echo TRIAGE_VERDICT=reproduced
else
    echo TRIAGE_VERDICT=not-reproduced
fi
