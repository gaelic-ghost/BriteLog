#!/usr/bin/env sh
set -eu

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [--prefix <dir>] [--bin-dir <dir>] [--lib-dir <dir>]

Defaults:
  prefix  = $HOME/.local
  bin-dir = <prefix>/bin
  lib-dir = <prefix>/lib/gaelic-ghost/britelog
USAGE
}

prefix="$HOME/.local"
bin_dir=""
lib_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    --bin-dir)
      bin_dir="${2:-}"
      shift 2
      ;;
    --lib-dir)
      lib_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown install argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[ -n "$bin_dir" ] || bin_dir="$prefix/bin"
[ -n "$lib_dir" ] || lib_dir="$prefix/lib/gaelic-ghost/britelog"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAYLOAD_DIR="$SCRIPT_DIR/payload"
BINARY_SOURCE="$PAYLOAD_DIR/britelog"
VERSION_FILE="$PAYLOAD_DIR/VERSION"

[ -x "$BINARY_SOURCE" ] || {
  printf 'error: expected an executable payload at %s\n' "$BINARY_SOURCE" >&2
  exit 1
}

version="unknown"
if [ -f "$VERSION_FILE" ]; then
  version=$(cat "$VERSION_FILE")
fi

target_root="$lib_dir/$version"
target_binary="$target_root/britelog"
target_link="$bin_dir/britelog"

mkdir -p "$target_root" "$bin_dir"
cp "$BINARY_SOURCE" "$target_binary"
chmod 0755 "$target_binary"
ln -sfn "$target_binary" "$target_link"

cat <<EOF
Installed BriteLog for this user.
  binary: $target_binary
  command: $target_link

Make sure $bin_dir is on your PATH if \`britelog\` is not already available in new shells.
EOF
