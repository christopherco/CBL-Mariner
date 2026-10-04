#!/bin/bash
# Prepare the GitHub-hosted runner for the triage repro tiers. Runs during
# Copilot setup steps (before the agent firewall) and in the spike workflow.
set -euo pipefail

image=${TRIAGE_IMAGE:-mcr.microsoft.com/azurelinux/core:4}

sudo apt-get update -q
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    qemu-system-x86 qemu-utils skopeo umoci buildah rpm jq pipx

# GitHub-hosted runners expose /dev/kvm only to root/kvm by default.
if test -e /dev/kvm; then
    echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
        | sudo tee /etc/udev/rules.d/99-triage-kvm.rules >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=kvm
fi

if ! command -v uv >/dev/null; then
    pipx install --quiet uv || echo "uv unavailable; T0 pytest checks will be skipped" >&2
fi

docker pull -q "$image"
if command -v podman >/dev/null; then
    podman pull -q "$image" >/dev/null || echo "podman pull failed; T2 will use docker" >&2
fi
