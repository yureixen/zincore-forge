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

DEVICE="${1:-}"
if [ -n "$DEVICE" ] && [ -f "devices/${DEVICE}.json" ]; then
    DEVICE_JSON="devices/${DEVICE}.json"
    DEVICE_LTO_OVERRIDE=$(read_field lto_mode)
    [ -n "$DEVICE_LTO_OVERRIDE" ] && LTO_MODE="$DEVICE_LTO_OVERRIDE"
fi

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

# CFI/Shadow-Call-Stack — enable only if THIS kernel's own Kconfig supports
if grep -rq "CONFIG_CFI_CLANG" arch/arm64/Kconfig 2>/dev/null; then
    fragment_add "$FRAGMENT_FILE" "-e CONFIG_CFI_CLANG"
    fragment_add "$FRAGMENT_FILE" "-e CONFIG_CFI_CLANG_SHADOW"
    log "CFI supported by this kernel's Kconfig — enabled"
else
    warn "CONFIG_CFI_CLANG not found in this kernel's Kconfig — skipping (not an error, just unsupported on this tree)"
fi

log "Fragment written: $FRAGMENT_FILE (LTO_MODE=$LTO_MODE)"
cat "$FRAGMENT_FILE"
