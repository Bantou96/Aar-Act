#!/usr/bin/env bash
# Version consistency guard.
#
# The audit script was at 4.2.0 while every JSON report it wrote claimed
# "version": "4.0.0", because the renderer had the number typed into it as a
# literal. Nothing failed. The reports were valid, the number was simply wrong,
# and anything keying off it (a SIEM ingest, a comparison across tool versions,
# an auditor asking which build produced the evidence) was told something untrue
# for as long as the drift lasted.
#
# Numbers that must agree, agree here or the build fails.
#
# Run: bash scripts/tests/test_versions.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }
eq() {
  local what="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then ok; else bad "$what: got '$got', want '$want'"; fi
}

semver='^[0-9]+\.[0-9]+\.[0-9]+$'

# ── The declared versions ────────────────────────────────────────────────────
BASELINE_SRC=$(grep -oP '^SCRIPT_VERSION="\K[^"]+'   src/main.sh)
BASELINE_BIN=$(grep -oP '^SCRIPT_VERSION="\K[^"]+'   cyberaar-baseline.sh)
AARTOOL_SRC=$(grep -oP '^AARTOOL_VERSION="\K[^"]+'   aartool-src/main.sh)
AARTOOL_BIN=$(grep -oP '^AARTOOL_VERSION="\K[^"]+'   aartool)
COLLECTION=$(grep -oP '^version:\s*\K\S+'            ../ansible-hardening/galaxy.yml)

for v in "$BASELINE_SRC" "$AARTOOL_SRC" "$COLLECTION"; do
  [[ "$v" =~ $semver ]] && ok || bad "not a semver: '$v'"
done

# ── A generated bundle must carry its source's version ───────────────────────
# The bundles are built, not edited. If someone bumps the source and forgets to
# rebuild, the committed script keeps shipping the old number. CI already fails
# on bundle drift; this says which number is wrong when it does.
eq "cyberaar-baseline.sh bundle version" "$BASELINE_BIN" "$BASELINE_SRC"
eq "aartool bundle version"              "$AARTOOL_BIN"  "$AARTOOL_SRC"

# ── Reports must state the version that produced them ────────────────────────
# Not a literal. This is the bug the file exists for.
if grep -qF '"version": "${SCRIPT_VERSION}"' src/renderers/json.sh; then
  ok
else
  bad "the JSON renderer hardcodes a version instead of using \$SCRIPT_VERSION"
fi
if grep -qP '"version":\s*"[0-9]+\.[0-9]+\.[0-9]+"' src/renderers/json.sh; then
  bad "the JSON renderer still contains a literal version number"
else
  ok
fi

# The HTML report shows it too, and must interpolate for the same reason.
if grep -q 'v\${SCRIPT_VERSION}' src/renderers/html.sh; then ok
else bad "the HTML renderer does not interpolate SCRIPT_VERSION"; fi

# ── The container image tag follows the collection version ───────────────────
# The EE workflow reads galaxy.yml to tag the image. If it stopped doing that,
# the published image and the collection inside it would part company.
if grep -q "grep '\^version:' ansible-hardening/galaxy.yml" ../.github/workflows/ee-build.yml; then
  ok
else
  bad "ee-build.yml no longer derives the image tag from galaxy.yml"
fi

# ── The changelog has an entry for the collection version being shipped ──────
if grep -qF "## [${COLLECTION}]" ../ansible-hardening/CHANGELOG.md; then
  ok
else
  bad "CHANGELOG.md has no '## [${COLLECTION}]' entry for the version in galaxy.yml"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
