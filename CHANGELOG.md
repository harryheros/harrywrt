# HarryWrt Changelog

Releases, newest first. Each entry is also the release's notes: the release
workflow publishes the entry for the pushed tag. Versions up to 4.2 have two
parts (v4.2); from 4.2.1 on they have three (v4.2.1).

## 4.2.1 (2026-11-16)

Adds the tools for expanding the root partition on x86, and labels manual
builds with the latest release tag.

- x86_64 images include `resize2fs` and `losetup`, so the root partition can
  be expanded by following OpenWrt's guide (see the README).
- A manual build started without a version is labelled with the latest
  release tag instead of an old fixed default.
- The built-in helper for one third-party package repository is removed;
  repositories you add to `/etc/apk/repositories.d/customfeeds.list` are
  still kept across upgrades.
- A shorter README and release notes.

## 4.2 (2026-11-03)

Uploading a local package in LuCI keeps working after LuCI's package manager
itself is upgraded.

- The change that lets LuCI install uploaded `.apk` files is reapplied at
  every boot and after every package transaction; in 4.1, an upgrade of
  `luci-app-package-manager` undid it and uploads failed with
  `UNTRUSTED signature`.
- Still built on OpenWrt 25.12.6.

## 4.1 (2026-10-27)

Built on OpenWrt 25.12.6 only: OpenWrt 24.10 reached end of life and is no
longer built.

- OpenWrt 25.12.6, the latest security and bug-fix release.
- No more 24.10 builds: 24.10 reached end of life on 30 September 2026, and
  4.0.0 was its last HarryWrt release.
- One `SHA256SUMS` for every file, and each build's package manifest and
  build details in a single `…-buildinfo.tar.gz`.
- LuCI's package manager app (`luci-app-package-manager`) replaces the opkg
  app.

Action needed: when moving a 24.10-based install to this release, do not
keep settings.

## 4.0.0 (2026-09-25)

Adds images for NanoPi and Raspberry Pi boards, and the packages you install
yourself come back after a firmware upgrade.

- Images for NanoPi R2S, R4S, R5C, R5S, R6C and R6S and for Raspberry Pi 4
  and 5, next to x86_64 and the ARM64 VM image.
- Packages you installed are recorded and reinstalled automatically after a
  firmware upgrade.
- irqbalance and packet steering spread network load over all CPU cores; VM
  images include the QEMU guest agent; Plus enables TCP BBR.
- Built on OpenWrt 25.12.5 and 24.10.8, the last 24.10 release.
- The Argon theme is no longer included, and the automatic root-partition
  expansion, which never ran, is removed (on x86_64, `parted` and
  `e2fsprogs` remain for expanding by hand).

## 3.3.0 (2026-06-08)

Moves the 24.10 builds to OpenWrt 24.10.7, and the Clean edition no longer
bundles the network cores.

- Built on OpenWrt 24.10.7 and 25.12.4.
- Clean is a minimal base without the network cores and geo data; Plus
  keeps them, so the LuCI apps that use them install offline.

Action needed: if you use a LuCI app that needs the network cores, use the
Plus edition, or install them yourself on Clean.

## 3.2 (2026-05-26)

Makes the network health checks more accurate, and rejects malformed release
tags.

- IPv6 shows "Not configured" instead of "Offline" on IPv4-only networks.
- The DNS check reports a failure when the router's own resolver fails but a
  public resolver answers (a broken or hijacked resolver).
- A malformed release tag stops the build instead of producing firmware
  labelled v1.0.
- Still built on OpenWrt 24.10.6 and 25.12.4.

## 3.1 (2026-05-20)

Adds a network health page and ACME certificates, and changes the default
timezone to UTC.

- Status → Network Health checks WAN, DNS and IPv6 every 5 minutes, on both
  editions.
- Plus adds ACME / Let's Encrypt certificates; x86_64 images include
  `parted` and `e2fsprogs`.
- The default timezone is UTC (was Asia/Hong_Kong).
- The LICENSE file now holds the GPL-2.0 text, matching the stated license
  (it held GPL-3.0).

## 3.0 (2026-05-18)

Introduces the Plus edition, next to Clean.

- Plus adds WireGuard (with QR codes), DDNS (Cloudflare, No-IP), UPnP /
  NAT-PMP (off by default), traffic monitoring (nlbwmon) and Wake-on-LAN.
- The 25.12 builds move to OpenWrt 25.12.4 (24.10.6 continues).
- `nano` is included.

## 2.0 (2026-04-03)

Adds builds on OpenWrt 25.12 (apk) next to 24.10, and an ARM64 image.

- Built on OpenWrt 24.10.6 (opkg) and 25.12.2 (apk).
- A generic ARM64 (aarch64) UEFI image next to x86_64.
- On 25.12, LuCI installs uploaded `.apk` files, which are not signed by an
  OpenWrt key; missing dependencies come from the official feeds.
- When `downloads.openwrt.org` is unreachable, packages come from the TUNA
  mirror.
- The root partition is 768 MB on x86_64 and 512 MB on aarch64 (was 1 GB).

## 1.1 (2026-03-06)

Adds IPv6 and LuCI apps for the firewall, packages and a web terminal.

- IPv6 support (odhcp6c, odhcpd).
- LuCI apps for the firewall, the package manager and the web terminal
  (ttyd).
- Still built on OpenWrt 24.10.5.

## 1.0 (2026-02-16)

First release: a clean OpenWrt 24.10.5 build for x86_64 PCs and virtual
machines.

- Images for BIOS and UEFI, in squashfs and ext4.
- LuCI over HTTPS with the official Bootstrap theme (Argon included), plus
  everyday tools such as bash, curl, htop, tcpdump and iperf3.
- dnsmasq-full and the nftables firewall (fw4), and a 1 GB root partition for
  the packages you add.
- Defaults: 192.168.1.1, hostname HarryWrt, timezone Asia/Hong_Kong.
