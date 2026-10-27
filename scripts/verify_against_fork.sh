#!/usr/bin/env bash
# The check that this layout is right while the fork is the source of truth: the tree prepare.sh makes must be
# identical to the fork's tip (same files, same bytes), apart from the pipeline files, which are written for this
# layout. Prints the differences, if any, and exits 1 on them.
#
#   FORK=/path/to/the/fork scripts/verify_against_fork.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORK="${FORK:-$HOME/sms-pc-port}"
DST="$ROOT/build/pcport-uwp"
[ -z "$(git -C "$FORK" status --porcelain)" ] || { echo "the fork has uncommitted changes:"; git -C "$FORK" status --short; exit 1; }
"$ROOT/scripts/prepare.sh" > /dev/null
echo "fork tip: $(git -C "$FORK" rev-parse --short HEAD)"
if diff -rq -x .git -x 'azure-pipelines*.yml' "$FORK" "$DST"; then
  echo "identical: build/pcport-uwp is the fork's tree"
else
  echo "DIFFERENT (above)"
  exit 1
fi
