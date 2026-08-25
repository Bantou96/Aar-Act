#!/usr/bin/env bash
# Install the built packages in the distributions they target, and use them.
#
# A package that builds is not a package that works. The failure this exists to
# catch is specific: aartool locates the playbooks, the baseline script and the
# dashboard by walking up from its own file, so /usr/bin/aartool has to be a
# symlink into /usr/share/aartool. If that ever becomes a copy, every command
# fails at run time while the package still builds, installs, and passes any
# check that only reads the file list.
#
# The probes run as a NON-ROOT user wherever they can. The first build of this
# package shipped mode 0640 throughout, and root could not tell the difference.
#
# Usage: packaging/tests/install-test.sh [DIST_DIR]
set -uo pipefail

cd "$(dirname "$0")/../.."
DIST="${1:-packaging/dist}"
DEB="$(ls "$DIST"/aartool_*_all.deb 2>/dev/null | head -1)"
RPM="$(ls "$DIST"/aartool-*.noarch.rpm 2>/dev/null | head -1)"
[[ -f "$DEB" ]] || { echo "no .deb in $DIST. Run packaging/build.sh first." >&2; exit 1; }
[[ -f "$RPM" ]] || { echo "no .rpm in $DIST. Run packaging/build.sh first." >&2; exit 1; }

PASS=0; FAIL=0

PROBE='
set -e
U=tester
useradd -m "$U" 2>/dev/null || true

echo "on PATH:            $(command -v aartool)"
test -L /usr/bin/aartool && echo "symlink:            yes (not a copy)"
echo "version:            $(su -s /bin/bash "$U" -c "aartool --version")"
su -s /bin/bash "$U" -c "aartool --help" >/dev/null && echo "help as non-root:   readable"
echo "checks found:       $(su -s /bin/bash "$U" -c "aartool explain --list" | wc -l)"
su -s /bin/bash "$U" -c "aartool explain SSH-01" >/dev/null && echo "explain SSH-01:     resolved"
su -s /bin/bash "$U" -c "aartool plan --target linux_servers" 2>&1 \
  | grep -q "/etc/aartool/inventory" && echo "inventory path:     /etc/aartool/inventory"
test -f /usr/share/aartool/ansible-hardening/inventory/hosts.example \
  && echo "example inventory:  present"
aartool inspect --no-save >/dev/null && echo "inspect:            ran to completion"
echo "roles shipped:      $(ls /usr/share/aartool/ansible-hardening/roles | wc -l)"
test -f /usr/share/aartool/dashboard/index.html && echo "dashboard:          present"
'

run_case() {
  local name="$1" image="$2" install="$3" out rc
  echo "=== $name ==="
  out=$(docker run --rm -v "$PWD/$DIST:/pkg:ro" "$image" bash -c "set -e; $install; $PROBE" 2>&1)
  rc=$?
  echo "$out" | sed 's/^/    /'
  if [[ $rc -eq 0 ]]; then PASS=$((PASS+1)); echo "    -> PASS"
  else FAIL=$((FAIL+1)); echo "    -> FAIL (exit $rc)"; fi
  echo
}

run_case "debian:12 (apt)" debian:12 \
  "apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq /pkg/$(basename "$DEB") >/dev/null 2>&1"

run_case "rockylinux:9 (dnf)" rockylinux:9 \
  "dnf install -y -q /pkg/$(basename "$RPM") >/dev/null 2>&1"

echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
