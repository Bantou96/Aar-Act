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

  # An explicit home wins over the search. Needed by anyone who COPIES aartool
  # somewhere rather than symlinking it, and by container images that mount the
  # toolkit at a fixed path.
  if [[ -n "${AARTOOL_HOME:-}" ]]; then
    [[ -d "$AARTOOL_HOME/ansible-hardening" ]] \
      || die "AARTOOL_HOME is set to '$AARTOOL_HOME' but there is no ansible-hardening/ there."
    root="$AARTOOL_HOME"
  else
    here="$(_self_dir)"
    root="$(_find_up "ansible-hardening" "$here")" \
      || die "Cannot find the toolkit. Looked for ansible-hardening/ in $here and six directories above it.
        If you copied aartool out of the repository rather than symlinking it, point it back:
          export AARTOOL_HOME=/path/to/aartool
        'aartool install' creates a symlink precisely so this does not happen."
  fi

  ANSIBLE_BASE="$root/ansible-hardening"
  # Overridable so a run can point at another estate's inventory, and so the
  # tests can work against a fixture instead of whatever is on the machine.
  #
  # A packaged install keeps its inventory in /etc instead. Everything under
  # /usr/share belongs to the package manager and is replaced wholesale on
  # upgrade, so an inventory written there would be silently destroyed by the
  # next `apt upgrade`. The marker file ships only in the .deb and the .rpm, so
  # a git checkout behaves exactly as it always has.
  if [[ -f "$root/.packaged" ]]; then
    INVENTORY="${AARTOOL_INVENTORY:-/etc/aartool/inventory}"
  else
    INVENTORY="${AARTOOL_INVENTORY:-$ANSIBLE_BASE/inventory/hosts}"
  fi
  INVENTORY_EXAMPLE="$ANSIBLE_BASE/inventory/hosts.example"
  TOOLKIT_DASHBOARD="$root/dashboard/index.html"
  BASELINE="$root/scripts/cyberaar-baseline.sh"
  HARDEN="$root/scripts/run-hardening.sh"

  # The inventory is NOT checked here. inventory/hosts is gitignored, because it
  # names real machines, so a fresh clone does not have one; and `inspect` on the
  # local machine has no use for it. Requiring it up front made every command
  # fail on a clean checkout, including the one command that needs nothing.
  # plan and apply check it themselves, where it actually matters.
  [[ -f "$BASELINE" ]] || die "cyberaar-baseline.sh not found: $BASELINE"
  [[ -f "$HARDEN"   ]] || die "run-hardening.sh not found: $HARDEN"
}

# Called by plan and apply, which cannot work without an inventory.
require_inventory() {
  [[ -f "$INVENTORY" ]] && return 0
  if [[ -f "$INVENTORY_EXAMPLE" ]]; then
    die "No inventory at $INVENTORY.
        It is gitignored, because it names real machines, so a fresh clone has none.
        Start from the template:
          cp $INVENTORY_EXAMPLE $INVENTORY"
  fi
  die "No inventory at $INVENTORY. Create it, listing your hosts and groups in INI format."
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
