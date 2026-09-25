# HarryWrt — OpenWrt-Based Firmware

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/platform-x86__64%20%7C%20NanoPi%20%7C%20Raspberry%20Pi%20%7C%20ARM64%20VM-orange.svg)](#)
[![Base](https://img.shields.io/badge/base-OpenWrt%2024.10.8%20%7C%2025.12.5-green.svg)](#)

HarryWrt is a stable, extensible OpenWrt-based firmware available in two profiles: **Clean** for minimalism and upstream compatibility, and **Plus** for users who want a full-featured primary router experience out of the box.

No bloat, no lock-in, no surprises — just a predictable and maintainable OpenWrt experience.

---

## Profiles

### Clean Edition
Minimal base system for users who want full control over what runs on their router.

- Clean base system — no unnecessary modifications
- Fully compatible with upstream OpenWrt packages
- No bundled proxy engines — a truly minimal base; add what you need yourself
- Built-in WAN/DNS/IPv6 health check dashboard
- Packages you install are reinstalled automatically after a firmware upgrade
- Multi-core tuning out of the box (irqbalance + packet steering)

### Plus Edition
Stable enhanced firmware. Everything in Clean, plus:

- WireGuard VPN, DDNS, UPnP / NAT-PMP, traffic monitoring (nlbwmon), Wake-on-LAN, network diagnostics
- ACME / Let's Encrypt certificate management
- Bundled proxy engines (xray-core, sing-box) and geo data, offline-ready for users who install a proxy LuCI app
- TCP BBR congestion control for the router's own connections (faster proxy upstream)
- UPnP disabled by default; all other components ready to configure on first boot
- See [Included Components](#included-components) for full package list


---

## Firmware Matrix

Every platform is built for both editions and both OpenWrt versions.

| Platform | Hardware | Images |
|----------|----------|--------|
| `x86_64` | PCs, mini PCs, soft routers, Proxmox/ESXi/QEMU VMs | squashfs / ext4 × BIOS / UEFI |
| `rockchip` | FriendlyElec NanoPi R2S, R4S, R5C, R5S, R6C, R6S | one image per board (microSD) |
| `rpi4` | Raspberry Pi 4 Model B / 400 / CM4 | factory (microSD) + sysupgrade |
| `rpi5` | Raspberry Pi 5 | factory (microSD) + sysupgrade |
| `aarch64` | ARM64 **virtual machines** / UEFI servers (Proxmox ARM, UTM, cloud) | combined EFI |

| OpenWrt | Package manager | Status |
|---------|-----------------|--------|
| 25.12.5 | apk  | **Current stable — recommended** |
| 24.10.8 | opkg | Final release (24.10 reached end of life in Sep 2026) |

Root partition: 768 MB (Clean) / 1024 MB (Plus).

> Board support comes from upstream OpenWrt. If a board is not yet supported by one OpenWrt release, that release simply has no image for it — the build log and the release list show exactly which boards were built.

### Which profile should I choose?

**Clean** — If you want full control, plan to install only what you need, or are deploying in a server/VM environment where minimal footprint matters.

**Plus** — If you want a primary home router with WireGuard VPN, DDNS, UPnP, and traffic monitoring ready to configure out of the box.

### Which OpenWrt version should I choose?

**24.10.8** — Final release of the 24.10 series, which reached end of life in September 2026 and will get no further security fixes. Only for existing opkg-based setups that cannot move yet; plan your migration to 25.12.

**25.12.5** — Recommended for new installations. Uses the new apk package manager (replaces opkg). Better performance and latest security patches.

### Which platform?

**x86_64** — Soft routers, PCs, virtual machines (Proxmox/ESXi/QEMU), industrial mini-PCs. The images use a fixed-size root partition; to use the rest of a larger disk, expand it manually (`parted` and `resize2fs` are pre-installed — see the official OpenWrt guide on expanding the root partition on x86). In Proxmox/QEMU, enable the QEMU Guest Agent option — HarryWrt includes the agent and turns it on automatically inside VMs.

**rockchip** — FriendlyElec NanoPi boards (R2S, R4S, R5C, R5S, R6C, R6S). Download the file with your board's name and write it to a microSD card (e.g. with balenaEtcher or Raspberry Pi Imager). All of these boards are 64-bit, including the R2S.

**rpi4 / rpi5** — Raspberry Pi 4 (incl. 400 / CM4) and Raspberry Pi 5. Use the `factory` image for a fresh microSD card and the `sysupgrade` image to upgrade a Pi that already runs OpenWrt/HarryWrt.

**aarch64 (armsr/armv8)** — Generic ARM64 UEFI image for **virtual machines** and UEFI servers only. It does **not** boot on NanoPi or Raspberry Pi boards (they have no UEFI firmware) — use the board images above.

---

## Downloads

Firmware images are available on the GitHub Releases page:

https://github.com/harryheros/harrywrt/releases

Each release includes BIOS and UEFI images (x86_64), squashfs and ext4 variants, and SHA256 checksum files.

### Which file do I need?

| Your hardware | File |
|----------|------|
| PC / mini PC / soft router (UEFI) | `*-x86_64-squashfs-uefi.img.gz` |
| Old PC (legacy BIOS) | `*-x86_64-squashfs-bios.img.gz` |
| Proxmox / ESXi / QEMU VM | `*-x86_64-ext4-uefi.img.gz` |
| NanoPi (R2S … R6S) | `*-rockchip-friendlyarm_nanopi-<model>-squashfs-sysupgrade.img.gz` |
| Raspberry Pi 4 | `*-rpi4-rpi-4-squashfs-factory.img.gz` |
| Raspberry Pi 5 | `*-rpi5-rpi-5-squashfs-factory.img.gz` |
| ARM64 VM | `*-aarch64-squashfs-combined-efi.img.gz` |

Pick `clean` or `plus` in the file name for the edition. **squashfs** is recommended (supports reset to defaults); **ext4** is fully writable.

---

## Included Components

### Web Interface
LuCI (HTTPS), luci-compat, ttyd (Web Terminal)

### Network Health
Built-in WAN/DNS/IPv6 health check dashboard (Status → Network Health). Results are cached for 5 minutes; use **Refresh Now** to re-check. Available on all profiles and only to logged-in LuCI users.

### Theme
Bootstrap (official OpenWrt theme)

### System Tools
bash, curl, wget-ssl, unzip, htop, openssl-util, ca-bundle

### Network Utilities
ip-full, iperf3, tcpdump, ethtool, resolveip

### Firewall / Kernel
nftables (fw4), kmod-tun, nft TProxy, nft-socket, nft-nat. Plus additionally includes the iptables-nft compatibility layer and ipt TProxy modules (Passwall2 iptables fallback mode).

### Performance
irqbalance and packet steering are enabled on first boot, spreading network load across all CPU cores.

### Proxy Engines (Plus edition only)
The **Plus** edition bundles, offline-ready: xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping and their runtime libs. The **Clean** edition does not include these — install them yourself if needed. On either edition, a proxy LuCI app (if desired) is installed separately after first boot.

### Plus Edition — Additional Components

| Component | Package(s) | Notes |
|-----------|-----------|-------|
| WireGuard VPN | kmod-wireguard, wireguard-tools, luci-app-wireguard, qrencode | QR code peer export supported |
| DDNS | ddns-scripts, luci-app-ddns, ddns-scripts-cloudflare, ddns-scripts-noip | Requires configuration to activate |
| UPnP / NAT-PMP | miniupnpd-nftables, luci-app-upnp | Disabled by default; enable in LuCI → Services → UPnP |
| TCP BBR | kmod-tcp-bbr | Enabled by default for the router's own connections |
| Traffic monitoring | nlbwmon, luci-app-nlbwmon | Per-device bandwidth tracking |
| Wake-on-LAN | etherwake, luci-app-wol | |
| Network diagnostics | mtr-json | |
| ACME / Let's Encrypt | acme, luci-app-acme | Certificate management for HTTPS services |

---

## Default Settings

- Hostname: HarryWrt
- Timezone: UTC
- LAN IP: 192.168.1.1
- User: root
- Password: unset on first boot
- NTP: enabled (0-3.openwrt.pool.ntp.org)

---

## First Access

After boot, connect via LAN (DHCP enabled) and open https://192.168.1.1

Set a password on first login before further configuration.

> Browser SSL warnings are expected (self-signed certificate).


---

## Upgrading

1. Download the new `.img.gz` from the [Releases page](https://github.com/harryheros/harrywrt/releases)
2. LuCI → System → Backup / Flash Firmware → Flash new firmware
3. Upload the `.img.gz` file
4. Choose whether to keep settings:
   - **Same OpenWrt version** (e.g. HarryWrt v3.0 → v3.1) — keeping settings is safe
   - **Different OpenWrt version** (e.g. 24.10 → 25.12) — do not keep settings; config format may have changed
5. Wait for reboot

### Your packages come back automatically

HarryWrt remembers the packages you installed yourself (AdGuard Home, Passwall2, …) in `/etc/harrywrt/user-packages.list`, which is kept across firmware upgrades. On the first boot of the new firmware, once the network is up, they are reinstalled from the package feeds in the background. Keep settings when flashing so the list is preserved.

- Progress and results: `/etc/harrywrt/restore.log` (also in the system log, tag `harrywrt`).
- A package that is not available in the configured feeds (e.g. Passwall2 installed from an uploaded file) is retried at every boot until it succeeds. Enable the Passwall2 repository (below) and run `harrywrt-pkg-restore` to reinstall it right away, or delete `/etc/harrywrt/pending-packages.list` to stop retrying.
- 24.10 → 25.12 upgrades work too (package names are the same); since settings should not be kept across that jump, back up `/etc/harrywrt/user-packages.list` yourself and copy it back before the first reboot if you want the automatic reinstall.

---

## Installing a Proxy LuCI App

On the **Plus** edition, the required dependencies (xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping, etc.) are already pre-installed, so you only need to install the LuCI app itself. On the **Clean** edition, install those dependencies yourself first (or use the Plus edition).

### On OpenWrt 25.12.5 — recommended: signed Passwall2 repository

One command adds the official Passwall2 package repository and its signing key, so Passwall2 installs **and updates** through the normal package manager with signature verification:

```sh
harrywrt-passwall-repo enable
apk add luci-app-passwall2
```

`harrywrt-passwall-repo status` shows the configured feeds; `harrywrt-passwall-repo disable` removes them.

### On OpenWrt 24.10.8 (opkg)

1. Download `luci-app-passwall2_VERSION_all.ipk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.ipk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

### On OpenWrt 25.12.5 — alternative: upload the package file

1. Download `luci-app-passwall2_VERSION_all.apk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.apk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

> **Note:** HarryWrt 25.12.5 lets LuCI install uploaded `.apk` files (which are not signed by an OpenWrt key). Missing dependencies are fetched from the official feeds when the router is online.

> **Important:** On 25.12.5, make sure to download the `.apk` format (not `.ipk`). The `.ipk` format is only compatible with 24.10.x.

### Mirror auto-detection

HarryWrt includes a built-in mirror auto-detection helper (`harrywrt-mirror-check`). On first boot, and on every package list update on 25.12.5, HarryWrt tests connectivity to `downloads.openwrt.org`. If the official server is unreachable, it automatically switches the repository configuration to the TUNA mirror (`mirrors.tuna.tsinghua.edu.cn/openwrt`) and restores the official server when it becomes reachable again.

This runs transparently; no manual configuration is needed.

If you need to switch or restore manually:

```sh
# Let the helper auto-detect and set the correct source (both versions)
/usr/bin/harrywrt-mirror-check

# Switch to TUNA mirror manually — OpenWrt 25.12 (apk)
sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_g' /etc/apk/repositories.d/distfeeds.list

# Restore official source — OpenWrt 25.12 (apk)
sed -i 's_mirrors.tuna.tsinghua.edu.cn/openwrt_downloads.openwrt.org_g' /etc/apk/repositories.d/distfeeds.list

# Switch to TUNA mirror manually — OpenWrt 24.10 (opkg)
sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_g' /etc/opkg/distfeeds.conf

# Restore official source — OpenWrt 24.10 (opkg)
sed -i 's_mirrors.tuna.tsinghua.edu.cn/openwrt_downloads.openwrt.org_g' /etc/opkg/distfeeds.conf
```

---

## Installing AdGuard Home

AdGuard Home is not pre-installed in HarryWrt. Install it directly from the package repository when needed.

### On OpenWrt 25.12.5 (apk)

```sh
apk update && apk add adguardhome
```

### On OpenWrt 24.10.8 (opkg)

```sh
opkg update && opkg install adguardhome
```

### After installation

AdGuard Home and dnsmasq both try to bind port 53. You need to move dnsmasq off port 53 before starting AdGuard Home, or they will conflict:

```sh
# Move dnsmasq to port 5353 (keeps DHCP and local DNS working)
uci set dhcp.@dnsmasq[0].port='5353'
uci commit dhcp
/etc/init.d/dnsmasq restart

# Start AdGuard Home
/etc/init.d/adguardhome enable
/etc/init.d/adguardhome start
```

Then open `http://192.168.1.1:3000` to complete the AdGuard Home setup wizard.

> If something goes wrong, restore dnsmasq to port 53 with:
> ```sh
> uci delete dhcp.@dnsmasq[0].port
> uci commit dhcp
> /etc/init.d/dnsmasq restart
> /etc/init.d/adguardhome stop
> /etc/init.d/adguardhome disable
> ```

---

## Customization

HarryWrt remains fully compatible with upstream OpenWrt. Install additional packages via LuCI (Web UI) or the command line (opkg on 24.10 / apk on 25.12).

---

## Integrity Verification

Each release includes SHA256 checksum files. Download the checksum file and the `.img.gz` into the same directory, then verify:

```sh
# Example: 25.12.5 Plus x86_64
cd ~/Downloads
sha256sum -c SHA256SUMS-25.12.5-plus-x86_64

# Other variants follow the same pattern
sha256sum -c SHA256SUMS-24.10.8-clean-x86_64
sha256sum -c SHA256SUMS-24.10.8-plus-x86_64
sha256sum -c SHA256SUMS-25.12.5-clean-x86_64
```

Each build also ships a `*.manifest` (every package and version in the image) and `*-feeds.buildinfo` / `*-version.buildinfo` / `*-config.buildinfo` (the exact feed commits, OpenWrt revision and configuration used), so any image can be audited or rebuilt.

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
- Passwall2 (Openwrt-Passwall Organization)
- AdGuard Home (AdGuard)

---

## Author

Maintained by: harryheros

---

Part of the [Nova infrastructure toolkit](https://github.com/harryheros).