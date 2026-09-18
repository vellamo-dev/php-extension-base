#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/../../../.." && pwd)"
YML="$ROOT/project.yml"
SRC="$ROOT/src/main/functions.php"
OUT="$ROOT/target/build/targets/linux"

if ! command -v container >/dev/null 2>&1; then
    echo "Apple container CLI is missing."
    echo "Install from https://github.com/apple/container/releases"
    echo "Then: container system start"
    exit 1
fi

[ -f "$YML" ] || { echo "missing $YML" >&2; exit 1; }

PHP_VERSION="$(awk '/^php-version:/{gsub(/["'\'']/, "", $2); print $2; exit}' "$YML")"
NAME="$(awk '/^name:/{print $2; exit}' "$YML")"
[ -n "$PHP_VERSION" ] || { echo "php-version missing in project.yml" >&2; exit 1; }
[ -n "$NAME" ] || NAME=core_extension

MOD="typephp_${NAME}"
SO="$OUT/${NAME}.so"
REL="target/build/targets/linux/${NAME}.so"
IMAGE="typephp-linux-build:${PHP_VERSION}"

echo "Testing: $REL"

if [ ! -f "$SO" ]; then
    echo "Loaded: Failed"
    echo "Loaded As:"
    echo "missing $REL — run tools/build/targets/linux/build-from-macos.sh"
    exit 1
fi

image_exists() {
    container image list --quiet 2>/dev/null | grep -qx "$IMAGE" \
        || container image list --quiet 2>/dev/null | grep -qx "localhost/$IMAGE" \
        || container image inspect "$IMAGE" >/dev/null 2>&1
}

if ! image_exists; then
    echo "Loaded: Failed"
    echo "Loaded As:"
    echo "image missing: $IMAGE"
    echo "run: sh tools/build/targets/linux/build-image-from-macos.sh"
    exit 1
fi

CONST_LINE=$(grep -E '^[[:space:]]*const[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "$SRC" | head -1 || true)
if [ -z "$CONST_LINE" ]; then
    CONST_NAME=""
else
    CONST_NAME=$(printf '%s\n' "$CONST_LINE" | sed -E 's/^[[:space:]]*const[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')
fi

container system start >/dev/null 2>&1 || true

RAW=$(container run --rm --arch amd64 \
    --volume "$ROOT:/src" \
    --workdir /src \
    "$IMAGE" \
    php -d "extension=/src/${REL}" \
    -r "echo extension_loaded('${MOD}') ? 'yes' : 'no'; echo PHP_EOL; echo defined('${CONST_NAME}') ? 'yes' : 'no'; echo PHP_EOL; echo defined('${CONST_NAME}') ? (string) ${CONST_NAME} : ''; echo PHP_EOL;")

loaded=$(printf '%s\n' "$RAW" | sed -n '1p')
has=$(printf '%s\n' "$RAW" | sed -n '2p')
val=$(printf '%s\n' "$RAW" | sed -n '3p')

if [ "$loaded" != "yes" ]; then
    echo "Loaded: Failed"
    echo "Loaded As:"
    exit 1
fi

echo "Loaded: Success"
echo "Loaded As: $MOD"

if [ -z "$CONST_NAME" ]; then
    echo "Testing constant:"
    echo "Value of constant:"
    echo "no constant in functions.php"
    exit 1
fi

echo "Testing constant: $CONST_NAME"

if [ "$has" != "yes" ]; then
    echo "Value of constant:"
    echo "$CONST_NAME not in the built extension — rebuild and try again"
    exit 1
fi

echo "Value of constant: $val"