#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/../../../.." && pwd)"
YML="$ROOT/project.yml"
OUT="$ROOT/target/build/targets/linux"
PHPX_BUILD="$ROOT/target/tpc/phpx-linux"

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

IMAGE="typephp-linux-build:${PHP_VERSION}"
SO_REL="target/build/targets/linux/${NAME}.so"

echo "PHP from project.yml: $PHP_VERSION"
echo "Image: $IMAGE"

image_exists() {
    container image list --quiet 2>/dev/null | grep -qx "$IMAGE" \
        || container image list --quiet 2>/dev/null | grep -qx "localhost/$IMAGE" \
        || container image inspect "$IMAGE" >/dev/null 2>&1
}

if image_exists; then
    echo "Image exists: $IMAGE"
else
    echo "Image missing: $IMAGE"
    echo "Building image..."
    sh "$HERE/build-image-from-macos.sh"
fi

mkdir -p "$OUT" "$PHPX_BUILD" "$ROOT/vendor"
rm -f "$OUT/${NAME}.so" "$ROOT/${NAME}.so"

container system start >/dev/null 2>&1 || true

set +e
container run --rm --arch amd64 \
    --volume "$ROOT:/src" \
    --workdir /src \
    "$IMAGE" \
    sh -lc "
set -eu
echo \"inside: \$(php -r 'echo PHP_VERSION;')\"
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export PHPX_HOME=/src/vendor/swoole/phpx
export PHPX_BUILD=/src/target/tpc/phpx-linux
export PHP_HOME=\"\$(php-config --prefix)\"

php \"\$(command -v composer)\" install --no-interaction --no-progress

TPC=/src/vendor/bin/tpc.php
[ -f \"\$TPC\" ] || { echo 'tpc missing after composer install' >&2; exit 1; }
[ -d \"\$PHPX_HOME\" ] || { echo \"PHPX missing: \$PHPX_HOME\" >&2; exit 1; }

mkdir -p \"\$PHPX_BUILD\" \"\$PHPX_HOME/lib\"
if [ ! -f \"\$PHPX_HOME/lib/libphpx.so\" ]; then
    echo 'building PHPX for Linux'
    rm -f \"\$PHPX_HOME/lib/libphpx.so\" \"\$PHPX_HOME/lib/\"*.a
    cmake -S \"\$PHPX_HOME\" -B \"\$PHPX_BUILD\" \
        -DCMAKE_BUILD_TYPE=Release \
        -Dphp_dir=\"\$PHP_HOME\"
    cmake --build \"\$PHPX_BUILD\" -j 4
fi
[ -f \"\$PHPX_HOME/lib/libphpx.so\" ] || { echo 'libphpx.so missing' >&2; exit 1; }

php \"\$TPC\" /src/project.yml -m ext -o $NAME
if [ -f /src/${NAME}.so ]; then
    mv -f /src/${NAME}.so /src/target/build/targets/linux/${NAME}.so
fi
[ -f /src/target/build/targets/linux/${NAME}.so ] || { echo 'linux .so was not produced' >&2; exit 1; }

sh /src/tools/build/targets/linux/bundle-so-from-macos.sh /src/target/build/targets/linux
ls -l /src/target/build/targets/linux
"
status=$?
set -e

if [ "$status" -ne 0 ] || [ ! -f "$OUT/${NAME}.so" ]; then
    echo "Linux build: Failed"
    exit 1
fi

echo "Linux build: Success"
echo "Artifact: $SO_REL"
ls -l "$OUT"