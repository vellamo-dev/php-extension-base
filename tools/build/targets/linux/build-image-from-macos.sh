#!/usr/bin/env bash
set -eu

PATH_SCR_BIM="$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PATH_SCR_BIM
YML="$PATH_SCR_BIM/../../../../project.yml"

if ! command -v container >/dev/null 2>&1; then
    echo "Apple container CLI is missing."
    echo "Install:"
    echo "  https://github.com/apple/container/releases"
    echo "  sudo installer -pkg container-*-installer-signed.pkg -target /"
    echo "  container system start"
    exit 1
fi

[ -f "$YML" ] || { echo "missing $YML" >&2; exit 1; }

PHP_VERSION="$(awk '/^php-version:/{gsub(/["'\'']/, "", $2); print $2; exit}' "$YML")"
[ -n "$PHP_VERSION" ] || { echo "php-version missing in project.yml" >&2; exit 1; }

IMAGE="typephp-linux-build:${PHP_VERSION}"

echo "PHP from project.yml: $PHP_VERSION"
echo "Image: $IMAGE (php:${PHP_VERSION}-cli)"

container system start >/dev/null 2>&1 || true
container builder start >/dev/null 2>&1 || true

container build --arch amd64 \
    --build-arg "PHP_VERSION=${PHP_VERSION}" \
    -t "$IMAGE" \
    -f "$PATH_SCR_BIM/Containerfile" \
    "$PATH_SCR_BIM"

echo "Linux image: Success ($IMAGE)"