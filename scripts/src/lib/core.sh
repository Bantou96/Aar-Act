# ─── COLORS ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── GLOBALS ─────────────────────────────────────────────────────────────────
PASS=0; WARN=0; FAIL=0

# Parallel result arrays — populated by add_result(), consumed by renderers
RESULT_CATEGORY=()
RESULT_STATUS=()
RESULT_ID=()
RESULT_NAME_EN=()
RESULT_NAME_FR=()
RESULT_DETAIL=()
RESULT_REMEDIATION=()

# Tracks check IDs that need remediation (for Ansible plan)
FAIL_IDS=()
WARN_IDS=()

# ─── HELPERS ─────────────────────────────────────────────────────────────────

section() {
  printf "\n${BOLD}${CYAN}━━━  %s  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" "$1"
}

# Encode special HTML characters to prevent XSS in report output
json_escape() {
  # Backslash first, then the quote, then control characters that would make the
  # document invalid. No & involved, so patsub_replacement does not apply here,
  # but this lives next to html_escape so both are found and reviewed together.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}

html_escape() {
  # The backslashes before & are required, not stylistic. Bash 5.2 added the
  # patsub_replacement option, on by default, which makes an unescaped & in the
  # replacement expand to the matched text exactly as sed does. Without them
  # "${s//</&lt;}" yields "<lt;" and the function silently stops escaping:
  # every value taken from the audited machine then lands raw in the report.
  # \& is literal in every bash version, so this stays correct on both sides of
  # 5.2. Covered by tests/test_html_escape.sh.
  local s="$1"
  s="${s//&/\&amp;}"
  s="${s//</\&lt;}"
  s="${s//>/\&gt;}"
  s="${s//\"/\&quot;}"
  s="${s//\'/\&#39;}"
  printf '%s' "$s"
}

# add_result CATEGORY STATUS ID NAME_EN NAME_FR DETAIL REMEDIATION_FR
add_result() {
  local category="$1" status="$2" id="$3" name_en="$4" name_fr="$5"
  local detail="${6:-}" remediation="${7:-}"

  local symbol color
  case "$status" in
    PASS) ((PASS++)); symbol="✅"; color=$GREEN ;;
    WARN) ((WARN++)); symbol="⚠️ "; color=$YELLOW; WARN_IDS+=("$id") ;;
    FAIL) ((FAIL++)); symbol="❌"; color=$RED;    FAIL_IDS+=("$id") ;;
  esac

  # Terminal — live streaming output (unchanged behaviour)
  printf "  ${color}${symbol}  ${BOLD}[%-6s]${NC}${color} %-45s${NC} %s\n" \
    "$status" "$name_en" "$detail"
  if [[ "$status" != "PASS" && -n "$remediation" ]]; then
    printf "         ${CYAN}↳ %s${NC}\n" "$remediation"
  fi

  # Append to parallel result arrays (renderers iterate these at end of run)
  RESULT_CATEGORY+=("$category")
  RESULT_STATUS+=("$status")
  RESULT_ID+=("$id")
  RESULT_NAME_EN+=("$name_en")
  RESULT_NAME_FR+=("$name_fr")
  RESULT_DETAIL+=("$detail")
  RESULT_REMEDIATION+=("$remediation")
}

cmd_exists() { command -v "$1" &>/dev/null; }
svc_active() { systemctl is-active --quiet "$1" 2>/dev/null; }
get_ssh()    { grep -iE "^\s*${1}\s" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}'; }
