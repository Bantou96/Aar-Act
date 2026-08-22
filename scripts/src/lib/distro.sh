# =============================================================================
#  DISTRIBUTION DETECTION
#
#  Two different questions, kept apart on purpose, because answering them as one
#  is what made the old message useless.
#
#    Can this machine be AUDITED?      Almost always yes. The checks read
#                                      sysctls, /proc, /etc and systemd. None of
#                                      that is distribution specific.
#
#    Are HARDENING ROLES available?    Currently only for the RHEL 9 family and
#                                      Ubuntu/Debian. That is a real limit and
#                                      pretending otherwise wastes people's time.
#
#  The old check matched six names and told everyone else to "use RHEL, Ubuntu or
#  Debian for official security support". Someone running openSUSE or Alpine does
#  not need to be told to change distribution; they need to know the audit will
#  still work and which part will not.
#
#  ID_LIKE is used before ID, so derivatives inherit correctly: Pop!_OS, Mint and
#  Zorin declare ID_LIKE=ubuntu; Rocky, Alma and Oracle declare ID_LIKE="rhel
#  centos fedora". A derivative nobody has heard of still lands in the right
#  family without this file being updated.
# =============================================================================

# Overridable so the mapping can be tested against every distribution rather
# than only the one the test happens to run on, and so a mounted image can be
# identified without booting it.
OS_RELEASE_PATH="${OS_RELEASE_PATH:-/etc/os-release}"

_DISTRO_ID=""; _DISTRO_LIKE=""; _DISTRO_PRETTY=""; _DISTRO_VERSION=""
if [[ -r "$OS_RELEASE_PATH" ]]; then
  _DISTRO_ID="$(       . "$OS_RELEASE_PATH" 2>/dev/null; printf '%s' "${ID:-}" )"
  _DISTRO_LIKE="$(     . "$OS_RELEASE_PATH" 2>/dev/null; printf '%s' "${ID_LIKE:-}" )"
  _DISTRO_PRETTY="$(   . "$OS_RELEASE_PATH" 2>/dev/null; printf '%s' "${PRETTY_NAME:-}" )"
  _DISTRO_VERSION="$(  . "$OS_RELEASE_PATH" 2>/dev/null; printf '%s' "${VERSION_ID:-}" )"
fi

distro_id()      { printf '%s' "${_DISTRO_ID:-unknown}"; }
distro_pretty()  { printf '%s' "${_DISTRO_PRETTY:-${_DISTRO_ID:-unknown}} ${_DISTRO_VERSION}"; }

# rhel | debian | suse | arch | alpine | gentoo | unknown
distro_family() {
  local id="$_DISTRO_ID" like=" $_DISTRO_LIKE "
  case "$id" in
    rhel|centos|almalinux|rocky|fedora|ol|oracle|amzn|scientific|cloudlinux) printf 'rhel'; return ;;
    ubuntu|debian|linuxmint|pop|raspbian|kali|zorin|elementary|devuan)       printf 'debian'; return ;;
    opensuse*|sles|sled|suse)                                               printf 'suse'; return ;;
    arch|manjaro|endeavouros|garuda)                                        printf 'arch'; return ;;
    alpine)                                                                 printf 'alpine'; return ;;
    gentoo)                                                                 printf 'gentoo'; return ;;
    # Azure Linux is RPM-based but uses tdnf and a different layout. Close to
    # the RHEL family is not the same as tested on it, so it gets its own name
    # and no role claim.
    mariner|azurelinux)                                                     printf 'azure'; return ;;
  esac
  # Unrecognised name: fall back to what the distribution says it resembles.
  case "$like" in
    *" rhel "*|*" centos "*|*" fedora "*) printf 'rhel' ;;
    *" debian "*|*" ubuntu "*)            printf 'debian' ;;
    *" suse "*|*" opensuse "*)            printf 'suse' ;;
    *" arch "*)                           printf 'arch' ;;
    *" alpine "*)                         printf 'alpine' ;;
    *)                                    printf 'unknown' ;;
  esac
}

# The package manager actually present, which is the thing the update check
# needs. Asking the binary beats inferring it from the family: Fedora has dnf5,
# some minimal images have neither.
distro_pkg_mgr() {
  local m
  for m in dnf5 dnf yum apt-get zypper pacman apk xbps-install emerge; do
    command -v "$m" >/dev/null 2>&1 && { printf '%s' "$m"; return; }
  done
  printf 'none'
}

# Do we ship Ansible hardening roles for this family?
#
# rhel and debian only. Everything else can still be audited: the checks read
# sysctls, /proc, /etc and systemd, none of which is distribution specific.
# Saying "audit works, hardening does not" is useful. Telling someone on
# openSUSE to switch to RHEL is not, and that is what the old message did.
distro_roles_available() {
  case "$(distro_family)" in
    rhel|debian) return 0 ;;
    *)           return 1 ;;
  esac
}

# What CI actually proves, as opposed to what the roles are written for. Molecule
# runs every role against these two images and nothing else, so this is the only
# claim that is backed by evidence.
distro_roles_tested() { printf 'Rocky Linux 9, Ubuntu 22.04'; }
