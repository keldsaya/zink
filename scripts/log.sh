#!/bin/bash
# Usage: ./log.sh "ACTION" "target"
# Example: ./log.sh "CC" "src/main.c"
# Output: "  CC          src/main.c"

ACTION="$1"
TARGET="$2"
WIDTH=10  

SPACES=$((WIDTH - ${#ACTION} - 2))  
if [ $SPACES -lt 1 ]; then
    SPACES=1
fi

printf "  %s%${SPACES}s%s\n" "$ACTION" "" "$TARGET"
