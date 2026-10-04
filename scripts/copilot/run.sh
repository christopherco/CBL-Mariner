#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
image=localhost/copilot-ci
if ! command -v docker >/dev/null || ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "Missing $image; run the repository's Copilot setup steps first" >&2
    exit 1
fi
version=$(tr -d '\n' < "$root/.azldev-version")
prepared=$(docker image inspect "$image" --format '{{index .Config.Labels "copilot.azldev-version"}}')
if test "$prepared" != "$version"; then
    echo "Prepared image pin '$prepared' differs from .azldev-version '$version'; rerun setup" >&2
    exit 1
fi
case "${1:-}" in
    azldev)
        shift
        set -- azldev "$@"
        ;;
    mock-shell)
        shift
        set -- azldev adv mock shell "$@"
        ;;
    session)
        shift
        if test "$#" -eq 0; then
            set -- bash -seu -o pipefail
        fi
        ;;
    readiness)
        shift
        set -- --readiness
        ;;
    *)
        echo 'Usage: bash scripts/copilot/run.sh {azldev ARGS|mock-shell ARGS|session [COMMAND ARGS]|readiness}' >&2
        exit 2
        ;;
esac
exec docker run --rm -i --cap-add=SYS_ADMIN \
    --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
    -v "$root:/workdir" -w /workdir "$image" "$@"
