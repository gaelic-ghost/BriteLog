#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/../lib"
. "$SELF_DIR/../lib/common.sh"

DIST_SCRIPT_DIR="$REPO_ROOT/scripts/distribution"
DIST_COMMON="$DIST_SCRIPT_DIR/lib/common.sh"

if [ ! -f "$DIST_COMMON" ]; then
  exit 0
fi

if [ "${REPO_MAINTENANCE_SKIP_DISTRIBUTION_ASSETS:-false}" = "true" ]; then
  exit 0
fi

if [ "${REPO_MAINTENANCE_SKIP_GH_RELEASE:-false}" = "true" ]; then
  exit 0
fi

if [ "${REPO_MAINTENANCE_DRY_RUN:-false}" = "true" ]; then
  log "Distribution preflight would check release packaging credentials for $RELEASE_TAG."
  exit 0
fi

. "$DIST_COMMON"
require_release_packaging_credentials

log "Distribution preflight confirmed the release packaging credentials needed for $RELEASE_TAG."
