#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:?Usage: env.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

if [ ! -f "$DEVICE_JSON" ]; then
    echo "✗ No device config found at $DEVICE_JSON"
    exit 1
fi

# Read device config
read_field() {
    python3 -c "
import json, sys
d = json.load(open('$DEVICE_JSON'))['$DEVICE']
print(d.get('$1', ''))
"
}

KERNEL_REPO=$(read_field kernel_repo)
KERNEL_BRANCH=$(read_field kernel_branch)
KERNEL_DEFCONFIG=$(read_field defconfig)
KERNEL_ARCH=$(read_field arch)
CLANG_VERSION=$(read_field clang_version)
CLANG_BRANCH=$(read_field clang_branch)

if [ -z "$CLANG_VERSION" ]; then
    echo "✗ No clang_version set in $DEVICE_JSON for device '$DEVICE'"
    exit 1
fi

if [ -z "$CLANG_BRANCH" ]; then
    echo "✗ No clang_branch set in $DEVICE_JSON for device '$DEVICE'"
    echo "  This must match the exact googlesource release branch this clang_version was published under"
    echo "  (e.g. android16-qpr2-release for r563880c) — do not guess this, verify against"
    echo "  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 first."
    exit 1
fi

echo "→ Device: $DEVICE"
echo "→ Kernel: $KERNEL_REPO ($KERNEL_BRANCH)"
echo "→ Clang:  clang-$CLANG_VERSION"

# Resolve Clang toolchain
CLANG_DIR="$(pwd)/toolchain/clang-${CLANG_VERSION}"

if [ ! -d "$CLANG_DIR/bin" ]; then
    echo "→ Fetching clang-${CLANG_VERSION} from googlesource (archive)..."
    mkdir -p "$CLANG_DIR"
    ARCHIVE_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/${CLANG_BRANCH}/clang-${CLANG_VERSION}.tar.gz"

    if ! curl -fsSL "$ARCHIVE_URL" -o "/tmp/clang-${CLANG_VERSION}.tar.gz"; then
        echo "✗ Could not download $ARCHIVE_URL"
        echo "  Check that clang-${CLANG_VERSION} exists under refs/heads/${CLANG_BRANCH} of this repo."
        exit 1
    fi

    tar -xzf "/tmp/clang-${CLANG_VERSION}.tar.gz" -C "$CLANG_DIR"
    rm -f "/tmp/clang-${CLANG_VERSION}.tar.gz"

    if [ ! -d "$CLANG_DIR/bin" ]; then
        echo "✗ Extracted archive but $CLANG_DIR/bin is missing — archive layout may differ from expected."
        exit 1
    fi
fi

export PATH="${CLANG_DIR}/bin:${PATH}"

# CRITICAL: this kernel's top-level Makefile assigns CC/LD/AR/etc
export LLVM=1
export LLVM_IAS=1

export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

echo "→ Toolchain ready: $(clang --version | head -1)"
