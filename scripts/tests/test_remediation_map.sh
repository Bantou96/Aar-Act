#!/usr/bin/env bash
# The remediation advice the report prints must actually work.
#
# Every audit ends with a plan like
#
#     ansible-playbook -i inventory/hosts playbooks/2_configure_hardening.yml --tags ssh
#
# built from ANSIBLE_MAP. Nothing checked that those tags exist in the playbook
# or that the roles named are real, so a typo produced a command that runs
# cleanly, matches nothing, changes nothing and reports success. An operator
# following it would believe the finding was remediated.
#
# This is the same shape as the inventory/hosts.yml bug: the tool's own output
# telling people to run something that cannot work.
#
# Run: bash scripts/tests/test_remediation_map.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

MAP="src/lib/ansible_map.sh"
PLAYBOOK="../ansible-hardening/playbooks/2_configure_hardening.yml"
ROLES_DIR="../ansible-hardening/roles"

PASS=0 FAIL=0
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

[[ -f "$MAP" ]]      || { echo "cannot find $MAP"; exit 1; }
[[ -f "$PLAYBOOK" ]] || { echo "cannot find $PLAYBOOK"; exit 1; }

# Tags the playbook actually defines.
playbook_tags="$(grep -oE '^\s+tags: \[[^]]+\]' "$PLAYBOOK" \
  | sed 's/.*\[//; s/\]//' | tr ',' '\n' | tr -d ' ' | sort -u)"

# Roles that actually exist on disk.
existing_roles="$(find "$ROLES_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort -u)"

while IFS= read -r line; do
  id="$(printf '%s' "$line" | sed -n 's/.*\["\([A-Z]*-[0-9]*\)"\].*/\1/p')"
  entry="$(printf '%s' "$line" | sed -n 's/.*\]="\([^"]*\)".*/\1/p')"
  [[ -n "$id" && -n "$entry" ]] || continue

  IFS='|' read -r tags role_r role_u _desc <<< "$entry"

  # Every tag must exist in the playbook, or the printed command matches nothing.
  IFS=',' read -ra tag_list <<< "$tags"
  for t in "${tag_list[@]}"; do
    [[ -z "$t" ]] && continue
    if printf '%s\n' "$playbook_tags" | grep -qx "$t"; then
      PASS=$((PASS + 1))
    else
      fail "$id names tag '$t', which no role in the playbook carries"
    fi
  done

  # Every role named must exist, or the plan points at nothing.
  for r in "$role_r" "$role_u"; do
    [[ -z "$r" || "$r" == "-" ]] && continue
    if printf '%s\n' "$existing_roles" | grep -qx "$r"; then
      PASS=$((PASS + 1))
    else
      fail "$id names role '$r', which does not exist in roles/"
    fi
  done
done < <(grep -E '^\s*\["[A-Z]+-[0-9]+"\]=' "$MAP")

# ── Molecule scenarios and the CI matrix ─────────────────────────────────────
# The matrix is a hand-written list. A scenario added on disk and not added here
# never runs, and nothing says so: CI stays green because it is green on the
# scenarios it was told about. That is the same shape as an unmapped check and
# an invalid remediation tag, so it gets the same treatment.
MOL_DIR=../ansible-hardening/molecule
CI=../.github/workflows/molecule.yml
if [[ -d "$MOL_DIR" && -f "$CI" ]]; then
  on_disk=$(find "$MOL_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort)
  in_ci=$(sed -n '/scenario:/,/steps:/p' "$CI" | grep -oP '^\s+- \K[a-z0-9_]+' | sort)
  while read -r sc; do
    [[ -z "$sc" ]] && continue
    if printf '%s\n' "$in_ci" | grep -qx "$sc"; then
      PASS=$((PASS + 1))
    else
      fail "molecule scenario '$sc' exists on disk but is not in the CI matrix, so it never runs"
    fi
  done <<<"$on_disk"
  while read -r sc; do
    [[ -z "$sc" ]] && continue
    if printf '%s\n' "$on_disk" | grep -qx "$sc"; then
      PASS=$((PASS + 1))
    else
      fail "CI matrix names molecule scenario '$sc', which does not exist"
    fi
  done <<<"$in_ci"
fi

# ── A role default must satisfy the check it remediates ──────────────────────
# The deepest version of "advice that does not work". Not a wrong tag, not a
# missing role: the role runs, succeeds, and writes a value the checker rejects.
# AUTH-03 demanded PASS_MAX_DAYS <= 90 while linux_authselect_ubuntu defaulted
# to 365, so an operator could apply the recommended fix, re-audit, and see no
# change. Forever. Meanwhile the RHEL role for the same control used 90, so the
# two platforms disagreed with each other as well.
#
# One row per pair we have actually reasoned about. Not exhaustive, and not
# meant to be: it exists so a known contradiction cannot come back.
#   check | file | variable | operator | bound
while IFS='|' read -r cid file var op bound; do
  [[ -z "$cid" || "$cid" == \#* ]] && continue
  path="../ansible-hardening/roles/$file/defaults/main.yml"
  if [[ ! -f "$path" ]]; then
    fail "$cid: $path does not exist"; continue
  fi
  val=$(grep -oP "^${var}:\s*\K[0-9]+" "$path" | head -1)
  if [[ -z "$val" ]]; then
    fail "$cid: $var not found in $file/defaults/main.yml"
  elif [[ "$op" == "le" && "$val" -le "$bound" ]] || [[ "$op" == "ge" && "$val" -ge "$bound" ]]; then
    PASS=$((PASS + 1))
  else
    fail "$cid: $file sets $var=$val, but the check requires $op $bound, so applying the remediation cannot clear the finding"
  fi
done <<'PAIRS'
AUTH-03|linux_authselect_ubuntu|linux_authselect_pass_max_days|le|90
AUTH-03|linux_user_management_rhel9|linux_password_max_days|le|90
AUTH-07|linux_authselect_ubuntu|linux_authselect_pass_min_days|ge|1
AUTH-08|linux_authselect_ubuntu|linux_authselect_pass_warn_age|ge|7
PAIRS

printf '\n%d assertions passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
