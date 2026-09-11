#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:?Usage: kernelsu.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

: "${KSU_REPO_URL:?KSU_REPO_URL not set — source config.env first}"
: "${KSU_REPO_PIN:?KSU_REPO_PIN not set — source config.env first}"
: "${KSU_SETUP_ARG:?KSU_SETUP_ARG not set — source config.env first}"
: "${SUSFS_REPO_URL:?SUSFS_REPO_URL not set — source config.env first}"
: "${SUSFS_REPO_PIN:?SUSFS_REPO_PIN not set — source config.env first}"

KERNEL_VERSION=$(python3 -c "
import json
print(json.load(open('$DEVICE_JSON'))['$DEVICE'].get('kernel_version',''))
")

if [ -z "$KERNEL_VERSION" ]; then
    echo "✗ kernel_version missing in $DEVICE_JSON"
    exit 1
fi

# Clone + pin dependencies BEFORE executing anything from them
WORKDIR="$(pwd)"
KSU_SRC="${WORKDIR}/.zincore_deps/resukisu"
SUSFS_SRC="${WORKDIR}/.zincore_deps/susfs"
mkdir -p "$(dirname "$KSU_SRC")"

echo "→ Cloning ReSukiSU (pinned to ${KSU_REPO_PIN})"
git clone --quiet "$KSU_REPO_URL" "$KSU_SRC"
git -C "$KSU_SRC" checkout --quiet "$KSU_REPO_PIN"

echo "→ Cloning SuSFS source (JackA1ltman, pinned to ${SUSFS_REPO_PIN})"
git clone --quiet "$SUSFS_REPO_URL" "$SUSFS_SRC"
git -C "$SUSFS_SRC" checkout --quiet "$SUSFS_REPO_PIN"

FRAGMENT_DIR="zincore_fragments"
FRAGMENT_FILE="${FRAGMENT_DIR}/kernelsu.config"
mkdir -p "$FRAGMENT_DIR"
: > "$FRAGMENT_FILE"
add() { echo "$1" >> "$FRAGMENT_FILE"; }

echo "→ Installing ReSukiSU (setup.sh arg: $KSU_SETUP_ARG)"
bash "${KSU_SRC}/kernel/setup.sh" "$KSU_SETUP_ARG"

echo "→ Applying SuSFS patch for kernel $KERNEL_VERSION"

if grep -q "CONFIG_KSU_SUSFS" "fs/namespace.c" 2>/dev/null; then
    echo "→ SuSFS already patched in this tree, skipping patch step"
else
    SUSFS_PATCH_FILE="${SUSFS_SRC}/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"

    if [ ! -f "$SUSFS_PATCH_FILE" ]; then
        echo "✗ $SUSFS_PATCH_FILE not found in pinned SuSFS source"
        echo "  Check that susfs_patch_to_${KERNEL_VERSION}.patch exists at this pinned commit."
        exit 1
    fi

    echo "→ Applying SuSFS patch"
    patch -p1 --fuzz=3 < "$SUSFS_PATCH_FILE" || true

    REJ_FILES=$(find . -name "*.rej" 2>/dev/null || true)
    if [ -n "$REJ_FILES" ]; then
        echo "✗ SuSFS patch produced rejected hunks — build stopped, NOT continuing silently:"
        echo "$REJ_FILES"
        echo ""
        echo "  Each .rej file above shows the exact hunk that failed to apply."
        echo "  These must be resolved manually against this kernel tree before a KSU build can be trusted."
        exit 1
    fi
    echo "→ SuSFS patch applied cleanly, no rejects"
fi

# Manual hook script
echo "→ Applying SuSFS manual hook patches"
bash "${SUSFS_SRC}/Patches/susfs_inline_hook_patches.sh" | tee /tmp/zincore_susfs_hook.log
grep -o "Current susfs patch version:[0-9.]*" /tmp/zincore_susfs_hook.log | head -1 | sed 's/Current susfs patch version://' > "${WORKDIR}/${DEVICE}-susfs-version.txt" || true

# Core config fragment (structural — merged into out/.config by compile.sh)
echo "→ Patching static symbol exports required by ReSukiSU"
unstatic() {
    local file="$1" regex="$2"
    if [ -f "$file" ] && grep -q "static $regex" "$file" 2>/dev/null; then
        sed -i "s/static $regex/$regex/" "$file"
        echo "  exported: $regex ($file)"
    fi
}
unstatic "security/selinux/selinuxfs.c" "ssize_t (\*write_op\[\])"
unstatic "security/selinux/selinuxfs.c" "const struct file_operations sel_handle_status_ops"
unstatic "security/selinux/selinuxfs.c" "DEFINE_MUTEX(sel_mutex);"
unstatic "security/selinux/ss/services.c" "struct page \*selinux_status_page;"
unstatic "security/selinux/ss/services.c" "DEFINE_MUTEX(selinux_status_lock);"
unstatic "security/selinux/ss/services.c" "DEFINE_RWLOCK(policy_rwlock);"
unstatic "security/selinux/hooks.c" "struct security_operations selinux_ops"

add "-e CONFIG_KSU"
add "-e CONFIG_KSU_SUSFS"
add "-e CONFIG_KSU_SUSFS_SUS_PATH"
add "-e CONFIG_KSU_SUSFS_SUS_MOUNT"
add "-e CONFIG_KSU_SUSFS_SUS_KSTAT"
add "-e CONFIG_KSU_SUSFS_SPOOF_UNAME"
add "-e CONFIG_KSU_SUSFS_ENABLE_LOG"
add "-e CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS"
add "-e CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG"
add "-e CONFIG_KSU_SUSFS_OPEN_REDIRECT"
add "-e CONFIG_KSU_SUSFS_SUS_MAP"

# THREAD_INFO_IN_TASK is conditionally required
if grep -q "THREAD_INFO_IN_TASK" "drivers/kernelsu/Kconfig" 2>/dev/null; then
    add "-e CONFIG_THREAD_INFO_IN_TASK"
    echo "→ THREAD_INFO_IN_TASK required by this KernelSU Kconfig, added"
fi

echo "→ Fragment written: $FRAGMENT_FILE"
cat "$FRAGMENT_FILE"
