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

# Detect a stale build: if the extension carries rpaths that do not exist here
# (built on another machine or with a different PHP), fail with a clear hint.
if command -v otool >/dev/null 2>&1; then
    RPS="$OUT/.rpaths.$$"
    otool -l "$SO" 2>/dev/null \
        | sed -n 's/^[[:space:]]*path //p' \
        | sed 's/[[:space:]]*(offset [0-9][0-9]*)$//' > "$RPS" || true
    stale=0
    while IFS= read -r p; do
        case "$p" in
            ""|@*) continue ;;
            /*) [ -d "$p" ] || { echo "  stale rpath: $p"; stale=1; } ;;
        esac
    done < "$RPS"
    rm -f "$RPS"
    if [ "$stale" -eq 1 ]; then
        echo "Result: Failed"
        echo "This extension references build paths that do not exist on this machine."
        echo "It was likely built on another machine or with a different PHP version."
        echo "Rebuild and bundle it:"
        echo "  tools/build/targets/macos/build.sh"
        echo "  tools/build/targets/macos/bundle-dylibs.sh target/build/targets/macos"
        exit 1
    fi
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
    if grep -q 'Library not loaded' "$ERR" 2>/dev/null; then
        echo "Hint: a dependency could not be found — rebuild and bundle the extension:"
        echo "  tools/build/targets/macos/build.sh"
        echo "  tools/build/targets/macos/bundle-dylibs.sh target/build/targets/macos"
    fi
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