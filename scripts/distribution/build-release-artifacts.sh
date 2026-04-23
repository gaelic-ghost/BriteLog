#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

"$SELF_DIR/package-app-zip.sh"
"$SELF_DIR/package-system-pkg.sh"
