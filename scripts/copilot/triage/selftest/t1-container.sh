#!/bin/bash
# T1 self-test: run a packaged command (installed with --packages dos2unix).
set -u
dos2unix --version | head -n 1
printf 'a\r\nb\r\n' > /tmp/in
dos2unix -q /tmp/in
if printf 'a\nb\n' | cmp -s - /tmp/in; then
    echo TRIAGE_VERDICT=reproduced
else
    echo TRIAGE_VERDICT=not-reproduced
fi
