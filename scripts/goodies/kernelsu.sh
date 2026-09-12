#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: kernelsu.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

: "${KSU_REPO_URL:?KSU_REPO_URL not set — source config.env first}"
: "${KSU_REPO_PIN:?KSU_REPO_PIN not set — source config.env first}"
: "${KSU_SETUP_ARG:?KSU_SETUP_ARG not set — source config.env first}"
: "${SUSFS_REPO_URL:?SUSFS_REPO_URL not set — source config.env first}"
: "${SUSFS_REPO_PIN:?SUSFS_REPO_PIN not set — source config.env first}"

KERNEL_VERSION=$(read_field kernel_version)
[ -n "$KERNEL_VERSION" ] || die "kernel_version missing in $DEVICE_JSON"

# Clone + pin dependencies BEFORE executing anything from them
WORKDIR="$(pwd)"
KSU_SRC="${WORKDIR}/.zincore_deps/resukisu"
SUSFS_SRC="${WORKDIR}/.zincore_deps/susfs"
mkdir -p "$(dirname "$KSU_SRC")"

log "Cloning ReSukiSU (pinned to ${KSU_REPO_PIN})"
git clone --quiet "$KSU_REPO_URL" "$KSU_SRC"
git -C "$KSU_SRC" checkout --quiet "$KSU_REPO_PIN"

log "Cloning SuSFS source (JackA1ltman, pinned to ${SUSFS_REPO_PIN})"
git clone --quiet "$SUSFS_REPO_URL" "$SUSFS_SRC"
git -C "$SUSFS_SRC" checkout --quiet "$SUSFS_REPO_PIN"

FRAGMENT_DIR="zincore_fragments"
FRAGMENT_FILE="${FRAGMENT_DIR}/kernelsu.config"
mkdir -p "$FRAGMENT_DIR"
: > "$FRAGMENT_FILE"

log "Installing ReSukiSU (setup.sh arg: $KSU_SETUP_ARG)"
bash "${KSU_SRC}/kernel/setup.sh" "$KSU_SETUP_ARG"

log "Applying SuSFS patch for kernel $KERNEL_VERSION"

if grep -q "CONFIG_KSU_SUSFS" "fs/namespace.c" 2>/dev/null; then
    log "SuSFS already patched in this tree, skipping patch step"
else
    SUSFS_PATCH_FILE="${SUSFS_SRC}/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"

    if [ ! -f "$SUSFS_PATCH_FILE" ]; then
        die "$SUSFS_PATCH_FILE not found in pinned SuSFS source — check that susfs_patch_to_${KERNEL_VERSION}.patch exists at this pinned commit."
    fi

    log "Applying SuSFS patch"
    patch -p1 --fuzz=3 < "$SUSFS_PATCH_FILE" || true

    REJ_FILES=$(find . -name "*.rej" 2>/dev/null || true)
    if [ -n "$REJ_FILES" ]; then
        warn "SuSFS patch produced rejected hunks — build stopped, NOT continuing silently:"
        warn "$REJ_FILES"
        warn "Each .rej file above shows the exact hunk that failed to apply."
        die "These must be resolved manually against this kernel tree before a KSU build can be trusted."
    fi
    log "SuSFS patch applied cleanly, no rejects"
fi

# Manual hook script
log "Applying SuSFS manual hook patches"
bash "${SUSFS_SRC}/Patches/susfs_inline_hook_patches.sh" | tee /tmp/zincore_susfs_hook.log
grep -o "Current susfs patch version:[0-9.]*" /tmp/zincore_susfs_hook.log | head -1 | sed 's/Current susfs patch version://' > "${WORKDIR}/${DEVICE}-susfs-version.txt" || true

# Core config fragment (structural — merged into out/.config by compile.sh)
log "Patching static symbol exports required by ReSukiSU"
unstatic() {
    local file="$1" regex="$2"
    if [ -f "$file" ] && grep -q "static $regex" "$file" 2>/dev/null; then
        sed -i "s/static $regex/$regex/" "$file"
        log "  exported: $regex ($file)"
    fi
}
unstatic "security/selinux/selinuxfs.c" "ssize_t (\*write_op\[\])"
unstatic "security/selinux/selinuxfs.c" "const struct file_operations sel_handle_status_ops"
unstatic "security/selinux/selinuxfs.c" "DEFINE_MUTEX(sel_mutex);"
unstatic "security/selinux/ss/services.c" "struct page \*selinux_status_page;"
unstatic "security/selinux/ss/services.c" "DEFINE_MUTEX(selinux_status_lock);"
unstatic "security/selinux/ss/services.c" "DEFINE_RWLOCK(policy_rwlock);"
unstatic "security/selinux/hooks.c" "struct security_operations selinux_ops"

fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_PATH"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_MOUNT"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_KSTAT"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SPOOF_UNAME"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_ENABLE_LOG"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_OPEN_REDIRECT"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_MAP"

# THREAD_INFO_IN_TASK is conditionally required
if grep -q "THREAD_INFO_IN_TASK" "drivers/kernelsu/Kconfig" 2>/dev/null; then
    fragment_add "$FRAGMENT_FILE" "-e CONFIG_THREAD_INFO_IN_TASK"
    log "THREAD_INFO_IN_TASK required by this KernelSU Kconfig, added"
fi

log "Fragment written: $FRAGMENT_FILE"
cat "$FRAGMENT_FILE"
