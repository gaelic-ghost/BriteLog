#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/../lib"
. "$SELF_DIR/../lib/common.sh"

DIST_SCRIPT_DIR="$REPO_ROOT/scripts/distribution"

if [ ! -d "$DIST_SCRIPT_DIR" ]; then
  log "No distribution script directory exists at $DIST_SCRIPT_DIR, so no release artifacts were uploaded."
  exit 0
fi

if [ "${REPO_MAINTENANCE_SKIP_DISTRIBUTION_ASSETS:-false}" = "true" ]; then
  log "Skipping distribution asset build/upload because --skip-distribution-assets was requested."
  exit 0
fi

if [ "${REPO_MAINTENANCE_SKIP_GH_RELEASE:-false}" = "true" ]; then
  log "Skipping distribution asset upload because --skip-gh-release leaves no GitHub release target."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  warn "gh is unavailable, so packaged release assets were not uploaded."
  exit 0
fi

if [ "${REPO_MAINTENANCE_DRY_RUN:-false}" = "true" ]; then
  log "Would build and upload packaged release assets for $RELEASE_TAG."
  exit 0
fi

BRITELOG_RELEASE_TAG="$RELEASE_TAG" sh "$DIST_SCRIPT_DIR/build-release-artifacts.sh"
BRITELOG_RELEASE_TAG="$RELEASE_TAG" sh "$DIST_SCRIPT_DIR/upload-github-release-artifacts.sh"

log "Built and uploaded packaged distribution assets for $RELEASE_TAG."
