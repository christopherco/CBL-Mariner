#!/bin/bash
# Reproduce a reported Azure Linux behavior in a disposable environment.
#
# Tiers (lowest sufficient tier first):
#   probe      record what this session can do -> env.json
#   static     T0: inspect an image's filesystem without executing it
#   container  T1: run the repro script in an unprivileged container
#   systemd    T2: run the repro script in a container with systemd as PID 1
#   vm         T3: boot the real Azure Linux kernel + systemd in QEMU
#
# The repro script is plain bash. It should print one line
# `TRIAGE_VERDICT=reproduced|not-reproduced|inconclusive`; its exit code and
# output are recorded either way. Evidence goes to --out (default:
# base/build/work/scratch/triage/<mode>-<timestamp>/), summarized in result.json.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/../../.." && pwd)
scratch_root="$root/base/build/work/scratch/triage"
default_image=mcr.microsoft.com/azurelinux/core:4

usage() {
    cat >&2 <<'EOF'
Usage: repro.sh probe [--image REF] [--out FILE]
       repro.sh {static|container|systemd|vm} --script FILE [options]

Options:
  --image REF       target image (default mcr.microsoft.com/azurelinux/core:4)
  --script FILE     bash repro script to run in the target
  --packages LIST   space-separated packages to dnf install first (not static)
  --timeout SEC     hard limit for the repro run (default 600; vm boot included)
  --out DIR         evidence directory
  --pytest          static: also run base/images/tests static-image-checks
  --keep-disk       vm: keep the generated disk image
EOF
    exit 2
}

mode=${1:-}
test -n "$mode" || usage
shift
image=$default_image
script=""
packages=""
timeout_sec=600
out=""
run_pytest=0
keep_disk=0
while test "$#" -gt 0; do
    case "$1" in
        --image) image=${2:?}; shift 2 ;;
        --script) script=${2:?}; shift 2 ;;
        --packages) packages=${2-}; shift 2 ;;
        --timeout) timeout_sec=${2:?}; shift 2 ;;
        --out) out=${2:?}; shift 2 ;;
        --pytest) run_pytest=1; shift ;;
        --keep-disk) keep_disk=1; shift ;;
        *) usage ;;
    esac
done
case "$timeout_sec" in ''|*[!0-9]*) echo "--timeout must be an integer" >&2; exit 2 ;; esac
if ! [[ "$packages" =~ ^[A-Za-z0-9._+\ -]*$ ]]; then
    echo "--packages contains unexpected characters" >&2
    exit 2
fi
command -v jq >/dev/null || { echo "jq is required on the host" >&2; exit 1; }

log() { printf '[triage %s] %s\n' "$mode" "$*" >&2; }

ensure_docker_image() {
    if ! docker image inspect "$1" >/dev/null 2>&1; then
        log "pulling $1"
        docker pull -q "$1" >/dev/null
    fi
}

image_digest() {
    docker image inspect --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{else}}{{.Id}}{{end}}' "$1"
}

verdict_from() {
    local v
    v=$(grep -aoE '^TRIAGE_VERDICT=(reproduced|not-reproduced|inconclusive)' "$1" | tail -n 1 | cut -d= -f2 || true)
    printf '%s' "${v:-unreported}"
}

# write_result EXIT TIMED_OUT [extra jq object]
write_result() {
    local extra=${3:-'{}'}
    jq -n \
        --arg tier "$mode" \
        --arg image "$image" \
        --arg digest "${digest:-}" \
        --arg packages "$packages" \
        --argjson exit_code "$1" \
        --argjson timed_out "$2" \
        --argjson duration_s "$SECONDS" \
        --arg verdict "$(verdict_from "$out/output.log")" \
        --arg started "$started" \
        --argjson extra "$extra" \
        '{tier: $tier, image: $image, digest: $digest, packages: $packages,
          exit_code: $exit_code, timed_out: $timed_out, duration_s: $duration_s,
          verdict: $verdict, started_utc: $started} + $extra' \
        > "$out/result.json"
    cat "$out/result.json"
}

prepare_run() {
    test -n "$script" || usage
    test -f "$script" || { echo "repro script not found: $script" >&2; exit 2; }
    out=${out:-"$scratch_root/$mode-$(date -u +%Y%m%dT%H%M%SZ)"}
    mkdir -p "$out"
    out=$(cd -- "$out" && pwd)
    cp -- "$script" "$out/repro.sh"
    chmod 0644 "$out/repro.sh"
    started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    SECONDS=0
}

json_bool() { if "$@" >/dev/null 2>&1; then echo true; else echo false; fi; }

# --------------------------------------------------------------------- probe
do_probe() {
    out=${out:-"$scratch_root/env.json"}
    mkdir -p "$(dirname -- "$out")"
    local docker_ok podman_ok pull_ok=false digest="" repo_ok=false kvm qemu
    local copilot_ci=false image_build=false image_build_reason
    docker_ok=$(json_bool docker info)
    podman_ok=$(json_bool podman info)
    if test "$docker_ok" = true && ensure_docker_image "$image" 2>/dev/null; then
        pull_ok=true
        digest=$(image_digest "$image")
        repo_ok=$(json_bool timeout 180 docker run --rm "$image" dnf -q -y makecache --refresh)
    fi
    kvm=$(json_bool test -r /dev/kvm -a -w /dev/kvm)
    qemu=$(json_bool command -v qemu-system-x86_64)
    image_build_reason="copilot-ci image not prepared"
    if test "$docker_ok" = true && docker image inspect localhost/copilot-ci >/dev/null 2>&1; then
        copilot_ci=true
        if bash "$root/scripts/copilot/run.sh" session bash -c 'sudo -n true' >/dev/null 2>&1; then
            image_build=true
            image_build_reason="sudo available in copilot-ci (loop devices still unverified)"
        else
            image_build_reason="azldev image build runs kiwi via sudo and needs loop devices; copilot-ci is non-root without sudo"
        fi
    fi
    local t2=false t3=false t3_accel=none
    if test "$pull_ok" = true && test "$repo_ok" = true; then
        if test "$podman_ok" = true || test "$docker_ok" = true; then t2=true; fi
        if test "$qemu" = true; then
            t3=true
            if test "$kvm" = true; then t3_accel=kvm; else t3_accel=tcg; fi
        fi
    fi
    jq -n \
        --arg image "$image" --arg digest "$digest" \
        --arg arch "$(uname -m)" --arg host_kernel "$(uname -r)" \
        --argjson nproc "$(nproc)" \
        --argjson mem_mb "$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)" \
        --argjson disk_free_mb "$(df -Pm "$root" | awk 'NR==2 {print $4}')" \
        --argjson docker "$docker_ok" --argjson podman "$podman_ok" \
        --argjson image_pull "$pull_ok" --argjson repos "$repo_ok" \
        --argjson kvm "$kvm" --argjson qemu "$qemu" \
        --argjson copilot_ci "$copilot_ci" --argjson azldev_image_build "$image_build" \
        --arg azldev_image_build_reason "$image_build_reason" \
        --argjson t0 "$( [ "$pull_ok" = true ] && echo true || echo false )" \
        --argjson t1 "$( [ "$pull_ok" = true ] && echo true || echo false )" \
        --argjson t2 "$t2" --argjson t3 "$t3" --arg t3_accel "$t3_accel" \
        '{image: $image, digest: $digest, arch: $arch, host_kernel: $host_kernel,
          nproc: $nproc, mem_mb: $mem_mb, disk_free_mb: $disk_free_mb,
          docker: $docker, podman: $podman, image_pull: $image_pull,
          azl_repos_reachable: $repos, kvm: $kvm, qemu: $qemu,
          copilot_ci: $copilot_ci, azldev_image_build: $azldev_image_build,
          azldev_image_build_reason: $azldev_image_build_reason,
          tiers: {T0_static: $t0, T1_container: $t1, T2_systemd: $t2,
                  T3_vm: $t3, T3_accel: $t3_accel}}' > "$out"
    cat "$out"
}

# -------------------------------------------------------------------- static
do_static() {
    prepare_run
    ensure_docker_image "$image"
    ensure_docker_image "$default_image"
    digest=$(image_digest "$image")
    tag="localhost/triage-static:$$"
    trap 'docker rmi -f "$tag" >/dev/null 2>&1 || true' EXIT
    mkdir -p "$out/context"
    docker build -q -f "$here/containers/static.Dockerfile" \
        --build-arg TARGET_IMAGE="$image" --build-arg HELPER_IMAGE="$default_image" \
        -t "$tag" "$out/context" > "$out/build.log" 2>&1
    docker run --rm --network none "$tag" cat /rootfs/etc/os-release > "$out/os-release" 2>&1 || true
    docker run --rm --network none "$tag" rpm --root /rootfs -qa --qf '%{NVRA}\n' 2>/dev/null \
        | sort > "$out/rpm-qa.txt" || true
    local rc=0 timed_out=false
    timeout --kill-after=10 "$timeout_sec" docker run --rm --network none -e ROOTFS=/rootfs \
        -v "$out/repro.sh:/triage/repro.sh:ro" "$tag" bash /triage/repro.sh \
        > "$out/output.log" 2>&1 || rc=$?
    if test "$rc" -eq 124; then timed_out=true; fi

    local pytest_rc=null
    if test "$run_pytest" -eq 1; then
        pytest_rc=$(run_static_pytest)
    fi
    write_result "$rc" "$timed_out" "$(jq -n --argjson p "$pytest_rc" '{pytest_exit_code: $p}')"
}

run_static_pytest() {
    local missing=""
    for tool in skopeo umoci buildah rpm uv; do
        command -v "$tool" >/dev/null || missing="$missing $tool"
    done
    if test -n "$missing"; then
        echo "static-image-checks skipped; missing host tools:$missing" > "$out/pytest.log"
        echo null
        return
    fi
    local rc=0
    skopeo copy -q "docker-daemon:$image" "oci-archive:$out/image.oci.tar" >> "$out/pytest.log" 2>&1 || rc=$?
    if test "$rc" -eq 0; then
        (cd "$root/base/images/tests" && uv run pytest -q cases/static/ \
            --image-path "$out/image.oci.tar" --image-name container-base \
            --capabilities container,runtime-package-management) >> "$out/pytest.log" 2>&1 || rc=$?
    fi
    rm -f "$out/image.oci.tar"
    echo "$rc"
}

# ----------------------------------------------------------- container modes
# Run repro steps in an already-started container with exec helper "$@".
exec_steps() {
    local rc=0 timed_out=false
    if test -n "$packages"; then
        # shellcheck disable=SC2086 # Package list is validated and space-separated.
        if ! "$@" dnf -y install $packages > "$out/dnf.log" 2>&1; then
            echo "TRIAGE_SETUP_FAILED: dnf install failed (see dnf.log)" > "$out/output.log"
            echo "125 false"
            return 0
        fi
    fi
    timeout --kill-after=10 "$timeout_sec" "$@" bash /triage/repro.sh > "$out/output.log" 2>&1 || rc=$?
    if test "$rc" -eq 124; then timed_out=true; fi
    "$@" cat /etc/os-release > "$out/os-release" 2>&1 || true
    "$@" rpm -qa --qf '%{NVRA}\n' 2>/dev/null | sort > "$out/rpm-qa.txt" || true
    echo "$rc $timed_out"
}

do_container() {
    prepare_run
    ensure_docker_image "$image"
    digest=$(image_digest "$image")
    name="triage-container-$$"
    trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
    docker run -d --name "$name" -v "$out/repro.sh:/triage/repro.sh:ro" \
        --entrypoint sleep "$image" infinity >/dev/null
    local res
    res=$(exec_steps docker exec "$name")
    # shellcheck disable=SC2086 # "<exit> <timed_out>" splits into two args.
    write_result $res
}

do_systemd() {
    prepare_run
    rt=${TRIAGE_SYSTEMD_RUNTIME:-}
    if test -z "$rt"; then
        if podman info >/dev/null 2>&1; then rt=podman; else rt=docker; fi
    fi
    tag="localhost/triage-systemd:$$"
    name="triage-systemd-$$"
    trap '"$rt" rm -f "$name" >/dev/null 2>&1 || true; "$rt" rmi -f "$tag" >/dev/null 2>&1 || true' EXIT
    mkdir -p "$out/context"
    "$rt" pull -q "$image" >/dev/null
    digest=$("$rt" image inspect --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{else}}{{.Id}}{{end}}' "$image")
    "$rt" build -f "$here/containers/systemd.Dockerfile" \
        --build-arg BASE_IMAGE="$image" --build-arg PACKAGES="$packages" \
        -t "$tag" "$out/context" > "$out/build.log" 2>&1
    if test "$rt" = podman; then
        podman run -d --name "$name" --systemd=always \
            -v "$out/repro.sh:/triage/repro.sh:ro" "$tag" >/dev/null
    else
        docker run -d --name "$name" --cgroupns=private \
            --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
            --cap-add=SYS_ADMIN --security-opt seccomp=unconfined \
            --security-opt apparmor=unconfined \
            -v "$out/repro.sh:/triage/repro.sh:ro" "$tag" >/dev/null
    fi
    local state=unknown
    for _ in $(seq 1 60); do
        state=$("$rt" exec "$name" systemctl is-system-running 2>/dev/null || true)
        case "$state" in running|degraded|maintenance|stopping) break ;; esac
        sleep 2
    done
    state=${state:-unknown}
    "$rt" exec "$name" systemctl --failed --no-legend --plain > "$out/failed-units.txt" 2>&1 || true
    # Packages were baked into the image, so exec_steps must not reinstall them.
    local saved_packages=$packages res
    packages=""
    res=$(exec_steps "$rt" exec "$name")
    packages=$saved_packages
    "$rt" exec "$name" journalctl -b --no-pager > "$out/journal.log" 2>&1 || true
    # shellcheck disable=SC2086 # "<exit> <timed_out>" splits into two args.
    write_result $res "$(jq -n --arg rt "$rt" --arg s "$state" '{runtime: $rt, system_state: $s}')"
}

# ------------------------------------------------------------------------ vm
do_vm() {
    prepare_run
    command -v qemu-system-x86_64 >/dev/null || { echo "qemu-system-x86_64 is not installed" >&2; exit 1; }
    ensure_docker_image "$image"
    digest=$(image_digest "$image")
    tag="localhost/triage-vm:$$"
    trap 'docker rmi -f "$tag" >/dev/null 2>&1 || true' EXIT
    mkdir -p "$out/context"
    cp "$here/containers/vm.Dockerfile" "$here/containers/triage-repro.service" "$out/context/"
    cp "$out/repro.sh" "$out/context/repro.sh"
    log "building root filesystem image"
    docker build -f "$out/context/vm.Dockerfile" \
        --build-arg BASE_IMAGE="$image" --build-arg PACKAGES="$packages" \
        -t "$tag" "$out/context" > "$out/build.log" 2>&1
    log "creating ext4 disk"
    docker run --rm --network none -e HOST_IDS="$(id -u):$(id -g)" -v "$out:/out" "$tag" bash -euc '
        size_mb=$(( $(du -sm /rootfs | cut -f1) * 13 / 10 + 512 ))
        truncate -s "${size_mb}M" /out/disk.img
        mkfs.ext4 -q -F -L root -d /rootfs /out/disk.img
        cp /rootfs/boot/triage-vmlinuz /out/vmlinuz
        cp /rootfs/boot/triage-initramfs.img /out/initramfs.img
        cp /rootfs/etc/os-release /out/os-release
        rpm --root /rootfs -qa --qf "%{NVRA}\n" | sort > /out/rpm-qa.txt
        find /rootfs/lib/modules -mindepth 1 -maxdepth 1 -printf "%f\n" | sort -V | tail -n 1 > /out/guest-kernel
        chown "$HOST_IDS" /out/disk.img /out/vmlinuz /out/initramfs.img /out/os-release /out/rpm-qa.txt /out/guest-kernel
    '
    docker rmi -f "$tag" >/dev/null 2>&1 || true

    local accel=tcg cpu=max
    if test -r /dev/kvm && test -w /dev/kvm; then accel=kvm; cpu=host; fi
    log "booting guest kernel $(cat "$out/guest-kernel") with accel=$accel"
    local rc=0 timed_out=false
    timeout --kill-after=10 "$timeout_sec" qemu-system-x86_64 \
        -machine "q35,accel=$accel" -cpu "$cpu" -smp 2 -m 2048 \
        -display none -monitor none -no-reboot \
        -serial "file:$out/serial.log" \
        -kernel "$out/vmlinuz" -initrd "$out/initramfs.img" \
        -append "root=/dev/vda rw console=ttyS0 panic=-1 systemd.show_status=1" \
        -drive "file=$out/disk.img,format=raw,if=virtio" \
        -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
        > "$out/qemu.log" 2>&1 || rc=$?
    if test "$rc" -eq 124; then timed_out=true; fi
    tr -d '\r' < "$out/serial.log" \
        | sed -n '/^TRIAGE_REPRO_BEGIN$/,/^TRIAGE_REPRO_END$/p' > "$out/output.log" || true
    local guest_rc
    guest_rc=$(grep -aoE '^TRIAGE_REPRO_EXIT=[0-9]+' "$out/output.log" | tail -n 1 | cut -d= -f2 || true)
    if test "$keep_disk" -eq 0; then rm -f "$out/disk.img"; fi
    rm -f "$out/vmlinuz" "$out/initramfs.img"
    local guest_exit=${guest_rc:-null}
    if test -z "$guest_rc"; then guest_exit=null; fi
    write_result "${guest_rc:-$rc}" "$timed_out" "$(jq -n \
        --arg accel "$accel" --arg kver "$(cat "$out/guest-kernel")" \
        --argjson qemu_exit "$rc" --argjson guest_exit "$guest_exit" \
        '{accel: $accel, guest_kernel: $kver, qemu_exit_code: $qemu_exit,
          guest_exit_code: $guest_exit,
          fidelity: "direct kernel boot of published packages; no grub, vm-base layout, cloud-init or Azure platform"}')"
}

case "$mode" in
    probe) do_probe ;;
    static) do_static ;;
    container) do_container ;;
    systemd) do_systemd ;;
    vm) do_vm ;;
    *) usage ;;
esac
