#!/bin/bash
# T1 self-test: run a packaged command (installed with --packages dos2unix).
# core:4 is minimal (no cmp/diffutils), so compare with bash only.
set -u
dos2unix --version | head -n 1
printf 'a\r\nb\r\n' > /tmp/in
dos2unix -q /tmp/in
if test "$(< /tmp/in)" = $'a\nb'; then
    echo TRIAGE_VERDICT=reproduced
else
    echo TRIAGE_VERDICT=not-reproduced
fi
