# ── Locating the toolkit ─────────────────────────────────────────────────────
# aartool may be run from the repo, from a copy in PATH, or from a checkout
# several directories below where it was invoked. It finds the pieces it wraps
# by walking up from its own location, which is the same approach
# run-hardening.sh takes.
#
# It resolves symlinks first. Installing to /usr/local/bin/aartool as a symlink
# is the obvious thing for a user to do, and without this the walk would start
# in /usr/local/bin and find nothing.

_self_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

# Walk up looking for a directory that contains the marker.
_find_up() {
  local marker="$1" search="$2"
  for _ in 1 2 3 4 5 6; do
    [[ -e "$search/$marker" ]] && { printf '%s' "$search"; return 0; }
    search="$(dirname "$search")"
    [[ "$search" == "/" ]] && break
  done
  return 1
}

resolve_paths() {
  local here root
  here="$(_self_dir)"

  root="$(_find_up "ansible-hardening" "$here")" \
    || die "Cannot find the toolkit. Looked for ansible-hardening/ in $here and six directories above it."

  ANSIBLE_BASE="$root/ansible-hardening"
  INVENTORY="$ANSIBLE_BASE/inventory/hosts"
  BASELINE="$root/scripts/cyberaar-baseline.sh"
  HARDEN="$root/scripts/run-hardening.sh"

  # Checked here rather than at the point of use, so a missing piece is reported
  # before anything runs instead of halfway through a playbook.
  [[ -f "$INVENTORY" ]] || die "Inventory not found: $INVENTORY"
  [[ -f "$BASELINE"  ]] || die "cyberaar-baseline.sh not found: $BASELINE"
  [[ -f "$HARDEN"    ]] || die "run-hardening.sh not found: $HARDEN"
}

# Confirm a target exists in the inventory before handing it to Ansible.
# The INI inventory lists hosts one per line and groups as [name]; a target may
# legitimately be either, so both forms are accepted.
target_in_inventory() {
  local target="$1"
  grep -qE "^\s*${target}(\s|$)" "$INVENTORY" && return 0
  grep -qE "^\s*\[${target}(:children)?\]\s*$" "$INVENTORY" && return 0
  return 1
}
