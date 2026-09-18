#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
CONF="$ROOT/project-php-mac.conf"
YML="$ROOT/project.yml"

ok_major() {
    case "$1" in
        8.4 | 8.5) return 0 ;;
        *) return 1 ;;
    esac
}

php_meta() {
    _bin=$1
    [ -x "$_bin" ] || return 1
    _ver="$("$_bin" -r 'echo PHP_VERSION;' 2>/dev/null)" || return 1
    _maj="$("$_bin" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)" || return 1
    _cfg="$(dirname -- "$_bin")/php-config"
    [ -x "$_cfg" ] || _cfg="$(command -v php-config 2>/dev/null || true)"
    _pre=""
    [ -n "$_cfg" ] && [ -x "$_cfg" ] && _pre="$("$_cfg" --prefix 2>/dev/null || true)"
    printf '%s\t%s\t%s\t%s\t%s\n' "$_bin" "$_ver" "$_maj" "${_cfg:-}" "${_pre:-}"
}

add_bin() {
    _b=$1
    [ -e "$_b" ] || return 0
    _b="$(cd -- "$(dirname -- "$_b")" && pwd)/$(basename -- "$_b")"
    case "$_b" in
        */php) ;;
        *) return 0 ;;
    esac
    _seen=$LIST
    while [ -n "$_seen" ]; do
        _line=${_seen%%$'\n'*}
        _rest=${_seen#"$_line"}
        _seen=${_rest#$'\n'}
        _old=${_line%%$'\t'*}
        [ "$_old" = "$_b" ] && return 0
        [ -z "$_rest" ] && break
    done
    _meta=$(php_meta "$_b") || return 0
    LIST="${LIST}${LIST:+$'\n'}${_meta}"
}

scan() {
    LIST=""
    if command -v brew >/dev/null 2>&1; then
        for f in php php@8.5 php@8.4 php@8.3 php@8.2; do
            _p="$(brew --prefix "$f" 2>/dev/null || true)"
            [ -n "$_p" ] && add_bin "$_p/bin/php"
        done
    fi
    add_bin /opt/homebrew/bin/php
    add_bin /usr/local/bin/php
    add_bin /opt/local/bin/php
    add_bin /usr/bin/php
    if command -v which >/dev/null 2>&1; then
        for _p in $(which -a php 2>/dev/null || true); do
            add_bin "$_p"
        done
    fi
    for _p in \
    /opt/homebrew/opt/php@*/bin/php \
    /usr/local/opt/php@*/bin/php \
    "$HOME"/Library/Application\ Support/Herd/bin/php \
    /opt/homebrew/Cellar/php/*/bin/php \
    /usr/local/Cellar/php/*/bin/php
    do
        add_bin "$_p"
    done
}

print_list() {
    i=0
    echo "$LIST" | while IFS="$(printf '\t')" read -r bin ver maj cfg pre; do
        [ -n "$bin" ] || continue
        i=$((i + 1))
        if ok_major "$maj"; then
            mark="ok"
        else
            mark="skip (TypePHP needs 8.4 or 8.5)"
        fi
        printf '%2d  %s  %s  [%s]\n' "$i" "$ver" "$bin" "$mark"
    done
}

count_list() {
    echo "$LIST" | awk 'NF{c++} END{print c+0}'
}

nth() {
    echo "$LIST" | awk -F '\t' -v n="$1" 'NF{i++} i==n{print; exit}'
}

write_conf() {
    _bin=$1 _ver=$2 _maj=$3 _cfg=$4 _pre=$5
    cat >"$CONF" <<EOF
PHP=$_bin
PHP_CONFIG=${_cfg}
PHP_VERSION=$_ver
PHP_MAJOR=$_maj
PHP_PREFIX=${_pre}
EOF
}

patch_yml() {
    _maj=$1
    [ -f "$YML" ] || {
        echo "missing $YML" >&2
        return 1
    }
    if grep -q '^php-version:' "$YML"; then
        tmp="$YML.tmp.$$"
        sed "s/^php-version:.*/php-version: \"$_maj\"/" "$YML" >"$tmp"
        mv "$tmp" "$YML"
    else
        printf '\nphp-version: "%s"\n' "$_maj" >>"$YML"
    fi
}

offer_install() {
    echo "No usable PHP 8.4/8.5 found."
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is missing. Install it:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo "Then: brew install php@8.4"
        return 1
    fi
    printf "Install php@8.4 with Homebrew? [y/N] "
    read -r ans
    case "$ans" in
        y | Y | yes)
            brew install php@8.4
            ;;
        *)
            echo "Install later with: brew install php@8.4"
            return 1
            ;;
    esac
}

scan

if [ "$(count_list)" -eq 0 ]; then
    offer_install || exit 1
    scan
fi

if [ "$(count_list)" -eq 0 ]; then
    echo "Still no PHP binaries found." >&2
    exit 1
fi

echo "PHP installs:"
print_list

printf "Select number: "
read -r num
case "$num" in
    '' | *[!0-9]*)
        echo "invalid selection" >&2
        exit 1
        ;;
esac

row=$(nth "$num")
[ -n "$row" ] || {
    echo "invalid selection" >&2
    exit 1
}

bin=$(printf '%s\n' "$row" | cut -f1)
ver=$(printf '%s\n' "$row" | cut -f2)
maj=$(printf '%s\n' "$row" | cut -f3)
cfg=$(printf '%s\n' "$row" | cut -f4)
pre=$(printf '%s\n' "$row" | cut -f5)

if ! ok_major "$maj"; then
    echo "TypePHP needs PHP 8.4 or 8.5, got $ver" >&2
    exit 1
fi

write_conf "$bin" "$ver" "$maj" "$cfg" "$pre"
patch_yml "$maj"

echo "wrote $CONF"
echo "php-version in project.yml -> $maj"
echo "PHP=$bin"