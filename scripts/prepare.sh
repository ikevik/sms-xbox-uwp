#!/usr/bin/env bash
# Make build/pcport-uwp: a copy of the sms-pc-port submodule (ext/sms-pc-port, with its own decomp and sdk
# submodules checked out) with patches/sms-port/*.patch applied and overlay/ copied over it. The build
# runs there. The submodule itself is never modified.
#
#   git submodule update --init --recursive
#   scripts/prepare.sh
#   cd build/pcport-uwp          # then the pipeline's steps (tools/ci/clang_survey.ps1 -Uwp)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${PCPORT_SRC:-$ROOT/ext/sms-pc-port}"
DST="${PCPORT_DST:-$ROOT/build/pcport-uwp}"
[ -f "$SRC/CMakeLists.txt" ] || { echo "sms-pc-port missing at $SRC (git submodule update --init --recursive)"; exit 1; }
[ -d "$SRC/decomp/src" ] || { echo "the decomp is missing in $SRC (git submodule update --init --recursive)"; exit 1; }

rm -rf "$DST"
mkdir -p "$DST"
# Everything but git's own files (a submodule's .git is a file, the main one a folder).
( cd "$SRC" && tar cf - --exclude=.git . ) | ( cd "$DST" && tar xf - )

n=0
for p in "$ROOT"/patches/sms-port/*.patch; do
  [ -f "$p" ] || continue
  if ( cd "$DST" && patch -p1 --no-backup-if-mismatch -s < "$p" ); then
    echo "applied $(basename "$p")"
    n=$((n + 1))
  else
    echo "FAILED  $(basename "$p")"
    exit 1
  fi
done

# Files this port adds (src/uwp, src/win_posix, third_party/angle-uwp, decomp-patches, tools, ...), at their paths.
cp -R "$ROOT"/overlay/. "$DST"/
echo "pcport-uwp ready: $DST ($n patches, overlay copied)"
