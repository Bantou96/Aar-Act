#!/usr/bin/env bash
# =============================================================================
#  CyberAar — Hardening Run Script
#
#  Locates ansible-hardening/ automatically by walking up the directory tree.
#
#  SENSITIVE VARIABLES — set in your shell BEFORE running this script:
#    read -sr LINUX_BOOTLOADER_PASSWORD ; export LINUX_BOOTLOADER_PASSWORD
#
#  This script never prompts for or stores any credentials.
#
#  Usage:
#    bash run-hardening.sh [options]
#
#  Options:
#    -u USER       SSH admin user                      (default: ansible)
#    -t TARGET     Ansible host or group               (default: linux_servers)
#    -s STEP       Step: 1, 2, 3, or all               (default: 2)
#    -T TAGS       Override tags for step 2 only       (default: hardening)
#    -K            Prompt for sudo/become password
#    -c            Check mode (--check --diff, no changes applied)
#    -h            Show this help
#
#  Examples:
#    # Connectivity test
#    ansible -i inventory/hosts linux_servers -m ping
#
#    # Dry-run hardening only
#    bash run-hardening.sh -u ubuntu -t ubuntu-vm-01 -c
#
#    # Full 3-step pipeline dry-run (baseline → harden → baseline)
#    bash run-hardening.sh -u ubuntu -t ubuntu-vm-01 -s all -c
#
#    # Apply full pipeline to Rocky VM
#    bash run-hardening.sh -u rockylinux -t rocky-vm-01 -s all
#
#    # SSH hardening only
#    bash run-hardening.sh -u ubuntu -t ubuntu-vm-01 -T ssh
#
#  Step tags (applied automatically — do not override with -T unless needed):
#    Step 1 (baseline before) : baseline
#    Step 2 (hardening)       : hardening  (override with -T)
#    Step 3 (baseline after)  : baseline
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
ADMIN_USER="ansible"
TARGET="linux_servers"
STEP="2"
HARDENING_TAGS="hardening"
SSH_KEY=""
CHECK_MODE=false
ASK_BECOME_PASS=false
LOG_DIR="$HOME/logs"

# ── Argument parsing ──────────────────────────────────────────────────────────
while getopts "u:t:s:T:i:Kch" opt; do
  case $opt in
    u) ADMIN_USER="$OPTARG" ;;
    t) TARGET="$OPTARG" ;;
    s) STEP="$OPTARG" ;;
    T) HARDENING_TAGS="$OPTARG" ;;
    # An estate with a dedicated key is the normal case, not the exception.
    # Without this the only way to connect was to have the key in an agent or
    # at a default path, and the failure looked like a permissions problem on
    # the target rather than a missing flag here.
    i) SSH_KEY="$OPTARG" ;;
    K) ASK_BECOME_PASS=true ;;
    c) CHECK_MODE=true ;;
    h) grep "^#" "$0" | grep -v "^#!/" | sed 's/^# \?//'; exit 0 ;;
    *) die "Unknown option. Use -h for help." ;;
  esac
done

# ── Auto-locate ansible-hardening/ ────────────────────────────────────────────
ANSIBLE_BASE=""
search="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pass 1: script is inside ansible-hardening/
for _ in 1 2 3 4 5 6; do
  if [[ -f "$search/inventory/hosts" && -d "$search/playbooks" ]]; then
    ANSIBLE_BASE="$search"; break
  fi
  search="$(dirname "$search")"
done

# Pass 2: walk up looking for ansible-hardening/
if [[ -z "$ANSIBLE_BASE" ]]; then
  search="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _ in 1 2 3 4 5 6; do
    if [[ -d "$search/ansible-hardening" ]]; then
      ANSIBLE_BASE="$search/ansible-hardening"; break
    fi
    search="$(dirname "$search")"
  done
fi

[[ -n "$ANSIBLE_BASE" ]] \
  || die "Cannot find ansible-hardening/ (looked 6 levels up from script location)."

# AARTOOL_INVENTORY lets a caller point the run at another inventory. aartool
# uses it for `--target localhost`, where it writes a one-line inventory to a
# temporary file: a packaged install has $ANSIBLE_BASE under /usr/share, which
# is read-only and replaced on upgrade, so there is nowhere there to put one.
# Same variable the aartool side already honours.
INVENTORY="${AARTOOL_INVENTORY:-$ANSIBLE_BASE/inventory/hosts}"
# Say where the roles are rather than relying on playbooks/roles being a symlink
# to ../roles. That symlink is how a git checkout resolves them, and a packaging
# step that quietly drops it leaves playbooks referencing roles nothing can find.
# Explicit beats implicit for the one path without which nothing runs.
export ANSIBLE_ROLES_PATH="$ANSIBLE_BASE/roles"

PLAYBOOK_1="$ANSIBLE_BASE/playbooks/1_execute_baseline_before.yml"
PLAYBOOK_2="$ANSIBLE_BASE/playbooks/2_configure_hardening.yml"
PLAYBOOK_3="$ANSIBLE_BASE/playbooks/3_execute_baseline_after.yml"

[[ -f "$INVENTORY"  ]] || die "inventory/hosts not found at: $INVENTORY"
[[ -f "$PLAYBOOK_1" ]] || die "1_execute_baseline_before.yml not found at: $PLAYBOOK_1"
[[ -f "$PLAYBOOK_2" ]] || die "2_configure_hardening.yml not found at: $PLAYBOOK_2"
[[ -f "$PLAYBOOK_3" ]] || die "3_execute_baseline_after.yml not found at: $PLAYBOOK_3"

# ── Prepare log ───────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d_%H-%M-%S)-hardening-${TARGET}.log"

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD} 🛡️  CyberAar — Hardening Run${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
echo ""
info "Base        : $ANSIBLE_BASE"
info "Target      : $TARGET"
info "Step        : $STEP"
info "User        : $ADMIN_USER"
info "Check mode  : $CHECK_MODE"
info "Log         : $LOG_FILE"
echo ""

# ── Warn if GRUB password is missing ─────────────────────────────────────────
if [[ "$STEP" == "2" || "$STEP" == "all" ]]; then
  if [[ -z "${LINUX_BOOTLOADER_PASSWORD:-}" ]]; then
    warn "LINUX_BOOTLOADER_PASSWORD not set — bootloader_password role will be skipped."
    warn "To enable:  read -sr LINUX_BOOTLOADER_PASSWORD ; export LINUX_BOOTLOADER_PASSWORD"
    echo ""
  else
    info "LINUX_BOOTLOADER_PASSWORD is set ✓"
    echo ""
  fi
fi

# ── Shared ansible-playbook flags (no --tags here — set per step below) ───────
BASE_FLAGS=(
  "--diff"
  "-u" "$ADMIN_USER"
  "-b"
  "-i" "$INVENTORY"
  "--extra-vars" "target=${TARGET}"
)
[[ -n "$SSH_KEY"      ]] && BASE_FLAGS+=("--private-key" "$SSH_KEY")
[[ "$CHECK_MODE"      == true ]] && BASE_FLAGS+=("--check")
[[ "$ASK_BECOME_PASS" == true ]] && BASE_FLAGS+=("--ask-become-pass")

# ── Run helper — tags passed explicitly per step ──────────────────────────────
run_playbook() {
  local playbook="$1"
  local label="$2"
  local tags="$3"
  info "Running : $label"
  info "Tags    : $tags"
  echo ""
  ANSIBLE_LOG_PATH="$LOG_FILE" ansible-playbook "${BASE_FLAGS[@]}" --tags "$tags" "$playbook"
  success "$label — done"
  echo ""
}

# ── Execute ───────────────────────────────────────────────────────────────────
case "$STEP" in
  1)
    run_playbook "$PLAYBOOK_1" "Step 1 — Pre-hardening baseline"  "baseline"
    ;;
  2)
    run_playbook "$PLAYBOOK_2" "Step 2 — System hardening"        "$HARDENING_TAGS"
    ;;
  3)
    run_playbook "$PLAYBOOK_3" "Step 3 — Post-hardening baseline" "baseline"
    ;;
  all)
    run_playbook "$PLAYBOOK_1" "Step 1 — Pre-hardening baseline"  "baseline"
    run_playbook "$PLAYBOOK_2" "Step 2 — System hardening"        "$HARDENING_TAGS"
    run_playbook "$PLAYBOOK_3" "Step 3 — Post-hardening baseline" "baseline"
    ;;
  *)
    die "Invalid step '$STEP'. Use 1, 2, 3, or all."
    ;;
esac

echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
success "Run complete.  Log → $LOG_FILE"
echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
echo ""
