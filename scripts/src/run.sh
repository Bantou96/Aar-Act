# =============================================================================
#  MAIN EXECUTION BLOCK
#  Root check → gather host info → run all check functions → render outputs
# =============================================================================

# ─── ROOT CHECK ──────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "❌  Please run as root: sudo bash $0"
  exit 1
fi

HOSTNAME_VAL=$(hostname -f 2>/dev/null || hostname)
DATE_VAL=$(date '+%Y-%m-%d %H:%M:%S')
OS_VAL=$(grep -oP '(?<=^PRETTY_NAME=").+(?=")' /etc/os-release 2>/dev/null || uname -o)

# ─── RUN CHECKS ──────────────────────────────────────────────────────────────
_checks_system
_checks_auth
_checks_ssh
_checks_filesystem
_checks_network
_checks_logging
_checks_integrity
_checks_compliance

# ─── COMPUTE SCORE ───────────────────────────────────────────────────────────
TOTAL=$((PASS + WARN + FAIL))
SCORE=0
# Values passed with -v rather than interpolated into the awk program text.
# PASS and TOTAL are internal counters today, so this is hygiene rather than a
# fix, but a program built by string concatenation is one refactor away from
# taking a value it did not choose.
[[ "$TOTAL" -gt 0 ]] && SCORE=$(awk -v p="$PASS" -v t="$TOTAL" 'BEGIN {printf "%.0f", (p / t) * 100}')

# ─── RENDER OUTPUTS ──────────────────────────────────────────────────────────
_render_summary          # terminal score box + ansible remediation plan
_render_json             # JSON file (if $JSON_OUT set)
_render_html             # HTML file (if $HTML_OUT set)
