#!/bin/bash
set -eu

REPO_TAR="https://github.com/vellamo-dev/php-extension-base/archive/refs/heads/main.tar.gz"

if [ "${1:-}" != "" ]; then
    NAME=$1
else
    echo "Type a short project name and press Enter."
    echo "Example: shop_ext"
    echo "Letters, numbers and underscore only."
    printf "Project name: "
    read -r NAME < /dev/tty
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

DIR=$NAME

if [ -e "$DIR" ]; then
    echo "Folder already exists: $DIR" >&2
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading kit..."
curl -fsSL "$REPO_TAR" | tar -xz -C "$TMP"

SRC=$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)
[ -n "$SRC" ] || { echo "Download failed." >&2; exit 1; }

mv "$SRC" "$DIR"

echo "Preparing $DIR ..."
bash "$DIR/tools/share/init.sh" "$NAME"

echo
echo "Folder: $DIR"
echo "Go there:  cd $DIR"
echo "Then open readme.md and follow the steps for your computer."