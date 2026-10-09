#!/usr/bin/env bash
# run in the project dir:
# bash tools/share/fix-permissions.sh
set -eu

PATH_SCR_FPR="$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PATH_SCR_FPR
cd "$PATH_SCR_FPR/../.."

find "$PATH_SCR_FPR/../.." \
    \( -path "$PATH_SCR_FPR/../../vendor" -o -path "$PATH_SCR_FPR/../../target" -o -path "$PATH_SCR_FPR/../../.git" \) -prune \
    -o -name '*.sh' -type f -print \
    | while IFS= read -r f; do
    chmod +x "$f"
    echo "chmod +x $f"
done