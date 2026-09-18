#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/../../../.." && pwd)"
CONF="$ROOT/project-php-mac.conf"
YML="$ROOT/project.yml"
OUT="$ROOT/target/build/targets/macos"

. "$CONF"
cd "$ROOT"

NAME="$(awk '/^name:/{print $2; exit}' "$YML")"
[ -n "$NAME" ] || NAME=core_extension
SO="$OUT/${NAME}.so"

mkdir -p "$OUT"
rm -f "$ROOT/${NAME}.so" "$SO"

"$PHP" "$TPC" "$YML" -m ext -o "$NAME"
[ -f "$ROOT/${NAME}.so" ] || { echo "tpc did not write $ROOT/${NAME}.so" >&2; exit 1; }
mv -f "$ROOT/${NAME}.so" "$SO"

echo "built: $SO"
ls -l "$SO"