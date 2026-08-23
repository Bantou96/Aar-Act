#!/usr/bin/env bash
# Distribution family mapping.
#
# The point of this file is coverage we cannot get any other way: CI runs on
# Ubuntu, and Molecule tests Rocky 9 and Ubuntu 22.04. Nothing in the pipeline
# ever executes on openSUSE, Alpine, Arch or Amazon Linux, so the only way to
# know the mapping is right for them is to feed it their /etc/os-release and
# assert the answer.
#
# The fixtures are the real ID and ID_LIKE values those distributions ship.
#
# Run: bash scripts/tests/test_distro.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0 FAIL=0
expect() {                       # expect <label> <os-release body> <family> <roles yes|no>
  local label="$1" body="$2" want_fam="$3" want_roles="$4"
  local f; f="$(mktemp)"
  printf '%b\n' "$body" > "$f"
  local got
  got="$(OS_RELEASE_PATH="$f" bash -c 'source src/lib/distro.sh
    printf "%s " "$(distro_family)"
    distro_roles_available && printf "yes" || printf "no"')"
  rm -f "$f"
  if [[ "$got" == "$want_fam $want_roles" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n      want: %s %s\n      got:  %s\n' "$label" "$want_fam" "$want_roles" "$got"
  fi
}

# ── RHEL family, including derivatives that only declare themselves via ID_LIKE
expect "Rocky 9"        'ID="rocky"\nID_LIKE="rhel centos fedora"\nVERSION_ID="9.4"'   rhel   yes
expect "AlmaLinux 9"    'ID="almalinux"\nID_LIKE="rhel centos fedora"\nVERSION_ID="9.4"' rhel yes
expect "RHEL 9"         'ID="rhel"\nID_LIKE="fedora"\nVERSION_ID="9.4"'                rhel   yes
expect "Oracle Linux"   'ID="ol"\nID_LIKE="fedora"\nVERSION_ID="9.4"'                  rhel   yes
expect "Fedora 40"      'ID=fedora\nVERSION_ID=40'                                     rhel   yes
expect "Amazon Linux"   'ID="amzn"\nID_LIKE="fedora"\nVERSION_ID="2023"'               rhel   yes
expect "CentOS Stream"  'ID="centos"\nID_LIKE="rhel fedora"\nVERSION_ID="9"'           rhel   yes

# ── Debian family
expect "Debian 12"      'ID=debian\nVERSION_ID="12"'                                   debian yes
expect "Ubuntu 24.04"   'ID=ubuntu\nID_LIKE=debian\nVERSION_ID="24.04"'                debian yes
expect "Linux Mint"     'ID=linuxmint\nID_LIKE="ubuntu debian"\nVERSION_ID="22"'       debian yes
expect "Pop!_OS"        'ID=pop\nID_LIKE="ubuntu debian"\nVERSION_ID="22.04"'          debian yes
expect "Kali"           'ID=kali\nID_LIKE=debian'                                      debian yes
expect "Raspberry Pi OS" 'ID=raspbian\nID_LIKE=debian\nVERSION_ID="12"'                debian yes
expect "Devuan"         'ID=devuan\nID_LIKE=debian'                                    debian yes

# ── Audit-only families: the audit runs, the hardening roles do not exist
expect "openSUSE Leap"  'ID="opensuse-leap"\nID_LIKE="suse opensuse"\nVERSION_ID="15.6"' suse  no
expect "SLES 15"        'ID="sles"\nID_LIKE="suse"\nVERSION_ID="15.6"'                 suse   no
expect "Alpine"         'ID=alpine\nVERSION_ID=3.20.0'                                 alpine no
expect "Arch"           'ID=arch'                                                      arch   no
expect "Manjaro"        'ID=manjaro\nID_LIKE=arch'                                     arch   no
expect "Gentoo"         'ID=gentoo'                                                    gentoo no

# Azure Linux is RPM-based but uses tdnf and a different layout. Close to the
# RHEL family is not the same as tested on it, so it must NOT claim roles.
expect "Azure Linux"    'ID=azurelinux\nVERSION_ID="3.0"'                              azure  no

# ── Unknown, and the degenerate cases
expect "NixOS"          'ID=nixos\nVERSION_ID="24.05"'                                 unknown no
expect "Void"           'ID=void'                                                      unknown no
expect "empty os-release" ''                                                           unknown no

# A derivative nobody has heard of still lands correctly, purely from ID_LIKE.
expect "unknown ubuntu derivative" 'ID=somedistro\nID_LIKE="ubuntu debian"'            debian yes
expect "unknown rhel derivative"   'ID=otherdistro\nID_LIKE="rhel"'                    rhel   yes

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
