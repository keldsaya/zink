#!/bin/sh

CONFIG_OUT=".config"
HEADER_OUT="include/config.h"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SCRIPT_DIR/lib.sh"

if [ ! -f "$CONFIG_OUT" ]; then
  echo "Error: $CONFIG_OUT not found. Run 'make defconfig' first." >&2
  exit 1
fi

mkdir -p include
generate_header > "$HEADER_OUT"
scripts/log.sh "GEN" "$HEADER_OUT"
