#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: env.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

[ -f "$DEVICE_JSON" ] || die "No device config found at $DEVICE_JSON"

KERNEL_REPO=$(read_field kernel_repo)
KERNEL_BRANCH=$(read_field kernel_branch)
CLANG_VERSION=$(read_field clang_version)
CLANG_BRANCH=$(read_field clang_branch)
KERNEL_ARCH=$(read_field arch)

[ -n "$KERNEL_ARCH" ] || die "No arch set in $DEVICE_JSON for device '$DEVICE'"
if [ "$KERNEL_ARCH" != "arm64" ]; then
    die "env.sh only supports arch=arm64 — device '$DEVICE' declares arch='$KERNEL_ARCH'."
fi

[ -n "$CLANG_VERSION" ] || die "No clang_version set in $DEVICE_JSON for device '$DEVICE'"

if [ -z "$CLANG_BRANCH" ]; then
    warn "No clang_branch set in $DEVICE_JSON for device '$DEVICE'"
    warn "This must match the exact googlesource release branch this clang_version was published under"
    die "(e.g. android16-qpr2-release for r563880c) — verify against https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 first, do not guess it."
fi

log "Device: $DEVICE"
log "Kernel: $KERNEL_REPO ($KERNEL_BRANCH)"
log "Clang:  clang-$CLANG_VERSION"

# Resolve Clang toolchain
CLANG_DIR="$(pwd)/toolchain/clang-${CLANG_VERSION}"

if [ -d "$CLANG_DIR/bin" ]; then
    log "Using cached toolchain at $CLANG_DIR (restored from CI cache or already present)"
else
    log "Fetching clang-${CLANG_VERSION} from googlesource (archive)..."
    mkdir -p "$CLANG_DIR"
    ARCHIVE_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/${CLANG_BRANCH}/clang-${CLANG_VERSION}.tar.gz"

    # retry_fetch (common.sh): survives transient network blips
    retry_fetch "$ARCHIVE_URL" "/tmp/clang-${CLANG_VERSION}.tar.gz"

    tar -xzf "/tmp/clang-${CLANG_VERSION}.tar.gz" -C "$CLANG_DIR"
    rm -f "/tmp/clang-${CLANG_VERSION}.tar.gz"

    [ -d "$CLANG_DIR/bin" ] || die "Extracted archive but $CLANG_DIR/bin is missing — archive layout may differ from expected."
fi

export PATH="${CLANG_DIR}/bin:${PATH}"

# CRITICAL: this kernel's top-level Makefile assigns CC/LD/AR/etc
export LLVM=1
export LLVM_IAS=1

export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

log "Toolchain ready: $(clang --version | head -1)"
