#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
CONF="$ROOT/project-php-mac.conf"
YML="$ROOT/project.yml"
COMPOSER_JSON="$ROOT/composer.json"

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

offer_brew() {
    _pkgs=$1
    if ! need_cmd brew; then
        echo "Homebrew missing. Install:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo "Then: brew install $_pkgs"
        exit 1
    fi
    echo "Missing tools. Install with: brew install $_pkgs"
    printf "Install now? [y/N] "
    read -r ans
    case "$ans" in
        y|Y|yes) brew install $_pkgs ;;
        *) exit 1 ;;
    esac
}

[ -f "$CONF" ] || {
    echo "missing $CONF — run tools/share/php-mac.sh first" >&2
    exit 1
}
# shellcheck disable=SC1090
. "$CONF"

[ -n "${PHP:-}" ] && [ -x "$PHP" ] || {
    echo "PHP in $CONF is not executable: ${PHP:-}" >&2
    exit 1
}

PHP_BINDIR="$(dirname -- "$PHP")"
export PATH="$PHP_BINDIR:/opt/homebrew/bin:/usr/local/bin:$PATH"
export CC="${CC:-/usr/bin/clang}"
export CXX="${CXX:-/usr/bin/clang++}"

if [ -z "${PHP_CONFIG:-}" ] || [ ! -x "$PHP_CONFIG" ]; then
    PHP_CONFIG="$PHP_BINDIR/php-config"
fi
[ -x "$PHP_CONFIG" ] || {
    echo "php-config not found next to $PHP" >&2
    exit 1
}

PHP_PREFIX="$("$PHP_CONFIG" --prefix)"
PHP_HOME="$PHP_PREFIX"
PHP_MAJOR="$("$PHP" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
PHP_FULL="$("$PHP" -r 'echo PHP_VERSION;')"

case "$PHP_MAJOR" in
    8.4|8.5) ;;
    *)
        echo "TypePHP needs PHP 8.4 or 8.5, got $PHP_FULL ($PHP)" >&2
        exit 1
        ;;
esac

missing=""
need_cmd cmake || missing="$missing cmake"
need_cmd pkg-config || missing="$missing pkg-config"
need_cmd composer || missing="$missing composer"
pkg-config --exists gmp 2>/dev/null || missing="$missing gmp"
pkg-config --exists mpfr 2>/dev/null || missing="$missing mpfr"
[ -z "$missing" ] || offer_brew "$missing"

need_cmd cmake
need_cmd composer

CMAKE_VER="$(cmake --version | awk 'NR==1{print $3}')"
CMAKE_OK="$(printf '%s\n' "$CMAKE_VER" | awk -F. '{print ($1>3)||($1==3&&$2>=24) ? 1 : 0}')"
[ "$CMAKE_OK" = 1 ] || {
    echo "CMake >= 3.24 required, found $CMAKE_VER" >&2
    exit 1
}

[ -f "$YML" ] || {
    echo "missing $YML" >&2
    exit 1
}

if [ ! -f "$COMPOSER_JSON" ]; then
    cat > "$COMPOSER_JSON" <<EOF
{
    "name": "local/php-extension-base",
    "require-dev": {
        "swoole/typephp": "^0.8.2"
    },
    "config": {
        "sort-packages": true
    }
}
EOF
    echo "wrote $COMPOSER_JSON"
fi

echo "composer install with $PHP ($PHP_FULL)"
"$PHP" "$(command -v composer)" install --working-dir="$ROOT" --no-interaction --no-progress

TPC="$ROOT/vendor/bin/tpc.php"
[ -f "$TPC" ] || {
    echo "tpc missing after composer install: $TPC" >&2
    exit 1
}

PHPX_HOME="${PHPX_HOME:-$ROOT/vendor/swoole/phpx}"
PHPX_BUILD="$ROOT/target/tpc/phpx"
[ -d "$PHPX_HOME" ] || {
    echo "swoole/phpx not installed at $PHPX_HOME" >&2
    exit 1
}

if [ "$(uname -s)" = Darwin ]; then
    PHPX_LIB="$PHPX_HOME/lib/libphpx.dylib"
else
    PHPX_LIB="$PHPX_HOME/lib/libphpx.so"
fi

rebuild=0
[ "${1:-}" = "--rebuild-phpx" ] && rebuild=1
[ -f "$PHPX_LIB" ] || rebuild=1

if [ "$rebuild" -eq 1 ]; then
    echo "building PHPX against $PHP_PREFIX"
    mkdir -p "$PHPX_BUILD" "$PHPX_HOME/lib"
    rm -f "$PHPX_HOME/lib/"*.a \
        "$PHPX_HOME/lib/libphpx.dylib" \
        "$PHPX_HOME/lib/libphpx.so"
    cmake -S "$PHPX_HOME" -B "$PHPX_BUILD" \
        -DCMAKE_BUILD_TYPE=Release \
        -Dphp_dir="$PHP_PREFIX"
    cmake --build "$PHPX_BUILD" -j 4
fi

[ -f "$PHPX_LIB" ] || {
    echo "PHPX library missing: $PHPX_LIB" >&2
    exit 1
}

{
    echo "PHP=$PHP"
    echo "PHP_CONFIG=$PHP_CONFIG"
    echo "PHP_VERSION=$PHP_FULL"
    echo "PHP_MAJOR=$PHP_MAJOR"
    echo "PHP_PREFIX=$PHP_PREFIX"
    echo "PHP_HOME=$PHP_HOME"
    echo "TPC=$TPC"
    echo "PHPX_HOME=$PHPX_HOME"
    echo "PHPX_BUILD=$PHPX_BUILD"
    echo "PHPX_LIB=$PHPX_LIB"
} > "$CONF"

export PHPX_HOME PHP_HOME
echo "verify tpc"
"$PHP" "$TPC" --help >/dev/null
echo "TypePHP ready"
echo "PHP=$PHP"
echo "TPC=$TPC"
echo "PHPX_LIB=$PHPX_LIB"