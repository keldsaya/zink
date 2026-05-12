#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"	

case "$1" in
    --defconfig)
        shift
        exec "$SCRIPT_DIR/defconfig.sh" "$@"
        ;;
    --oldconfig)
        shift
        exec "$SCRIPT_DIR/oldconfig.sh" "$@"
        ;;
    --savedefconfig)
        shift
        exec "$SCRIPT_DIR/savedefconfig.sh" "$@"
        ;;
    --header)
        shift
        exec "$SCRIPT_DIR/header.sh" "$@"
        ;;
    --enable)
        shift
        exec "$SCRIPT_DIR/enable.sh" "$@"
        ;;
    --disable)
        shift
        exec "$SCRIPT_DIR/disable.sh" "$@"
        ;;
    *)
        echo "Usage: $0 --defconfig|--oldconfig|--savedefconfig|--header|--enable VAR|--disable VAR"
        exit 1
        ;;
esac
