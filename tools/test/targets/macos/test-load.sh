#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/../../../.." && pwd)"
CONF="$ROOT/project-php-mac.conf"
YML="$ROOT/project.yml"
SRC="$ROOT/src/main/functions.php"
OUT="$ROOT/target/build/targets/macos"

. "$CONF"
cd "$ROOT"

NAME="$(awk '/^name:/{print $2; exit}' "$YML")"
[ -n "$NAME" ] || NAME=core_extension
MOD="typephp_${NAME}"
SO="$OUT/${NAME}.so"
REL="target/build/targets/macos/${NAME}.so"

echo "Testing: $REL"

if [ ! -f "$SO" ]; then
    echo "Loaded: Failed"
    echo "Loaded As:"
    echo "missing $REL — build first"
    exit 1
fi

ERR="$OUT/load.err"
OUTF="$OUT/load.out"
set +e
"$PHP" -d "extension=$SO" -r "echo extension_loaded('$MOD') ? 'yes' : 'no';" >"$OUTF" 2>"$ERR"
status=$?
set -e

if [ "$status" -ne 0 ] || grep -qiE 'warning|error|unable to load' "$ERR"; then
    echo "Loaded: Failed"
    echo "Loaded As:"
    cat "$ERR"
    exit 1
fi

if [ "$(cat "$OUTF")" != "yes" ]; then
    echo "Loaded: Failed"
    echo "Loaded As:"
    exit 1
fi

echo "Loaded: Success"
echo "Loaded As: $MOD"

CONST_LINE=$(grep -E '^[[:space:]]*const[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "$SRC" | head -1 || true)
if [ -z "$CONST_LINE" ]; then
    echo "Testing constant:"
    echo "Value of constant:"
    echo "no constant in functions.php"
    exit 1
fi

CONST_NAME=$(printf '%s\n' "$CONST_LINE" | sed -E 's/^[[:space:]]*const[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')
echo "Testing constant: $CONST_NAME"

set +e
"$PHP" -d "extension=$SO" -r "
echo defined('$CONST_NAME') ? 'yes' : 'no';
echo chr(10);
echo defined('$CONST_NAME') ? (string) $CONST_NAME : '';
" >"$OUTF" 2>"$ERR"
set -e

has=$(sed -n '1p' "$OUTF")
val=$(sed -n '2p' "$OUTF")

if [ "$has" = "yes" ]; then
    echo "Value of constant: $val"
else
    echo "Value of constant:"
    echo "$CONST_NAME not in the built extension — rebuild and try again"
    exit 1
fi