#!/usr/bin/env bash
# Do the checks call commands that exist?
#
# SYS-10 tested for Ctrl-Alt-Delete masking with `systemctl is-masked`, which is
# not a systemd verb and never has been. systemd answers "Unknown command verb
# 'is-masked'" and exits non-zero, so the check reported FAIL on every host ever
# scanned, including hosts where the target was correctly masked. It was found
# by auditing a real estate: 15 nodes, 15 FAIL, 0 PASS, every one of them masked.
#
# A check that can never pass is the mirror of a check that can never fail. Both
# are worse than no check, because both look like information.
#
# This validates the subcommands the checks invoke against the real tool's own
# help output, on whatever machine the tests run on.
#
# Run: bash scripts/tests/test_check_commands.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }

# ── systemctl ────────────────────────────────────────────────────────────────
if ! command -v systemctl >/dev/null 2>&1; then
  printf 'SKIP  systemctl not present on this machine\n'
else
  # systemctl --help lists its verbs indented under section headings. Take any
  # leading lowercase word that is followed by whitespace or an argument.
  VERBS=$(systemctl --help 2>/dev/null \
          | grep -oP '^\s{2}\K[a-z][a-z-]+(?=\s|$|\s+[A-Z\[])' | sort -u)
  [[ -n "$VERBS" ]] || { printf 'SKIP  could not read systemctl verbs\n'; VERBS=""; }

  if [[ -n "$VERBS" ]]; then
    # Every `systemctl <verb>` the checks invoke, ignoring options.
    # Strip comments first. The first version of this guard matched the very
    # comment explaining the bug it was written to prevent, and reported the
    # fixed file as still broken.
    used=$(cat src/checks/*.sh | sed 's/#.*//' \
           | grep -oP '\bsystemctl\s+(?:--?\S+\s+)*\K[a-z][a-z-]+' | sort -u)
    for v in $used; do
      if printf '%s\n' "$VERBS" | grep -qx "$v"; then
        ok
      else
        bad "src/checks/ calls 'systemctl $v', which this systemd does not have"
      fi
    done
    printf '  checked %d distinct systemctl verbs against systemd %s\n' \
      "$(printf '%s\n' "$used" | grep -c .)" "$(systemctl --version | head -1 | awk '{print $2}')"
  fi
fi

# ── The specific regression, named ───────────────────────────────────────────
# Cheap, explicit, and survives a machine where the verb list cannot be read.
if cat src/checks/*.sh | sed 's/#.*//' | grep -q 'systemctl is-masked'; then
  bad "src/checks/ still uses 'systemctl is-masked'; the verb is 'is-enabled', which prints 'masked'"
else
  ok
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
