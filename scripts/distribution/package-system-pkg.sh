#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"

version=$(resolve_version)
payload_root="$BRITELOG_OUTPUT_DIR/pkg/payload"
artifact_path="$BRITELOG_OUTPUT_DIR/${BRITELOG_ARTIFACT_BASENAME}-${version}-macos-installer.pkg"
install_root="/Applications/$BRITELOG_PRODUCT_NAME"
payload_bundle="$payload_root$install_root"

ensure_clean_dir "$payload_root"
mkdir -p "$BRITELOG_OUTPUT_DIR"

product=$(build_release_product)
copy_release_product_bundle "$product" "$payload_bundle"

pkgbuild \
  --root "$payload_root" \
  --identifier "$BRITELOG_DISTRIBUTION_ID" \
  --version "$version" \
  "$artifact_path"

maybe_sign_pkg "$artifact_path"
maybe_notarize "$artifact_path"

log "Built system-wide app installer package: $artifact_path"
