#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"

version=$(resolve_version)
payload_root="$BRITELOG_OUTPUT_DIR/pkg/payload"
scripts_root="$BRITELOG_OUTPUT_DIR/pkg/scripts"
artifact_path="$BRITELOG_OUTPUT_DIR/${BRITELOG_COMMAND_NAME}-${version}-macos-installer.pkg"
install_root="/usr/local/libexec/gaelic-ghost/$BRITELOG_COMMAND_NAME/$version"
payload_binary="$payload_root$install_root/$BRITELOG_COMMAND_NAME"

ensure_clean_dir "$payload_root"
ensure_clean_dir "$scripts_root"
mkdir -p "$BRITELOG_OUTPUT_DIR"

binary=$(build_release_binary)
copy_release_binary_as_command "$binary" "$payload_binary"

cat >"$scripts_root/postinstall" <<EOF
#!/bin/sh
set -eu

mkdir -p /usr/local/bin
ln -sfn "$install_root/$BRITELOG_COMMAND_NAME" "/usr/local/bin/$BRITELOG_COMMAND_NAME"
EOF
chmod 0755 "$scripts_root/postinstall"

pkgbuild \
  --root "$payload_root" \
  --scripts "$scripts_root" \
  --identifier "$BRITELOG_DISTRIBUTION_ID" \
  --version "$version" \
  "$artifact_path"

maybe_sign_pkg "$artifact_path"
maybe_notarize "$artifact_path"

log "Built system-wide installer package: $artifact_path"
