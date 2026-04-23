#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/../.." && pwd)
DERIVED_DATA_PATH="$REPO_ROOT/dist/integration/DerivedData"
APP_BUNDLE_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/BriteLog.app"
APP_EXECUTABLE_PATH="$APP_BUNDLE_PATH/Contents/MacOS/BriteLog"
TEMP_ROOT=$(mktemp -d)
BUILD_LOG="$TEMP_ROOT/xcodebuild.log"
RUN_STDOUT="$TEMP_ROOT/britelog-app.stdout"
RUN_STDERR="$TEMP_ROOT/britelog-app.stderr"
RUN_LOG="$TEMP_ROOT/runtime-policy.log"

cleanup() {
  rm -rf "$TEMP_ROOT"
}

trap cleanup EXIT

xcodebuild \
  -project "$REPO_ROOT/Apps/BriteLog/BriteLog.xcodeproj" \
  -scheme BriteLog \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >"$BUILD_LOG" 2>&1

[ -d "$APP_BUNDLE_PATH" ] || {
  printf 'error: expected built app bundle at %s\n' "$APP_BUNDLE_PATH" >&2
  exit 1
}

[ -x "$APP_EXECUTABLE_PATH" ] || {
  printf 'error: expected built app executable at %s\n' "$APP_EXECUTABLE_PATH" >&2
  exit 1
}

"$APP_EXECUTABLE_PATH" >"$RUN_STDOUT" 2>"$RUN_STDERR" &
app_pid=$!
sleep 2

if kill -0 "$app_pid" >/dev/null 2>&1; then
  kill "$app_pid" >/dev/null 2>&1 || true
  wait "$app_pid" >/dev/null 2>&1 || true
  printf 'BriteLog app smoke test passed.\n'
  printf '  app: %s\n' "$APP_BUNDLE_PATH"
  printf '  executable: %s\n' "$APP_EXECUTABLE_PATH"
  exit 0
fi

log show --last 2m --style compact \
  --predicate 'eventMessage CONTAINS[c] "BriteLog.app" OR eventMessage CONTAINS[c] "BriteLog" OR process == "amfid" OR process == "taskgated-helper"' \
  >"$RUN_LOG"

if grep -F "Unsatisfied Entitlements: com.apple.logging.local-store" "$RUN_LOG" >/dev/null 2>&1; then
  printf 'BriteLog.app built successfully, but macOS blocked execution because com.apple.logging.local-store does not have a matching provisioning profile in this build context.\n'
  printf 'This confirms the restricted-entitlement gate for the signed app path.\n'
  printf '  app: %s\n' "$APP_BUNDLE_PATH"
  exit 0
fi

printf 'error: the Xcode app did not run successfully, and the failure did not match the expected restricted-entitlement gate.\n' >&2

if [ -s "$RUN_STDERR" ]; then
  printf 'stderr:\n' >&2
  cat "$RUN_STDERR" >&2
fi

if [ -s "$RUN_LOG" ]; then
  printf 'recent log excerpt:\n' >&2
  tail -40 "$RUN_LOG" >&2
fi

if [ -s "$BUILD_LOG" ]; then
  printf 'build log excerpt:\n' >&2
  tail -40 "$BUILD_LOG" >&2
fi

exit 1
