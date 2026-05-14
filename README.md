# HarryWrt — OpenWrt-Based Firmware

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/platform-x86__64%20%7C%20aarch64-orange.svg)](#)
[![Base](https://img.shields.io/badge/base-OpenWrt%2024.10.6%20%7C%2025.12.4-green.svg)](#)

HarryWrt is a stable, extensible OpenWrt-based firmware available in two profiles: **Clean** for minimalism and upstream compatibility, and **Plus** for users who want a full-featured primary router experience out of the box.

No bloat, no lock-in, no surprises — just a predictable and maintainable OpenWrt experience.

---

## Profiles

### Clean Edition
Minimal base system for users who want full control over what runs on their router.

- Clean base system — no unnecessary modifications
- Fully compatible with upstream OpenWrt packages
- Pre-installed Passwall2 dependencies for offline setup
- Modern firewall stack (nftables / fw4)

### Plus Edition
Full-featured primary router firmware. Everything in Clean, plus:

- AdGuard Home — DNS-layer ad and tracker blocking (port 53; dnsmasq moved to 5353)
- WireGuard VPN — kernel module + LuCI UI + QR code export
- DDNS — Cloudflare and No-IP scripts with LuCI management
- UPnP / NAT-PMP — miniupnpd-nftables, disabled by default, enable via LuCI
- Threat blocking — banip with LuCI management
- Traffic monitoring — nlbwmon per-device bandwidth tracking
- System statistics — collectd + LuCI graphs (CPU, memory, interface)
- Multi-WAN load balancing — mwan3 with LuCI management
- Wake-on-LAN
- Network diagnostics — mtr-json

---

## Shared Features

- Dual OpenWrt version support (24.10.6 LTS + 25.12.4 stable)
- Dual platform support (x86_64 + aarch64 ARM64)
- Modern firewall stack (nftables / fw4)
- Built and released automatically via GitHub Actions

---

## Firmware Matrix

| OpenWrt | Profile | Platform | rootfs | Package Manager | Status |
|---------|---------|----------|--------|-----------------|--------|
| 24.10.6 | Clean   | x86_64   | 768MB  | opkg            | LTS (EOL Sep 2026) |
| 24.10.6 | Clean   | aarch64  | 512MB  | opkg            | LTS (EOL Sep 2026) |
| 25.12.4 | Clean   | x86_64   | 768MB  | apk             | Current Stable |
| 25.12.4 | Clean   | aarch64  | 512MB  | apk             | Current Stable |
| 24.10.6 | Plus    | x86_64   | 1024MB | opkg            | LTS (EOL Sep 2026) |
| 24.10.6 | Plus    | aarch64  | 768MB  | opkg            | LTS (EOL Sep 2026) |
| 25.12.4 | Plus    | x86_64   | 1024MB | apk             | Current Stable |
| 25.12.4 | Plus    | aarch64  | 768MB  | apk             | Current Stable |

### Which profile should I choose?

**Clean** — If you want full control, plan to install only what you need, or are deploying in a server/VM environment where minimal footprint matters.

**Plus** — If you are migrating from pfSense/OPNsense or want a primary home router with DDNS, VPN, ad blocking, and traffic monitoring ready to configure out of the box.

### Which OpenWrt version should I choose?

**24.10.6** — If you have an existing opkg-based setup with many installed packages and want a stable, familiar upgrade path. Will receive security fixes until September 2026.

**25.12.4** — Recommended for new installations. Uses the new apk package manager (replaces opkg). Better performance, latest security patches, and long-term support.

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
| Modern x86 PC / VM (UEFI) — Clean | `*-clean-*-x86_64-squashfs-uefi.img.gz` |
| Modern x86 PC / VM (UEFI) — Plus  | `*-plus-*-x86_64-squashfs-uefi.img.gz` |
| Legacy x86 PC (BIOS) — Clean      | `*-clean-*-x86_64-squashfs-bios.img.gz` |
| Legacy x86 PC (BIOS) — Plus       | `*-plus-*-x86_64-squashfs-bios.img.gz` |
| ARM64 devices — Clean             | `*-clean-*-aarch64-squashfs-*.img.gz` |
| ARM64 devices — Plus              | `*-plus-*-aarch64-squashfs-*.img.gz` |

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

### Plus Edition — Additional Components

| Component | Package(s) | Notes |
|-----------|-----------|-------|
| AdGuard Home | adguardhome | DNS on port 53; dnsmasq on port 5353; management UI at port 3000; DoH upstreams via IP (1.1.1.1 / 8.8.8.8); default credentials admin/harrywrt |
| WireGuard VPN | kmod-wireguard, wireguard-tools, luci-app-wireguard, qrencode | QR code peer export supported |
| DDNS | ddns-scripts, luci-app-ddns, ddns-scripts-cloudflare, ddns-scripts-noip | Disabled by default |
| UPnP / NAT-PMP | miniupnpd-nftables, luci-app-upnp | Disabled by default; enable via LuCI |
| Threat blocking | banip, luci-app-banip | Disabled by default |
| Traffic monitoring | nlbwmon, luci-app-nlbwmon | |
| System statistics | collectd, luci-app-statistics | CPU, memory, interface graphs |
| Multi-WAN | mwan3, luci-app-mwan3 | |
| Wake-on-LAN | etherwake, luci-app-wol | |
| Network diagnostics | mtr-json | |

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

### AdGuard Home (Plus only)

AdGuard Home starts automatically on first boot and is accessible at http://192.168.1.1:3000

Default credentials:
- Username: `admin`
- Password: `harrywrt`

**Change your password after first login** via Settings → General Settings → Account.

The management UI is also accessible via Services → AdGuard Home in LuCI.

DNS filtering rules (AdGuard DNS filter, AdAway) are pre-loaded but disabled by default. Enable them in the AdGuard Home UI under Filters → DNS blocklists.

> If you change the AdGuard Home port, access it directly via the new port. The LuCI menu entry always points to port 3000.

---

## Installing Passwall2

All required dependencies (xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping, etc.) are already pre-installed in HarryWrt. You only need to install the Passwall2 LuCI app itself.

### On OpenWrt 24.10.6 (opkg)

1. Download `luci-app-passwall2_VERSION_all.ipk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.ipk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

### On OpenWrt 25.12.4 (apk)

1. Download `luci-app-passwall2_VERSION_all.apk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.apk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

> **Note:** HarryWrt 25.12.4 has been patched to allow local package uploads without signature errors. The install experience is identical to 24.10.6 — upload and install, no SSH or command line needed.

> **Important:** On 25.12.4, make sure to download the `.apk` format (not `.ipk`). The `.ipk` format is only compatible with 24.10.x.

---

## Customization

HarryWrt remains fully compatible with upstream OpenWrt. Install additional packages via LuCI (Web UI) or the command line (opkg on 24.10 / apk on 25.12).

### Enable Argon Theme

LuCI → System → System → Language and Style → Theme → Argon

---

## Integrity Verification

Each release includes SHA256 checksum files. Always verify downloaded images before use:

```sh
# Clean edition
sha256sum -c SHA256SUMS-24.10.6-clean-x86_64

# Plus edition
sha256sum -c SHA256SUMS-24.10.6-plus-x86_64
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
- AdGuard Home (AdguardTeam)

---

## Author

Maintained by: harryheros
---

Part of the [Nova infrastructure toolkit](https://github.com/harryheros).
