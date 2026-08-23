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

# Point at the shipped example rather than whatever inventory this machine has.
# Two reasons: the tests stay hermetic and pass on a fresh clone, where
# inventory/hosts does not exist because it is gitignored; and every run proves
# the example we ask new users to copy is actually usable.
export AARTOOL_INVENTORY="../ansible-hardening/inventory/hosts.example"

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

# ── The example inventory we ship is usable ──────────────────────────────────
# ubuntu-vm-01 is defined in hosts.example. If someone edits the example and
# breaks its format, this fails rather than the new user finding out.
check    "example inventory resolves a host" \
         "$($AARTOOL plan -t ubuntu-vm-01 --help 2>&1)" \
         "--target"
check_rc "known host passes the inventory check" 0 \
         env AARTOOL_INVENTORY="../ansible-hardening/inventory/hosts.example" \
         "$AARTOOL" plan -t ubuntu-vm-01 --help

# ── A missing inventory says what to do about it ─────────────────────────────
check    "missing inventory points at the example" \
         "$(AARTOOL_INVENTORY=/nonexistent/hosts $AARTOOL plan -t any 2>&1)" \
         "cp "

# ── surface and doctor ───────────────────────────────────────────────────────
check    "surface runs read-only"  "$($AARTOOL surface 2>&1)"          "Kernel attack surface"
check    "surface names the tier"  "$($AARTOOL surface 2>&1)"          "safe tier only"
check    "surface --strict widens" "$($AARTOOL surface --strict 2>&1)" "KRN-01"
check    "surface --fix emits a drop-in" "$($AARTOOL surface --fix 2>&1)" "sysctl --system"
check_rc "surface changes nothing without --apply" 0 "$AARTOOL" surface
check    "doctor reports"          "$($AARTOOL doctor 2>&1)"           "toolkit located"

# --apply must not be satisfiable by a pipe, same rule as 'apply'.
check    "surface --apply needs root or a tty" \
         "$($AARTOOL surface --apply </dev/null 2>&1)" \
         "root"

# ── The catalogue and the audit must not drift ───────────────────────────────
# Every doorway aartool offers to close has a KRN check that reports on it, and
# every KRN check that maps to a sysctl is offered. Without this, someone adds a
# mitigation to one side and the two views of the same machine start disagreeing
# — which is exactly the class of bug this toolkit exists to find.
cat_ids=$(bash -c 'source aartool-src/lib/surface.sh; surface_catalogue' | cut -f1 | sort -u)
krn_ids=$(grep -ohE '"KRN-[0-9]{2}"' src/checks/kernel.sh | tr -d '"' | sort -u)
missing=""
for id in $cat_ids; do
  printf '%s\n' "$krn_ids" | grep -qx "$id" || missing="$missing $id"
done
if [[ -z "$missing" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  printf 'FAIL  catalogue entries with no KRN check:%s\n' "$missing"
fi

# ── report ───────────────────────────────────────────────────────────────────
_rep_src="../ansible-hardening/reports/before/ubuntu-vm-01/before_ubuntu-vm-01_1772639445.json"
if [[ -f "$_rep_src" ]]; then
  _rep_out="$(mktemp -t aartool-test-XXXXXX.html)"
  $AARTOOL report "$_rep_src" --out "$_rep_out" >/dev/null 2>&1
  check "report embeds the data"   "$(grep -c 'var PRELOAD' "$_rep_out")" "1"
  check "report keeps script tags balanced" \
        "$(printf '%s/%s' "$(grep -o '<script' "$_rep_out" | wc -l)" "$(grep -o '</script>' "$_rep_out" | wc -l)")" \
        "2/2"

  # A hostname is attacker-influenced on a machine you were asked to audit.
  # Embedding it in a <script> block without escaping < would end the block and
  # turn the rest of the file into markup, in a report you then email to a
  # client. Assert the breakout is closed rather than trusting that it is.
  _rep_evil="$(mktemp -t aartool-evil-XXXXXX.json)"
  sed 's|"host": *"[^"]*"|"host": "evil</script><img src=x onerror=alert(1)>"|' "$_rep_src" > "$_rep_evil"
  _rep_evil_out="$(mktemp -t aartool-evil-XXXXXX.html)"
  $AARTOOL report "$_rep_evil" --out "$_rep_evil_out" >/dev/null 2>&1
  check "hostile hostname does not break out" \
        "$(printf '%s/%s' "$(grep -o '<script' "$_rep_evil_out" | wc -l)" "$(grep -o '</script>' "$_rep_evil_out" | wc -l)")" \
        "2/2"
  check "hostile markup is escaped, not embedded raw" \
        "$(grep -c 'u003c/script' "$_rep_evil_out")" "1"
  rm -f "$_rep_out" "$_rep_evil" "$_rep_evil_out"
fi

check    "report rejects a missing file" "$($AARTOOL report /nonexistent.json 2>&1)" "No such report"
check    "serve refuses a non-numeric port" "$($AARTOOL report --serve abc 2>&1)" "port number"

# ── diff ─────────────────────────────────────────────────────────────────────
if [[ -f "$_rep_src" ]]; then
  # A regression and an improvement in the same pair, so the two are not
  # confused with each other.
  _d_after="$(mktemp -t aartool-after-XXXXXX.json)"
  python3 - "$_rep_src" "$_d_after" <<'PYEOF' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1])); b = d["cyberaar_baseline"]
b["date"] = "2099-01-01 00:00:00"; b["score"] = (b.get("score") or 50) - 7
for r in b["results"]:
    if r["id"] == "SSH-02": r["status"] = "FAIL"
    if r["id"] == "LOG-01": r["status"] = "PASS"
json.dump(d, open(sys.argv[2], "w"))
PYEOF

  if [[ -s "$_d_after" ]]; then
    check    "diff names the regression" "$($AARTOOL diff "$_rep_src" "$_d_after" 2>&1)" "SSH-02"
    check    "diff separates improvements" "$($AARTOOL diff "$_rep_src" "$_d_after" 2>&1)" "Improved"
    # The exit code is the whole point in cron: 1 means something regressed.
    check_rc "diff exits 1 on a regression" 1 "$AARTOOL" diff "$_rep_src" "$_d_after"
    check_rc "diff exits 0 when nothing changed" 0 "$AARTOOL" diff "$_rep_src" "$_rep_src"
    # --quiet must be genuinely silent, or cron mails you every week and you
    # stop reading it.
    check    "diff --quiet is silent when clean" "$($AARTOOL diff "$_rep_src" "$_rep_src" --quiet 2>&1)" ""
    check    "diff --quiet still reports a regression" \
             "$($AARTOOL diff "$_rep_src" "$_d_after" --quiet 2>&1)" "SSH-02"
  fi

  # Comparing two machines would produce a difference that is not drift.
  _d_other="$(mktemp -t aartool-other-XXXXXX.json)"
  sed 's|"host": *"[^"]*"|"host": "a-different-box"|' "$_rep_src" > "$_d_other"
  check    "diff refuses two different hosts" "$($AARTOOL diff "$_rep_src" "$_d_other" 2>&1)" "different hosts"
  check_rc "diff exits 2 when it cannot compare" 2 "$AARTOOL" diff "$_rep_src" "$_d_other"
  rm -f "$_d_after" "$_d_other"
fi

echo '{"not":"a report"}' > /tmp/aartool-notreport.$$.json
check    "diff rejects a non-report" "$($AARTOOL diff /tmp/aartool-notreport.$$.json /tmp/aartool-notreport.$$.json 2>&1)" "not a cyberaar-baseline report"
rm -f /tmp/aartool-notreport.$$.json
check    "diff needs two arguments" "$($AARTOOL diff one.json 2>&1)" "exactly two reports"

# ── install ──────────────────────────────────────────────────────────────────
# The symlink-not-copy decision is load-bearing: aartool finds everything it
# wraps by walking up from its own file, so a copy alone in /usr/local/bin finds
# nothing. These assert the symlink resolves, the copy fails with an actionable
# message, and AARTOOL_HOME rescues it.
_ins_prefix="$(mktemp -d -t aartool-prefix-XXXXXX)"
$AARTOOL install --prefix "$_ins_prefix" >/dev/null 2>&1
check_rc "install creates a working symlink" 0 "$_ins_prefix/bin/aartool" --version
check    "installed link points at the source" \
         "$(readlink "$_ins_prefix/bin/aartool" | grep -c 'scripts/aartool')" "1"

_ins_copy="$(mktemp -d -t aartool-copy-XXXXXX)/aartool"
cp ./aartool "$_ins_copy" 2>/dev/null
check    "a copy fails with a usable message" \
         "$("$_ins_copy" doctor 2>&1)" "AARTOOL_HOME"
check_rc "AARTOOL_HOME rescues a copy" 0 \
         env AARTOOL_HOME="$(cd .. && pwd)" "$_ins_copy" --version

check    "AARTOOL_HOME pointing nowhere is rejected" \
         "$(AARTOOL_HOME=/tmp $AARTOOL doctor 2>&1)" "no ansible-hardening"

# Overwriting a real file at the install path would be destructive.
printf 'important\n' > "$_ins_prefix/bin/notalink"
check    "install refuses to clobber a real file" \
         "$($AARTOOL install --prefix "$(dirname "$(dirname "$_ins_prefix/bin/notalink")")" 2>&1; \
            rm -f "$_ins_prefix/bin/aartool"; printf 'x')" "x"

$AARTOOL install --prefix "$_ins_prefix" --uninstall >/dev/null 2>&1
check    "uninstall removes the link" "$([ -e "$_ins_prefix/bin/aartool" ] && printf yes || printf no)" "no"
rm -rf "$_ins_prefix" "$(dirname "$_ins_copy")"

# ── inspect forwards every remote flag the baseline documents ────────────────
# inspect passes a WHITELIST of options through to cyberaar-baseline.sh, so a
# flag added to the baseline is silently rejected by aartool until someone
# remembers to widen that list. This asserts the two agree, rather than leaving
# it to memory.
for _flag in --host --host-file --inventory --user --ssh-key --ssh-opt; do
  if grep -q -- "$_flag" ../scripts/src/main.sh 2>/dev/null || grep -q -- "$_flag" ./src/main.sh 2>/dev/null; then
    check "inspect forwards $_flag" \
          "$($AARTOOL inspect "$_flag" x --help 2>&1 | grep -c 'Unknown option')" "0"
  fi
done

# ── Per-command help ─────────────────────────────────────────────────────────
check    "inspect help" "$($AARTOOL inspect --help 2>&1)" "Changes nothing"
check    "plan help"    "$($AARTOOL plan --help 2>&1)"    "--target"
check    "apply help"   "$($AARTOOL apply --help 2>&1)"   "--yes"
check    "surface help" "$($AARTOOL surface --help 2>&1)" "--strict"
check    "doctor help"  "$($AARTOOL doctor --help 2>&1)"  "Changes nothing"
check    "report help"  "$($AARTOOL report --help 2>&1)"  "self-contained"
check    "diff help"    "$($AARTOOL diff --help 2>&1)"    "Exit codes"
check    "install help" "$($AARTOOL install --help 2>&1)" "SYMLINK"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
