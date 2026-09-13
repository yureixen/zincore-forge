#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

FRAGMENT_DIR="zincore_fragments"
FRAGMENT_FILE="${FRAGMENT_DIR}/generic.config"
mkdir -p "$FRAGMENT_DIR"
: > "$FRAGMENT_FILE"

log "Building generic config fragment..."

# MODVERSIONS: not needed for a monolithic non-modular boot setup
fragment_add "$FRAGMENT_FILE" "-d CONFIG_MODVERSIONS"

# LTO mode, driven by config.env
: "${LTO_MODE:?LTO_MODE is not set — source config.env before running patches.sh}"

case "$LTO_MODE" in
    thin)
        fragment_add "$FRAGMENT_FILE" "-d CONFIG_LTO_NONE"
        fragment_add "$FRAGMENT_FILE" "-e CONFIG_LTO_CLANG"
        fragment_add "$FRAGMENT_FILE" "-e CONFIG_THINLTO"
        ;;
    full)
        fragment_add "$FRAGMENT_FILE" "-d CONFIG_LTO_NONE"
        fragment_add "$FRAGMENT_FILE" "-e CONFIG_LTO_CLANG"
        fragment_add "$FRAGMENT_FILE" "-d CONFIG_THINLTO"
        ;;
    none)
        fragment_add "$FRAGMENT_FILE" "-e CONFIG_LTO_NONE"
        fragment_add "$FRAGMENT_FILE" "-d CONFIG_LTO_CLANG"
        fragment_add "$FRAGMENT_FILE" "-d CONFIG_THINLTO"
        ;;
    *)
        die "Unknown LTO_MODE '$LTO_MODE' — expected thin|full|none"
        ;;
esac

log "Fragment written: $FRAGMENT_FILE (LTO_MODE=$LTO_MODE)"
cat "$FRAGMENT_FILE"
