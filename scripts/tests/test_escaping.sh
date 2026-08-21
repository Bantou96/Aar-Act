#!/usr/bin/env bash
# Regression tests for the escaping helpers.
#
# These exist because html_escape was silently broken on bash 5.2 and later.
# 5.2 added the patsub_replacement option, on by default, which makes an
# unescaped & in a ${var//pattern/replacement} replacement expand to the matched
# text, exactly as sed does. "${s//</&lt;}" therefore produced "<lt;" and the
# function stopped escaping anything, on Ubuntu 24.04, Debian 13, Fedora 38+ and
# RHEL 10. Nothing failed loudly: the report was still written, and every value
# taken from the audited machine landed in it raw.
#
# Run: bash scripts/tests/test_escaping.sh
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
source src/lib/core.sh

PASS=0 FAIL=0
check() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n      want: %s\n      got:  %s\n' "$label" "$want" "$got"
  fi
}

# ── html_escape ──────────────────────────────────────────────────────────────
check "html: script tag"  "$(html_escape '<script>')"      '&lt;script&gt;'
check "html: ampersand"   "$(html_escape 'a & b')"         'a &amp; b'
check "html: quote"       "$(html_escape 'a"b')"           'a&quot;b'
check "html: apostrophe"  "$(html_escape "a'b")"           'a&#39;b'
check "html: gt"          "$(html_escape 'a>b')"           'a&gt;b'
check "html: empty"       "$(html_escape '')"              ''
check "html: plain"       "$(html_escape 'ubuntu 24.04')"  'ubuntu 24.04'

# Ampersand must be replaced first, or the entities it produces get re-escaped.
check "html: order"       "$(html_escape '&lt;')"          '&amp;lt;'

# Attribute break-out, the reason the quote cases matter.
check "html: attr breakout" "$(html_escape 'x" onload="alert(1)')" \
                            'x&quot; onload=&quot;alert(1)'

# ── json_escape ──────────────────────────────────────────────────────────────
check "json: quote"       "$(json_escape 'a"b')"           'a\"b'
check "json: backslash"   "$(json_escape 'a\b')"           'a\\b'
check "json: newline"     "$(json_escape "$(printf 'a\nb')")" 'a b'
check "json: plain"       "$(json_escape 'ubuntu 24.04')"  'ubuntu 24.04'

# Backslash must be replaced before the quote, or \" becomes \\" and shifts.
check "json: order"       "$(json_escape 'a\"b')"          'a\\\"b'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
