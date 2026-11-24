# HarryWrt

> OpenWrt-based firmware in two editions: stable and predictable, with no bloat, no lock-in and no telemetry.

[![Version](https://img.shields.io/badge/version-v4.2.1-blue.svg)](https://github.com/harryheros/harrywrt/releases)
[![Base](https://img.shields.io/badge/base-OpenWrt%2025.12.6-green.svg)](#downloads)
[![License](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](#license)
[![Platform](https://img.shields.io/badge/platform-x86__64%20%7C%20NanoPi%20%7C%20Raspberry%20Pi%20%7C%20ARM64%20VM-orange.svg)](#downloads)

[Editions](#editions) · [Downloads](#downloads) · [First boot](#first-boot) · [Upgrading](#upgrading) · [Installing packages](#installing-packages) · [Changelog](./CHANGELOG.md) · [License](#license)

Fully compatible with upstream OpenWrt packages: everything in the official feeds installs as usual.

## Editions

**Clean** is for full control, servers and VMs. **Plus** is for a primary home router, ready out of the box.

| | Clean | Plus |
|---|:---:|:---:|
| LuCI (HTTPS), web terminal, IPv6 | ✓ | ✓ |
| dnsmasq-full, nftables with TProxy / TUN | ✓ | ✓ |
| Network health page, multi-core tuning | ✓ | ✓ |
| WireGuard, DDNS, ACME | — | ✓ |
| UPnP (off by default), Wake-on-LAN | — | ✓ |
| Traffic monitoring, TCP BBR | — | ✓ |
| Network cores: xray-core, sing-box, geo data | — | ✓ |
| Root partition | 768 MB | 1024 MB |

With the network cores in Plus, the LuCI apps that use them install offline.

Both editions reinstall the packages you added yourself after a firmware upgrade.

## Downloads

Images are on the [Releases page](https://github.com/harryheros/harrywrt/releases), built on OpenWrt **25.12.6** (apk package manager). Pick `clean` or `plus` in the file name, then the file for your hardware:

- **PC, mini PC or soft router (UEFI)**: `*-x86_64-squashfs-uefi.img.gz`
- **Old PC (legacy BIOS)**: `*-x86_64-squashfs-bios.img.gz`
- **Proxmox, ESXi or QEMU VM**: `*-x86_64-ext4-uefi.img.gz`
- **NanoPi R2S, R4S, R5C, R5S, R6C, R6S**: `*-rockchip-friendlyarm_nanopi-<model>-squashfs-sysupgrade.img.gz`
- **Raspberry Pi 4, 400, CM4**: `*-rpi4-rpi-4-squashfs-factory.img.gz`
- **Raspberry Pi 5**: `*-rpi5-rpi-5-squashfs-factory.img.gz`
- **ARM64 VM or UEFI server**: `*-aarch64-squashfs-combined-efi.img.gz`

Notes:

- **squashfs** is recommended (supports reset to defaults); **ext4** is fully writable.
- NanoPi and Raspberry Pi: write the image to a microSD card (e.g. balenaEtcher). Raspberry Pi upgrades use the `sysupgrade` file.
- The `aarch64` image is for virtual machines only; it does not boot on NanoPi or Raspberry Pi.
- x86 images have a fixed root partition; to expand it, follow OpenWrt's guide on expanding the root partition on x86. `parted` is included; on v4.2 and earlier, add the other tools with `apk add resize2fs losetup`. In Proxmox / QEMU, enable the QEMU Guest Agent option.
- A board missing from a release is not supported by that OpenWrt version.
- OpenWrt 24.10 is end of life and no longer built; HarryWrt v4.0 was its last release.

What changed in each release: [CHANGELOG.md](./CHANGELOG.md).

**Verify** a download: put `SHA256SUMS` next to the image and run `sha256sum -c --ignore-missing SHA256SUMS` (macOS: `shasum -a 256 -c --ignore-missing SHA256SUMS`). Each build's `…-buildinfo.tar.gz` lists every package and the exact sources used; it is not needed to install.

## First boot

Connect to LAN (DHCP is on) and open **https://192.168.1.1**. Log in as `root`, set a password first. A browser certificate warning is expected (self-signed).

Defaults: hostname `HarryWrt`, timezone UTC, NTP on. The network health page is under Status → Network Health.

## Upgrading

LuCI → System → Backup / Flash Firmware → upload the new `.img.gz`.

- **Same OpenWrt version**: keep settings.
- **From a 24.10-based build**: do not keep settings.

**Your packages come back.** Packages you installed yourself are listed in `/etc/harrywrt/user-packages.list`, kept across upgrades, and reinstalled in the background on first boot (log: `/etc/harrywrt/restore.log`). A package not in the feeds, such as an uploaded file, is retried at every boot; run `harrywrt-pkg-restore` to retry now, or delete `/etc/harrywrt/pending-packages.list` to stop. When moving from 24.10, back up `user-packages.list` and copy it back before the first reboot.

## Installing packages

Install anything from LuCI (System → Software) or with `apk`. If `downloads.openwrt.org` is unreachable, HarryWrt switches to the TUNA mirror automatically and switches back when it recovers (`harrywrt-mirror-check` runs it by hand).

### Third-party packages

Packages that are not in the official feeds can be uploaded under System → Software → Upload Package (use `.apk`, not `.ipk`); HarryWrt allows unsigned uploads, and missing dependencies come from the official feeds. Command line: `apk add --allow-untrusted ./PACKAGE.apk`. A repository you add to `/etc/apk/repositories.d/customfeeds.list` is kept across firmware upgrades.

### AdGuard Home

AdGuard Home needs port 53, so move dnsmasq to 5353 first:

```sh
apk update && apk add adguardhome
uci set dhcp.@dnsmasq[0].port='5353' && uci commit dhcp && /etc/init.d/dnsmasq restart
/etc/init.d/adguardhome enable && /etc/init.d/adguardhome start
```

Then finish setup at `http://192.168.1.1:3000`. To undo, stop and disable `adguardhome`, then:

```sh
uci delete dhcp.@dnsmasq[0].port && uci commit dhcp && /etc/init.d/dnsmasq restart
```

## Included packages

**Both editions**: LuCI (HTTPS), luci-compat, Bootstrap theme, ttyd, bash, nano, curl, wget-ssl, unzip, htop, openssl-util, ca-bundle, ip-full, iperf3, tcpdump, ethtool, resolveip, dnsmasq-full, nftables (fw4) with kmod-tun, TProxy, socket and NAT modules, irqbalance.

**Plus adds**: WireGuard (with QR export), DDNS (Cloudflare, No-IP), ACME / Let's Encrypt, miniupnpd, nlbwmon, Wake-on-LAN, mtr, TCP BBR, iptables-nft compatibility with TProxy modules, xray-core, sing-box, chinadns-ng, geoview, v2ray-geoip, v2ray-geosite, tcping.

## License

[GPL-2.0](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html), following the OpenWrt licensing model. Provided as-is, without warranty; no telemetry, hidden services or proprietary components.

Credits: OpenWrt, LuCI, the Openwrt-Passwall package feed (network cores), AdGuard Home (AdGuard).

Part of the [Nova infrastructure toolkit](https://github.com/harryheros).
