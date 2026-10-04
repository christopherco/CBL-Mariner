#!/bin/bash
set -euo pipefail

# The runner is built with the caller's UID, so no recursive sudo chown is needed.
test "$(id -u)" -ne 0
test -w /workdir
exec "$@"
