#!/usr/bin/env bash
# Build the .deb and the .rpm.
#
# Usage: packaging/build.sh [OUTDIR]     (default: packaging/dist)
#
# The payload is staged with `git archive HEAD`, never copied from the working
# tree. That is a safety property, not tidiness: ansible-hardening/inventory/
# hosts is gitignored because it names real machines, and it is present in most
# working copies. Copying the tree would publish it to anyone who runs
# `apt install aartool`.
#
# nfpm runs in a container so this needs no packaging toolchain on the host and
# behaves the same here as it does in CI.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="${1:-$ROOT/packaging/dist}"
STAGE="$ROOT/packaging/stage"
NFPM_IMAGE="goreleaser/nfpm:v2.43.0"

VERSION="$(grep -oP '^AARTOOL_VERSION="\K[^"]+' scripts/aartool-src/main.sh)"
[[ -n "$VERSION" ]] || { echo "cannot read AARTOOL_VERSION" >&2; exit 1; }

echo "aartool $VERSION"

# ── Stage ────────────────────────────────────────────────────────────────────
rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE" "$OUT"

if ! git diff --quiet HEAD -- scripts/aartool; then
  echo "WARNING: scripts/aartool differs from HEAD. The package is built from" >&2
  echo "         HEAD, so your uncommitted bundle will NOT be in it." >&2
fi

git archive HEAD | tar -x -C "$STAGE"

# Prune what a user does not need at runtime. Everything here is either build
# scaffolding or test scaffolding; the sources stay on GitHub, which is where
# the GPL points people anyway.
rm -rf \
  "$STAGE/ansible-hardening/molecule" \
  "$STAGE/ansible-hardening/requirements-dev.txt" \
  "$STAGE/scripts/tests" \
  "$STAGE/scripts/src" \
  "$STAGE/scripts/aartool-src" \
  "$STAGE/scripts/build.sh" \
  "$STAGE/scripts/build-aartool.sh" \
  "$STAGE/execution-environment" \
  "$STAGE/packaging" \
  "$STAGE/.github" \
  "$STAGE/CLAUDE.md"

# The inventory must not be in the payload under any circumstances. git archive
# already excludes it, so this is a second lock on the same door: if it is ever
# committed by mistake, the build fails rather than shipping it.
if [[ -e "$STAGE/ansible-hardening/inventory/hosts" ]]; then
  echo "REFUSING TO BUILD: ansible-hardening/inventory/hosts is in the payload." >&2
  echo "That file names real machines and is meant to be gitignored." >&2
  exit 1
fi

# Tells resolve_paths that this is a packaged install, so it reads the
# inventory from /etc/aartool rather than from under /usr/share.
printf 'Installed from a distribution package. Inventory lives in /etc/aartool/inventory.\n' \
  > "$STAGE/.packaged"

# nfpm takes each file's mode from the stage, and a working copy carries
# whatever the developer's umask produced. Here that was 0640 and 0750, which
# packages a tool root can run and no other user can even read. Normalise:
# everyone may read, directories stay traversable, and the executable bit is
# preserved only where it already existed. Same fix, and the same reason, as
# the chmod that follows an rsync into a webroot.
chmod -R a+rX "$STAGE"

# ── Build ────────────────────────────────────────────────────────────────────
for pkg in deb rpm; do
  docker run --rm \
    -v "$ROOT/packaging:/work" \
    -v "$OUT:/out" \
    -w /work \
    -e "AARTOOL_VERSION=$VERSION" \
    "$NFPM_IMAGE" \
    package --config /work/nfpm.yaml --packager "$pkg" --target /out
done

rm -rf "$STAGE"

echo
ls -1 "$OUT"
( cd "$OUT" && sha256sum ./* > SHA256SUMS && cat SHA256SUMS )
