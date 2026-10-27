## HarryWrt {{REL}}

Based on OpenWrt **{{OWRT}}** (apk package manager).
OpenWrt 24.10 reached end of life on 30 September 2026 and is no longer built; HarryWrt v4.0 was its last release.

### Which file do I need?

File names: `HarryWrt-<OpenWrt>-<edition>-{{REL}}-<platform>-…img.gz`

| Your hardware | Platform | File to use |
|---|---|---|
| PC / mini PC / soft router (UEFI) | `x86_64` | `…-x86_64-squashfs-uefi.img.gz` |
| Old PC (legacy BIOS) | `x86_64` | `…-x86_64-squashfs-bios.img.gz` |
| Proxmox / ESXi / QEMU VM | `x86_64` | `…-x86_64-ext4-uefi.img.gz` |
| NanoPi R2S / R4S / R5C / R5S / R6C / R6S | `rockchip` | `…-rockchip-friendlyarm_nanopi-<model>-squashfs-sysupgrade.img.gz` (write to microSD) |
| Raspberry Pi 4 / 400 / CM4 | `rpi4` | `…-rpi4-rpi-4-squashfs-factory.img.gz` (write to microSD) |
| Raspberry Pi 5 | `rpi5` | `…-rpi5-rpi-5-squashfs-factory.img.gz` (write to microSD) |
| ARM64 VM (Proxmox ARM, UTM, cloud) | `aarch64` | `…-aarch64-squashfs-combined-efi.img.gz` |

- **squashfs** (recommended): supports reset to defaults. **ext4**: fully writable, easier to resize.
- **Upgrading** a device that already runs OpenWrt/HarryWrt: use the `sysupgrade` file (boards) or the same image (x86).
- A board missing from this release is not supported by OpenWrt {{OWRT}}.

### Editions

**Clean** — LuCI (HTTPS), dnsmasq-full, nftables transparent-proxy kernel (TProxy/TUN), IPv6, network health page, irqbalance.

**Plus** — Clean + everything Passwall2 needs to install offline (Xray, sing-box, chinadns-ng, geodata), WireGuard, DDNS + ACME, UPnP (off by default), traffic statistics, Wake-on-LAN, TCP BBR.

### Defaults

- Address: `192.168.1.1` · Hostname: `HarryWrt` · Timezone: UTC · Theme: Bootstrap (official)
- Packages you install are reinstalled automatically after a firmware upgrade (see README)

### Verify

`SHA256SUMS` covers every file in this release: `sha256sum -c --ignore-missing SHA256SUMS`.

Each build also has a `…-buildinfo.tar.gz`: the package manifest (every package version) and the exact OpenWrt, feed and config details used — for reproducing a build or reporting a problem. You do not need it to install the firmware.
