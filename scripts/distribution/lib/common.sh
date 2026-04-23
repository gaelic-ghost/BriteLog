#!/usr/bin/env sh
set -eu

DIST_COMMON_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DIST_ROOT=$(CDPATH= cd -- "$DIST_COMMON_DIR/../.." && pwd)

BRITELOG_PROJECT_PATH="${BRITELOG_PROJECT_PATH:-$DIST_ROOT/Apps/BriteLog/BriteLog.xcodeproj}"
BRITELOG_SCHEME="${BRITELOG_SCHEME:-BriteLog}"
BRITELOG_CONFIGURATION="${BRITELOG_CONFIGURATION:-Release}"
BRITELOG_PRODUCT_NAME="${BRITELOG_PRODUCT_NAME:-BriteLog.app}"
BRITELOG_EXECUTABLE_NAME="${BRITELOG_EXECUTABLE_NAME:-BriteLog}"
BRITELOG_ARTIFACT_BASENAME="${BRITELOG_ARTIFACT_BASENAME:-britelog}"
BRITELOG_DISTRIBUTION_ID="${BRITELOG_DISTRIBUTION_ID:-com.gaelic-ghost.britelog}"
BRITELOG_DERIVED_DATA_PATH="${BRITELOG_DERIVED_DATA_PATH:-$DIST_ROOT/dist/DerivedData}"
BRITELOG_OUTPUT_DIR="${BRITELOG_OUTPUT_DIR:-$DIST_ROOT/dist}"
BRITELOG_INSTALLER_CERT="${BRITELOG_INSTALLER_CERT:-}"
BRITELOG_NOTARY_PROFILE="${BRITELOG_NOTARY_PROFILE:-}"
BRITELOG_ALLOW_UNSIGNED_RELEASE_ASSETS="${BRITELOG_ALLOW_UNSIGNED_RELEASE_ASSETS:-false}"

log() {
  printf '%s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

ensure_clean_dir() {
  dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

resolve_version() {
  if [ "${BRITELOG_VERSION:-}" ]; then
    printf '%s\n' "$BRITELOG_VERSION"
    return
  fi

  if [ "${BRITELOG_RELEASE_TAG:-}" ]; then
    printf '%s\n' "${BRITELOG_RELEASE_TAG#v}"
    return
  fi

  if [ "${RELEASE_TAG:-}" ]; then
    printf '%s\n' "${RELEASE_TAG#v}"
    return
  fi

  if git -C "$DIST_ROOT" describe --tags --exact-match >/dev/null 2>&1; then
    git -C "$DIST_ROOT" describe --tags --exact-match | sed 's/^v//'
    return
  fi

  git -C "$DIST_ROOT" rev-parse --short HEAD
}

resolve_release_tag() {
  if [ "${BRITELOG_RELEASE_TAG:-}" ]; then
    printf '%s\n' "$BRITELOG_RELEASE_TAG"
    return
  fi

  if [ "${RELEASE_TAG:-}" ]; then
    printf '%s\n' "$RELEASE_TAG"
    return
  fi

  if git -C "$DIST_ROOT" describe --tags --exact-match >/dev/null 2>&1; then
    git -C "$DIST_ROOT" describe --tags --exact-match
    return
  fi

  die "Could not determine the GitHub release tag automatically. Pass --release-tag <vX.Y.Z> or set BRITELOG_RELEASE_TAG."
}

release_product_path() {
  printf '%s\n' "$BRITELOG_DERIVED_DATA_PATH/Build/Products/$BRITELOG_CONFIGURATION/$BRITELOG_PRODUCT_NAME"
}

release_executable_path() {
  printf '%s\n' "$(release_product_path)/Contents/MacOS/$BRITELOG_EXECUTABLE_NAME"
}

build_release_product() {
  log "Building $BRITELOG_SCHEME ($BRITELOG_CONFIGURATION) from $BRITELOG_PROJECT_PATH"
  xcodebuild \
    -project "$BRITELOG_PROJECT_PATH" \
    -scheme "$BRITELOG_SCHEME" \
    -configuration "$BRITELOG_CONFIGURATION" \
    -derivedDataPath "$BRITELOG_DERIVED_DATA_PATH" \
    build >&2

  product=$(release_product_path)
  [ -d "$product" ] || die "Expected built app bundle at $product, but it was not found."
  executable=$(release_executable_path)
  [ -x "$executable" ] || die "Expected built app executable at $executable, but it was not found."
  printf '%s\n' "$product"
}

copy_release_product_bundle() {
  source_bundle="$1"
  target_bundle="$2"
  ensure_parent_dir "$target_bundle"
  cp -R "$source_bundle" "$target_bundle"
}

maybe_sign_pkg() {
  pkg_path="$1"

  if [ -z "$BRITELOG_INSTALLER_CERT" ]; then
    log "Leaving package unsigned because BRITELOG_INSTALLER_CERT is not set."
    return
  fi

  signed_path="${pkg_path%.pkg}-signed.pkg"
  log "Signing package with installer identity: $BRITELOG_INSTALLER_CERT"
  productsign --sign "$BRITELOG_INSTALLER_CERT" "$pkg_path" "$signed_path"
  mv "$signed_path" "$pkg_path"
}

maybe_notarize() {
  artifact_path="$1"

  if [ -z "$BRITELOG_NOTARY_PROFILE" ]; then
    log "Skipping notarization because BRITELOG_NOTARY_PROFILE is not set."
    return
  fi

  log "Submitting $artifact_path for notarization with profile $BRITELOG_NOTARY_PROFILE"
  xcrun notarytool submit "$artifact_path" --keychain-profile "$BRITELOG_NOTARY_PROFILE" --wait

  case "$artifact_path" in
    *.pkg|*.dmg)
      log "Stapling notarization ticket to $artifact_path"
      xcrun stapler staple "$artifact_path"
      ;;
    *)
      log "Skipping stapler for $artifact_path; keep the notarized artifact as distributed."
      ;;
  esac
}

require_release_packaging_credentials() {
  if [ "$BRITELOG_ALLOW_UNSIGNED_RELEASE_ASSETS" = "true" ]; then
    log "Proceeding without required release-signing checks because BRITELOG_ALLOW_UNSIGNED_RELEASE_ASSETS=true."
    return
  fi

  [ -n "$BRITELOG_INSTALLER_CERT" ] || die "GitHub release assets require BRITELOG_INSTALLER_CERT so the .pkg is signed before upload."
  [ -n "$BRITELOG_NOTARY_PROFILE" ] || die "GitHub release assets require BRITELOG_NOTARY_PROFILE so the .pkg and .zip are notarized before upload."
}
