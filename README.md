# HarryWrt — OpenWrt-Based Firmware

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/platform-x86__64%20%7C%20NanoPi%20%7C%20Raspberry%20Pi%20%7C%20ARM64%20VM-orange.svg)](#)
[![Base](https://img.shields.io/badge/base-OpenWrt%2025.12.6-green.svg)](#)

A stable, predictable OpenWrt firmware in two editions. No bloat, no lock-in, no telemetry — fully compatible with upstream OpenWrt packages.

---

## Editions

| | **Clean** | **Plus** |
|---|---|---|
| For | Full control, servers and VMs | A primary home router, ready out of the box |
| Base | LuCI (HTTPS), web terminal, dnsmasq-full, nftables with TProxy / TUN, IPv6 | Everything in Clean |
| Extras | Network health page, multi-core tuning | WireGuard, DDNS, ACME, UPnP (off by default), traffic monitoring, Wake-on-LAN, TCP BBR |
| Proxy engines | Not included | xray-core, sing-box, chinadns-ng and geo data, offline-ready |
| Root partition | 768 MB | 1024 MB |

Both editions reinstall the packages you added yourself after a firmware upgrade.

---

## Downloads

Images are on the [Releases page](https://github.com/harryheros/harrywrt/releases), built on OpenWrt **25.12.6** (apk package manager). Pick `clean` or `plus` in the file name.

| Hardware | File |
|---|---|
| PC / mini PC / soft router (UEFI) | `*-x86_64-squashfs-uefi.img.gz` |
| Old PC (legacy BIOS) | `*-x86_64-squashfs-bios.img.gz` |
| Proxmox / ESXi / QEMU VM | `*-x86_64-ext4-uefi.img.gz` |
| NanoPi R2S / R4S / R5C / R5S / R6C / R6S | `*-rockchip-friendlyarm_nanopi-<model>-squashfs-sysupgrade.img.gz` |
| Raspberry Pi 4 / 400 / CM4 | `*-rpi4-rpi-4-squashfs-factory.img.gz` |
| Raspberry Pi 5 | `*-rpi5-rpi-5-squashfs-factory.img.gz` |
| ARM64 VM / UEFI server | `*-aarch64-squashfs-combined-efi.img.gz` |

- **squashfs** is recommended (supports reset to defaults); **ext4** is fully writable.
- NanoPi and Raspberry Pi: write the image to a microSD card (e.g. balenaEtcher). Raspberry Pi upgrades use the `sysupgrade` file.
- The `aarch64` image is for virtual machines only; it does not boot on NanoPi or Raspberry Pi.
- x86 images have a fixed root partition; to expand it, follow OpenWrt's guide on expanding the root partition on x86. `parted` is included; on v4.2 and earlier, add the other tools with `apk add resize2fs losetup`. In Proxmox / QEMU, enable the QEMU Guest Agent option.
- A board missing from a release is not supported by that OpenWrt version.
- OpenWrt 24.10 is end of life and no longer built; HarryWrt v4.0 was its last release.

**Verify** a download: put `SHA256SUMS` next to the image and run `sha256sum -c --ignore-missing SHA256SUMS` (macOS: `shasum -a 256 -c --ignore-missing SHA256SUMS`). Each build's `…-buildinfo.tar.gz` lists every package and the exact sources used; it is not needed to install.

---

## First boot

Connect to LAN (DHCP is on) and open **https://192.168.1.1**. Log in as `root`, set a password first. A browser certificate warning is expected (self-signed).

Defaults: hostname `HarryWrt`, timezone UTC, NTP on. The network health page is under Status → Network Health.

---

## Upgrading

LuCI → System → Backup / Flash Firmware → upload the new `.img.gz`.

- **Same OpenWrt version**: keep settings.
- **From a 24.10-based build**: do not keep settings.

**Your packages come back.** Packages you installed yourself are listed in `/etc/harrywrt/user-packages.list`, kept across upgrades, and reinstalled in the background on first boot (log: `/etc/harrywrt/restore.log`). A package not in the feeds, such as an uploaded file, is retried at every boot; run `harrywrt-pkg-restore` to retry now, or delete `/etc/harrywrt/pending-packages.list` to stop. When moving from 24.10, back up `user-packages.list` and copy it back before the first reboot.

---

## Installing packages

Install anything from LuCI (System → Software) or with `apk`. If `downloads.openwrt.org` is unreachable, HarryWrt switches to the TUNA mirror automatically and switches back when it recovers (`harrywrt-mirror-check` runs it by hand).

### Passwall2

The Plus edition already has the proxy engines; on Clean, install them first.

**Recommended — signed repository** (installs and updates through the package manager):

```sh
harrywrt-passwall-repo enable      # also: status, disable
apk add luci-app-passwall2
```

Updates then appear under System → Software → Updates. Passwall2's own App Update page updates the proxy cores only, not Passwall2 itself.

**Or upload the file**: download `luci-app-passwall2_VERSION_all.apk` (not `.ipk`) from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases), then System → Software → Upload Package. HarryWrt allows unsigned uploads; missing dependencies come from the official feeds. Command line: `apk add --allow-untrusted ./luci-app-passwall2_VERSION_all.apk`.

### AdGuard Home

AdGuard Home needs port 53, so move dnsmasq to 5353 first:

```sh
apk update && apk add adguardhome
uci set dhcp.@dnsmasq[0].port='5353' && uci commit dhcp && /etc/init.d/dnsmasq restart
/etc/init.d/adguardhome enable && /etc/init.d/adguardhome start
```

Then finish setup at `http://192.168.1.1:3000`. To undo: `uci delete dhcp.@dnsmasq[0].port && uci commit dhcp && /etc/init.d/dnsmasq restart`, then stop and disable `adguardhome`.

---

## Included packages

**Both editions**: LuCI (HTTPS), luci-compat, Bootstrap theme, ttyd, bash, nano, curl, wget-ssl, unzip, htop, openssl-util, ca-bundle, ip-full, iperf3, tcpdump, ethtool, resolveip, dnsmasq-full, nftables (fw4) with kmod-tun, TProxy, socket and NAT modules, irqbalance.

**Plus adds**: WireGuard (with QR export), DDNS (Cloudflare, No-IP), ACME / Let's Encrypt, miniupnpd, nlbwmon, Wake-on-LAN, mtr, TCP BBR, iptables-nft compatibility with TProxy modules, xray-core, sing-box, chinadns-ng, geoview, v2ray-geoip, v2ray-geosite, tcping.

---

## License

GPL-2.0, following the OpenWrt licensing model. Provided as-is, without warranty; no telemetry, hidden services or proprietary components.

Credits: OpenWrt, LuCI, Passwall2 (Openwrt-Passwall), AdGuard Home (AdGuard).

Part of the [Nova infrastructure toolkit](https://github.com/harryheros).
