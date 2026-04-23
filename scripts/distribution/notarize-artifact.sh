#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"

[ "$#" -eq 1 ] || die "Usage: notarize-artifact.sh <artifact-path>"
artifact_path="$1"
[ -f "$artifact_path" ] || die "Artifact not found: $artifact_path"

maybe_notarize "$artifact_path"
