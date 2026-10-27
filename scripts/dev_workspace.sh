#!/usr/bin/env bash
# Make build/pcport-dev, a place to change sms-pc-port for the Xbox: the tree scripts/prepare.sh makes, as a git
# repository, so that `git status`, `git diff` and `git log` there show what you changed.
#
#   upstream   the pinned sms-pc-port, as it is (tagged "pristine")
#   patches    patches/sms-port/ applied
#   overlay    overlay/ copied over it (tagged "prepared")
#
# Edit files in build/pcport-dev (commit there if you like: the commits stay local); scripts/save_patches.sh then turns
# the difference to "pristine" into patches/sms-port/ and overlay/. The game's own sources (decomp/) are not changed
# here: a change to them is a new patch in overlay/decomp-patches/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${PCPORT_SRC:-$ROOT/ext/sms-pc-port}"
DST="${WORK:-$ROOT/build/pcport-dev}"
[ -f "$SRC/CMakeLists.txt" ] && [ -d "$SRC/decomp/src" ] || { echo "sms-pc-port is missing at $SRC (git submodule update --init --recursive)"; exit 1; }
[ -z "$(git -C "$ROOT" status --porcelain -- patches/sms-port overlay)" ] || {
  echo "patches/sms-port/ or overlay/ have uncommitted changes; commit or discard them first, so the workspace starts from what is committed:"
  git -C "$ROOT" status --short -- patches/sms-port overlay
  exit 1
}
if [ -d "$DST/.git" ] && [ -n "$(git -C "$DST" status --porcelain)" ] && [ "${FORCE:-}" != 1 ]; then
  echo "$DST has changes that are not saved (scripts/save_patches.sh). FORCE=1 starts it again and drops them."
  exit 1
fi

rm -rf "$DST"
mkdir -p "$DST"
( cd "$SRC" && tar cf - --exclude=.git . ) | ( cd "$DST" && tar xf - )

export GIT_AUTHOR_NAME=workspace GIT_AUTHOR_EMAIL=workspace@localhost GIT_COMMITTER_NAME=workspace GIT_COMMITTER_EMAIL=workspace@localhost
cd "$DST"
git init -q
git config core.autocrlf false
printf '* -text\n' > .git/info/attributes     # no line-ending conversion: the patches must match the files byte for byte
printf '/build*\n' >> .git/info/exclude     # a build made here is not part of the change
git add -A -f >/dev/null
git commit -q -m "upstream: sms-pc-port at the pinned commit $(git -C "$SRC" rev-parse --short HEAD)"
git tag pristine

for p in "$ROOT"/patches/sms-port/*.patch; do
  [ -f "$p" ] || continue
  patch -p1 --no-backup-if-mismatch -s < "$p"
done
git add -A >/dev/null
git commit -q --allow-empty -m "patches: patches/sms-port applied"

cp -R "$ROOT"/overlay/. "$DST"/
git add -A >/dev/null
git commit -q --allow-empty -m "overlay: overlay/ copied over"
git tag prepared

# What the workspace was made from (patches/ and overlay/ as they are now), so that saving from a stale one is refused.
hash_tool() { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; }
( cd "$ROOT" && find patches/sms-port overlay -type f | LC_ALL=C sort | while IFS= read -r f; do hash_tool < "$f" | cut -d' ' -f1; echo "$f"; done | hash_tool | cut -d' ' -f1 ) > .git/sms-saved-from
echo "workspace ready: $DST"
echo "edit there, then: scripts/save_patches.sh"
