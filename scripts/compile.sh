#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: compile.sh <device> <variant>}"
VARIANT="${2:?Usage: compile.sh <device> <variant>}"
DEVICE_JSON="devices/${DEVICE}.json"
OUT_DIR="out"
WORKDIR="$(pwd)"

DEFCONFIG=$(read_field defconfig)
KERNEL_ARCH=$(read_field arch)
AK3_REPO=$(read_field ak3_repo)
AK3_BRANCH=$(read_field ak3_branch)
KERNEL_NAME=$(read_field kernel_name)

: "${DEFCONFIG:?defconfig missing in $DEVICE_JSON}"
: "${AK3_REPO:?ak3_repo missing in $DEVICE_JSON}"
: "${AK3_BRANCH:?ak3_branch missing in $DEVICE_JSON}"
: "${KERNEL_NAME:?kernel_name missing in $DEVICE_JSON}"

log "Building $DEVICE ($VARIANT) — defconfig: $DEFCONFIG"

# Base defconfig
mkdir -p "$OUT_DIR"
make O="$OUT_DIR" ARCH="$KERNEL_ARCH" $DEFCONFIG

# Full kernel name control from builder
./scripts/config --file "${OUT_DIR}/.config" --set-str CONFIG_LOCALVERSION "-${KERNEL_NAME}-${VARIANT}-zincore"

# Generic insurance: disable git-dirty auto-suffix
./scripts/config --file "${OUT_DIR}/.config" --disable CONFIG_LOCALVERSION_AUTO
./scripts/config --file "${OUT_DIR}/.config" --disable CONFIG_LOCALVERSION_SHA

# Merge all fragments written by patches.sh / goodies.sh into out/.config
FRAGMENT_DIR="zincore_fragments"
if [ -d "$FRAGMENT_DIR" ]; then
    for FRAGMENT in "$FRAGMENT_DIR"/*.config; do
        [ -f "$FRAGMENT" ] || continue
        log "Merging fragment: $FRAGMENT"
        ./scripts/config --file "${OUT_DIR}/.config" $(cat "$FRAGMENT")
    done
fi

# Resolve dependencies after all fragment toggles
make O="$OUT_DIR" ARCH="$KERNEL_ARCH" olddefconfig

# ccache
if command -v ccache >/dev/null 2>&1; then
    export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
    export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-2G}"
    export CCACHE_COMPRESS=1
    log "ccache enabled — dir: $CCACHE_DIR, max size: $CCACHE_MAXSIZE"
    CC_WRAPPED="ccache clang"
else
    warn "ccache not found on PATH — building without a compiler cache"
    CC_WRAPPED="clang"
fi

# KCFLAGS: legacy-kernel / modern-clang compatibility shims
export KCFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=incompatible-function-pointer-types"

BUILD_LOG="${WORKDIR}/${DEVICE}-${VARIANT}-build.log"
log "Compiling (log: $BUILD_LOG)"
make -j"$(nproc)" O="$OUT_DIR" ARCH="$KERNEL_ARCH" CC="$CC_WRAPPED" KCFLAGS="$KCFLAGS" 2>&1 | tee "$BUILD_LOG"

# Fail loudly if the kernel image was never produced, even if make "succeeded"
IMAGE_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/Image.gz-dtb"
[ -f "$IMAGE_PATH" ] || IMAGE_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/Image.gz"
[ -f "$IMAGE_PATH" ] || IMAGE_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/Image"

if [ ! -f "$IMAGE_PATH" ]; then
    die "No kernel image found at expected paths under ${OUT_DIR}/arch/${KERNEL_ARCH}/boot/ — build did not actually produce output, check $BUILD_LOG"
fi
log "Kernel image: $IMAGE_PATH"

if [ "$VARIANT" = "ksu" ]; then
    grep -o "ReSukiSU version name: [^ ]*" "$BUILD_LOG" | head -1 | sed -E 's/ReSukiSU version name: //' > "${WORKDIR}/${DEVICE}-resukisu-version.txt" || true
    grep -o "Supported Unofficial Manager:.*" "$BUILD_LOG" | head -1 | sed -E 's/Supported Unofficial Manager: //' > "${WORKDIR}/${DEVICE}-resukisu-managers.txt" || true
fi

# Save final .config as a debug artifact
cp "${OUT_DIR}/.config" "${WORKDIR}/${DEVICE}-${VARIANT}-config"

# Package with AnyKernel3
AK3_DIR="${WORKDIR}/AnyKernel3"
rm -rf "$AK3_DIR"
git clone --depth 1 -b "$AK3_BRANCH" "$AK3_REPO" "$AK3_DIR"

cp "$IMAGE_PATH" "$AK3_DIR/"

# Auto-detect + package whatever boot-related artifacts
BOOT_DIR="${OUT_DIR}/arch/${KERNEL_ARCH}/boot"

for f in dtbo.img dtb.img; do
    if [ -f "${BOOT_DIR}/${f}" ]; then
        cp "${BOOT_DIR}/${f}" "$AK3_DIR/${f%.img}"
        log "${f} included (auto-detected)"
    else
        log "${f} not produced by this build, skipping (not an error)"
    fi
done

DATE_TAG=$(date +%Y%m%d-%H%M)
ZIP_NAME="zincore-${DEVICE}-${VARIANT}-${DATE_TAG}.zip"

pushd "$AK3_DIR" >/dev/null
zip -r9 "${WORKDIR}/${ZIP_NAME}" . -x ".git/*" -x "*.zip"
popd >/dev/null

log "Packaged: ${ZIP_NAME}"
log "Debug artifacts: ${DEVICE}-${VARIANT}-build.log, ${DEVICE}-${VARIANT}-config"
log "compile.sh done"
