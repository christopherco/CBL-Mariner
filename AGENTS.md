# Azure Linux — Agent Guide

For project context and architecture, see [`.github/copilot-instructions.md`](.github/copilot-instructions.md).

## Copilot cloud sessions (fork rollout)

Setup prepares `localhost/copilot-ci` from the unchanged `.azldev-version` pin.
azldev and mock are **container tools**, not Ubuntu host tools. From the checkout:

```sh
bash scripts/copilot/run.sh readiness
bash scripts/copilot/run.sh azldev comp render -p <name> --fail-on-error
bash scripts/copilot/run.sh azldev comp build -p <name>
bash scripts/copilot/run.sh mock-shell --add-package /workdir/base/out/rpms/<channel>/<name>.rpm -- <binary> --version
```

For build/inspection/local-RPM testing in one disposable container, use
`bash scripts/copilot/run.sh session` with a quoted heredoc. Inside, use ordinary
`azldev` and `mock` commands from `/workdir`; host paths become `/workdir/...`.
The wrapper preserves argument boundaries and stdin without a TTY. Each host
invocation has a fresh mock root; group related commands into one session.
The complete regression is:
`bash scripts/copilot/run.sh session bash /workdir/.github/workflows/containers/copilot-tracer.sh`.
Focused environment checks: `bash scripts/copilot/test.sh`.

Keep scratch files/logs in the configured work directory (`base/build/work/scratch`
for this project); RPM outputs are in `base/out`. Inspect exact local RPMs with
`mock --copyin` and `rpm -qip`/`rpm -qlp` before testing. Never substitute repository
packages or install Azure Linux RPMs on the host. Failure diagnostics belong in
the regression tracer, not normal setup.

Current-session public CA trust is read by the container entrypoint and mock user
config at command time, **after** firewall injection. No CA is baked into the image.
Keep the agent firewall, proxy and TLS verification enabled. Ask for missing
source domains to be allowlisted; do not bypass blocked downloads, managed CA
mounts, or permissions. The wrapper uses only the established mock capability
flags; never add `--privileged`, host credentials/home, or the Docker socket.
Docker workloads are not comprehensively bounded by the agent firewall.

Load the azldev/build/mock skills before packaging work. For component changes,
refresh locks, render, build and smoke-test; after committing component inputs,
re-render and amend so Release/changelog and lock checks match committed history.
Do not commit pilot logs, RPMs, or session CA material. Missing/stale images or
trust fail explicitly; readiness alone is not build success. This rollout is
tested for x86_64 Azure Linux 4.0-stage2 only; other targets and image/VM workflows
are unverified. Default-branch activation is a separate reviewer action.

## Mandatory Testing

> **USE YOUR BEST JUDGEMENT**, but when in doubt, test. If your change could affect the built RPMs, smoke-test before reporting success. See [`azldev-mock`](.agents/skills/azldev-mock/SKILL.md).

### Examples of changes that should trigger a final test prior to sign-off (not an exhaustive list)

- Version bumps or pinning a new upstream version
- Adding, modifying, or removing overlays (trivial edits may only require `render` verification, but when in doubt, do a full build + smoke-test)
- Changing build config (`build.defines`, `build.with`, `build.without`)
- Modifying local spec files or source files (again, trivial edits may not require a full rebuild, but when in doubt, test)
- Adding a new component (first build)

### Examples of changes that may not require testing (no effect on RPM output)

- Moving a component definition between files (inline `components.toml` → dedicated `<name>.comp.toml` or vice versa)
- Editing only component metadata fields (e.g., overlay descriptions, build descriptions, comments) without changing actual build config or overlays
- Adding or editing TOML comments
- Pure documentation or formatting changes

### Minimum required testing

1. **Build** — `azldev comp build -p <name>` succeeds, RPMs appear in `base/out/`.
2. **Inspect** — Use `mock --copyin` to copy the RPM into the chroot and inspect with `rpm -qlp` without installing. See [`azldev-mock`](.agents/skills/azldev-mock/SKILL.md).
3. **Smoke-test** — Use a mock chroot (`azldev adv mock shell --add-package /path/to/rpm`) to install and validate basic functionality (e.g., `<binary> --version`, service starts, library loads). See [`azldev-mock`](.agents/skills/azldev-mock/SKILL.md).

Do NOT skip testing for changes that affect RPM output. Do NOT tell the user "the build succeeded" without also running the smoke-test. If testing cannot be performed (e.g., the package has no runnable binary, or some other issue), explicitly document why and what was verified instead.

## Conventions

- Always run `azldev comp list -p <name> -q -O json` before modifying a component.
- Prefer overlays over forking/local specs when customizing upstream packages.
- After modifying overlays or component config, re-render with `azldev comp render -p <name>` and inspect `specs/<first-char>/<name>/` to verify the result. This is the fastest verification path.
  - Note: Changing a global snapshot time may affect all components that depend on it, potentially causing widespread rebuilds. Full re-render is time-consuming, but may be done by `azldev comp render -a --clean-stale`.
- **Always re-run `azldev comp update -p <name>` before opening a PR**, even for minor edits — lock fingerprints are computed from the full component config, and the `Update Locks` CI check runs against the committed state. See [`azldev-update-component`](.agents/skills/azldev-update-component/SKILL.md).
- **Every commit that touches a component bumps `%changelog` / `Release:` on the next render** (rpmautospec walks `git log` for the spec). After committing, re-render and amend so the spec tracks your commit, otherwise `Check Rendered Specs` will fail. See [`azldev-update-component`](.agents/skills/azldev-update-component/SKILL.md) for the finalize-and-amend pattern, plus the pin-bump variant.
- Use `prep-sources` for deeper debugging: `azldev comp prep-sources -p <name> --skip-overlays --force -o <pre-dir> -q` and `azldev comp prep-sources -p <name> --force -o <post-dir> -q` to diff pre/post overlay output when you need to understand what upstream provides vs. what overlays change. Always use `--force` to overwrite an existing output dir, `rm -rf` requires user confirmation which is disruptive.
- Follow the inner loop cycle: investigate → modify → render → build → test → inspect. See [`azldev-build-component`](.agents/skills/azldev-build-component/SKILL.md).
  - Note: Use your best judgement, some packages are VERY slow to build (e.g., `kernel`), in those cases you may want to do multiple iterations of investigate → modify → verify with `render` before doing a full build + test.
- `prep-sources -o <dir>` output is ad-hoc (user-chosen dir). `comp build` output goes to project-configured dirs (`base/out/`, `base/build/`). Don't conflate them.
- For temporary files, ensure they are all placed inside the project's defined work directory (`azldev config dump -q -f json 2>&1 | grep 'workDir'`). Example commands use `base/build/work/scratch/`, and all temp directories should be inside it unless there's a specific reason not to be.

> **Do NOT use `/tmp` or bare `mktemp -d`** — always use `base/build/work/scratch/` (or a subdirectory) for temporary files. This avoids permission issues and keeps all working files inside the project tree.

Example: `workDir="/home/user/azurelinux/base/build/work"`, use "./base/build/work/scratch/" for all temp dirs, or a subdir like "./base/build/work/scratch/thing".

## Skills

Detailed workflows live in skills (loaded on-demand when relevant):

| Task | Skill |
| ---- | ----- |
| Use azldev or edit distro configuration | [`azldev`](.agents/skills/azldev/SKILL.md) |
| Build a component, debug build failures | [`azldev-build-component`](.agents/skills/azldev-build-component/SKILL.md) |
| Bump a component's upstream pin (lock files) | [`azldev-update-component`](.agents/skills/azldev-update-component/SKILL.md) |
| Add a new component to the distro | [`azldev-add-component`](.agents/skills/azldev-add-component/SKILL.md) |
| Remove component(s) from the distro | [`azldev-remove-component`](.agents/skills/azldev-remove-component/SKILL.md) |
| Diagnose and fix overlay issues | [`azldev-overlays`](.agents/skills/azldev-overlays/SKILL.md) |
| Test and inspect packages in mock chroot | [`azldev-mock`](.agents/skills/azldev-mock/SKILL.md) |
| Review component for hygiene and best practices | [`azldev-comp-toml` review checklist](.agents/skills/azldev-comp-toml/SKILL.md#review-checklist) |
| Build, boot, test, or configure images | [`azldev-image`](.agents/skills/azldev-image/SKILL.md) |
| Triage Koji build failures | [`skill-koji-triage`](.agents/skills/skill-koji-triage/SKILL.md) |
| Batch-triage build failures from results file | [`skill-mass-triage`](.agents/skills/skill-mass-triage/SKILL.md) |
| Fix Stage 1 Fedora mirror dependency gaps (injections) | [`skill-fedora-mirror-injections`](.agents/skills/skill-fedora-mirror-injections/SKILL.md) |
| Inspect Koji AKS cluster health and node pools | [`skill-aks-health`](.agents/skills/skill-aks-health/SKILL.md) |
| Resolve Koji AKS deployment context | [`skill-deployment-context`](.agents/skills/skill-deployment-context/SKILL.md) |
| KQL queries for Koji logs, pods, and events | [`skill-kql-queries`](.agents/skills/skill-kql-queries/SKILL.md) |
| Query Azure Monitor metrics for Koji AKS | [`skill-metrics`](.agents/skills/skill-metrics/SKILL.md) |

> **Azure infra workflow ordering:** Before running any KQL log queries, metrics queries, or AKS health checks, **always resolve deployment context first** using [`skill-deployment-context`](.agents/skills/skill-deployment-context/SKILL.md). This provides the resource group, cluster name, subscription, and Log Analytics workspace needed by the other Azure skills.

## Directory Guidance

- **Components:** [`base/comps/AGENTS.md`](base/comps/AGENTS.md) — file organization rules
- **Distro config:** [`distro/AGENTS.md`](distro/AGENTS.md) — build defaults, shared config
