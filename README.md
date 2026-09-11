# Zincore Forge

This kernel focuses on adding ReSukiSU and SuSFS on top of a stock kernel — without dragging in extra modules or tweaks you never asked for.

# Disclaimer

***Your warranty is now void. I am not responsible for bricked devices, dead SD cards, or you getting fired because an alarm failed to work. Please do some research if you have any concerns about features included before flashing it! YOU are choosing to make these modifications, and if you point the finger at me for messing up your device, I will laugh at you.***
<p align="right">Your typical XDA Forum Disclaimer.</p>

# Compatibility

**Device**
- Redmi Note 10 Pro / Pro Max ([`sweet`](https://www.gsmarena.com/xiaomi_redmi_note_10_pro-10662.php))

**Supports**
- Android 13 – 16

# Variants

**ksu**
- ReSukiSU — a KernelSU-based root solution for Android
- SuSFS — an addon root-hiding solution for KernelSU

**nsu**
- Stock kernel — no additions

# Installation

**Flash**
1. Download the zip for your variant (`nsu` or `ksu`) from [Releases](../../releases)
2. Back up your current `boot` and `dtbo` partitions
3. Reboot to recovery
4. Flash or sideload the zip
5. Reboot to system
6. Install [ReSukiSU Manager](https://github.com/ReSukiSU/ReSukiSU/releases) if needed. (`ksu` only)

**Restore to stock**
1. Reboot to bootloader
2. Flash the stock boot image: `fastboot flash boot boot.img`
3. Flash the stock dtbo image: `fastboot flash dtbo dtbo.img`
4. Reboot: `fastboot reboot`

# Release schedule

Builds are published **monthly**. Emergency releases may be published when significant changes to the kernel source or build dependencies change significantly.

# Credits

- [aosp-xiaomi](https://github.com/aosp-xiaomi/android_kernel_xiaomi_sm6150) — kernel source
- [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — KernelSU for non-GKI
- [JackA1ltman](https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd) — SuSFS patches
