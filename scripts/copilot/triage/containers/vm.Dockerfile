# T3: assemble a bootable Azure Linux root filesystem from the published
# container image and repositories, without kiwi, loop devices or privileges.
# QEMU boots the kernel and initramfs directly, so the guest runs the real
# Azure Linux kernel and systemd, but not grub or the vm-base disk layout.
ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS rootfs
ARG PACKAGES=""
RUN dnf -y install kernel systemd systemd-udev dracut util-linux e2fsprogs \
        iproute procps-ng ${PACKAGES} \
    && dnf clean all
RUN set -eu; \
    kver=$(find /lib/modules -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -V | tail -n 1); \
    test -n "$kver"; \
    dracut --no-hostonly --force --kver "$kver" \
        --add-drivers "virtio_blk virtio_pci virtio_net ext4" \
        /boot/triage-initramfs.img; \
    cp "/lib/modules/$kver/vmlinuz" /boot/triage-vmlinuz; \
    printf '/dev/vda / ext4 defaults 0 1\n' > /etc/fstab; \
    : > /etc/machine-id
COPY repro.sh /opt/triage/repro.sh
COPY triage-repro.service /etc/systemd/system/triage-repro.service
RUN systemctl enable triage-repro.service && systemctl set-default multi-user.target

FROM ${BASE_IMAGE}
RUN dnf -y install e2fsprogs && dnf clean all
COPY --from=rootfs / /rootfs
