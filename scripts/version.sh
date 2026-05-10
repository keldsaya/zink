#!/bin/sh

VERSION=$1
PATCHLEVEL=$2
SUBLEVEL=$3
EXTRAVERSION=$4
NAME=$5
OUTPUT=$6

if [ -z "$OUTPUT" ]; then
    echo "Usage: $0 VERSION PATCHLEVEL SUBLEVEL EXTRAVERSION NAME OUTPUT"
    exit 1
fi

if [ -n "$PATCHLEVEL" ]; then
    VER_STR="${VERSION}.${PATCHLEVEL}"
    if [ -n "$SUBLEVEL" ]; then
        VER_STR="${VER_STR}.${SUBLEVEL}"
    fi
else
    VER_STR="${VERSION}"
fi
VER_STR="${VER_STR}${EXTRAVERSION}"

cat > "$OUTPUT" << EOF
#ifndef __VERSION_H
#define __VERSION_H

#define VERSION_MAJOR ${VERSION}
#define VERSION_MINOR ${PATCHLEVEL}
#define VERSION_PATCH ${SUBLEVEL}
#define VERSION_EXTRA ${EXTRAVERSION}
#define VERSION_STR "${VER_STR} (${NAME})"

#define PROGRAM_VERSION "${VER_STR}"
#define PROGRAM_NAME "${NAME}"

#endif /* __VERSION_H */
EOF

echo "  GEN   $OUTPUT"
