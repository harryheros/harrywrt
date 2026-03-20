# HarryWrt

[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/Platform-BIOS%20%7C%20UEFI-orange.svg)](#)

HarryWrt is a clean and stable OpenWrt-based firmware focused on reliability, performance, and extensibility.

Built on official OpenWrt 24.10.x, HarryWrt is intended for users who want a minimal yet practical base system with useful built-in tools and expanded storage space for future customization.

---

## Overview

HarryWrt is not a heavily modified OpenWrt fork.

Instead, it preserves the official OpenWrt experience while improving the default environment for practical deployments.

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
- additional netfilter modules for advanced networking features

---

## Default Settings

Hostname: HarryWrt  
Timezone: Asia/Hong_Kong  
Default LAN IP: 192.168.1.1  
Default user: root  
Password state: unset on first boot

---

## First Access

After booting, HarryWrt uses the default LAN address and provides DHCP service for connected clients.

You can access the LuCI Web UI at:

https://192.168.1.1

On first access, set a password for the system before continuing with further configuration.

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

## Extended Networking Capabilities

HarryWrt includes a number of components commonly required for advanced networking use cases.

Examples include:

- modern firewall and packet filtering components
- tun and related kernel support
- common runtime libraries used by additional networking software
- optional geodata packages for software that requires them

This makes the firmware easier to extend for routing, tunneling, filtering, or other advanced network application scenarios.

Users may install additional applications after adding the appropriate package feeds.

---

## Optional: Enable Argon Theme

Argon theme is included but not enabled by default.

To enable it:

LuCI → System → System → Language and Style → Theme → Argon

---

## Optional: Customization

HarryWrt is designed to remain highly compatible with upstream OpenWrt packages.

Users may install additional LuCI applications or utilities such as monitoring tools, networking utilities, storage services, or other OpenWrt packages through the standard package management system.

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

---

## Author

HarryWrt Project  
Maintained by: harryheros
