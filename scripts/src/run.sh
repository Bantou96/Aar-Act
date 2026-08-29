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
# The human-readable one above has no timezone, which is fine on a page someone
# reads and wrong for the SIEM ingestion docs/BASELINE.md advertises: two hosts
# in two zones produce timestamps that cannot be ordered. Emitted alongside
# rather than instead, because `date` is in the HTML header and is what the
# dashboard sorts on in every report already written.
DATE_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
OS_VAL=$(grep -oP '(?<=^PRETTY_NAME=").+(?=")' /etc/os-release 2>/dev/null || uname -o)

# ─── RUN CHECKS ──────────────────────────────────────────────────────────────
_checks_system
# Kernel checks used to run at bundle-load time, because this file was the only
# check family with no wrapping function. That put twelve unlabelled KRN rows
# above section 1, before any header had been printed. It runs here now, which
# is where build.sh already placed the file in the concatenation order.
_checks_kernel
_checks_auth
_checks_ssh
_checks_filesystem
_checks_network
_checks_logging
_checks_integrity
_checks_compliance

# ─── COMPUTE SCORE ───────────────────────────────────────────────────────────
# A warning counts as half a failure, not as a whole one.
#
# This used to be PASS / TOTAL, which penalised a WARN exactly as hard as a
# FAIL. A stock Ubuntu box with 8 real failures and 57 warnings scored 40% in
# red, and a reader has no way to tell that from a machine with 65 failures.
# Worse, many warnings are "cannot determine" rather than "is wrong": no /boot
# to read, no mokutil installed, a container with no systemd. Scoring those
# identically to PermitRootLogin=yes is what made the number untrustworthy, and
# a number nobody trusts gets ignored along with the findings under it.
#
# FAIL still costs full marks. The point is that the headline number should
# separate "wrong" from "unverified", which is the same distinction `advise`
# makes when it pulls decisions out into their own list.
TOTAL=$((PASS + WARN + FAIL))
SCORE=0
# Values passed with -v rather than interpolated into the awk program text.
# PASS and TOTAL are internal counters today, so this is hygiene rather than a
# fix, but a program built by string concatenation is one refactor away from
# taking a value it did not choose.
[[ "$TOTAL" -gt 0 ]] && SCORE=$(awk -v p="$PASS" -v w="$WARN" -v t="$TOTAL" \
  'BEGIN {printf "%.0f", ((p + (w * 0.5)) / t) * 100}')

# ─── RENDER OUTPUTS ──────────────────────────────────────────────────────────
_render_summary          # terminal score box + ansible remediation plan
_render_json             # JSON file (if $JSON_OUT set)
_render_html             # HTML file (if $HTML_OUT set)

# ─── HAND THE REPORTS BACK ───────────────────────────────────────────────────
# This script has to run as root: it reads sshd_config, /etc/shadow and the
# audit rules. Everything it writes was therefore owned by root, mode 600, and
# under sudo that left the person who ran it unable to open the report the tool
# had just printed a path to. `aartool report` and `aartool diff` both failed on
# it with a permission error.
#
# `aartool inspect` already handled this (cmd/inspect.sh). The standalone script
# did not, and the standalone script is the path the README advertises as the
# fastest way to try the tool, so this was the first-run experience.
#
# Only files this run wrote, and the directory only when this run created it: a
# --output-dir the user pointed at something pre-existing is not ours to give
# away.
if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
  for _f in "$JSON_OUT" "$HTML_OUT"; do
    [[ -n "$_f" && -e "$_f" ]] && chown "${SUDO_UID}:${SUDO_GID}" "$_f" 2>/dev/null
  done
  [[ "${OUTPUT_DIR_CREATED:-false}" == true && -d "$OUTPUT_DIR" ]] \
    && chown "${SUDO_UID}:${SUDO_GID}" "$OUTPUT_DIR" 2>/dev/null
  true
fi
