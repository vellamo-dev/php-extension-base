#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/../../../.." && pwd)"
CONF="$ROOT/project-php-mac.conf"
LIBS="$HERE/libs.conf"
OUT="${1:-}"

[ -n "$OUT" ] && [ -d "$OUT" ] || { echo "usage: bundle-dylibs.sh <out-dir>" >&2; exit 1; }
[ -f "$CONF" ] || { echo "missing $CONF" >&2; exit 1; }
. "$CONF"
[ -f "$LIBS" ] || { echo "missing $LIBS" >&2; exit 1; }

search_lib() {
    _name=$1
    case "$_name" in
        /*) [ -f "$_name" ] && printf '%s\n' "$_name" && return 0 ;;
    esac
    for _dir in \
    "${PHPX_HOME:-}/lib" \
    "${PHP_PREFIX:-}/lib" \
    "${PHP_HOME:-}/lib" \
    /opt/homebrew/lib \
    /opt/homebrew/opt/gmp/lib \
    /opt/homebrew/opt/mpfr/lib \
    /usr/local/lib
    do
        [ -f "$_dir/$_name" ] && printf '%s\n' "$_dir/$_name" && return 0
    done
    return 1
}

retarget() {
    _bin=$1
    install_name_tool -add_rpath "@loader_path" "$_bin" 2>/dev/null || true
    otool -L "$_bin" | awk '/\.dylib/ {print $1}' | while IFS= read -r dep; do
        case "$dep" in
            /usr/lib/*|/System/*|@*) continue ;;
        esac
        _base=$(basename -- "$dep")
        [ -f "$OUT/$_base" ] || continue
        install_name_tool -change "$dep" "@loader_path/$_base" "$_bin" 2>/dev/null || true
    done
    case "$(basename -- "$_bin")" in
        *.so|libphpx.dylib) strip -x "$_bin" 2>/dev/null || true ;;
    esac
    codesign --force -s - "$_bin" 2>/dev/null || true
}

while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|\#*) continue ;;
    esac
    src=$(search_lib "$line") || { echo "support lib not found: $line" >&2; exit 1; }
    dst="$OUT/$(basename -- "$src")"
    cp -fL "$src" "$dst"
    echo "bundled $dst"
    retarget "$dst"
done < "$LIBS"

for f in "$OUT"/*.so "$OUT"/*.dylib; do
    [ -f "$f" ] || continue
    retarget "$f"
done