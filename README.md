# HarryWrt — Clean OpenWrt-Based Firmware

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/platform-x86__64%20%7C%20aarch64-orange.svg)](#)
[![Base](https://img.shields.io/badge/base-OpenWrt%2024.10.6%20%7C%2025.12.2-green.svg)](#)

HarryWrt is a clean, stable, and extensible OpenWrt-based firmware focused on minimalism, stability, and upstream compatibility.

Designed for users who want a minimal, reliable system with practical defaults and strong compatibility with upstream packages.

No bloat, no lock-in, no surprises — just a predictable and maintainable OpenWrt experience.

---

## Features

- Clean base system — no unnecessary modifications
- Fully compatible with upstream OpenWrt packages
- Dual OpenWrt version support (24.10.6 LTS + 25.12.2 stable)
- Dual platform support (x86_64 + aarch64 ARM64)
- Pre-installed Passwall2 dependencies for offline setup
- Modern firewall stack (nftables / fw4)
- Built and released automatically via GitHub Actions

---

## Firmware Matrix

| OpenWrt | Platform | rootfs | Package Manager | Status |
|---------|----------|--------|-----------------|--------|
| 24.10.6 | x86_64   | 768MB  | opkg            | LTS (EOL Sep 2026) |
| 24.10.6 | aarch64  | 512MB  | opkg            | LTS (EOL Sep 2026) |
| 25.12.2 | x86_64   | 768MB  | apk             | Current Stable |
| 25.12.2 | aarch64  | 512MB  | apk             | Current Stable |

### Which version should I choose?

**24.10.6** — If you have an existing opkg-based setup with many installed packages and want a stable, familiar upgrade path. Will receive security fixes until September 2026.

**25.12.2** — Recommended for new installations. Uses the new apk package manager (replaces opkg). Better performance, latest security patches, and long-term support.

### Which platform?

**x86_64** — For soft routers, PCs, virtual machines (Proxmox/ESXi/QEMU), industrial mini-PCs.

**aarch64 (armsr/armv8)** — Generic ARM64 UEFI image. Works with NanoPi R2S/R4S/R5S/R6S, Raspberry Pi 4/5, and other ARM64 devices that support UEFI boot. For device-specific optimizations, consider using dedicated target images.

---

## Downloads

Firmware images are available on the GitHub Releases page:

https://github.com/harryheros/harrywrt/releases

Each release includes BIOS and UEFI images (x86_64), squashfs and ext4 variants, and SHA256 checksum files.

### Recommended Images

| Use Case | File |
|----------|------|
| Modern x86 PC / VM (UEFI) | `*-x86_64-squashfs-uefi.img.gz` |
| Legacy x86 PC (BIOS) | `*-x86_64-squashfs-bios.img.gz` |
| ARM64 devices | `*-aarch64-squashfs-*.img.gz` |

---

## Included Components

### Web Interface
LuCI (HTTPS), luci-compat, ttyd (Web Terminal)

### Themes
Default: Bootstrap (official). Optional: Argon (included, not enabled by default)

### System Tools
bash, curl, wget-ssl, unzip, htop, openssl-util, ca-bundle

### Network Utilities
ip-full, iperf3, tcpdump, ethtool, resolveip

### Firewall / Kernel
nftables (fw4), iptables-nft compatibility layer, kmod-tun, TProxy modules (nft + ipt), nft-socket, nft-nat

### Passwall2 Ready
Pre-installed dependencies: xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping, coreutils, libev, libsodium, libudns. Install passwall2 itself via package manager or manual upload after first boot.

---

## Default Settings

- Hostname: HarryWrt
- Timezone: Asia/Hong_Kong
- LAN IP: 192.168.1.1
- User: root
- Password: unset on first boot
- NTP: enabled (pool.ntp.org)

---

## First Access

After boot, connect via LAN (DHCP enabled) and open https://192.168.1.1

Set a password on first login before further configuration.

> Browser SSL warnings are expected (self-signed certificate).

---

## Installing Passwall2

All required dependencies (xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping, etc.) are already pre-installed in HarryWrt. You only need to install the Passwall2 LuCI app itself.

### On OpenWrt 24.10.6 (opkg)

1. Download `luci-app-passwall2_VERSION_all.ipk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.ipk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

### On OpenWrt 25.12.2 (apk)

1. Download `luci-app-passwall2_VERSION_all.apk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.apk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

> **Note:** HarryWrt 25.12.2 has been patched to allow local package uploads without signature errors. The install experience is identical to 24.10.6 — upload and install, no SSH or command line needed.

> **Important:** On 25.12.2, make sure to download the `.apk` format (not `.ipk`). The `.ipk` format is only compatible with 24.10.x.

---

## Customization

HarryWrt remains fully compatible with upstream OpenWrt. Install additional packages via LuCI (Web UI) or the command line (opkg on 24.10 / apk on 25.12).

### Enable Argon Theme

LuCI → System → System → Language and Style → Theme → Argon

---

## Integrity Verification

Each release includes SHA256 checksum files. Always verify downloaded images before use:

```sh
sha256sum -c SHA256SUMS-24.10.6-x86_64
```

---

## Disclaimer

HarryWrt is provided as-is without warranty. This firmware contains no telemetry, hidden services, or proprietary components. Users are responsible for their own deployments and configurations.

---

## License

HarryWrt follows the OpenWrt licensing model and is distributed under GPL-2.0.

All modifications and distributed binaries comply with upstream OpenWrt licensing requirements.

---

## Credits

- OpenWrt Project
- LuCI Project
- Argon Theme (jerrykuku)
- Passwall2 (Openwrt-Passwall Organization)

---

## Author

Maintained by: harryheros
---

Part of the [Nova infrastructure toolkit](https://github.com/harryheros).
