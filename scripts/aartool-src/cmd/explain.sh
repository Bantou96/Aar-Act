# ── explain ──────────────────────────────────────────────────────────────────
# A report that says "FAIL SSH-09: weak algorithms" tells an operator that
# something is wrong and nothing about what to do, what it costs, or whether it
# matters more than the thirty-nine other lines. That gap is where hardening
# reports go to die: read once, filed, never acted on.
#
# explain answers for any check ID, from three sources in order of depth:
#   1. a written entry, where knowing the mechanism changes the decision
#   2. the remediation map, which covers 99 of 109 IDs
#   3. the check's own title, read out of the built baseline
#
# It never says "no information". A command that sometimes refuses to answer
# stops being the thing people reach for.

# Pull one field out of the ANSIBLE_MAP entry in the built baseline.
# Format: ["ID"]="tags|role_rhel|role_ubuntu|description"
_explain_map_line() {
  grep -oP '^\s*\["'"$1"'"\]="\K[^"]+' "$BASELINE" 2>/dev/null | head -1 || true
}

# The English title, from the add_result the check emits. Its category, status,
# id and title are on one physical line, so this is a plain grep.
#
# Prefer the PASS branch. Checks name the state they want, so the PASS title is
# the name of the control; the first branch in file order is often a diagnostic
# ("Cannot determine installed kernels") that reads like nonsense as a heading.
_explain_title() {
  local t
  t=$(grep -oP 'add_result\s+"[^"]+"\s+"PASS"\s+"'"$1"'"\s+"\K[^"]+' "$BASELINE" 2>/dev/null | head -1 || true)
  [[ -n "$t" ]] || t=$(grep -oP 'add_result\s+"[^"]+"\s+"[^"]+"\s+"'"$1"'"\s+"\K[^"]+' "$BASELINE" 2>/dev/null | head -1 || true)
  printf '%s' "$t"
}

_explain_category() {
  grep -oP 'add_result\s+"\K[^"]+(?="\s+"[^"]+"\s+"'"$1"'")' "$BASELINE" 2>/dev/null | head -1 || true
}

_explain_usage() {
  cat <<'EOF'
aartool explain: what a finding means, what it costs, and what to do

Usage:
  aartool explain <CHECK-ID>     Explain one check
  aartool explain --list         List every check ID aartool knows
  aartool explain --written      List the IDs with a written entry

Examples:
  aartool explain KRN-01         # the doorway most Linux LPEs walk through
  aartool explain SSH-02
  aartool explain --list | grep KRN

IDs come from an audit. Run 'aartool inspect' first if you do not have one.
EOF
}

# Every ID the baseline can emit, in file order.
_explain_all_ids() {
  grep -oP 'add_result\s+"[^"]+"\s+"[^"]+"\s+"\K[A-Z]+-[0-9]+' "$BASELINE" 2>/dev/null \
    | awk '!seen[$0]++' || true
}

cmd_explain() {
  resolve_paths

  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) _explain_usage; return 0 ;;
      --list)
        _explain_all_ids | while read -r i; do
          printf '  %-10s %s\n' "$i" "$(_explain_title "$i")"
        done
        return 0 ;;
      --written) kb_ids | tr ' ' '\n' | grep -v '^$' | sed 's/^/  /'; return 0 ;;
      -*) die "Unknown option for explain: $1. Try 'aartool explain --help'." ;;
      *)  [[ -z "$id" ]] || die "explain takes one check ID at a time. Got '$id' and '$1'."
          id="${1^^}"; shift ;;
    esac
  done

  [[ -n "$id" ]] || { _explain_usage; return 1; }

  local title; title="$(_explain_title "$id")"
  if [[ -z "$title" ]]; then
    # Suggest, rather than just refusing. A wrong ID is nearly always a typo or
    # a family guess, and the family prefix is enough to be useful.
    local family="${id%%-*}" near
    near="$(_explain_all_ids | grep "^${family}-" | head -8 | tr '\n' ' ' || true)"
    if [[ -n "$near" ]]; then
      die "No check called '$id'. Checks in the $family family: $near
        Full list: aartool explain --list"
    fi
    die "No check called '$id'. See the full list: aartool explain --list"
  fi

  printf '\n%s%s%s  %s\n' "$BOLD" "$id" "$RESET" "$title"
  local cat; cat="$(_explain_category "$id")"
  [[ -n "$cat" ]] && printf '%sCategory: %s%s\n' "$CYAN" "$cat" "$RESET"
  printf '\n'

  if kb_has "$id"; then
    kb_entry "$id" | sed -e 's/^/  /' -e 's/[[:space:]]*$//'
  else
    # No written entry. Assemble one from the remediation map, which is
    # generated from the same table the reports use, so it cannot go stale
    # relative to what apply would actually do.
    local map; map="$(_explain_map_line "$id")"
    if [[ -n "$map" ]]; then
      local tags rhel ubu desc
      IFS='|' read -r tags rhel ubu desc <<<"$map"
      cat <<EOF | sed -e 's/^/  /' -e 's/[[:space:]]*$//'
WHAT
  $desc

FIX WITH AARTOOL
  aartool plan  --target HOST --user USER --only ${tags%%,*}
  aartool apply --target HOST --user USER --only ${tags%%,*}

  tags   $tags
  roles  $rhel (RHEL 9 family)
         $ubu (Debian / Ubuntu)

MORE
  No written entry for this check yet. To see exactly what apply would change
  on a real machine, run the plan above: it is a dry run and changes nothing.
  Written entries: aartool explain --written
EOF
    else
      cat <<EOF | sed -e 's/^/  /' -e 's/[[:space:]]*$//'
WHAT
  $title

FIX WITH AARTOOL
  Nothing. This check is deliberately not mapped to a role, which means one of
  two things: it is informational, or its remediation is not a configuration
  change a playbook can make safely (a reboot, a boot parameter, or a decision
  that needs someone who knows what the machine runs).

MORE
  Run 'aartool inspect' to see the evidence line for this check on the machine
  itself. It carries the observed value, which is usually the missing piece.
EOF
    fi
  fi
  printf '\n'
}
