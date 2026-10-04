#!/bin/bash
set -euo pipefail

# The runner is built with the caller's UID, so no recursive sudo chown is needed.
if test "$(id -u)" -eq 0 || test "$(id -gn)" != mock || ! test -w /workdir; then
    echo 'Copilot runner requires a non-root mock-group user and writable /workdir' >&2
    exit 1
fi
if test "${1:-}" = --readiness; then
    azldev --version
    mock --version
    azldev comp list -p dos2unix -q -O json | jq -e 'length == 1' >/dev/null
    exit
fi
export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
if ! test -r "$GIT_SSL_CAINFO" || ! openssl x509 -in "$GIT_SSL_CAINFO" -noout >/dev/null 2>&1; then
    echo "Missing or unusable current-session CA bundle: $GIT_SSL_CAINFO" >&2
    exit 1
fi
if test "$#" -eq 0; then
    echo 'Copilot runner requires a command' >&2
    exit 2
fi
exec "$@"
