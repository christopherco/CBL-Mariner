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
from configparser import ConfigParser
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import mock_open, patch

from mockbuild.buildroot import Buildroot
from mockbuild.config import load_config

with open('/home/builduser/.config/mock.cfg') as config_file:
    source = compile(config_file.read(), 'copilot-mock.cfg', 'exec')
options = {
    'dnf.conf': '[main]\nkeepcache=1\n[custom]\nbaseurl=https://example.test/repo\nsslcacert=/stale/repo-ca.pem\nsslverify=0\n',
    'bootstrap_dnf.conf': '[main]\nkeepcache=0\n[bootstrap]\nbaseurl=https://example.test/bootstrap\n',
    'files': {'etc/existing-file': 'preserved'},
    'dnf5_common_opts': ['--best'],
    'root': 'caller-selected-root',
    'rootdir': '/custom/root',
    'plugin_conf': {'root_cache_opts': {'dir': '/custom/cache'}},
}
actual = deepcopy(options)
exec(source, {'config_opts': actual})
if (
    not actual['root'].startswith(options['root'] + '-copilot-')
    or actual['files']['etc/existing-file'] != 'preserved'
    or actual['dnf5_common_opts'][0] != '--best'
    or 'keepcache=1' not in actual['dnf.conf']
    or 'https://example.test/repo' not in actual['dnf.conf']
    or 'keepcache=0' not in actual['bootstrap_dnf.conf']
    or 'https://example.test/bootstrap' not in actual['bootstrap_dnf.conf']
    or 'sslverify=0' in actual['dnf.conf']
    or '/stale/repo-ca.pem' in actual['dnf.conf']
):
    raise RuntimeError('Session trust helper changed caller configuration')

# Use mock's actual write-if-absent implementation with retained/cache-restored
# files. Rotation must select new paths/state without overwriting old bytes.
with TemporaryDirectory(dir='/workdir/base/build/work/scratch/copilot-validation') as directory:
    retained = Path(directory)
    snapshots = []
    for ca in ('-----BEGIN CERTIFICATE-----\nold\n', '-----BEGIN CERTIFICATE-----\nnew\n'):
        current = deepcopy(options)
        with patch('builtins.open', mock_open(read_data=ca)):
            exec(source, {'config_opts': current})
        root = SimpleNamespace(
            config=current,
            make_chroot_path=lambda key: str(retained / key),
        )
        Buildroot._init_aux_files(root)
        ca_key = next(key for key in current['files'] if key.startswith('etc/copilot-session/'))
        if (retained / ca_key).read_text() != ca:
            raise RuntimeError('Rotated trust reused stale CA bytes')
        snapshots.append((current, ca_key, ca))
    old, new = snapshots
    if (
        old[1] == new[1]
        or old[0]['root'] == new[0]['root']
        or old[0]['rootdir'] == new[0]['rootdir']
        or old[0]['plugin_conf']['root_cache_opts']['dir'] == new[0]['plugin_conf']['root_cache_opts']['dir']
        or (retained / old[1]).read_text() != old[2]
    ):
        raise RuntimeError('CA rotation did not isolate retained roots/cache')
    repeated = deepcopy(options)
    with patch('builtins.open', mock_open(read_data=new[2])):
        exec(source, {'config_opts': repeated})
    if repeated != new[0]:
        raise RuntimeError('Unchanged CA did not retain stable configuration')
    print('CA_ROTATION_RETAINED_FILES_OK')

# Load the real stage2 config through mock, including the session helper, and
# check each effective repo value rather than relying on main/CLI settings.
effective = load_config(
    '/workdir/distro/mock/azl4/stage2',
    '/workdir/distro/mock/azl4/stage2/azurelinux-4.0-x86_64.cfg',
)
dnf = ConfigParser(interpolation=None)
dnf.read_string(effective['dnf.conf'])
for repo in ('base', 'sdk'):
    ca_path = dnf[repo]['sslcacert']
    if (
        not dnf[repo].getboolean('sslverify')
        or ca_path.lstrip('/') not in effective['files']
        or '/azurelinux/4.0/beta/' + repo not in dnf[repo]['baseurl']
    ):
        raise RuntimeError('Incorrect effective trust/repository config: ' + repo)
    print('EFFECTIVE_REPO_TRUST_OK', repo, ca_path)
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
