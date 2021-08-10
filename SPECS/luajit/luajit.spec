%global rctag beta3

Name:           luajit
Version:        2.1.0
%global apiver %(v=%{version}; echo ${v%.${v#[0-9].[0-9].}})
%global srcver %{version}%{?rctag:-%{rctag}}
Release:        0.20%{?rctag:%{rctag}}%{?dist}
Summary:        Just-In-Time Compiler for Lua
License:        MIT
URL:            http://luajit.org/
Source0:        http://luajit.org/download/LuaJIT-%{srcver}.tar.gz

# Patches from https://github.com/siddhesh/LuaJIT.git
# Generated from v2.1 branch against the 2.1.0-beta3 tag.
# Some patches, as indicated below, have been modified to account for merge
# commits, so care needs to be taken when auto-generating patches so that
# existing patches are not replaced.

# Merge commit
Patch1: 0001-Fix-LJ_MAX_JSLOTS-assertion-in-rec_check_slots.patch
# Merge commit
Patch2: 0002-Add-missing-LJ_MAX_JSLOTS-check.patch
Patch3: 0003-MIPS-Use-precise-search-for-exit-jump-patching.patch
Patch4: 0004-MIPS-Fix-handling-of-spare-long-range-jump-slots.patch
Patch5: 0005-MIPS64-Add-soft-float-support-to-JIT-compiler-backen.patch
Patch6: 0006-FreeBSD-x64-Avoid-changing-resource-limits-if-not-ne.patch
Patch7: 0007-Remove-unused-define.patch
Patch8: 0008-Modify-fix-for-warning-from-ar.patch
Patch9: 0009-x64-LJ_GC64-Fix-emit_rma.patch
Patch10: 0010-PPC-Add-soft-float-support-to-interpreter.patch
Patch11: 0011-Use-https-for-freelists.org-links.patch
Patch12: 0012-x64-LJ_GC64-Fix-fallback-case-of-asm_fuseloadk64.patch
Patch13: 0013-PPC-Add-soft-float-support-to-JIT-compiler-backend.patch
Patch14: 0014-x64-LJ_GC64-Fix-type-check-only-variant-of-SLOAD.patch
Patch15: 0015-MIPS64-Hide-internal-function.patch
# Merge commit
Patch16: 0016-DynASM-x86-Fix-potential-REL_A-overflow.patch
Patch17: 0017-LJ_GC64-Fix-ir_khash-for-non-string-GCobj.patch
Patch18: 0018-LJ_GC64-Make-ASMREF_L-references-64-bit.patch
Patch19: 0019-Fix-FOLD-rule-for-strength-reduction-of-widening.patch
Patch20: 0020-ARM64-Fix-assembly-of-HREFK.patch
Patch21: 0021-MIPS64-Fix-register-allocation-in-assembly-of-HREF.patch
Patch22: 0022-ARM64-Fix-xpcall-error-case.patch
Patch23: 0023-Fix-saved-bytecode-encapsulated-in-ELF-objects.patch
Patch24: 0024-ARM64-Fix-xpcall-error-case-really.patch
Patch25: 0025-MIPS64-Fix-xpcall-error-case.patch
Patch26: 0026-Fix-IR_BUFPUT-assembly.patch
# This patch gets dropped when merged from master to v2.1.
# Patch27: 0027-Fix-string.format-c-0.patch
Patch28: 0028-Fix-ARMv8-32-bit-subset-detection.patch
Patch29: 0029-Fix-LuaJIT-API-docs-for-LUAJIT_MODE_.patch
Patch30: 0030-MIPS64-Fix-soft-float-0.0-vs.-0.0-comparison.patch
# Merge commit
Patch31: 0031-FFI-Don-t-assert-on-1LL-5.2-compatibility-mode-only.patch
# Merge commit
Patch32: 0032-Fix-GCC-7-Wimplicit-fallthrough-warnings.patch
# Merge commit
Patch33: 0033-Clear-stack-after-print_jit_status-in-CLI.patch
Patch34: 0034-Fix-rechaining-of-pseudo-resurrected-string-keys.patch
Patch35: 0035-DynASM-x86-Add-BMI1-and-BMI2-instructions.patch
Patch36: 0036-Give-expected-results-for-negative-non-base-10-numbe.patch
Patch37: 0037-FFI-Add-tonumber-specialization-for-failed-conversio.patch
Patch38: 0038-Bump-copyright-date-to-2018.patch
# Merge commit
Patch39: 0039-FFI-Make-FP-to-U64-conversions-match-JIT-backend-beh.patch
Patch40: 0040-x86-x64-Check-for-jcc-when-using-xor-r-r-in-emit_loa.patch
# Merge commit
Patch41: 0041-PPC-NetBSD-Fix-endianess-check.patch
Patch42: 0042-DynASM-x86-Add-FMA3-instructions.patch
Patch43: 0043-x86-Disassemble-FMA3-instructions.patch
Patch44: 0044-From-Lua-5.3-assert-accepts-any-type-of-error-object.patch
Patch45: 0045-Windows-Add-UWP-support-part-1.patch
Patch46: 0046-ARM64-Fix-write-barrier-in-BC_USETS.patch
Patch47: 0047-ARM64-Fix-exit-stub-patching.patch
Patch48: 0048-DynASM-Fix-warning.patch
Patch49: 0049-DynASM-x86-Fix-vroundps-vroundpd-encoding.patch
Patch50: 0050-Fix-memory-probing-allocator-to-check-for-valid-end-.patch
Patch51: 0051-MIPS-MIPS64-Fix-TSETR-barrier-again.patch
Patch52: 0052-Actually-implement-maxirconst-trace-limit.patch
Patch53: 0053-Better-detection-of-MinGW-build.patch
# Merge commit
Patch54: 0054-Fix-overflow-of-snapshot-map-offset.patch
Patch55: 0055-DynASM-PPC-Fix-shadowed-variable.patch
Patch56: 0056-DynASM-MIPS-Fix-shadowed-variable.patch
Patch57: 0057-Fix-MinGW-build.patch
Patch58: 0058-Fix-os.date-for-wider-libc-strftime-compatibility.patch
Patch59: 0059-Improve-luaL_addlstring.patch
Patch60: 0060-Fix-arm64-register-allocation-issue-for-XLOAD.patch
Patch61: 0061-Fix-arm64-register-allocation-issue-for-XLOAD.patch
Patch62: 0062-Remove-redundant-emit_check_ofs.patch
Patch63: 0063-aarch64-Use-the-xzr-register-whenever-possible.patch
Patch64: 0064-Merge-in-LuaJIT-test-cleanup-into-the-main-repo.patch
Patch65: 0065-Add-support-for-FNMADD-and-FNMSUB.patch
Patch66: 0066-Fix-os.date-for-timezone-change-awareness.patch
Patch67: 0067-Revert-FFI-Make-FP-to-U64-conversions-match-JIT-back.patch
Patch68: 0068-bench-Fix-build-warnings.patch
Patch69: 0069-Guard-against-undefined-behaviour-when-casting-from-.patch
Patch70: 0070-Fix-build-erro-with-fnmsub-fusing.patch
Patch71: 0071-aarch64-better-float-to-unsigned-int-conversion.patch
Patch72: 0072-Better-behaviour-for-float-to-uint32_t-conversions.patch
Patch73: luajit-s390x.patch
Patch74: arm-Fix-up-condition-codes-for-conditional-arithmeti.patch
Patch75: bugfix-fixed-a-segfault-when-unsinking-64-bit-pointers.patch
Patch76: remove-setrlimit-on-freebsd.patch
Patch77: test-check-for-package_searchers-only-in-compat5_2.patch
Patch78: patch-for-ppc64-support.patch
Patch79: luajit-openresty-features.patch
Patch80: luajit-update-20190925.patch

ExclusiveArch:  %{arm} %{ix86} x86_64 %{mips} aarch64 s390x ppc64le

BuildRequires:  gcc
BuildRequires:  make

%description
LuaJIT implements the full set of language features defined by Lua 5.1.
The virtual machine (VM) is API- and ABI-compatible to the standard
Lua interpreter and can be deployed as a drop-in replacement.

%package devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description devel
This package contains development files for %{name}.

%prep
%autosetup -n LuaJIT-%{srcver} -p1

# Enable Lua 5.2 features
sed -i -e '/-DLUAJIT_ENABLE_LUA52COMPAT/s/^#//' src/Makefile

# preserve timestamps (cicku)
sed -i -e '/install -m/s/-m/-p -m/' Makefile

%build
# Q= - enable verbose output
# E= @: - disable @echo messages
# NOTE: we use amalgamated build as per documentation suggestion doc/install.html
make amalg Q= E=@: PREFIX=%{_prefix} TARGET_STRIP=: \
           CFLAGS="%{build_cflags}" LDFLAGS="%{build_ldflags}" \
           MULTILIB=%{_lib} \
           %{?_smp_mflags}

%install
# PREREL= - disable -betaX suffix
# INSTALL_TNAME - executable name
%make_install PREFIX=%{_prefix} \
              MULTILIB=%{_lib}

rm -rf _tmp_html ; mkdir _tmp_html
cp -a doc _tmp_html/html

# Remove static .a
find %{buildroot} -type f -name *.a -delete -print

%ldconfig_scriptlets

%check

# Don't fail the build on a check failure.
make check || true

%files
%license COPYRIGHT
%doc README
%{_bindir}/%{name}
%{_bindir}/%{name}-%{srcver}
%{_libdir}/lib%{name}-*.so.*
%{_mandir}/man1/%{name}.1*
%{_datadir}/%{name}-%{srcver}/

%files devel
%doc _tmp_html/html/
%{_includedir}/%{name}-%{apiver}/
%{_libdir}/lib%{name}-*.so
%{_libdir}/pkgconfig/%{name}.pc

%changelog
* Thu Jul 22 2021 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.20beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_35_Mass_Rebuild

* Tue Jan 26 2021 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.19beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_34_Mass_Rebuild

* Tue Jul 28 2020 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.18beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_33_Mass_Rebuild

* Wed Jan 29 2020 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.17beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_32_Mass_Rebuild

* Wed Sep 25 2019 Siddhesh Poyarekar <sid@reserved-bit.com> - 2.1.0-0.16beta3
- New API functions jit.prngstate and thread.exdata from OpenResty.
- Bug fixes in ppc64le and aarch64.
- Optimised string hash function for SSE4.2
- Miscellaneous bug fixes.

* Thu Jul 25 2019 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.16beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_31_Mass_Rebuild

* Tue Jun 25 2019 Siddhesh Poyarekar <sid@reserved-bit.com> - 2.1.0-0.15beta3
- Port JIT features and fixes from openresty/luajit2.

* Wed Jun 19 2019 Siddhesh Poyarekar <sid@reserved-bit.com> - 2.1.0-0.14beta3
- Patch for PPC64 support.

* Wed Jun 19 2019 Siddhesh Poyarekar <sid@reserved-bit.com> - 2.1.0-0.13beta3
- arm: Fix up condition codes for conditional arithmetic insn.
- bugfix: fixed a segfault when unsinking 64-bit pointers.
- Remove setrlimit on FreeBSD.
- test: Check for package.searchers only in compat5.2.

* Mon Jun 17 07:10:20 CEST 2019 Igor Gnatenko <ignatenkobrain@fedoraproject.org> - 2.1.0-0.12beta3
- Enable Lua 5.2 compatibility

* Wed Apr 24 2019 Siddhesh Poyarekar <sid@reserved-bit.com> - 2.1.0-0.11beta3
- Add s390x support.

* Fri Apr 12 2019 Siddhesh Poyarekar <sid@reserved-bit.com> - 2.1.0-0.10beta3
- Add upstream bug fixes from the v2.1 branch.
- Add bug fixes from https://github.com/siddhesh/LuaJIT.git
- Incorporate tests and benchmarks from LuaJIT-test-cleanup.

* Fri Feb 01 2019 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.9beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_30_Mass_Rebuild

* Fri Jul 13 2018 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.8beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_29_Mass_Rebuild

* Thu Feb 08 2018 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.7beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_28_Mass_Rebuild

* Thu Aug 03 2017 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.6beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_27_Binutils_Mass_Rebuild

* Wed Jul 26 2017 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.5beta3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_27_Mass_Rebuild

* Mon May 15 2017 Tom Callaway <spot@fedoraproject.org> - 2.1.0-0.4beta3
- Update to 2.1.0-beta3

* Fri Feb 10 2017 Fedora Release Engineering <releng@fedoraproject.org> - 2.1.0-0.3beta2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_26_Mass_Rebuild

* Mon Aug 29 2016 Igor Gnatenko <ignatenko@redhat.com> - 2.1.0-0.2beta2
- Add aarch64 to ExclusiveArch

* Mon Aug 29 2016 Igor Gnatenko <ignatenko@redhat.com> - 2.1.0-0.1beta2
- Update to 2.1.0-beta2 (RHBZ #1371158)

* Mon May 09 2016 Dan Horák <dan[at]danny.cz> - 2.0.4-5
- set ExclusiveArch also for Fedora

* Thu Feb 04 2016 Fedora Release Engineering <releng@fedoraproject.org> - 2.0.4-4
- Rebuilt for https://fedoraproject.org/wiki/Fedora_24_Mass_Rebuild

* Fri Aug 07 2015 Oliver Haessler <oliver@redhat.com> - 2.0.4-3
- only build x86_64 on EPEL as luajit has no support for ppc64

* Wed Jun 17 2015 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.0.4-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_23_Mass_Rebuild

* Thu May 21 2015 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.4-1
- 2.0.4

* Sun Aug 17 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.0.3-4
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_22_Mass_Rebuild

* Wed Jul 09 2014 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.3-3
- rebuild against lua 5.2

* Sat Jun 07 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.0.3-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_Mass_Rebuild

* Thu Mar 13 2014 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.3-1
- 2.0.3 upstream release

* Sun Dec 15 2013 Clive Messer <clive.messer@communitysqueeze.org> - 2.0.2-9
- Apply luajit-path64.patch on x86_64.

* Mon Dec 09 2013 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.2-8
- Fix strip (thanks Ville Skyttä)

* Fri Dec 06 2013 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.2-7
- Fix executable binary

* Mon Dec 02 2013 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.2-6
- Fix .pc

* Sun Dec 01 2013 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.2-5
- Fixed short-circuit builds (schwendt)

* Sat Nov 30 2013 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.2-4
- Preserve timestamps at install

* Fri Nov 29 2013 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.2-3
- fixed some issues found by besser82
- Moved html-docs to -devel subpackage (besser82)
 
* Thu Nov 28 2013 Igor Gnatenko <i.gnatenko.brain@gmail.com> - 2.0.2-2
- Re-update

* Mon Sep 02 2013 Muayyad Alsadi <alsadi@gmail.com> - 2.0.2-1
- Update to new upstream version
- remove PREREL= option

* Mon Feb 06 2012 Andrei Lapshin - 2.0.0-0.4.beta9
- Update to new upstream version
- Rename main executable to luajit
- Remove BuildRoot tag and %%clean section

* Sun Oct 09 2011 Andrei Lapshin - 2.0.0-0.3.beta8
- Enable debug build
- Enable verbose build output
- Move libluajit-*.so to -devel
- Add link to upstream hotfix #1

* Tue Jul 05 2011 Andrei Lapshin <alapshin@gmx.com> - 2.0.0-0.2.beta8
- Append upstream hotfix #1

* Sun Jul 03 2011 Andrei Lapshin <alapshin@gmx.com> - 2.0.0-0.1.beta8
- Initial build
