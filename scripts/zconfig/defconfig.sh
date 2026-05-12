#!/bin/sh

CONFIG_OUT=".config"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SCRIPT_DIR/lib.sh"

rm -f $CONFIG_OUT

{
  echo "# Auto-generated"
  echo ""
  generate_defconfig
} > "$CONFIG_OUT"

echo "  GEN   $CONFIG_OUT"
