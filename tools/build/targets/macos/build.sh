#!/usr/bin/env bash
set -eu

PATH_SCR_BLD="$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PATH_SCR_BLD
CONF="$PATH_SCR_BLD/../../../../project-php-mac.conf"
YML="$PATH_SCR_BLD/../../../../project.yml"
OUT="$PATH_SCR_BLD/../../../../target/build/targets/macos"

[ -f "$CONF" ] || {
    echo "missing $CONF — run tools/share/php-mac.sh first" >&2
    exit 1
}
source "$PATH_SCR_BLD/../../../../project-php-mac.conf"
[ -n "${PHP:-}" ] && [ -x "$PHP" ] || {
    echo "$CONF has no usable PHP (got: ${PHP:-})" >&2
    echo "Re-run: tools/share/php-mac.sh" >&2
    exit 1
}
[ -n "${TPC:-}" ] && [ -f "$TPC" ] || {
    echo "$CONF has no usable TPC (got: ${TPC:-})" >&2
    echo "Re-run: tools/share/setup-type-php.sh" >&2
    exit 1
}
cd "$PATH_SCR_BLD/../../../.."

NAME="$(awk '/^name:/{print $2; exit}' "$YML")"
[ -n "$NAME" ] || NAME=core_extension
SO="$OUT/${NAME}.so"

mkdir -p "$OUT"
rm -f "$PATH_SCR_BLD/../../../../${NAME}.so" "$SO"

"$PHP" "$TPC" "$YML" -m ext -o "$NAME"
[ -f "$PATH_SCR_BLD/../../../../${NAME}.so" ] || { echo "tpc did not write $PATH_SCR_BLD/../../../../${NAME}.so" >&2; exit 1; }
mv -f "$PATH_SCR_BLD/../../../../${NAME}.so" "$SO"

bash "$PATH_SCR_BLD/bundle-dylibs.sh" "$OUT"

echo "built: $SO"
ls -l "$SO"