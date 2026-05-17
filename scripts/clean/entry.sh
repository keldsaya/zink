#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$1" in
  --base)
    exec "$SCRIPT_DIR/base.sh" "$2"
    ;;
  --proper)
    exec "$SCRIPT_DIR/proper.sh"
    ;;
  --dist)
    exec "$SCRIPT_DIR/dist.sh"
    ;;
  *)
    echo "Usage: $0 --base <program> |--proper|--dist"
    exit 1
    ;;
esac
