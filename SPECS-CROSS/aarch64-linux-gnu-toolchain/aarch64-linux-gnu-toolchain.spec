%define  debug_package %{nil}

Summary:        aarch64-linux-gnu cross compiling toolchain
Name:           aarch64-linux-gnu-toolchain
Version:        0.1.0
Release:        1%{?dist}
License:        GPLv2+
Vendor:         Microsoft Corporation
Distribution:   Mariner
Group:          Development/Tools
Source0:        %{name}-%{version}.tar.gz

%description
aarch64-linux-gnu cross compiling toolchain binaries

%prep
%autosetup -c

%build

%install
install -d %{buildroot}/opt/cross
cp -r * %{buildroot}/opt/cross

%files
%defattr(-,root,root)
/opt/cross/*

%changelog
* Fri Feb 19 2021 Chris Co <chrco@microsoft.com> 0.1.0-1
- Initial version