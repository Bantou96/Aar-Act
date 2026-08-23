#!/usr/bin/env bash
# Documentation guard.
#
# The worst bug this repository has shipped twice is not a crash. It is our own
# output telling someone to run a command that cannot work: a remediation line
# naming an Ansible tag no role carries, a report renderer pointing at an
# inventory file that does not exist, and a first draft of docs/AARTOOL.md that
# told people to run 'aartool inspect --json FILE' when the flag is '-o DIR'.
#
# Each of those fails silently. The reader runs it, gets an error they assume is
# their own fault, and stops trusting the tool.
#
# So: every aartool invocation inside a fenced code block in the documentation
# is parsed, and its command and long options are checked against the CLI's own
# --help. Documentation that drifts fails the build.
#
# Run: bash scripts/tests/test_docs.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
AARTOOL="./aartool"
DOCS=(../README.md ../docs/AARTOOL.md)

PASS=0 FAIL=0
fail() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }
ok()   { PASS=$((PASS+1)); }

# Commands the dispatcher accepts, taken from the help rather than hardcoded.
COMMANDS=$($AARTOOL --help 2>&1 | sed -n '/^Commands:/,/^Global options:/p' \
          | grep -oP '^  \K[a-z]+' | sort -u)
[[ -n "$COMMANDS" ]] || { printf 'FAIL  could not read the command list from --help\n'; exit 1; }

# Cache each command's long options once.
declare -A OPTS
for c in $COMMANDS; do
  OPTS["$c"]=" $($AARTOOL "$c" --help 2>&1 | grep -oP '\-\-[a-z][a-z-]*' | sort -u | tr '\n' ' ')"
done
# Global options are accepted everywhere.
GLOBAL=" --help --verbose --version "

for doc in "${DOCS[@]}"; do
  [[ -f "$doc" ]] || { fail "$doc does not exist"; continue; }

  # Only fenced code blocks. Prose says things like "the --only it printed",
  # and a shell line is what a reader actually copies.
  while IFS= read -r line; do
    # Strip a leading sudo, a leading ./scripts/ or scripts/ path, and comments.
    line="${line%%#*}"
    line=$(sed -E 's#^[[:space:]]*(sudo[[:space:]]+)?(\./)?(scripts/)?aartool[[:space:]]+##' <<<"$line")
    [[ "$line" == "$(sed -E 's#^[[:space:]]*##' <<<"$line")" ]] || true

    read -ra words <<<"$line"
    [[ ${#words[@]} -gt 0 ]] || continue
    cmd="${words[0]}"

    # Placeholders in a usage synopsis, not a real invocation.
    [[ "$cmd" == "<command>" || "$cmd" == \<* ]] && continue

    if ! grep -qx -- "$cmd" <<<"$COMMANDS"; then
      # 'why' is a documented alias, and the dispatcher lists aliases nowhere.
      [[ "$cmd" == "why" ]] && { ok; continue; }
      fail "$(basename "$doc"): 'aartool $cmd' is not a command"
      continue
    fi
    ok

    for w in "${words[@]:1}"; do
      [[ "$w" == --* ]] || continue
      w="${w%%=*}"
      # Documented placeholders like --only TAGS are fine; the flag is the word.
      if [[ "${OPTS[$cmd]}" != *" $w "* && "$GLOBAL" != *" $w "* ]]; then
        fail "$(basename "$doc"): 'aartool $cmd $w' is not an option $cmd accepts"
      else
        ok
      fi
    done
  done < <(awk '/^```/{f=!f; next} f' "$doc" | grep -E '^[[:space:]]*(sudo[[:space:]]+)?(\./)?(scripts/)?aartool[[:space:]]')
done

# The dedicated manual must exist and be linked from the README, or nobody
# finds it.
[[ -f ../docs/AARTOOL.md ]] && ok || fail "docs/AARTOOL.md is missing"
grep -q 'docs/AARTOOL.md' ../README.md && ok || fail "README.md does not link to docs/AARTOOL.md"

# No em dashes: house style, and they are a nuisance to type on the keyboard
# this repository is written from.
for doc in "${DOCS[@]}" ; do
  n=$(grep -c '—' "$doc" 2>/dev/null || true)
  [[ "$n" == "0" ]] && ok || fail "$(basename "$doc") contains $n em dashes"
done

# Counts in prose drift the moment a role or a check is added, and a README
# that says 51 roles next to a directory holding 52 is the first thing a
# sceptical reader checks. Both numbers are derivable, so derive them.
ROLES_ON_DISK=$(find ../ansible-hardening/roles -maxdepth 1 -mindepth 1 -type d | wc -l)
for doc in "${DOCS[@]}"; do
  while read -r n; do
    [[ "$n" == "$ROLES_ON_DISK" ]] && ok \
      || fail "$(basename "$doc") says $n roles; there are $ROLES_ON_DISK on disk"
  done < <(grep -oP '\b\K[0-9]+(?= (\w+ )?roles?\b)' "$doc" | sort -u)
done

CHECKS=$($AARTOOL explain --list 2>/dev/null | grep -c .)
for doc in "${DOCS[@]}"; do
  while read -r n; do
    [[ "$n" == "$CHECKS" ]] && ok \
      || fail "$(basename "$doc") says $n checks; the baseline emits $CHECKS"
  done < <(grep -oP '\b\K[0-9]+(?= (security )?checks?\b)' "$doc" | sort -u)
done

# Check IDs quoted in prose must exist. Four knowledge-base entries were once
# written against the wrong ID, and the same mistake in a document is worse: the
# reader cannot run it to find out.
KNOWN_IDS=$($AARTOOL explain --list 2>/dev/null | awk '{print $1}')
for doc in "${DOCS[@]}"; do
  while read -r id; do
    if printf '%s\n' "$KNOWN_IDS" | grep -qx "$id"; then
      ok
    else
      fail "$(basename "$doc") refers to check $id, which does not exist"
    fi
  done < <(grep -oP '\b(SYS|AUTH|SSH|NET|KRN|FS|LOG|INT|COMP)-[0-9]{2}\b' "$doc" | sort -u)
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
