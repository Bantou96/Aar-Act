#!/usr/bin/env bash
# The single filesystem pass must agree with the three walks it replaced.
#
# FS-05, FS-07 and FS-10 each ran `find / -xdev` separately. They now share one
# traversal, which is roughly 3x less I/O and, on a host with a real number of
# inodes, the difference between an audit that feels instant and one that looks
# hung. That is only worth having if the numbers are the same, and "the same"
# is not something to assume about a rewritten find expression.
#
# Runs against a fixture tree rather than /, so it is fast, deterministic, and
# does not need root.
#
# Run: bash scripts/tests/test_fs_walk.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }

ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT

# A tree with a known answer for each predicate, including the cases that make
# the combined expression easy to get wrong.
mkdir -p "$ROOT"/{bin,shared,sticky,nested/deep}
: > "$ROOT/bin/su";        chmod 4755 "$ROOT/bin/su"          # SUID  -> S
: > "$ROOT/bin/mount";     chmod 4711 "$ROOT/bin/mount"       # SUID  -> S
: > "$ROOT/bin/plain";     chmod 0755 "$ROOT/bin/plain"       # not SUID
: > "$ROOT/bin/sgid";      chmod 2755 "$ROOT/bin/sgid"        # SGID, not SUID
chmod 0777 "$ROOT/shared"                                     # ww, no sticky -> T
chmod 1777 "$ROOT/sticky"                                     # ww WITH sticky, not counted
chmod 0777 "$ROOT/nested/deep"                                # ww, no sticky -> T
# A world-writable FILE must not be counted as a directory.
: > "$ROOT/shared/loose";  chmod 0666 "$ROOT/shared/loose"

# THE case this fixture originally missed: a file matching TWO predicates.
# The first combined expression joined its groups with -o, which short-circuits,
# so a SUID file that was also unowned printed S and never reached the unowned
# clause. The fixture had no overlapping file, so it passed a broken expression
# and the bug was only caught by diffing against the three walks on a real
# filesystem. A fixture that cannot express the overlap cannot test the operator.
: > "$ROOT/bin/suid_unowned"
# chown BEFORE chmod. POSIX has chown clear the setuid and setgid bits, so
# doing it the other way round produced a file that was no longer SUID and the
# overlap this case exists to test quietly disappeared.
chown 65533:65533 "$ROOT/bin/suid_unowned" 2>/dev/null || SKIP_OVERLAP=1
chmod 4755 "$ROOT/bin/suid_unowned"

# Three SUID files: su, mount, suid_unowned. sgid is 2755, which is SGID and
# must not count. The file is created either way; only the chown is conditional,
# so WANT_S does not depend on it.
WANT_S=3 WANT_T=2

three_s=$(find "$ROOT" -xdev -perm -4000 -type f 2>/dev/null | wc -l)
three_t=$(find "$ROOT" -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | wc -l)

three_u=$(find "$ROOT" -xdev \( -nouser -o -nogroup \) -type f 2>/dev/null | wc -l)

one_s=0 one_t=0 one_u=0
while read -r tag; do
  case "$tag" in
    S) one_s=$((one_s+1)) ;;
    T) one_t=$((one_t+1)) ;;
    U) one_u=$((one_u+1)) ;;
  esac
done < <(find "$ROOT" -xdev \
    \( -type f -perm -4000 -printf 'S\n' -o -true \) \
    \( -type d -perm -0002 ! -perm -1000 -printf 'T\n' -o -true \) \
    \( -type f \( -nouser -o -nogroup \) -printf 'U\n' -o -true \) 2>/dev/null)

# Against the fixture's known answer, so a bug present in BOTH expressions is
# still caught. Comparing them only to each other would pass on two wrongs.
[[ "$three_s" == "$WANT_S" ]] && ok || bad "three-walk SUID: want $WANT_S, got $three_s"
[[ "$three_t" == "$WANT_T" ]] && ok || bad "three-walk sticky: want $WANT_T, got $three_t"
[[ "$one_s"   == "$WANT_S" ]] && ok || bad "single-pass SUID: want $WANT_S, got $one_s"
[[ "$one_t"   == "$WANT_T" ]] && ok || bad "single-pass sticky: want $WANT_T, got $one_t"
[[ "$one_u"   == "$three_u" ]] && ok || bad "single-pass unowned: want $three_u, got $one_u"
[[ "$one_s" == "$three_s" && "$one_t" == "$three_t" && "$one_u" == "$three_u" ]] && ok \
  || bad "single pass disagrees with the three walks it replaced"

# The overlap itself: a file that is both SUID and unowned must appear in BOTH
# counts. This is the assertion that fails on a short-circuiting -o.
if [[ -z "${SKIP_OVERLAP:-}" ]]; then
  if (( one_s == 3 && one_u >= 1 )); then ok; else
    bad "a file that is both SUID and unowned was counted once, not twice (S=$one_s U=$one_u); the groups are short-circuiting"
  fi
else
  ok   # chown needs root; the overlap case cannot be built here
fi

# The fallback exists for a find without -printf. If -printf ever stops being
# detected on a GNU host, three checks would silently report zero.
find / -xdev -maxdepth 0 -printf '' 2>/dev/null && ok \
  || bad "find -printf not detected on this host; the combined pass would be skipped"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
