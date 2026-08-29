# ─── COLORS ──────────────────────────────────────────────────────────────────
# Only when stdout is a terminal. These used to be unconditional, so
# `aartool inspect > audit.txt` wrote 134 lines of raw \033[ escapes into the
# file, and the `aartool diff ... || mail` pattern the README suggests mailed
# escape sequences to whoever was on call.
#
# NO_COLOR is honoured because it is the convention every other CLI follows
# (no-color.org): set to anything, colour is off. FORCE_COLOR overrides in the
# other direction, for piping into `less -R` on purpose.
if [[ -n "${FORCE_COLOR:-}" ]] || { [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; }; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
  DIM='\033[2m'   # column headers and IDs: present, but not competing with the result
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''; DIM=''
fi

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

# A fixed-width rule with a column header, so a section reads as a table rather
# than as a stream. The old version appended a fixed-length bar to a
# variable-length title, so every section ended at a different column.
# The table has to fit the terminal it is printed in. This was a hard-coded 86,
# which is wider than the 80 columns a default terminal gives you, so every row
# wrapped and the table stopped being a table. Worse, the section rules were
# drawn at 86 while rows ran to 156 characters, because the DETAIL column had no
# bound at all: the rules ended 70 columns short of the content they were meant
# to be ruling off.
#
# tput needs a terminal; when there is none (a pipe, a file, CI) 100 is a
# sensible fixed width for a file someone will open later.
if [[ -t 1 ]]; then
  REPORT_WIDTH=$(tput cols 2>/dev/null || echo 86)
else
  REPORT_WIDTH=100
fi
[[ "$REPORT_WIDTH" =~ ^[0-9]+$ ]] || REPORT_WIDTH=86
(( REPORT_WIDTH < 60 ))  && REPORT_WIDTH=60    # below this nothing helps
(( REPORT_WIDTH > 140 )) && REPORT_WIDTH=140   # long lines are hard to track back

# Column widths derived from it once, so the header rule and the rows cannot
# disagree. 2 indent + 6 status + 1 + 9 id + 1 + name + 1 + detail.
COL_NAME=42
COL_DETAIL=$(( REPORT_WIDTH - 2 - 6 - 1 - 9 - 1 - COL_NAME - 1 ))
if (( COL_DETAIL < 18 )); then                 # narrow terminal: give up name width first
  COL_NAME=$(( COL_NAME - (18 - COL_DETAIL) ))
  (( COL_NAME < 20 )) && COL_NAME=20
  COL_DETAIL=$(( REPORT_WIDTH - 2 - 6 - 1 - 9 - 1 - COL_NAME - 1 ))
  (( COL_DETAIL < 8 )) && COL_DETAIL=8
fi
# A horizontal rule at the current table width. Every renderer that wants one
# calls this; literal runs of ━ were baked at 61 characters while the table was
# 86 and the rows were 156, so nothing lined up with anything.
rule() {
  local ch="${1:-━}" n="${2:-$REPORT_WIDTH}"
  printf '%*s' "$n" '' | tr ' ' "$ch"
}

section() {
  local title="$1" pad
  # Section titles used to be "1. SYSTEM & OS / Systeme et OS" and this stripped
  # the half after the slash. No caller passes one any more: the output is
  # English throughout. Kept because it costs nothing and a bilingual title
  # would otherwise print raw, but it is no longer doing any work.
  title="${title%% / *}"
  pad=$(( REPORT_WIDTH - ${#title} - 6 ))
  (( pad < 3 )) && pad=3
  printf "\n${BOLD}${CYAN}── %s %s${NC}\n" "$title" "$(printf '─%.0s' $(seq 1 "$pad"))"
  printf "${DIM}  %-6s %-9s %-*s %s${NC}\n" "STATUS" "ID" "$COL_NAME" "CHECK" "DETAIL"
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

# add_result CATEGORY STATUS ID NAME_EN NAME_FR DETAIL REMEDIATION
#
# NAME_FR is carried and rendered nowhere. That is deliberate, not an oversight:
# every output surface (terminal, HTML, JSON, dashboard) is English, and the
# report used to declare lang="fr" while printing English names either side of a
# French score label, which read as a bug rather than as a translation.
#
# The French names are kept because they are complete and correct, one for every
# branch of every check, properly accented. That is the expensive half of a
# French mode and it already exists; deleting it to save a bash array would mean
# rebuilding it later. scripts/tests/test_french_names.sh keeps it complete, so
# a French mode stays a switch rather than a project.
#
# The last parameter was documented as REMEDIATION_FR and has not been French
# for a long time; remediation text is English like everything else.
add_result() {
  local category="$1" status="$2" id="$3" name_en="$4" name_fr="$5"
  local detail="${6:-}" remediation="${7:-}"

  local color
  case "$status" in
    PASS) ((PASS++)); color=$GREEN ;;
    WARN) ((WARN++)); color=$YELLOW; WARN_IDS+=("$id") ;;
    FAIL) ((FAIL++)); color=$RED;    FAIL_IDS+=("$id") ;;
  esac

  # Terminal: one aligned row per check, streamed as it runs.
  #
  # No emoji in this column. ✅ is one cell wide, ⚠️ is two plus a variation
  # selector, and ❌ is two: mixing them means no two rows line up, which is
  # most of why 109 results read as a wall. The status word carries the colour
  # and aligns.
  #
  # The ID is printed because `aartool explain SSH-01` needs it, and until now
  # the only place to find it was the JSON report.
  # Truncate to the derived widths rather than letting DETAIL run to whatever
  # length the machine happened to produce. An ellipsis is honest: the full text
  # is in the JSON and the HTML, and `aartool explain <ID>` prints all of it.
  local _n="$name_en" _d="$detail"
  (( ${#_n} > COL_NAME ))   && _n="${_n:0:$((COL_NAME-1))}…"
  (( ${#_d} > COL_DETAIL )) && _d="${_d:0:$((COL_DETAIL-1))}…"
  printf "  ${color}%-6s${NC} ${DIM}%-9s${NC} %-*s %s\n" \
    "$status" "$id" "$COL_NAME" "$_n" "$_d"

  # Per-check hints are off by default: they doubled the length of every run,
  # and `aartool explain <ID>` gives the same thing in full, plus what closing
  # the finding costs. AARTOOL_HINTS=1, or `aartool inspect --hints`.
  if [[ "${AARTOOL_HINTS:-0}" == "1" && "$status" != "PASS" && -n "$remediation" ]]; then
    printf "         ${CYAN}hint: %s${NC}\n" "$remediation"
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
