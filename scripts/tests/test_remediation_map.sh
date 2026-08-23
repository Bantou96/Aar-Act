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
cd "$(dirname "$0")/.."

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

printf '\n%d assertions passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
