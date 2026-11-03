<div align="center">

# Zincore Forge

[![Downloads](https://img.shields.io/github/downloads/yureixen/zincore-forge/total?label=Downloads&labelColor=1f2328&color=6e56cf)](https://github.com/yureixen/zincore-forge/releases)
[![License](https://img.shields.io/github/license/yureixen/zincore-forge?label=License&labelColor=1f2328&color=6e56cf)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-Channel-6e56cf?labelColor=1f2328)](https://t.me/deadenddrops)

</div>

GitHub Actions builder for non-GKI kernels. It compiles the source maintained by teams like LineageOS and PixelOS with a pinned AOSP Clang toolchain, keeping close to their own configuration so the kernel remains as stable and predictable as they made it.

## Approach

Built for those who want the stability of a stock kernel but still want root when they need it. The `ksu` build adds BakaSU and SuSFS on top, and nothing else, while the `nsu` build is the vanilla kernel.

## Compatibility

| Supported devices | Kernel version | Supported Android versions |
| :--- | :---: | :---: |
| Xiaomi Redmi 7/Y3 ([onclite](https://www.gsmarena.com/xiaomi_redmi_7-9498.php)) | 4.9 | Android 13 – 17 |
| Xiaomi Redmi Note 7 Pro ([violet](https://www.gsmarena.com/xiaomi_redmi_note_7_pro-9521.php)) | 4.14 | Android 13 – 17 |
| Xiaomi Redmi Note 10 Pro/Pro Max ([sweet](https://www.gsmarena.com/xiaomi_redmi_note_10_pro-10662.php)) | 4.14 | Android 13 – 17 |

## Installation

> [!CAUTION]
> Your warranty is now void. I am not responsible for bricked devices or dead SD cards. Please do some research if you have any concerns about the features this builder includes in its kernels before flashing them! YOU are choosing to make these modifications, and if you point the finger at me for messing up your device, I will laugh at you.

> [!IMPORTANT]
> Back up your current `boot` (and `dtbo`, if your device has one) partitions.

### Flash
1. Download the zip for your variant (`nsu` or `ksu`) from [Releases](../../releases).
2. Reboot to recovery.
3. Flash or sideload the zip.
4. Reboot to system.
5. Install [BakaSU Manager](https://github.com/Baka-SU/BakaSU/releases) if needed (`ksu` only).

### Restore to stock
1. Reboot to bootloader.
2. Flash the stock boot image: `fastboot flash boot boot.img`
3. If you backed up `dtbo`, restore it too: `fastboot flash dtbo dtbo.img`
4. Reboot: `fastboot reboot`

## Release schedule

New builds are released on the **1st of every month**. Each release rebuilds every supported device and variant from the latest kernel source. An emergency release may follow between cycles if the kernel source or build dependencies change significantly.

## Credits

- [Baka-SU](https://github.com/Baka-SU) for KernelSU on non-GKI kernels.
- [Hadad](https://codeberg.org/hadad) for kernel source.
- [JackA1ltman](https://github.com/JackA1ltman) for KernelSU hook script and SuSFS patches.
- [LineageOS](https://github.com/LineageOS) for kernel source.
- [osm0sis](https://github.com/osm0sis/AnyKernel3) for AnyKernel3.
- [PixelOS](https://github.com/PixelOS-Devices) for kernel source.
- [riarumoda](https://github.com/riarumoda/perf_neon-builder) for the inspiration.
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) for SuSFS.
- [tiann](https://github.com/tiann/KernelSU) for the original KernelSU.
