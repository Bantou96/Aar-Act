#!/usr/bin/env bash
# Smoke tests for the aartool CLI.
#
# These check the parts that decide whether a machine gets changed: that a
# target is required, that it must exist in the inventory, that plan never
# passes apply's flags, and that apply refuses to run unattended without --yes.
# A CLI that guards a destructive operation should have those asserted rather
# than assumed.
#
# Run: bash scripts/tests/test_aartool.sh
set -uo pipefail
cd "$(dirname "$0")/.."
AARTOOL="./aartool"

PASS=0 FAIL=0
check() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" == *"$want"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n      want to contain: %s\n      got:             %s\n' "$label" "$want" "$got"
  fi
}
check_rc() {
  local label="$1" want="$2"; shift 2
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" == "$want" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n      want exit %s, got %s\n' "$label" "$want" "$rc"
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
check    "version"          "$($AARTOOL --version 2>&1)"        "aartool"
check    "help lists plan"  "$($AARTOOL --help 2>&1)"           "plan"
check_rc "no args exits 1"  1  "$AARTOOL"
check    "unknown command"  "$($AARTOOL frobnicate 2>&1)"       "Unknown command"
check    "audit points to inspect" "$($AARTOOL audit 2>&1)"     "aartool inspect"
check    "harden points to plan"   "$($AARTOOL harden 2>&1)"    "aartool plan"

# ── Target handling: the guard that stops a fleet-wide run ───────────────────
check    "plan needs target"   "$($AARTOOL plan 2>&1)"                       "--target is required"
check    "apply needs target"  "$($AARTOOL apply 2>&1)"                      "--target is required"
check    "unknown target"      "$($AARTOOL plan -t no-such-host 2>&1)"       "is not a host or group"
check    "missing value"       "$($AARTOOL plan --target 2>&1)"              "needs a value"
check    "positional rejected" "$($AARTOOL plan web-01 2>&1)"                "The target goes after --target"
check    "unknown option"      "$($AARTOOL plan --targets x 2>&1)"           "Unknown option for plan"

# ── plan is not apply ────────────────────────────────────────────────────────
check    "--yes rejected on plan" "$($AARTOOL plan -t x --yes 2>&1)"         "only applies to 'apply'"

# ── apply refuses to run unattended ──────────────────────────────────────────
# stdin is redirected from /dev/null so there is no terminal, which is how this
# would be invoked from CI or a cron job. It must refuse rather than proceed.
check    "apply without a tty" \
         "$($AARTOOL apply -t ubuntu-vm-01 </dev/null 2>&1)" \
         "needs confirmation"

# ── Per-command help ─────────────────────────────────────────────────────────
check    "inspect help" "$($AARTOOL inspect --help 2>&1)" "Changes nothing"
check    "plan help"    "$($AARTOOL plan --help 2>&1)"    "--target"
check    "apply help"   "$($AARTOOL apply --help 2>&1)"   "--yes"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
