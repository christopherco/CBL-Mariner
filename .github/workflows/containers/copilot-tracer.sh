#!/bin/bash
set -euo pipefail

# Run in localhost/copilot-ci with the checkout mounted at /workdir, stdin
# preserved, and the existing SYS_ADMIN/seccomp/AppArmor mock flags.
cd /workdir
scratch=/workdir/base/build/work/scratch/copilot-tracer
mkdir -p "$scratch"
exec > >(tee "$scratch/ci-like-session.log") 2>&1
test "${GIT_SSL_CAINFO:-}" = /etc/ssl/certs/ca-certificates.crt
test -r "$GIT_SSL_CAINFO"
config=/workdir/distro/mock/azl4/stage2/azurelinux-4.0-x86_64.cfg
configdir=$(dirname "$config")

diagnose() {
    local rc=$?
    trap - ERR
    set +e
    printf 'TRACER_FAILURE stage=%s exit=%s\n' "$stage" "$rc"
    local url=https://packages.microsoft.com/azurelinux/4.0/beta/base/x86_64/repodata/repomd.xml
    printf 'Runner TLS diagnostics, URL=%s\n' "$url"
    curl --version
    rpm -q mock dnf curl openssl ca-certificates
    ls -l "$GIT_SSL_CAINFO"
    sha256sum "$GIT_SSL_CAINFO"
    curl --fail --silent --show-error --cacert "$GIT_SSL_CAINFO" \
        --connect-timeout 15 --max-time 30 -o /dev/null \
        -w 'Runner verified curl HTTP=%{http_code}\n' "$url"
    printf 'Runner verified curl exit=%s\n' "$?"
    mock -r "$config" --configdir "$configdir" --debug-config \
        > "$scratch/mock-effective.config"
    grep -A40 -E "^config_opts\['(bootstrap_dnf.conf|dnf.conf)'\]" \
        "$scratch/mock-effective.config"
    # Host DNF4 can install diagnostic tools with the selected verified CA.
    # This does not substitute a repository dos2unix RPM.
    mock -r "$config" --configdir "$configdir" --no-bootstrap-chroot \
        --config-opts root=azl-4.0-stage2-x86_64-bootstrap \
        --config-opts package_manager=dnf4 \
        --config-opts 'chroot_setup_cmd=install curl openssl' --chroot -- \
        bash -c '
            set +e
            rpm -q dnf5 libdnf5 curl curl-libs openssl ca-certificates
            ls -l /etc/ssl/certs/ca-certificates.crt
            sha256sum /etc/ssl/certs/ca-certificates.crt
            ls -l /etc/copilot-session/proxy-ca.pem
            sha256sum /etc/copilot-session/proxy-ca.pem
            grep -nE "sslcacert|sslverify|baseurl|reposdir" /etc/dnf/dnf.conf
            dnf5 --version
            dnf5 --dump-main-config
            dnf5 --releasever 4.0 --dump-repo-config=base
            if command -v curl; then
                curl --version
                curl --fail --silent --show-error \
                    --cacert /etc/ssl/certs/ca-certificates.crt \
                    --connect-timeout 15 --max-time 30 -o /dev/null \
                    -w "Bootstrap verified curl HTTP=%{http_code}\n" \
                    https://packages.microsoft.com/azurelinux/4.0/beta/base/x86_64/repodata/repomd.xml
                printf "Bootstrap verified curl exit=%s\n" "$?"
            fi
            dnf5 --releasever 4.0 --setopt=sslcacert=/etc/copilot-session/proxy-ca.pem \
                --setopt=sslverify=1 --repo=base --refresh makecache
            printf "Direct bootstrap DNF5 exit=%s\n" "$?"
        '
    exit "$rc"
}
stage=environment
trap diagnose ERR
id
uname -m
azldev --version
printf 'GIT_SSL_CAINFO=%s\n' "$GIT_SSL_CAINFO"
azldev comp build --help
azldev adv mock shell --help
azldev comp list -p dos2unix -q -O json
stage=render
azldev comp render -p dos2unix --fail-on-error
stage=build
touch "$scratch/build-start"
azldev comp build -p dos2unix
stage=select-local-rpm
mapfile -t rpms < <(find /workdir/base/out/rpms -type f \
    -name 'dos2unix-[0-9]*.x86_64.rpm' -newer "$scratch/build-start" -print)
if test "${#rpms[@]}" -ne 1; then
    printf 'Expected one newly built main RPM, found %s\n' "${#rpms[@]}"
    exit 1
fi
rpm_path=${rpms[0]}
printf 'LOCAL_RPM=%s\n' "$rpm_path"
sha256sum "$rpm_path"
stage=test-root-init
mock -r "$config" --configdir "$configdir" --init
mock -r "$config" --configdir "$configdir" --copyin "$rpm_path" /tmp/
copied_rpm="/tmp/$(basename "$rpm_path")"
stage=inspect-local-rpm
azldev adv mock shell -c "$config" -- rpm -qip "$copied_rpm"
azldev adv mock shell -c "$config" -- rpm -qlp "$copied_rpm"
stage=install-and-smoke-test
# Expand package identity variables in the chroot, not in the runner shell.
# shellcheck disable=SC2016
azldev adv mock shell -c "$config" --add-package "$rpm_path" -- \
    bash -eu -o pipefail -c '
        format="%{NAME}/%{VERSION}/%{RELEASE}/%{ARCH}"
        expected=$(rpm -qp --qf "$format" "$1")
        installed=$(rpm -q --qf "$format" dos2unix)
        printf "LOCAL_PACKAGE_IDENTITY=%s\nINSTALLED_PACKAGE_IDENTITY=%s\n" "$expected" "$installed"
        test "$installed" = "$expected"
        dos2unix --version
        printf "alpha\r\nbeta\r\n" > /tmp/copilot-tracer-input
        printf "alpha\nbeta\n" > /tmp/copilot-tracer-expected
        dos2unix /tmp/copilot-tracer-input
        cmp /tmp/copilot-tracer-input /tmp/copilot-tracer-expected
        printf "Conversion byte comparison passed\nCOPILOT_TRACER_SMOKE_OK\n"
    ' copilot-tracer "$copied_rpm"
