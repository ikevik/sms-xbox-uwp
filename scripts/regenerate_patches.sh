#!/usr/bin/env bash
# Transition aid while the work is still done in the fork (https://github.com/ikevik/sms-pc-port, branch uwp-xbox):
# rebuilds patches/sms-port/ and overlay/ from the fork's tip, as the difference to the sms-pc-port commit this
# repo pins. Edited upstream files go into the patches below (a file's whole difference in one patch); files the
# fork adds are copied into overlay/ at the same paths. azure-pipelines*.yml stay as they are here: they are
# written for this layout, so they are never overwritten.
#
#   FORK=/path/to/the/fork scripts/regenerate_patches.sh [fork ref, default HEAD]
#
# A fork file that is edited but not listed below stops the script; list it in the patch it belongs to.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORK="${FORK:-$HOME/sms-pc-port}"
REF="${1:-HEAD}"
BASE="$(git -C "$ROOT/ext/sms-pc-port" rev-parse HEAD)"   # the pinned upstream commit
git -C "$FORK" merge-base --is-ancestor "$BASE" "$REF" || { echo "the fork's $REF does not contain the pinned commit $BASE"; exit 1; }

patch_name() {   # the patch an edited file belongs to
  case "$1" in
    .gitignore|CMakeLists.txt|src/port_compat.h|src/port_include/sms_modhook.h|platform/mtx/mtx.cpp|platform/os/crash_info.cpp|platform/os/os_thread.cpp|ext/coop/game/coop.cpp|ext/multiplayer/game/mp_game.cpp|ext/multiplayer/game/mp_server.cpp)
      echo 0001-msvc-and-uwp-build ;;
    platform/gx/CMakeLists.txt|platform/gx/src/gl_loader.cpp|platform/gx/src/gx_render.cpp|platform/gx/src/gx_platform.cpp|platform/gx/src/gx_shader.cpp|platform/gx/src/gx_hdr.cpp|platform/gx/src/gx_hires.cpp)
      echo 0002-uwp-angle-renderer ;;
    platform/audio/ai.cpp)
      echo 0003-uwp-xaudio2-output ;;
    platform/card/card.cpp|platform/misc/port_settings.cpp|src/port_include/port_settings.h|platform/vi/vi.cpp)
      echo 0004-saves-and-menu-settings ;;
    *) echo "" ;;
  esac
}

cd "$ROOT"
rm -rf patches/sms-port overlay
mkdir -p patches/sms-port overlay

edited="$(git -C "$FORK" diff --name-only --diff-filter=M "$BASE..$REF")"
other="$(git -C "$FORK" diff --name-only --diff-filter=DRTUXB "$BASE..$REF")"
[ -z "$other" ] || { echo "deleted, renamed or retyped files need a patch group of their own:"; echo "$other"; exit 1; }

unlisted=""
names=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n="$(patch_name "$f")"
  if [ -z "$n" ]; then unlisted="$unlisted $f"; else names="$names $n"; fi
done <<< "$edited"
[ -z "$unlisted" ] || { echo "edited files that no patch lists:$unlisted"; exit 1; }

for n in $(printf '%s\n' $names | sort -u); do
  files=()
  while IFS= read -r f; do
    [ -n "$f" ] && [ "$(patch_name "$f")" = "$n" ] && files+=("$f")
  done <<< "$edited"
  git -C "$FORK" diff --no-color --no-ext-diff "$BASE..$REF" -- "${files[@]}" > "patches/sms-port/$n.patch"
  echo "patches/sms-port/$n.patch: ${#files[@]} files, $(grep -c '^[+][^+]' "patches/sms-port/$n.patch") lines added"
done

added="$(git -C "$FORK" diff --name-only --diff-filter=A "$BASE..$REF" | grep -v '^azure-pipelines.*\.yml$' || true)"
echo "$added" | while IFS= read -r f; do [ -n "$f" ] && echo "$f"; done > /dev/null
git -C "$FORK" archive "$REF" -- $(echo "$added" | tr '\n' ' ') | tar -x -C overlay
echo "overlay/: $(echo "$added" | grep -c .) files"
