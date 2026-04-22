#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"

version=$(resolve_version)
stage_root="$BRITELOG_OUTPUT_DIR/zip-stage"
bundle_root="$stage_root/${BRITELOG_COMMAND_NAME}-${version}"
payload_root="$bundle_root/payload"
artifact_path="$BRITELOG_OUTPUT_DIR/${BRITELOG_COMMAND_NAME}-${version}-macos-user.zip"

ensure_clean_dir "$stage_root"
mkdir -p "$payload_root" "$BRITELOG_OUTPUT_DIR"

binary=$(build_release_binary)
copy_release_binary_as_command "$binary" "$payload_root/$BRITELOG_COMMAND_NAME"
cp "$SELF_DIR/templates/install-user.sh" "$bundle_root/install.sh"
chmod 0755 "$bundle_root/install.sh"
printf '%s\n' "$version" >"$payload_root/VERSION"

(
  cd "$stage_root"
  zip -qry "$artifact_path" "$(basename "$bundle_root")"
)

maybe_notarize "$artifact_path"

log "Built per-user zip bundle: $artifact_path"
