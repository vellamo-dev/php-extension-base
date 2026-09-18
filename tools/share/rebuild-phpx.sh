#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
exec "$ROOT/tools/share/setup-type-php.sh" --rebuild-phpx