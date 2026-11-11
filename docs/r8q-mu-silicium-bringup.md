# Samsung Galaxy S20 FE 5G (r8q) — Mu-Silicium bring-up notes

This document records the r8q boot and USB-networking workflow provided for this device. It is an **experimental, separate bring-up path**; it is not the standard Kali NetHunter Pro `./build.sh -t r8q` image-install procedure, and it does not convert the Kali image into Arch Linux ARM. The supplied workflow boots Arch Linux ARM using Mu-Silicium UEFI and a separately built mainline kernel.

> **Destructive operations:** the procedure reformats the phone's `cache` partition for use as an ESP and formats `userdata`. Back up anything important and confirm partition labels/devices before running formatting or flashing commands. Flashing firmware and repartitioning can leave the device unbootable if the wrong image or partition is used. This guide is not a substitute for the device-specific recovery instructions.

## Workspace and prerequisites

The commands below assume the external r8q bring-up workspace described in the supplied workflow. Set these variables to your actual paths:

- `$KSRC`: mainline Linux kernel source tree
- `$OUT`: kernel build output directory (`O=`)
- `$MUSIL`: Mu-Silicium checkout
- `KV`: kernel release string, for example `7.1.2`

The referenced `PREREQUISITES.md`, `dts/`, `config/`, `initramfs/`, `rootfs/`, and `scripts/` are part of that bring-up workflow; they are not supplied by this repository's standard Kali image build. Make sure they exist in the appropriate checkout before running the commands. Do not assume scripts with the same names in this repository are interchangeable.

## 1. Build the kernel and device tree

Apply the two r8q display-fix device-tree files from the bring-up workspace's `dts/` directory to `$KSRC/arch/arm64/boot/dts/qcom/`. Build the kernel and DTB using that workspace's script:

```sh
KSRC=... OUT=... ./scripts/build_kernel.sh
```

The bring-up configuration requires an embedded switch-root initramfs (`CONFIG_INITRAMFS_SOURCE`) containing `init` and `irfs.devnodes`, plus a static AArch64 BusyBox at `bin/busybox`. It also forces the kernel command line from `config/cmdline.txt`; retain `simpledrm` for the display path. Review the kernel configuration and command line before building.

Expected artifacts:

```text
$OUT/arch/arm64/boot/Image
$OUT/arch/arm64/boot/dts/qcom/sm8250-samsung-r8q.dtb
```

## 2. Embed the DTB in Mu-Silicium and build UEFI

The workflow places the DTB in the firmware, where Mu-Silicium's `DtPlatformDxe` exposes it to the kernel. Enable the Device Tree FREEFORM block in `$MUSIL/Platforms/Samsung/r8qPkg/r8q.fdf`, then build:

```sh
MUSIL=$MUSIL \
DTB=$OUT/arch/arm64/boot/dts/qcom/sm8250-samsung-r8q.dtb \
./scripts/build-uefi.sh
```

The supplied workflow expects `$MUSIL/Mu-r8q-0.img` as output. Verify the build completed and that the image contains the intended DTB before flashing.

## 3. Flash UEFI to BOOT

Boot the phone into download mode (power off, hold Volume Up and Volume Down, then connect USB). Verify the target and image before flashing:

```sh
./scripts/flash.sh "$MUSIL/Mu-r8q-0.img"
```

The supplied script uses Heimdall to flash the `BOOT` partition and reboots the phone. Follow the bring-up workspace's recovery guidance if the phone does not boot.

## 4. Prepare the ESP on `cache`

Boot Mu-Silicium into mass-storage mode and identify the `cache` partition carefully. This formats that partition as a FAT32 ESP using 4096-byte sectors; verify `$ESP` is the intended device before proceeding:

```sh
ESP=$(lsblk -o NAME,PARTLABEL -rn | awk '$2=="cache"{print "/dev/"$1}')
printf 'ESP candidate: %s\n' "$ESP"
# Check the printed device and its partition label before running mkfs.
sudo mkfs.vfat -F 32 -S 4096 -n R8QESP "$ESP"
```

## 5. Deploy the kernel to the ESP

Still in mass-storage mode, deploy the kernel Image using the bring-up workspace script. The expected destination is `ESP:/EFI/BOOT/BOOTAA64.EFI`:

```sh
./scripts/deploy-esp.sh "$OUT/arch/arm64/boot/Image"
```

## 6. Install the root filesystem

The supplied workflow installs Arch Linux ARM onto `userdata`; this is destructive and erases its existing contents. Confirm the target and back up data first. Use the external workflow's prerequisites and installer:

```sh
KV=7.1.2 OUT="$OUT" KSRC="$KSRC" ./scripts/install-arch.sh
```

That workflow moves the kernel module tree aside rather than cold-plugging it, because the supplied notes report that cold-plugging the full tree can hard-reset the SoC. It overlays the supplied `rootfs/`, enables SSH, systemd-networkd, and `r8q-usb-gadget`, and configures root autologin and a root password. Treat any default root password as temporary: change it before use and do not expose password-based root SSH to an untrusted network.

## 7. Boot and connect over USB

Exit mass-storage mode and boot the phone. The expected sequence is the initramfs switch-root message, systemd startup, and a root shell on `tty1`. A USB NCM network interface should appear on the PC. Replace `<netdev>` with the interface shown by your host:

```sh
DEV=<netdev>
sudo ip addr add 172.16.42.14/24 dev "$DEV"
sudo ip link set "$DEV" up
ssh root@172.16.42.1
```

## 8. Optional host tethering

To share the PC's internet connection, run the bring-up workspace's host-side NAT helper. The supplied notes say host forwarding/NAT must be enabled again after a host reboot:

```sh
./scripts/host-tether.sh
```

Then test connectivity from the phone and initialize the Arch keyring on a fresh install if needed:

```sh
ssh root@172.16.42.1 'ping -c2 archlinux.org'
ssh root@172.16.42.1 'pacman-key --init && pacman-key --populate archlinuxarm && pacman -Sy'
```

## Iteration notes

- Kernel, command-line, or initramfs changes: rebuild `Image`, enter mass-storage mode, deploy it to the ESP, and reboot; the supplied workflow does not require reflashing UEFI for these changes.
- DTB changes: rebuild the DTB, rebuild Mu-Silicium with the updated DTB, then flash the resulting firmware from download mode.
- Root filesystem changes: edit the mounted `userdata` filesystem in mass-storage mode, or update the running system over SSH.

This workflow and its scripts should be validated against the current external bring-up checkout and the exact device variant before use. The repository's existing r8q Kali target remains a different build path.
