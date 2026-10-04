#!/bin/bash
# Spike self-test: run every repro tier against the published image and
# summarize per-tier verdicts. Every tier runs even if an earlier one fails.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/../../.." && pwd)
base="$root/base/build/work/scratch/triage/selftest"
rm -rf "$base"
mkdir -p "$base"
repro="$here/repro.sh"
summary="$base/summary.md"

bash "$repro" probe --out "$base/env.json" || { echo "probe failed" >&2; exit 1; }

printf '| Tier | Status | Verdict | Duration (s) | Notes |\n|---|---|---|---|---|\n' > "$summary"
failures=0
run_tier() {
    local tier=$1 mode=$2 feasible=$3
    shift 3
    if test "$feasible" != true; then
        printf '| %s | skipped | - | - | probe reports tier unavailable |\n' "$tier" >> "$summary"
        return
    fi
    local out="$base/$mode" rc=0
    bash "$repro" "$mode" --out "$out" "$@" > "$base/$mode.stdout" 2> "$base/$mode.stderr" || rc=$?
    if test "$rc" -ne 0 || ! test -f "$out/result.json"; then
        printf '| %s | error | - | - | harness exit %s; see %s.stderr |\n' "$tier" "$rc" "$mode" >> "$summary"
        failures=$((failures + 1))
        return
    fi
    local verdict duration notes
    verdict=$(jq -r .verdict "$out/result.json")
    duration=$(jq -r .duration_s "$out/result.json")
    notes=$(jq -r '[(.accel // empty | "accel=" + .), (.runtime // empty | "runtime=" + .),
        (.system_state // empty | "state=" + .), (.guest_kernel // empty | "kernel=" + .),
        (if .pytest_exit_code == null then empty else "pytest=" + (.pytest_exit_code|tostring) end),
        (if .timed_out then "TIMED OUT" else empty end)] | join(", ")' "$out/result.json")
    local status=pass
    if test "$verdict" != reproduced; then
        status=fail
        failures=$((failures + 1))
    fi
    printf '| %s | %s | %s | %s | %s |\n' "$tier" "$status" "$verdict" "$duration" "$notes" >> "$summary"
}

tier() { jq -r ".tiers.$1" "$base/env.json"; }
run_tier T0-static static "$(tier T0_static)" --script "$here/selftest/t0-static.sh" --pytest
run_tier T1-container container "$(tier T1_container)" --script "$here/selftest/t1-container.sh" --packages dos2unix
run_tier T2-systemd systemd "$(tier T2_systemd)" --script "$here/selftest/t2-systemd.sh"
run_tier T3-vm vm "$(tier T3_vm)" --script "$here/selftest/t3-vm.sh" --timeout 1200

echo '### Environment' >> "$summary"
{ echo '```json'; cat "$base/env.json"; echo '```'; } >> "$summary"
cat "$summary"
if test "$failures" -ne 0; then
    echo "TRIAGE_SELFTEST_FAILURES=$failures"
    exit 1
fi
echo TRIAGE_SELFTEST_OK
