#!/usr/bin/env bash
# Save what was changed in the workspace (build/pcport-dev, from scripts/dev_workspace.sh) as patches/sms-port/ and
# overlay/: every file of sms-pc-port that differs from the pinned commit goes into a patch (the one patches/groups.txt
# names for it, else 0099-other), every file that is new goes into overlay/ at its path. Then it proves the result: it
# rebuilds the tree from the saved patches and overlay and compares it with the workspace.
#
#   scripts/save_patches.sh        then review `git diff` and commit
#
# The workspace is the only place patches/ and overlay/ are written from: they are rebuilt whole. If they changed
# since the workspace was made or last saved (a pull, an edit by hand), saving is refused: FORCE=1 overrides.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$ROOT/build/pcport-dev}"
[ -d "$WORK/.git" ] || { echo "no workspace at $WORK (scripts/dev_workspace.sh)"; exit 1; }

hash_tool() { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; }
state() { ( cd "$ROOT" && find patches/sms-port overlay -type f | LC_ALL=C sort | while IFS= read -r f; do hash_tool < "$f" | cut -d' ' -f1; echo "$f"; done | hash_tool | cut -d' ' -f1 ); }
if [ "${FORCE:-}" != 1 ] && [ "$(state)" != "$(cat "$WORK/.git/sms-saved-from" 2>/dev/null || true)" ]; then
  echo "patches/ or overlay/ changed since the workspace was made or last saved; saving would overwrite that."
  echo "Make the workspace again (scripts/dev_workspace.sh) or FORCE=1 to overwrite."
  exit 1
fi

cd "$WORK"
export GIT_AUTHOR_NAME=workspace GIT_AUTHOR_EMAIL=workspace@localhost GIT_COMMITTER_NAME=workspace GIT_COMMITTER_EMAIL=workspace@localhost
git add -A >/dev/null    # only the index of the workspace: its files stay as they are

diff_names() { git diff --cached --no-renames --name-only "--diff-filter=$1" pristine; }
group_of() { awk -F'\t' -v f="$1" '$0 !~ /^#/ && $2 == f { print $1; found = 1; exit } END { if (!found) print "0099-other" }' "$ROOT/patches/groups.txt"; }

edited="$(diff_names MDTU)"
added="$(diff_names A)"

# decomp/ and sdk/ are other projects' sources: not patched here (the game's changes are decomp-patches/ files)
bad="$( { echo "$edited"; echo "$added"; } | grep -E '^(decomp|sdk)/' || true)"
if [ -n "$bad" ]; then
  echo "these files of the game's sources (decomp/) or the mod SDK (sdk/) differ from the pinned ones:"
  echo "$bad" | head -10
  echo "Change the game with a patch in overlay/decomp-patches/ instead, and restore these (git -C $WORK checkout pristine -- <file>)."
  exit 1
fi
# a binary file of sms-pc-port cannot be patched
if [ -n "$edited" ] && git diff --cached --no-renames --numstat pristine -- $(echo "$edited" | tr '\n' ' ') | grep -q '^-'; then
  echo "an edited file of sms-pc-port is binary; patches cannot carry that:"
  git diff --cached --no-renames --numstat pristine | awk '$1 == "-" { print $3 }'
  exit 1
fi

rm -rf "$ROOT/patches/sms-port" "$ROOT/overlay"
mkdir -p "$ROOT/patches/sms-port" "$ROOT/overlay"

names=""
while IFS= read -r f; do [ -n "$f" ] && names="$names $(group_of "$f")"; done <<< "$edited"
for n in $(printf '%s\n' $names | sort -u); do
  files=()
  while IFS= read -r f; do [ -n "$f" ] && [ "$(group_of "$f")" = "$n" ] && files+=("$f"); done <<< "$edited"
  git diff --cached --no-color --no-ext-diff --no-renames pristine -- "${files[@]}" > "$ROOT/patches/sms-port/$n.patch"
  echo "patches/sms-port/$n.patch: ${#files[@]} files"
done
if [ -n "$added" ]; then
  printf '%s\n' "$added" | tar -cf - -T - | tar -xf - -C "$ROOT/overlay"
fi
echo "overlay/: $(printf '%s\n' "$added" | grep -c . || true) files"

# The proof: the saved patches and overlay rebuild the workspace. Both trees are compared as git trees (file names,
# modes and contents).
check="$(mktemp -d)"
trap 'rm -rf "$check"' EXIT
PCPORT_DST="$check/tree" "$ROOT/scripts/prepare.sh" > /dev/null
rebuilt="$(cd "$check/tree" && git init -q && git config core.autocrlf false && printf '* -text\n' > .git/info/attributes && git add -A -f >/dev/null && git write-tree)"
saved="$(git -C "$WORK" write-tree)"
if [ "$rebuilt" = "$saved" ]; then
  echo "checked: the saved patches and overlay rebuild the workspace exactly"
else
  echo "THE SAVED PATCHES DO NOT REBUILD THE WORKSPACE:"
  diff -rq -x .git "$WORK" "$check/tree" | head -20 || true
  exit 1
fi
state > "$WORK/.git/sms-saved-from"
echo "saved; review with: git -C $ROOT status && git -C $ROOT diff"
