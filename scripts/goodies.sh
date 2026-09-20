#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: goodies.sh <device> <variant>}"
VARIANT="${2:?Usage: goodies.sh <device> <variant>}"
GOODIES_DIR="${SCRIPT_DIR}/goodies"

case "$VARIANT" in
    nsu) log "NSU (stock) variant — no goodies to apply" ;;
    ksu)
        log "KSU variant — applying ReSukiSU + SuSFS"
        bash "${GOODIES_DIR}/kernelsu.sh" "$DEVICE"
        ;;
    *) die "Unknown variant '$VARIANT' — expected nsu or ksu" ;;
esac

log "goodies.sh done for variant: $VARIANT"
