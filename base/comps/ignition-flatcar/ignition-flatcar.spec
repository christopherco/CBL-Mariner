%bcond_with check

%global goarch %{_arch}
%ifarch x86_64
%global goarch amd64
%endif
%ifarch aarch64
%global goarch arm64
%endif

%define with_cross  0
%define with_validate  0
%define with_grub  0

%global goipath         github.com/coreos/ignition
%global gomodulesmode   GO111MODULE=on
Version:                2.22.0

%global golicenses      LICENSE
%global godocs          README.md docs/
%global dracutlibdir %{_prefix}/lib/dracut

Name:           ignition-flatcar
Release:        %autorelease
Vendor:         Microsoft Corporation
Distribution:   Azure Linux
Summary:        First boot installer and configuration tool
License:        Apache-2.0
URL:            https://github.com/coreos/ignition
Source0:        https://github.com/coreos/ignition/archive/refs/tags/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
Patch0:         0001-sed-s-coreos-flatcar.patch
Patch1:         0002-config-add-ignition-translation.patch
Patch2:         0003-mod-add-flatcar-ignition-0.36.2.patch
Patch3:         0004-sum-go-mod-tidy.patch
Patch4:         0005-vendor-go-mod-vendor.patch
Patch5:         0006-config-v3_6-convert-ignition-2.x-to-3.x.patch
Patch6:         0007-internal-prv-cmdline-backport-flatcar-patch.patch
Patch7:         0008-provider-qemu-apply-fw_cfg-patch.patch
Patch8:         0009-config-3_6-test-add-ignition-2.x-test-cases.patch
Patch9:         0010-internal-disk-fs-ignore-fs-format-mismatches-for-the.patch
Patch10:        0011-VMware-Fix-guestinfo.-.config.data-and-.config.url-v.patch
Patch11:        0012-config-version-handle-configuration-version-1.patch
Patch12:        0013-config-util-add-cloud-init-detection-to-initial-pars.patch
Patch13:        0014-Revert-drop-OEM-URI-support.patch
Patch14:        0015-internal-resource-url-support-btrfs-as-OEM-partition.patch
Patch15:        0016-translation-support-OEM-and-oem.patch
Patch16:        0017-revert-internal-oem-drop-noop-OEMs.patch
Patch17:        0018-docs-Add-re-added-platforms-to-docs-to-pass-tests.patch
Patch18:        0019-usr-share-oem-oem.patch
Patch19:        0020-internal-exec-stages-mount-Mount-oem.patch
Patch20:        CVE-2026-27141.patch
Patch21:        CVE-2026-39821.patch
Patch22:        CVE-2026-29181.patch
Patch23:        CVE-2026-33814.patch
Patch24:        CVE-2026-56852.patch

BuildRequires: libblkid-devel
BuildRequires: systemd-rpm-macros
BuildRequires: golang

ExcludeArch: %{ix86}

# Requires for 'disks' stage
%if 0%{?fedora}
Recommends: btrfs-progs
%endif
Requires: dosfstools
Requires: gdisk
Requires: dracut
Requires: dracut-network

%description
Ignition is a utility used to manipulate systems during the initramfs.
This includes partitioning disks, formatting partitions, writing files
(regular files, systemd units, etc.), and configuring users. On first
boot, Ignition reads its configuration from a source of truth (remote
URL, network metadata service, hypervisor bridge, etc.) and applies the
configuration.

%prep
%autosetup -p1 -n ignition-%{version}

%build
export LDFLAGS="-X github.com/flatcar/ignition/v2/internal/version.Raw=%{version} -X github.com/flatcar/ignition/v2/internal/distro.selinuxRelabel=false "
export GOFLAGS="-mod=vendor"
go build -ldflags "${LDFLAGS:-}" -o ./ignition internal/main.go

%install
install -m 0755 -d %{buildroot}/%{_libexecdir}
install -d -p %{buildroot}%{_bindir}
install -p -m 0755 ./ignition %{buildroot}%{_bindir}
ln -rsf %{buildroot}%{_bindir}/ignition %{buildroot}%{_libexecdir}/ignition-rmcfg

%if %{with check}
%check
sed -i '34d' ./test
sed -i '/Checking gofmt/,+5d' ./test
sed -i '/Checking gofix.../,/Checking [a-zA-Z0-9_-]\+\.\.\./{ /Checking gofix.../d; /Checking [a-zA-Z0-9_-]\+\.\.\./!d }' ./test
VERSION=%{version} GOARCH=%{goarch} ./test
%endif

%files
%license %{golicenses}
%doc %{godocs}
%{_libexecdir}/ignition-rmcfg
%{_bindir}/ignition

%changelog
%autochangelog
