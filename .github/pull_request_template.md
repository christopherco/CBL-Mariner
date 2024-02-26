<!--
COMMENT BLOCKS WILL NOT BE INCLUDED IN THE PR.
Feel free to delete sections of the template which do not apply to your PR, or add additional details
-->

###### Merge Checklist  <!-- REQUIRED -->
<!-- You can set them now ([x]) or set them later using the Github UI -->
**All** boxes should be checked before merging the PR *(just tick any boxes which don't apply to this PR)*
- [ ] The toolchain has been rebuilt successfully (or no changes were made to it)
- [ ] The toolchain/worker package manifests are up-to-date
- [ ] Any updated packages successfully build (or no packages were changed)
- [ ] Packages depending on static components modified in this PR (Golang, `*-static` subpackages, etc.) have had their `Release` tag incremented.
- [ ] Package tests (%check section) have been verified with RUN_CHECK=y for existing SPEC files, or added to new SPEC files
- [ ] All package sources are available
- [ ] cgmanifest files are up-to-date and sorted (`./cgmanifest.json`, `./toolkit/scripts/toolchain/cgmanifest.json`, `.github/workflows/cgmanifest.json`)
- [ ] LICENSE-MAP files are up-to-date (`./SPECS/LICENSES-AND-NOTICES/data/licenses.json`, `./SPECS/LICENSES-AND-NOTICES/LICENSES-MAP.md`, `./SPECS/LICENSES-AND-NOTICES/LICENSE-EXCEPTIONS.PHOTON`)
- [ ] All source files have up-to-date hashes in the `*.signatures.json` files
- [ ] `sudo make go-tidy-all` and `sudo make go-test-coverage` pass
- [ ] Documentation has been updated to match any changes to the build system
- [ ] Ready to merge

---

###### PR Description <!-- REQUIRED -->
<!-- This is your changelog message for this PR -->
<!-- Ensure you are covering the following areas in your PR description
   - Describe the problem being fixed.
   - Describe what happens if we don’t fix the problem.
   - Describe what the pull request is changing.  
   - To the best of your knowledge, where potential regressions might arise? 
   - Link to the upstream patch: 
-->

###### Test Methodology
<!-- Describe how this change was validated. -->

<!-- For changes targeted at our stable release, please also include the following -->
- Fix verification
   - Impacted user verification - xxxx
- Package Tests
   - Package build & ptest - xxxx
   - Upgrade/downgrade test - xxxx
- Scenario Test results (or explain why the scenario does not need to be tested)
   - AKS: xxxx
   - Azure VM: xxxx
   - BVT: xxxx
   - BareMetal: xxxx
   - ISO: xxxx
   - Container: xxxx

###### Regression Risk <!-- REQUIRED for PRs targeting our Stable Release. OPTIONAL otherwise -->
To the best of your knowledge, where might potential problems/regressions arise?

###### Does this affect the toolchain?  <!-- REQUIRED -->
<!-- Any packages which are included in the toolchain should be carefully considered. Make sure the toolchain builds with these changes if so. -->
<!-- Update: manifests/package/toolchain_*.txt, pkggen_core_*.txt, update_manifests.sh -->
<!-- To validate: make clean; make workplan REBUILD_TOOLCHAIN=y DISABLE_UPSTREAM_REPOS=y CONFIG_FILE="" ... -->
**YES/NO**

###### Relevant links  <!-- optional -->
<!-- Link to Github issues, ADO URL, NIST CVE -->
- #xxxx
- https://nvd.nist.gov/vuln/detail/CVE-YYYY-XXXX
