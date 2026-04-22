#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"

release_tag=""
build_first="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --release-tag)
      release_tag="${2:-}"
      shift 2
      ;;
    --build)
      build_first="true"
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage:
  upload-github-release-artifacts.sh [--release-tag <vX.Y.Z>] [--build]

Options:
  --release-tag  GitHub release tag to upload into. Defaults to BRITELOG_RELEASE_TAG,
                 RELEASE_TAG, or the exact tag at HEAD.
  --build        Build the .pkg and .zip artifacts before uploading them.
USAGE
      exit 0
      ;;
    *)
      die "Unknown upload argument: $1"
      ;;
  esac
done

[ -n "$release_tag" ] || release_tag=$(resolve_release_tag)
require_release_packaging_credentials

if ! command -v gh >/dev/null 2>&1; then
  die "GitHub CLI (gh) is required to upload release artifacts."
fi

if [ "$build_first" = "true" ]; then
  BRITELOG_RELEASE_TAG="$release_tag" "$SELF_DIR/build-release-artifacts.sh"
fi

version="${release_tag#v}"
pkg_path="$BRITELOG_OUTPUT_DIR/${BRITELOG_COMMAND_NAME}-${version}-macos-installer.pkg"
zip_path="$BRITELOG_OUTPUT_DIR/${BRITELOG_COMMAND_NAME}-${version}-macos-user.zip"

[ -f "$pkg_path" ] || die "Expected installer package at $pkg_path before upload."
[ -f "$zip_path" ] || die "Expected per-user zip bundle at $zip_path before upload."

gh release view "$release_tag" >/dev/null 2>&1 || die "GitHub release $release_tag does not exist yet. Create it before uploading assets."
gh release upload "$release_tag" "$pkg_path" "$zip_path" --clobber

log "Uploaded release assets to GitHub release $release_tag:"
log "  $pkg_path"
log "  $zip_path"
