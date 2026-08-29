#!/usr/bin/env bash
# The reachability wave is defined twice on purpose and must never differ.
#
# `_wave_of` lives in the baseline engine, which writes it into every JSON
# result. `_advise_wave` lives in aartool, which orders the plan. They are in
# two separate bundles that ship independently, so nothing but this file stops
# them drifting, and a drift is silent: advise would sort a finding into wave 2
# while the report it came from says wave 1, and the dashboard would agree with
# whichever it happened to read.
#
# This is the third mirror of this shape in the repository. The other two
# (remediation tags, the dashboard's WAVES) each drifted before they were
# guarded.
#
# Run: bash scripts/tests/test_waves.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }

# shellcheck source=/dev/null
source src/lib/ansible_map.sh              # provides _wave_of

# _advise_wave is inside the aartool bundle; pull the function out rather than
# sourcing the whole thing, which would run a CLI.
ADVISE=aartool-src/cmd/advise.sh
[[ -f "$ADVISE" ]] || { echo "FAIL  $ADVISE missing"; exit 1; }
eval "$(awk '/^_advise_wave\(\) \{/,/^\}/' "$ADVISE")"

command -v _advise_wave >/dev/null || { echo "FAIL  could not extract _advise_wave"; exit 1; }

# Every ID the baseline can emit, taken from the checks themselves rather than
# from a list kept by hand: a family added without a wave is the failure this
# guards against, and a hand-written list would not contain it.
mapfile -t IDS < <(grep -rhoP 'add_result\s+"[^"]*"\s+"[^"]*"\s+"\K[A-Z]+-[0-9]+' src/checks/ | sort -u)
[[ ${#IDS[@]} -gt 50 ]] || { echo "FAIL  only found ${#IDS[@]} check IDs; the extraction is broken"; exit 1; }

for id in "${IDS[@]}"; do
  a=$(_wave_of "$id"); b=$(_advise_wave "$id")
  if [[ "$a" == "$b" ]]; then ok; else
    bad "$id: engine says wave $a, advise says wave $b"
  fi
done

# A wave must be one of the four advise knows how to name.
for id in "${IDS[@]}"; do
  w=$(_wave_of "$id")
  [[ "$w" =~ ^[1-4]$ ]] && ok || bad "$id: wave '$w' is not 1-4"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
