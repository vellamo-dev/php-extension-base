#!/usr/bin/env bash
set -eu

PATH_SCR_TPM="$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PATH_SCR_TPM
YML="$PATH_SCR_TPM/../../../../project.yml"
TEST="$PATH_SCR_TPM/../../../../src/tests/test.php"
OUT="$PATH_SCR_TPM/../../../../target/build/targets/linux"

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

echo "Testing: src/tests/test.php"

if [ ! -f "$SO" ]; then
    echo "Result: Failed"
    echo "missing $REL — run tools/build/targets/linux/build-from-macos.sh"
    exit 1
fi

if [ ! -f "$TEST" ]; then
    echo "Result: Failed"
    echo "missing src/tests/test.php"
    exit 1
fi

image_exists() {
    container image list --quiet 2>/dev/null | grep -qx "$IMAGE" \
        || container image list --quiet 2>/dev/null | grep -qx "localhost/$IMAGE" \
        || container image inspect "$IMAGE" >/dev/null 2>&1
}

if ! image_exists; then
    echo "Result: Failed"
    echo "image missing: $IMAGE"
    exit 1
fi

container system start >/dev/null 2>&1 || true

set +e
container run --rm --arch amd64 \
    --volume "$PATH_SCR_TPM/../../../..:/src" \
    --workdir /src \
    "$IMAGE" \
    sh -lc "
set -eu
export LD_LIBRARY_PATH=/src/target/build/targets/linux
SO=/src/${REL}
php -d \"extension=\$SO\" -r \"exit(extension_loaded('${MOD}') ? 0 : 1);\"
php -d \"extension=\$SO\" /src/src/tests/test.php
"
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "Result: Failed"
    echo "src/tests/test.php exited $status"
    exit "$status"
fi

echo "Result: Success"