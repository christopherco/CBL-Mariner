#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
run="$root/scripts/copilot/run.sh"

# Exercise the missing-setup branch without removing the prepared image.
(
    # shellcheck disable=SC2317 # Called by run.sh in a child Bash process.
    docker() { return 1; }
    export -f docker
    if output=$(bash "$run" readiness 2>&1); then
        echo 'Missing setup unexpectedly succeeded' >&2
        exit 1
    fi
    grep -q 'Missing localhost/copilot-ci' <<< "$output"
)

printf 'stdin preserved\n' | bash "$run" session bash -eu -o pipefail -c '
    test "$1" = "$3"
    test "$2" = "$4"
    read -r line
    test "$line" = "stdin preserved"
' -- 'argument with spaces' 'literal * ; $(not-executed)' \
    'argument with spaces' 'literal * ; $(not-executed)'

bash "$run" session bash -seu -o pipefail <<'CONTAINER'
scratch=/workdir/base/build/work/scratch/copilot-validation
mkdir -p "$scratch"
azldev config dump -q -f json > "$scratch/wrapped.json"
azldev --config-file /workdir/distro/azurelinux.distro.toml config dump -q -f json > "$scratch/explicit.json"
cmp "$scratch/wrapped.json" "$scratch/explicit.json"
printf '[project]\ndescription = "caller-selected-description"\n' > "$scratch/override.toml"
azldev --config-file "$scratch/override.toml" config dump -q -f json \
    | jq -e '.project.description == "caller-selected-description"' >/dev/null
python3 - <<'PYTHON'
from copy import deepcopy
from unittest.mock import patch

with open('/home/builduser/.config/mock.cfg') as config_file:
    source = compile(config_file.read(), 'copilot-mock.cfg', 'exec')
options = {
    'dnf.conf': '[main]\nkeepcache=1\n[custom]\nbaseurl=https://example.test/repo\nsslverify=0\n',
    'bootstrap_dnf.conf': '[main]\nkeepcache=0\n[bootstrap]\nbaseurl=https://example.test/bootstrap\n',
    'files': {'etc/existing-file': 'preserved'},
    'dnf5_common_opts': ['--best'],
    'root': 'caller-selected-root',
}
actual = deepcopy(options)
exec(source, {'config_opts': actual})
if (
    actual['root'] != options['root']
    or actual['files']['etc/existing-file'] != 'preserved'
    or actual['dnf5_common_opts'][0] != '--best'
    or 'keepcache=1' not in actual['dnf.conf']
    or 'https://example.test/repo' not in actual['dnf.conf']
    or 'keepcache=0' not in actual['bootstrap_dnf.conf']
    or 'https://example.test/bootstrap' not in actual['bootstrap_dnf.conf']
    or 'sslverify=0' in actual['dnf.conf']
):
    raise RuntimeError('Session trust helper changed caller configuration')
with patch('builtins.open', side_effect=FileNotFoundError):
    try:
        exec(source, {'config_opts': deepcopy(options)})
    except RuntimeError as error:
        if 'Cannot read current-session CA bundle' not in str(error):
            raise
    else:
        raise RuntimeError('Missing session trust unexpectedly succeeded')
PYTHON
CONTAINER
bash "$run" mock-shell --help >/dev/null
echo 'COPILOT_ENVIRONMENT_TESTS_OK'
