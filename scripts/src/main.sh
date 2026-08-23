#!/usr/bin/env bash
# =============================================================================
#  CyberAar Security Baseline Checker
#  Vérificateur de Sécurité de Base CyberAar
#
#  Version   : 4.2.0
#  Author    : CyberAar (https://github.com/cyberaar/cyberaar-toolkit)
#  License   : GPL v3
#  Target    : RHEL/CentOS/Ubuntu/Debian (Linux Government Servers)
#
#  Usage:
#    sudo bash cyberaar-baseline.sh
#    sudo bash cyberaar-baseline.sh --html-out /tmp/report.html
#    sudo bash cyberaar-baseline.sh --json-out /tmp/report.json
#    sudo bash cyberaar-baseline.sh --html-out /tmp/report.html --json-out /tmp/report.json
#    sudo cyberaar-baseline [same options] (after --install)
# =============================================================================

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_VERSION="4.2.0"
SCRIPT_NAME="cyberaar-baseline"

_show_help() {
  cat <<'HELPEOF'
CyberAar Security Baseline Checker v4.2.0

Usage: cyberaar-baseline [OPTIONS]

  --html-out <file>      Write HTML report to <file>
  --json-out <file>      Write JSON report to <file>
  --output-dir <dir>     Auto-name + store HTML and JSON in <dir>

Remote / Fleet options:
  --host <ip|host>       Run against a single remote host via SSH
  --host-file <file>     Run against multiple hosts (one IP/host per line)
  --inventory <file>     Parse an Ansible inventory file for hosts
  --user <user>          SSH user for remote scan (default: root)
  --ssh-key <keyfile>    SSH private key for remote scan
  --ssh-opt <opt>        Extra ssh option, repeatable. For a bastion:
                           --ssh-opt '-J admin@bastion.example.com' 
  --ansible-dir <dir>    Path to your Ansible repo (for playbook suggestions)

Install options:
  --install              Install to /usr/local/bin/cyberaar-baseline
  --uninstall            Remove from /usr/local/bin/cyberaar-baseline
  --version              Print version and exit
  --help, -h             Show this help

Examples:
  # Local scan
  sudo cyberaar-baseline --html-out /tmp/report.html
  sudo cyberaar-baseline --output-dir /var/log/cyberaar

  # Remote single host
  cyberaar-baseline --host 10.0.1.10 --user admin --html-out /tmp/report-10.0.1.10.html

  # Fleet scan from file
  cyberaar-baseline --host-file /etc/cyberaar/hosts.txt --user admin --output-dir /var/log/cyberaar

  # Fleet scan from Ansible inventory
  cyberaar-baseline --inventory inventory/hosts --user admin --output-dir /var/log/cyberaar

  # With Ansible remediation suggestions
  cyberaar-baseline --host 10.0.1.10 --ansible-dir ~/cyberaar-toolkit/ansible-hardening

  # Install
  sudo bash cyberaar-baseline.sh --install
HELPEOF
}

# ─── CLI ARGS ────────────────────────────────────────────────────────────────
HTML_OUT=""
JSON_OUT=""
# Declared before the parse loop: += on an undeclared name is an error under
# set -u, which would make the flag unusable rather than merely wrong.
REMOTE_SSH_OPTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --html-out)       HTML_OUT="$2";        shift 2 ;;
    --host)           REMOTE_HOST="$2";     shift 2 ;;
    --host-file)      REMOTE_HOST_FILE="$2";shift 2 ;;
    --inventory)      ANSIBLE_INVENTORY="$2";shift 2 ;;
    --user)           REMOTE_USER="$2";     shift 2 ;;
    --ssh-key)        REMOTE_KEY="$2";      shift 2 ;;
    # Repeatable, and word-split on purpose so --ssh-opt '-J host' and
    # --ssh-opt -J --ssh-opt host both work.
    # shellcheck disable=SC2206
    --ssh-opt)        REMOTE_SSH_OPTS+=($2); shift 2 ;;
    --ansible-dir)    ANSIBLE_DIR="$2";     shift 2 ;;
    --json-out)   JSON_OUT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --install)    DO_INSTALL=true; shift ;;
    --uninstall)  DO_UNINSTALL=true; shift ;;
    --version)    echo "cyberaar-baseline v4.2.0"; exit 0 ;;
    --help|-h)    _show_help; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

OUTPUT_DIR="${OUTPUT_DIR:-}"
DO_INSTALL="${DO_INSTALL:-false}"
DO_UNINSTALL="${DO_UNINSTALL:-false}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_HOST_FILE="${REMOTE_HOST_FILE:-}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_KEY="${REMOTE_KEY:-}"
ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-}"
ANSIBLE_DIR="${ANSIBLE_DIR:-}"

if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
  DATESTR=$(date '+%Y%m%d-%H%M%S')
  HOST_SLUG=$(hostname -s 2>/dev/null | tr -cd 'a-zA-Z0-9-')
  [[ -z "$HTML_OUT" ]] && HTML_OUT="${OUTPUT_DIR}/cyberaar-${HOST_SLUG}-${DATESTR}.html"
  [[ -z "$JSON_OUT" ]] && JSON_OUT="${OUTPUT_DIR}/cyberaar-${HOST_SLUG}-${DATESTR}.json"
fi

# ─── INSTALL ─────────────────────────────────────────────────────────────────
if [[ "$DO_INSTALL" == true ]]; then
  [[ $EUID -ne 0 ]] && { echo '❌  Root required: sudo bash cyberaar-baseline.sh --install'; exit 1; }
  INST_DEST='/usr/local/bin/cyberaar-baseline'
  cp -f "$SCRIPT_PATH" "$INST_DEST"
  chmod 755 "$INST_DEST"
  chown root:root "$INST_DEST"
  echo "✅  Installed → $INST_DEST"
  echo "    Try: sudo cyberaar-baseline --help"
  exit 0
fi

# ─── UNINSTALL ───────────────────────────────────────────────────────────────
if [[ "$DO_UNINSTALL" == true ]]; then
  INST_DEST='/usr/local/bin/cyberaar-baseline'
  [[ -f "$INST_DEST" ]] && rm -f "$INST_DEST" && echo "✅  Removed $INST_DEST" || echo "⚠️   Not found: $INST_DEST"
  exit 0
fi

