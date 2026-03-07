# HarryWrt

[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/Platform-BIOS%20%7C%20UEFI-orange.svg)](#)

HarryWrt is a clean and stable OpenWrt-based firmware focused on reliability, performance, and extensibility.

Built on official OpenWrt 24.10.x, HarryWrt is designed for users who want a minimal yet practical base system with useful built-in tools and expanded storage space for future customization.

---

## Overview

HarryWrt is not a heavily modified OpenWrt fork.

Instead, it preserves the official OpenWrt experience while improving the default environment for real-world deployments.

Key characteristics:

- Clean base system with stable defaults
- Useful built-in tools for diagnostics and maintenance
- Expanded root filesystem for future packages
- High compatibility with upstream OpenWrt packages
- Easy to extend without breaking the stock experience

The goal of HarryWrt is to provide a reliable and extensible base firmware suitable for routers, virtual machines, and network appliances.

---

## Releases

Firmware builds are published on the [GitHub Releases](https://github.com/harryheros/harrywrt/releases) page.

Users can download the latest firmware images and release notes there.

Each release includes firmware images and SHA256 checksum files for integrity verification.

---

## Firmware Information

Base: OpenWrt 24.10.x  
Target: x86_64 (generic)  
Edition: Clean  
Root filesystem size: 1024MB (1GB)

---

## Included Packages

### Web UI

- LuCI (HTTPS)
- luci-compat

### Theme

The default interface keeps the official OpenWrt Bootstrap theme.

Argon theme is included but not enabled by default.

### Tools

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
- additional netfilter modules for advanced networking (tproxy / socket support)

---

## Default Settings

Hostname: HarryWrt  
Timezone: Asia/Hong_Kong  
Default LAN IP: 192.168.1.1  
Default login: root  
Default password: none

---

## Web UI Access

After booting, HarryWrt will use the default LAN address and provide DHCP service for connected clients.

You can access the LuCI Web UI at:

https://192.168.1.1

To change the LAN IP address via SSH:

vi /etc/config/network

Note: Your browser may display an SSL warning because the system uses a self-signed certificate. This is expected.

---

## Recommended Images

HarryWrt provides both BIOS and UEFI images.

Recommended choices:

- squashfs-uefi.img.gz for most modern systems
- squashfs-bios.img.gz for legacy BIOS systems

---

## Advanced Networking Support

HarryWrt includes additional networking capabilities that make it easier to deploy advanced routing or proxy solutions when needed.

The firmware already contains commonly required components such as:

- runtime support for xray-core and sing-box
- v2ray-geoip and v2ray-geosite data
- required kernel modules such as tun, tproxy, and nftables
- commonly required runtime libraries

Users may install additional networking applications such as Passwall2, OpenClash, or other proxy clients after adding the appropriate package feeds.

---

## Optional: Enable Argon Theme

Argon theme is included but not enabled by default.

To enable it:

LuCI → System → System → Language and Style → Theme → Argon

---

## Optional: Customization

HarryWrt is designed to remain highly compatible with upstream OpenWrt packages.

Users may install additional LuCI applications or utilities such as monitoring tools, networking utilities, proxy clients, or file services through the standard OpenWrt package management system.

Packages can be installed through the Web UI or via SSH using the OpenWrt package manager.

---

## Integrity Verification

Each release includes a SHA256SUMS file.

Users should verify downloaded images to ensure file integrity.

---

## Disclaimer

HarryWrt is provided as-is without warranty.

This firmware is based on official OpenWrt sources and does not include hidden services, telemetry, or proprietary components.

Users are responsible for their own configurations and deployments.

---

## License

HarryWrt follows the licensing model of OpenWrt.

OpenWrt is licensed under GPL-2.0.

This repository contains build scripts and configurations that follow the same open-source principles.

---

## Credits

- OpenWrt Project
- LuCI Project
- Argon Theme by jerrykuku
- GitHub Actions build system

---

## Author

HarryWrt Project  
Maintained by: harryheros
