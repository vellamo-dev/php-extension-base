#!/bin/sh
# run in the project dir:
# bash tools/share/fix-permissions.sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"

find "$ROOT" \
    \( -path "$ROOT/vendor" -o -path "$ROOT/target" -o -path "$ROOT/.git" \) -prune \
    -o -name '*.sh' -type f -print \
    | while IFS= read -r f; do
    chmod +x "$f"
    echo "chmod +x $f"
done