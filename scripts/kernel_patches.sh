#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: kernel_patches.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

mapfile -t PATCHES < <(read_list kernel_patches)
if (( ${#PATCHES[@]} == 0 )); then
    log "No kernel_patches for $DEVICE"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

n=0
for url in "${PATCHES[@]}"; do
    [[ -n "$url" ]] || continue
    [[ "$url" == https://* ]] || die "kernel_patches: only https:// URLs are allowed (got '$url')"
    n=$((n + 1))
    file="${TMP_DIR}/${n}.patch"
    log "Kernel patch ${n}/${#PATCHES[@]}: $url"
    retry_fetch "$url" "$file"
    [[ -s "$file" ]] || die "kernel_patches: empty download for $url"
    if ! patch -p1 --dry-run --no-backup-if-mismatch -s < "$file" >/dev/null; then
        die "kernel_patches: does not apply cleanly: $url"
    fi
    patch -p1 --no-backup-if-mismatch -s < "$file"
done

log "kernel_patches: applied $n patch(es)"
