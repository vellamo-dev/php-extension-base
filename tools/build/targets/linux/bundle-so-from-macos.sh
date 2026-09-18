#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/../../../.." && pwd)"
LIBS="$HERE/libs.conf"
OUT="${1:-$ROOT/target/build/targets/linux}"
YML="$ROOT/project.yml"

[ -d "$OUT" ] || { echo "usage: bundle-so.sh <out-dir>" >&2; exit 1; }
[ -f "$LIBS" ] || { echo "missing $LIBS" >&2; exit 1; }

NAME="$(awk '/^name:/{print $2; exit}' "$YML")"
[ -n "$NAME" ] || NAME=core_extension
SO="$OUT/${NAME}.so"
[ -f "$SO" ] || { echo "missing $SO" >&2; exit 1; }

PHPX_LIB="${PHPX_HOME:-$ROOT/vendor/swoole/phpx}/lib"

search_lib() {
    _name=$1
    for _dir in \
    "$PHPX_LIB" \
    /usr/lib/x86_64-linux-gnu \
    /lib/x86_64-linux-gnu \
    /usr/lib/aarch64-linux-gnu \
    /lib/aarch64-linux-gnu \
    /usr/lib
    do
        [ -f "$_dir/$_name" ] && printf '%s\n' "$_dir/$_name" && return 0
    done
    return 1
}

while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|\#*) continue ;;
    esac
    src=$(search_lib "$line") || { echo "support lib not found: $line" >&2; exit 1; }
    dst="$OUT/$(basename -- "$src")"
    cp -fL "$src" "$dst"
    echo "bundled $dst"
done < "$LIBS"

command -v patchelf >/dev/null 2>&1 || { echo "patchelf missing" >&2; exit 1; }

for f in "$SO" "$OUT"/libphpx.so "$OUT"/libmpfr.so.6 "$OUT"/libgmp.so.10 "$OUT"/libgmpxx.so.4; do
    [ -f "$f" ] || continue
    patchelf --set-rpath '$ORIGIN' "$f"
done

strip --strip-unneeded "$SO" "$OUT/libphpx.so"