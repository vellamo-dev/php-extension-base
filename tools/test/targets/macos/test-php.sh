#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/../../../.." && pwd)"
CONF="$ROOT/project-php-mac.conf"
YML="$ROOT/project.yml"
TEST="$ROOT/src/tests/test.php"
OUT="$ROOT/target/build/targets/macos"

. "$CONF"
cd "$ROOT"

NAME="$(awk '/^name:/{print $2; exit}' "$YML")"
[ -n "$NAME" ] || NAME=core_extension
MOD="typephp_${NAME}"
SO="$OUT/${NAME}.so"

echo "Testing: src/tests/test.php"

if [ ! -f "$SO" ]; then
    echo "Result: Failed"
    echo "missing target/build/targets/macos/${NAME}.so — build first"
    exit 1
fi

if [ ! -f "$TEST" ]; then
    echo "Result: Failed"
    echo "missing src/tests/test.php"
    exit 1
fi

ERR="$OUT/run.err"
set +e
"$PHP" -d "extension=$SO" -r "exit(extension_loaded('$MOD') ? 0 : 1);" 2>"$ERR"
ready=$?
set -e

if [ "$ready" -ne 0 ]; then
    echo "Result: Failed"
    echo "module $MOD not loaded"
    cat "$ERR"
    exit 1
fi

set +e
"$PHP" -d "extension=$SO" "$TEST"
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "Result: Failed"
    echo "src/tests/test.php exited $status"
    exit "$status"
fi

echo "Result: Success"