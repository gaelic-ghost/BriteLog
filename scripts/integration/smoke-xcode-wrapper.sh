#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/../.." && pwd)
DERIVED_DATA_PATH="$REPO_ROOT/dist/integration/DerivedData"
BINARY_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/BriteLogTool"
TEMP_ROOT=$(mktemp -d)
TEMP_HOME="$TEMP_ROOT/home"
TEMP_XDG="$TEMP_ROOT/xdg"
BUILD_LOG="$TEMP_ROOT/xcodebuild.log"
RUN_STDOUT="$TEMP_ROOT/britelogtool.stdout"
RUN_STDERR="$TEMP_ROOT/britelogtool.stderr"
RUN_LOG="$TEMP_ROOT/runtime-policy.log"

cleanup() {
  rm -rf "$TEMP_ROOT"
}

trap cleanup EXIT

mkdir -p "$TEMP_HOME" "$TEMP_XDG"

xcodebuild \
  -project "$REPO_ROOT/Apps/BriteLogTool/BriteLogTool.xcodeproj" \
  -scheme BriteLogTool \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >"$BUILD_LOG" 2>&1

[ -x "$BINARY_PATH" ] || {
  printf 'error: expected built wrapper executable at %s\n' "$BINARY_PATH" >&2
  exit 1
}

if "$BINARY_PATH" --help >"$RUN_STDOUT" 2>"$RUN_STDERR"; then
  XDG_CONFIG_HOME="$TEMP_XDG" "$BINARY_PATH" themes select ice >/dev/null
  list_output=$(XDG_CONFIG_HOME="$TEMP_XDG" "$BINARY_PATH" themes list)
  printf '%s\n' "$list_output" | grep -F "* ice - Ice (current default)" >/dev/null

  config_path="$TEMP_XDG/gaelic-ghost/britelog/config.json"
  [ -f "$config_path" ] || {
    printf 'error: expected wrapper run to create config at %s\n' "$config_path" >&2
    exit 1
  }

  printf 'BriteLogTool wrapper smoke test passed.\n'
  printf '  binary: %s\n' "$BINARY_PATH"
  printf '  config: %s\n' "$config_path"
  exit 0
fi

log show --last 2m --style compact \
  --predicate 'eventMessage CONTAINS[c] "BriteLogTool" OR process == "amfid" OR process == "taskgated-helper"' \
  >"$RUN_LOG"

if grep -F "Unsatisfied Entitlements: com.apple.logging.local-store" "$RUN_LOG" >/dev/null 2>&1; then
  printf 'BriteLogTool built successfully, but macOS blocked execution because com.apple.logging.local-store does not have a matching provisioning profile in this build context.\n'
  printf 'This confirms the restricted-entitlement gate for the Xcode wrapper path.\n'
  printf '  binary: %s\n' "$BINARY_PATH"
  exit 0
fi

printf 'error: the Xcode wrapper did not run successfully, and the failure did not match the expected restricted-entitlement gate.\n' >&2

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
