#!/usr/bin/env bash
set -eu
PATH_SCR_RBP="$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PATH_SCR_RBP
exec "$PATH_SCR_RBP/../../tools/share/setup-type-php.sh" --rebuild-phpx