#!/usr/bin/env bash
# Every add_result must carry a French check name.
#
# NAME_FR is rendered by nothing today: the tool is English everywhere. It is
# kept because it is complete, one correct and accented name for every branch of
# every check, and that is the expensive half of a French mode. An asset like
# that does not die by being deleted, it dies by rotting: someone adds a check
# family, passes "" because nothing displays it anyway, and a year later it is
# 80% complete and worth nothing. Then French becomes a project instead of a
# switch, and the work already done is wasted.
#
# So this guards completeness rather than use. It deliberately does NOT check
# translation quality, which no test can do.
#
# Run: bash scripts/tests/test_french_names.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }

mapfile -t FILES < <(ls src/checks/*.sh)
[[ ${#FILES[@]} -ge 8 ]] || { echo "FAIL  only ${#FILES[@]} check files found; the glob is wrong"; exit 1; }

total=0
for f in "${FILES[@]}"; do
  # Positional call: add_result CATEGORY STATUS ID NAME_EN NAME_FR ...
  # Read with the same field order the function uses, from the source, so a call
  # that spreads over two lines is still seen.
  while IFS=$'\t' read -r id name_en name_fr; do
    total=$((total+1))
    if [[ -z "${name_fr// }" ]]; then
      bad "$(basename "$f"): $id \"$name_en\" has no French name"
    elif [[ "$name_fr" == "$name_en" ]]; then
      # Not automatically wrong: "SELinux Enforcing" and "SELinux Permissive"
      # are the same in both languages, and those are the only two in the tree
      # today, at 17 and 18 characters. A longer string identical on both sides
      # is a copy, which is how this rots quietly. The threshold is set from
      # those two rather than picked: 20 leaves them room and still catches a
      # copied sentence.
      if (( ${#name_en} > 20 )); then
        bad "$(basename "$f"): $id French name is a copy of the English: \"$name_fr\""
      else
        ok
      fi
    else
      ok
    fi
  done < <(
    perl -0777 -ne 'while (/add_result\s+"[^"]*"\s+"[^"]*"\s+"([^"]*)"\s+"([^"]*)"\s+"([^"]*)"/gs) { print "$1\t$2\t$3\n" }' "$f"
  )
done

# ── The other half: everything that IS rendered must be English ─────────────
#
# NAME_FR above is deliberate French that nothing displays. DETAIL and
# REMEDIATION are the opposite: they are printed in the terminal, written into
# the JSON and rendered in the HTML report, so French in them is a defect. Six
# were found by a human opening a report in 2026-08-31: four "Appliquez:" in
# sys.sh, an "Isolez /tmp: ajoutez ... dans /etc/fstab" and a "Si IPv6 non
# requis: ... dans /etc/sysctl.d/".
#
# The existing prose guard in test_dashboard.sh could not have caught them: it
# reads the RENDERER, and these strings live in the checks. Guard the fields
# themselves, extracted the same way the function reads them, so the check is
# about the category rather than about the six strings that were found.
#
# The word list is restricted to French words that are not also English. "plus"
# is the trap: "plus blacklist iwlwifi" is a correct English remediation and the
# broader list in test_dashboard.sh flags it.
fr_rendered='appliquez|ajoutez|isolez|activez|desactivez|d\xc3\xa9sactivez|verifiez|v\xc3\xa9rifiez|installez|configurez|laissez|dans|pour|une|avec|cette|aux|les|des|sont|selon|chaque|leur|entre|sans|requis'
fr_rendered=$(printf '%b' "$fr_rendered")

rendered=0
for f in "${FILES[@]}"; do
  # Args 6 and 7 (DETAIL, REMEDIATION) are optional and usually sit on a
  # backslash continuation, so the separator class has to allow the backslash
  # itself. \s alone stops at it and silently matches nothing.
  while IFS=$'\t' read -r id field text; do
    [[ -z "${text// }" ]] && continue
    rendered=$((rendered+1))
    hit=$(printf '%s' "$text" | grep -oiP "\\b($fr_rendered)\\b" | sort -u | paste -sd, - || true)
    if [[ -n "$hit" ]]; then
      bad "$(basename "$f"): $id $field is French ($hit): \"$text\""
    else
      ok
    fi
  done < <(
    perl -0777 -ne '
      while (/add_result[\s\\]+"[^"]*"[\s\\]+"[^"]*"[\s\\]+"([^"]*)"[\s\\]+"[^"]*"[\s\\]+"[^"]*"(?:[\s\\]+"([^"]*)")?(?:[\s\\]+"([^"]*)")?/gs) {
        my ($id, $detail, $rem) = ($1, $2, $3);
        print "$id\tDETAIL\t$detail\n"      if defined $detail && $detail ne "";
        print "$id\tREMEDIATION\t$rem\n"    if defined $rem    && $rem    ne "";
      }' "$f"
  )
done

# Same reasoning as the count assertion below: a guard that reads nothing passes
# forever. These fields are optional, so the floor is lower than for the names.
if (( rendered >= 150 )); then ok; else
  bad "only $rendered detail/remediation strings parsed; expected 150+, so the extraction is broken"
fi

# The extraction itself has to be believable: if the regex stops matching, every
# assertion above silently passes on an empty set.
if (( total >= 200 )); then ok; else
  bad "only $total add_result calls parsed; expected 200+, so the extraction is broken"
fi

printf '\n%d passed, %d failed  (%d calls checked, %d rendered strings)\n' "$PASS" "$FAIL" "$total" "$rendered"
[[ "$FAIL" -eq 0 ]]
