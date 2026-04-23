#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"

version=$(resolve_version)
stage_root="$BRITELOG_OUTPUT_DIR/zip-stage"
payload_bundle="$stage_root/$BRITELOG_PRODUCT_NAME"
artifact_path="$BRITELOG_OUTPUT_DIR/${BRITELOG_ARTIFACT_BASENAME}-${version}-macos-app.zip"

ensure_clean_dir "$stage_root"
mkdir -p "$BRITELOG_OUTPUT_DIR"

product=$(build_release_product)
copy_release_product_bundle "$product" "$payload_bundle"

(
  cd "$stage_root"
  zip -qry "$artifact_path" "$BRITELOG_PRODUCT_NAME"
)

maybe_notarize "$artifact_path"

log "Built app zip bundle: $artifact_path"
