#!/bin/bash
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
YML="$ROOT/project.yml"

cd "$ROOT"

if [ "${1:-}" != "" ]; then
    NAME=$1
else
    printf "Project name (required): "
    read -r NAME
fi

if [ -z "$NAME" ]; then
    echo "A name is required. Example: shop_ext" >&2
    exit 1
fi

case "$NAME" in
    *[!a-zA-Z0-9_]*)
        echo "Use only letters, numbers and underscore." >&2
        exit 1
        ;;
esac

if [ ! -f "$YML" ]; then
    echo "missing project.yml" >&2
    exit 1
fi

tmp="$YML.tmp.$$"
sed "s/^name:.*/name: $NAME/" "$YML" > "$tmp"
mv "$tmp" "$YML"

bash "$ROOT/tools/share/fix-permissions.sh"

echo "Name in project.yml: $NAME"
echo "PHP will load it as: typephp_$NAME"
echo

os=$(uname -s)
case "$os" in
    Darwin)
        echo "This Mac can build the Mac add-on and a Linux add-on."
        echo "Read readme.md in this folder, then:"
        echo "  bash tools/share/php-mac.sh"
        echo "  bash tools/share/setup-type-php.sh"
        echo "  bash tools/build/targets/macos/build.sh"
        ;;
    Linux)
        echo "Native Linux build is not written yet."
        echo "Read readme.md in this folder."
        ;;
    *)
        echo "This OS is not set up in the kit ($os)."
        echo "Read readme.md in this folder."
        ;;
esac