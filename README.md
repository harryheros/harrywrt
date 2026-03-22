# HarryWrt — Clean OpenWrt-Based Firmware (x86_64)

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/platform-BIOS%20%7C%20UEFI-orange.svg)](#)
[![Base](https://img.shields.io/badge/base-OpenWrt%2024.10.x-green.svg)](#)
[![Architecture](https://img.shields.io/badge/arch-x86__64-lightgrey.svg)](#)

HarryWrt is a clean, stable, and extensible firmware based on official OpenWrt.

It is designed for users who want a minimal, reliable system with practical defaults and strong compatibility with upstream packages.

---

## ✨ Features

- Clean base system with no unnecessary modifications
- Fully compatible with upstream OpenWrt packages
- Expanded root filesystem (1GB) for future extensions
- Pre-installed essential tools for diagnostics and maintenance
- Modern firewall stack (nftables / fw4)
- Ready for advanced networking and proxy deployments
- Built and released automatically via GitHub Actions

---

## 📦 Firmware Information

- Base: OpenWrt 24.10.x  
- Target: x86_64 (generic)  
- Edition: Clean  
- Root filesystem: 1024MB  

---

## ⬇️ Downloads

Firmware images are available on the GitHub Releases page:

👉 https://github.com/harryheros/harrywrt/releases

Each release includes:

- BIOS and UEFI images
- squashfs and ext4 variants
- SHA256 checksum file

---

## 💿 Recommended Images

- `squashfs-uefi.img.gz` → modern systems (UEFI)
- `squashfs-bios.img.gz` → legacy BIOS systems

---

## 🧩 Included Components

### Web Interface

- LuCI (HTTPS)
- luci-compat

### Themes

- Default: Bootstrap (official OpenWrt)
- Optional: Argon (not enabled by default)

### System Tools

- bash
- curl
- wget-ssl
- unzip
- htop
- openssl-util
- ca-bundle

### Network Utilities

- ip-full
- iperf3
- tcpdump
- ethtool
- resolveip

### Firewall / Kernel

- nftables (fw4)
- iptables-nft
- kmod-tun
- advanced netfilter modules

---

## ⚙️ Default Settings

- Hostname: HarryWrt  
- Timezone: Asia/Hong_Kong  
- LAN IP: 192.168.1.1  
- User: root  
- Password: unset on first boot  

---

## 🌐 First Access

After boot:

- Connect via LAN (DHCP enabled)
- Open: https://192.168.1.1

Set a password on first login before further configuration.

> Note: Browser SSL warnings are expected (self-signed certificate)

---

## 🔧 Customization

HarryWrt is designed to remain fully compatible with upstream OpenWrt.

You can install additional packages via:

- LuCI (Web UI)
- opkg (SSH)

---

## 🎨 Optional: Enable Argon Theme

LuCI → System → System → Language and Style → Theme → Argon

---

## 🔐 Integrity Verification

Each release includes a `SHA256SUMS` file.

Always verify downloaded images before use.

---

## ⚠️ Disclaimer

HarryWrt is provided as-is without warranty.

This firmware contains no telemetry, hidden services, or proprietary components.

Users are responsible for their own deployments and configurations.

---

## ⚖️ License

HarryWrt follows the OpenWrt licensing model (GPL-2.0).

---

## 🙏 Credits

- OpenWrt Project  
- LuCI Project  
- Argon Theme (jerrykuku)

---

## 👤 Author

Maintained by: harryheros
