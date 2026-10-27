#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# HarryWrt DIY Script (Multi-version / Multi-platform / Multi-profile)
#
# Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE] [REL]
#   TARGET: x86_64 | aarch64 | rockchip | rpi4 | rpi5
#   e.g. diy.sh 25.12.6 x86_64 clean v4.1
#        diy.sh 25.12.6 rockchip plus v4.1
#   OpenWrt 25.12 or newer (apk). 24.10 (opkg) reached end of life on
#   2026-09-30 and is no longer supported; v4.0 was its last release.
#
# - Branding (banner / motd / DISTRIB_DESCRIPTION via base-files template)
# - LuCI theme: Bootstrap (falls back to it if a kept theme is missing)
# - Go toolchain GOTOOLCHAIN=auto patch (for geoview)
# - First boot: musl loader symlink fix (arch-aware)
# - First boot: clean the build-time passwall_packages feed (distfeeds only)
# - First boot: LuCI package-manager shim (local .apk + mirror auto-detect)
# - Network health page (LuCI, rpcd ACL)
# - irqbalance + packet steering; qemu-ga only inside VMs
# - Reinstall user packages after firmware upgrades
# - harrywrt-passwall-repo: signed Passwall2 apk repository
# - [plus only] UPnP disabled by default, TCP BBR
# =============================================================

HARRYWRT_VER="${1:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE] [REL]}"
TARGET="${2:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE] [REL]}"
PROFILE="${3:-clean}"
HARRYWRT_REL="${4:-}"

# Guard: must be run from inside the openwrt source directory
if [[ ! -f "Makefile" ]] || ! grep -q "TOPDIR:=" Makefile 2>/dev/null; then
  echo "ERROR: diy.sh must be run from within the openwrt source directory (current: $PWD)" >&2
  exit 1
fi

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"
mkdir -p "${FILES_DIR}/usr/libexec"

echo "============================================================"
echo " HarryWrt DIY: OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}"
echo "============================================================"

# Derive human-readable edition label
case "${PROFILE}" in
  plus)  EDITION="Plus" ;;
  *)     EDITION="Clean" ;;
esac

# ------------------------------------------------------------
# 0a) Version guard: everything below assumes apk (OpenWrt 25.12+).
# ------------------------------------------------------------
OWRT_MAJOR="${HARRYWRT_VER%%.*}"
if ! [[ "$OWRT_MAJOR" =~ ^[0-9]+$ ]] || (( OWRT_MAJOR < 25 )); then
  echo "ERROR: OpenWrt ${HARRYWRT_VER} is not supported (25.12 or newer required;" >&2
  echo "       24.10 reached end of life on 2026-09-30, HarryWrt v4.0 was its last release)" >&2
  exit 1
fi

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy for geoview
#    GOTOOLCHAIN=local → auto (allows downloading newer Go)
# ------------------------------------------------------------
echo "[patch] Patching GOTOOLCHAIN=local -> auto in golang framework ..."

GOLANG_FRAMEWORK_FILES=(
  "feeds/packages/lang/golang/golang-package.mk"
  "feeds/packages/lang/golang/golang-build.sh"
)

for f in "${GOLANG_FRAMEWORK_FILES[@]}"; do
  if [ -f "$f" ]; then
    if grep -qE '\bGOTOOLCHAIN=local\b' "$f"; then
      sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$f"
      echo "[patch] Framework patched: $f"
    else
      echo "[patch] No GOTOOLCHAIN=local in: $f (already auto or not set)"
    fi
  else
    echo "[patch] WARNING: framework file not found: $f" >&2
  fi
done

# Scan all .mk/.sh under golang lang dir
while IFS= read -r -d '' f; do
  if grep -qE '\bGOTOOLCHAIN=local\b' "$f"; then
    sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$f"
    echo "[patch] Additional file patched: $f"
  fi
done < <(find feeds/packages/lang/golang -type f \( -name "*.mk" -o -name "*.sh" \) -print0 2>/dev/null)

# Double-insurance: inject into geoview Makefile
GEOVIEW_MK_CANDIDATES=(
  "feeds/passwall_packages/geoview/Makefile"
  "feeds/packages/net/geoview/Makefile"
)
for mk in "${GEOVIEW_MK_CANDIDATES[@]}"; do
  if [ -f "$mk" ]; then
    echo "[patch] Found geoview Makefile: $mk"
    if ! grep -qE '\bGOTOOLCHAIN\b' "$mk"; then
      sed -i '/^include.*golang-package/i export GOTOOLCHAIN=auto' "$mk"
      echo "[patch] Injected GOTOOLCHAIN=auto into: $mk"
    else
      sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$mk"
      echo "[patch] Updated GOTOOLCHAIN in: $mk"
    fi
  fi
done

# Sanity check (warn only)
remaining=$(grep -RInE '\bGOTOOLCHAIN=local\b' feeds/packages/lang/golang 2>/dev/null || true)
if [[ -n "$remaining" ]]; then
  echo "[patch] WARNING: GOTOOLCHAIN=local still found:" >&2
  echo "$remaining" | head -n 10 >&2
else
  echo "[patch] Confirmed: no GOTOOLCHAIN=local remaining."
fi

# ------------------------------------------------------------
# 1) System defaults (hostname, timezone, NTP)
#    Note: cronloglevel=7 is required for 25.12+
# ------------------------------------------------------------
CRONLOGLEVEL=7

cat > "${FILES_DIR}/etc/config/system" <<EOF
config system
  option hostname 'HarryWrt'
  option timezone 'UTC'
  option zonename 'UTC'
  option ttylogin '0'
  option log_proto 'stderr'
  option conloglevel '8'
  option cronloglevel '${CRONLOGLEVEL}'

config timeserver 'ntp'
  option enabled '1'
  option enable_server '0'
  list server '0.openwrt.pool.ntp.org'
  list server '1.openwrt.pool.ntp.org'
  list server '2.openwrt.pool.ntp.org'
  list server '3.openwrt.pool.ntp.org'
EOF

# ------------------------------------------------------------
# 2) SSH login banner
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then
  PLUS_BANNER_LINE=" Plus extras: UPnP available, disabled by default"
else
  PLUS_BANNER_LINE=""
fi

BANNER_VER="${HARRYWRT_REL:-${HARRYWRT_VER}}"
cat > "${FILES_DIR}/etc/banner" <<EOF
---------------------------------------------------------------
 _   _                          __        __     _
| | | | __ _ _ __ _ __ _   _   \ \      / /_ __| |_
| |_| |/ _\` | '__| '__| | | |   \ \ /\ / / '__| __|
|  _  | (_| | |  | |  | |_| |    \ V  V /| |  | |_
|_| |_|\__,_|_|  |_|   \__, |     \_/\_/ |_|   \__|
                        |___/
---------------------------------------------------------------
 HarryWrt ${BANNER_VER} | ${EDITION} Edition | ${TARGET}
 Based on OpenWrt | No Bloatware | Performance Focused
---------------------------------------------------------------
${PLUS_BANNER_LINE}
EOF

# ------------------------------------------------------------
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<EOF
HarryWrt ${BANNER_VER} - ${EDITION} Edition (based on OpenWrt) [${TARGET}]
EOF

# ------------------------------------------------------------
# 4) Branding — patch ONLY the human-readable description lines in
#    OpenWrt's own templates (package/base-files). The build then fills
#    in every other field (DISTRIB_ARCH, DISTRIB_TARGET, DISTRIB_REVISION,
#    OPENWRT_ARCH, ...) with the correct values for each target.
#
#    v3.1 replaced /etc/openwrt_release and /usr/lib/os-release wholesale
#    and later filled DISTRIB_ARCH from `uname -m` and DISTRIB_TARGET from
#    the board name. Those are not the same thing: on armsr/armv8 the
#    package architecture is aarch64_generic (uname says aarch64), and the
#    target is "armsr/armv8", not a board name. Tools that build package
#    repository URLs from DISTRIB_ARCH — including Passwall2's documented
#    apk repository setup — broke on aarch64, and DISTRIB_REVISION lost
#    the real build revision.
# ------------------------------------------------------------
if [[ -n "${HARRYWRT_REL}" ]]; then
  DESC="HarryWrt ${HARRYWRT_REL} ${EDITION} (OpenWrt %V %C)"
else
  DESC="HarryWrt ${EDITION} (OpenWrt %V %C)"
fi

OWRT_RELEASE_TPL="package/base-files/files/etc/openwrt_release"
OS_RELEASE_TPL="package/base-files/files/usr/lib/os-release"

if [ -f "$OWRT_RELEASE_TPL" ] && grep -q "^DISTRIB_DESCRIPTION=" "$OWRT_RELEASE_TPL"; then
  sed -i "s|^DISTRIB_DESCRIPTION=.*|DISTRIB_DESCRIPTION='${DESC}'|" "$OWRT_RELEASE_TPL"
  echo "[brand] DISTRIB_DESCRIPTION -> ${DESC}"
else
  echo "[brand] WARNING: $OWRT_RELEASE_TPL template not found or changed; branding skipped" >&2
fi

if [ -f "$OS_RELEASE_TPL" ]; then
  sed -i -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${DESC}\"|" \
         -e "s|^OPENWRT_RELEASE=.*|OPENWRT_RELEASE=\"${DESC}\"|" "$OS_RELEASE_TPL"
  echo "[brand] os-release PRETTY_NAME / OPENWRT_RELEASE patched"
else
  echo "[brand] WARNING: $OS_RELEASE_TPL template not found; os-release branding skipped" >&2
fi

# ------------------------------------------------------------
# 5) LuCI theme: official Bootstrap
#
#    v3.2 no longer ships Argon. Settings kept across a sysupgrade may
#    still point LuCI at a theme that is no longer installed, which
#    leaves the web UI unstyled/broken — fall back to Bootstrap then.
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/50-force-default-theme" <<'EOF'
#!/bin/sh
command -v uci >/dev/null 2>&1 || exit 0
cur="$(uci -q get luci.main.mediaurlbase)"
if [ -z "$cur" ] || [ ! -d "/www${cur}" ]; then
  uci -q set luci.main.mediaurlbase='/luci-static/bootstrap'
  uci -q commit luci
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/50-force-default-theme"

# ------------------------------------------------------------
# 5b) DHCP and dnsmasq sensible defaults
#     - DHCP start from .10 (leave .2-.9 for static devices)
#     - sequential IP assignment (like every commercial router)
#     - dnsmasq cache 150 -> 1000 for better DNS performance
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/51-harrywrt-dhcp-defaults" <<'EOF'
#!/bin/sh
# DHCP: start from .10, sequential, larger cache
uci -q set dhcp.lan.start='10'
uci -q set dhcp.lan.limit='240'
uci -q set dhcp.lan.sequential_ip='1'
uci -q set dhcp.@dnsmasq[0].cachesize='1000'
uci -q commit dhcp
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/51-harrywrt-dhcp-defaults"

# ------------------------------------------------------------
# 6) First boot: musl loader symlink fix (arch-aware)
# ------------------------------------------------------------
case "${TARGET}" in
  x86_64)                        MUSL_LOADER="ld-musl-x86_64.so.1" ;;
  aarch64|rockchip|rpi4|rpi5)    MUSL_LOADER="ld-musl-aarch64.so.1" ;;
  *)                             MUSL_LOADER="" ;;
esac

if [[ -n "${MUSL_LOADER}" ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix" <<EOF
#!/bin/sh
if [ ! -L /lib/${MUSL_LOADER} ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/${MUSL_LOADER}
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix"
fi

# ------------------------------------------------------------
# 7) Guardian removed from Clean/Plus
#
#    The old harrywrt_guardian could silently restart passwall2
#    after firewall/passwall2 config changes. That kind of hidden
#    automation is useful only in a lab/full profile, not in daily
#    Clean/Plus firmware.
# ------------------------------------------------------------

# ------------------------------------------------------------
# 8) First boot: clean non-existent passwall_packages feed
#
#    The passwall_packages feed is added at build time to
#    compile dependencies, but the URL gets baked into the
#    firmware's apk repository config. Since OpenWrt's
#    official download server doesn't host this feed, apk
#    will fail when refreshing repos (even for local installs).
#    This script removes the phantom feed entry on first boot.
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed" <<'EOF'
#!/bin/sh
# Remove the build-time passwall_packages feed from OpenWrt's own feed
# list only. customfeeds.list is left alone: it may hold the signed
# Passwall2 repository added with `harrywrt-passwall-repo enable`
# (v3.1 cleaned every *.list and would have wiped it on each upgrade).
f=/etc/apk/repositories.d/distfeeds.list
[ -f "$f" ] && sed -i '/passwall_packages/d' "$f"
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed"

# ------------------------------------------------------------
# 9) First boot: replace LuCI package manager for local .apk
#    install and install mirror auto-detect helper
#
#    OpenWrt 25.12 switched from opkg to apk (Alpine Package
#    Keeper). Unlike opkg, apk enforces signature verification
#    on ALL packages — including local uploads via LuCI. This
#    breaks the "upload .apk → install" workflow that users
#    expect from 24.10's seamless .ipk experience.
#
#    Strategy: replace /usr/libexec/package-manager-call entirely
#    with a known-good wrapper rather than patching with sed
#    (the upstream script is compressed into a few long lines,
#    making sed append unreliable regardless of pattern accuracy).
#    The wrapper handles:
#      1) --allow-untrusted for local .apk file installs
#      2) mirror auto-detect via harrywrt-mirror-check before update
#      3) preserves the JSON output format LuCI expects
# ------------------------------------------------------------

# harrywrt-mirror-check: switch the apk feeds between the official server
# and the TUNA mirror depending on which one is reachable
mkdir -p "${FILES_DIR}/usr/bin"
cat > "${FILES_DIR}/usr/bin/harrywrt-mirror-check" <<'EOF'
#!/bin/sh
# HarryWrt: auto-detect and switch apk mirror
OFFICIAL="downloads.openwrt.org"
MIRROR="mirrors.tuna.tsinghua.edu.cn/openwrt"
if wget -q -O /dev/null --timeout=3 "https://${OFFICIAL}" 2>/dev/null; then
	for f in /etc/apk/repositories.d/*.list; do
		[ -f "$f" ] || continue
		sed -i "s|${MIRROR}|${OFFICIAL}|g" "$f"
	done
else
	for f in /etc/apk/repositories.d/*.list; do
		[ -f "$f" ] || continue
		sed -i "s|${OFFICIAL}|${MIRROR}|g" "$f"
	done
fi
EOF
chmod 0755 "${FILES_DIR}/usr/bin/harrywrt-mirror-check"

cat > "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager" <<'PATCHEOF'
#!/bin/sh
# HarryWrt: wrap LuCI's package-manager-call with a small shim.
#
# v3.1 replaced the whole upstream script with a frozen copy, so any change
# LuCI made to it in a 25.12.x update was silently lost (or broke the
# Software page). The shim keeps the upstream script and only intercepts:
#   - install of a local .apk file  -> apk add --allow-untrusted
#     (no --no-network: missing dependencies can still be fetched from the
#      official feeds when online; v3.1 made such installs fail outright)
#   - update                        -> mirror check, then upstream
# Everything else is passed to the upstream script unchanged.

PMC="/usr/libexec/package-manager-call"
UP="$PMC.upstream"
[ -x "$PMC" ] || exit 0
grep -q 'HarryWrt package-manager shim' "$PMC" && exit 0

# Migrate a v3.1 full replacement back to the pristine upstream copy.
if [ -f "$PMC.harrywrt.bak" ] && grep -qi 'harrywrt' "$PMC"; then
	cp -f "$PMC.harrywrt.bak" "$PMC"
fi

cp -f "$PMC" "$UP" || exit 1
chmod 0755 "$UP"

cat > "$PMC" <<'EOF'
#!/bin/sh
# HarryWrt package-manager shim (upstream script: /usr/libexec/package-manager-call.upstream)
UP="/usr/libexec/package-manager-call.upstream"

_local_apk_args() {
	for p in "$@"; do
		case "$p" in
			*.apk) [ -f "$p" ] && return 0 ;;
		esac
	done
	return 1
}

action="$1"

case "$action" in
update)
	[ -x /usr/bin/harrywrt-mirror-check ] && /usr/bin/harrywrt-mirror-check >/dev/null 2>&1
	exec "$UP" "$@"
;;
install)
	shift
	if [ -x /usr/bin/apk ] && _local_apk_args "$@"; then
		. /usr/share/libubox/jshn.sh
		cmd="apk --allow-untrusted"
		while [ -n "$1" ]; do
			case "$1" in
				--force-removal-of-dependent-packages) cmd="$cmd -r"; shift ;;
				--force-overwrite) cmd="$cmd $1"; shift ;;
				-*) shift ;;
				*) break ;;
			esac
		done
		(
			if flock -x 9; then
				$cmd add "$@" >/tmp/ipkg.out 2>/tmp/ipkg.err
				code=$?
				stdout="$(cat /tmp/ipkg.out)"
				stderr="$(cat /tmp/ipkg.err)"
			else
				code=255
				stderr="Failed to acquire lock"
			fi
			json_init
			json_add_int code "$code"
			json_add_string pkmcmd "$cmd add $*"
			[ -n "$stdout" ] && json_add_string stdout "$stdout"
			[ -n "$stderr" ] && json_add_string stderr "$stderr"
			json_dump
		) 9>/tmp/ipkg.lock
		rm -f /tmp/ipkg.lock /tmp/ipkg.err /tmp/ipkg.out
		[ -x /usr/sbin/harrywrt-pkg-snapshot ] && /usr/sbin/harrywrt-pkg-snapshot >/dev/null 2>&1
		exit 0
	fi
	"$UP" install "$@"; rc=$?
	[ -x /usr/sbin/harrywrt-pkg-snapshot ] && /usr/sbin/harrywrt-pkg-snapshot >/dev/null 2>&1
	exit $rc
;;
remove)
	"$UP" "$@"; rc=$?
	[ -x /usr/sbin/harrywrt-pkg-snapshot ] && /usr/sbin/harrywrt-pkg-snapshot >/dev/null 2>&1
	exit $rc
;;
*)
	exec "$UP" "$@"
;;
esac
EOF
chmod 0755 "$PMC"

grep -q 'HarryWrt package-manager shim' "$PMC" || {
	echo "HarryWrt package-manager shim install failed; restoring upstream" >&2
	cp -f "$UP" "$PMC"
	exit 1
}
exit 0
PATCHEOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager"

# ------------------------------------------------------------
# 10) Plus-only safe defaults
#
#     Plus keeps optional network-facing services disabled by default.
#     UPnP is installed but off; turn it on in LuCI (Services -> UPnP).
#     (v3.1's harrywrt-feature-manager only duplicated that toggle.)
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then

cat > "${FILES_DIR}/etc/uci-defaults/60-harrywrt-plus-safe-defaults" <<'EOF'
#!/bin/sh
# Plus safe defaults: UPnP installed but disabled on first boot.

# v3.1 leftovers
rm -f /usr/bin/harrywrt-feature-manager /usr/libexec/harrywrt-feature-manager

# Disable optional services on first boot.
for svc in miniupnpd; do
  [ -x /etc/init.d/$svc ] || continue
  /etc/init.d/$svc stop >/dev/null 2>&1 || true
  /etc/init.d/$svc disable >/dev/null 2>&1 || true
done

uci -q set upnpd.config.enabled='0' 2>/dev/null || true
uci -q commit upnpd 2>/dev/null || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/60-harrywrt-plus-safe-defaults"

fi

# ------------------------------------------------------------
# 11) WAN/DNS health check (all profiles, all platforms)
#
#     Status -> Network Health in LuCI. Tests WAN reachability, DNS
#     resolution and IPv6 connectivity; results are cached for 5 minutes.
#
#     v3.1 served this from an unauthenticated /cgi-bin endpoint (anyone on
#     the LAN or a guest network could read the WAN IP without logging in),
#     its LuCI view read the DOM in load() — before render() created it —
#     so the page stayed on "Checking..." forever, and the refresh job was
#     written to /etc/cron.d, which OpenWrt's busybox crond never reads.
#     Now: LuCI calls the script through rpcd with an ACL (login required).
# ------------------------------------------------------------
mkdir -p "${FILES_DIR}/usr/bin"
mkdir -p "${FILES_DIR}/usr/share/luci/menu.d"
mkdir -p "${FILES_DIR}/usr/share/rpcd/acl.d"
mkdir -p "${FILES_DIR}/www/luci-static/resources/view/harrywrt"

cat > "${FILES_DIR}/usr/bin/harrywrt-health-check" <<'EOF'
#!/bin/sh
# HarryWrt network health check — prints one JSON object.
#   (no args)   serve the cached result if younger than 5 minutes
#   --refresh   always run the checks
CACHE_FILE="/tmp/harrywrt-health.json"
MAX_AGE=300

if [ "${1:-}" != "--refresh" ] && [ -s "$CACHE_FILE" ]; then
    age=$(( $(date +%s) - $(date +%s -r "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ "$age" -ge 0 ] && [ "$age" -lt "$MAX_AGE" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

check_wan() {
    if wget -q -O /dev/null --timeout=5 "http://connectivitycheck.gstatic.com/generate_204" 2>/dev/null; then
        echo "ok"
    elif wget -q -O /dev/null --timeout=5 "http://www.msftconnecttest.com/connecttest.txt" 2>/dev/null; then
        echo "ok"
    else
        echo "fail"
    fi
}

check_dns() {
    # The system resolver is what clients actually use; if only an external
    # resolver answers, the local one is broken, which is reported as fail.
    if nslookup openwrt.org >/dev/null 2>&1; then echo "ok"; else echo "fail"; fi
}

check_ipv6() {
    # ok / unavailable (no global IPv6 address) / fail (address but unreachable)
    if ! ip -6 addr show scope global 2>/dev/null | grep -q "inet6"; then
        echo "unavailable"; return
    fi
    if ping -6 -c 1 -W 3 2606:4700:4700::1111 >/dev/null 2>&1 \
       || ping6 -c 1 -W 3 2606:4700:4700::1111 >/dev/null 2>&1; then
        echo "ok"
    else
        echo "fail"
    fi
}

check_wan_ip() {
    ip route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -n1
}

JSON="$(printf '{"timestamp":"%s","wan":"%s","dns":"%s","ipv6":"%s","wan_ip":"%s"}' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(check_wan)" "$(check_dns)" "$(check_ipv6)" "$(check_wan_ip)")"
printf '%s\n' "$JSON" > "$CACHE_FILE.tmp" && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
printf '%s\n' "$JSON"
EOF
chmod 0755 "${FILES_DIR}/usr/bin/harrywrt-health-check"

# rpcd ACL: only authenticated LuCI sessions may run the check.
cat > "${FILES_DIR}/usr/share/rpcd/acl.d/luci-app-harrywrt-health.json" <<'EOF'
{
  "luci-app-harrywrt-health": {
    "description": "Grant access to the HarryWrt network health check",
    "read": {
      "file": {
        "/usr/bin/harrywrt-health-check": [ "exec" ],
        "/usr/bin/harrywrt-health-check --refresh": [ "exec" ]
      }
    }
  }
}
EOF

cat > "${FILES_DIR}/usr/share/luci/menu.d/harrywrt-health.json" <<'EOF'
{
  "admin/status/harrywrt-health": {
    "title": "Network Health",
    "order": 5,
    "action": {
      "type": "view",
      "path": "harrywrt/health"
    },
    "depends": {
      "acl": [ "luci-app-harrywrt-health" ]
    }
  }
}
EOF

cat > "${FILES_DIR}/www/luci-static/resources/view/harrywrt/health.js" <<'EOF'
'use strict';
'require view';
'require fs';
'require ui';

var CHECK = '/usr/bin/harrywrt-health-check';

function runCheck(refresh) {
	return fs.exec_direct(CHECK, refresh ? [ '--refresh' ] : [], 'json')
		.catch(function(err) { return { error: String(err) }; });
}

function badge(status) {
	var color = '#d9534f', text = _('Offline');
	if (status === 'ok') { color = '#5cb85c'; text = _('Online'); }
	else if (status === 'unavailable') { color = '#888'; text = _('Not configured'); }
	return E('span', {
		'style': 'display:inline-block;padding:2px 10px;border-radius:3px;font-weight:bold;color:#fff;margin-left:8px;background:' + color
	}, text);
}

function row(label, status, extra) {
	return E('div', { 'style': 'display:flex;align-items:center;padding:10px 0;border-bottom:1px solid #eee;' }, [
		E('span', { 'style': 'width:140px;font-weight:bold;' }, label),
		badge(status),
		extra ? E('span', { 'style': 'margin-left:12px;color:#666;font-size:0.9em;' }, extra) : ''
	]);
}

function renderResult(d) {
	if (!d || d.error)
		return [ E('p', { 'style': 'color:#d9534f;' }, _('Failed to run health check') + (d && d.error ? ': ' + d.error : '')) ];
	var nodes = [
		row(_('WAN'), d.wan, d.wan_ip || ''),
		row(_('DNS'), d.dns, ''),
		row(_('IPv6'), d.ipv6, '')
	];
	if (d.timestamp)
		nodes.push(E('p', { 'style': 'margin-top:12px;color:#aaa;font-size:0.85em;' },
			_('Last checked') + ': ' + new Date(d.timestamp).toLocaleTimeString()));
	return nodes;
}

return view.extend({
	load: function() {
		return runCheck(false);
	},

	render: function(data) {
		var status = E('div', { 'id': 'harrywrt-health-status' }, renderResult(data));
		var btn = E('button', {
			'class': 'cbi-button cbi-button-action',
			'style': 'margin-top:1em;',
			'click': ui.createHandlerFn(this, function() {
				status.replaceChildren(E('p', { 'style': 'color:#888;' }, _('Checking...')));
				return runCheck(true).then(function(d) {
					status.replaceChildren.apply(status, renderResult(d));
				});
			})
		}, _('Refresh Now'));

		return E('div', { 'style': 'padding:1em;max-width:600px;' }, [
			E('h2', {}, _('Network Health')),
			status,
			btn
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
EOF

# v3.1 artefacts that must not linger after a sysupgrade with kept settings
cat > "${FILES_DIR}/etc/uci-defaults/52-harrywrt-health-cleanup" <<'EOF'
#!/bin/sh
rm -f /www/cgi-bin/harrywrt-health /etc/cron.d/harrywrt-health
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/52-harrywrt-health-cleanup"

# ------------------------------------------------------------
# 12) RootFS auto-expand — removed in v3.2.
#
#     The v3.1 first-boot script called `findfs /`, which busybox does not
#     support (it only accepts LABEL=/UUID=), so it always exited without
#     doing anything. Had it run, it would have resized partition 2 of the
#     squashfs image — a read-only squashfs whose overlay lives inside it —
#     which resize2fs cannot handle. parted and e2fsprogs remain installed
#     for manual expansion (see README).
# ------------------------------------------------------------

# ------------------------------------------------------------
# 13) Performance: irqbalance + packet steering (all profiles)
#     Spreads NIC interrupts and packet processing over all CPU cores —
#     noticeable on multi-core x86 soft routers and NanoPi R5S/R6S.
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/70-harrywrt-performance" <<'EOF'
#!/bin/sh
if [ -f /etc/config/irqbalance ]; then
  uci -q set irqbalance.irqbalance.enabled='1'
  uci -q commit irqbalance
  /etc/init.d/irqbalance enable >/dev/null 2>&1
fi
uci -q get network.globals >/dev/null || uci -q set network.globals=globals
if [ -z "$(uci -q get network.globals.packet_steering)" ]; then
  uci -q set network.globals.packet_steering='1'
  uci -q commit network
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/70-harrywrt-performance"

# ------------------------------------------------------------
# 14) QEMU guest agent (x86_64 / aarch64 VM images)
#     Only useful inside a VM with the agent channel enabled; on bare
#     metal it would just keep failing, so disable it there.
# ------------------------------------------------------------
if [[ "${TARGET}" == "x86_64" || "${TARGET}" == "aarch64" ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/71-harrywrt-qemu-ga" <<'EOF'
#!/bin/sh
[ -x /etc/init.d/qemu-ga ] || exit 0
if grep -qs 'org.qemu.guest_agent' /sys/class/virtio-ports/*/name; then
  /etc/init.d/qemu-ga enable >/dev/null 2>&1
else
  /etc/init.d/qemu-ga stop >/dev/null 2>&1
  /etc/init.d/qemu-ga disable >/dev/null 2>&1
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/71-harrywrt-qemu-ga"
fi

# ------------------------------------------------------------
# 15) TCP BBR (Plus) — for connections the router itself makes
#     (xray / sing-box upstream traffic).
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then
mkdir -p "${FILES_DIR}/etc/sysctl.d"
cat > "${FILES_DIR}/etc/sysctl.d/12-harrywrt-bbr.conf" <<'EOF'
# HarryWrt: TCP BBR congestion control (kmod-tcp-bbr)
net.ipv4.tcp_congestion_control=bbr
EOF
fi

# ------------------------------------------------------------
# 16) Reinstall user packages after a firmware upgrade
#
#     /etc/harrywrt/user-packages.list  packages the user installed on
#                                       top of the firmware (kept across
#                                       sysupgrade via /lib/upgrade/keep.d)
#     /etc/harrywrt/firmware-packages.list  what this firmware ships with,
#                                       recorded at its first boot
#     On the first boot of a new firmware, missing user packages are
#     installed again from the configured feeds once the network is up.
#     Log: /etc/harrywrt/restore.log (and syslog, tag "harrywrt").
# ------------------------------------------------------------
mkdir -p "${FILES_DIR}/usr/sbin" "${FILES_DIR}/etc/init.d" "${FILES_DIR}/lib/upgrade/keep.d"

cat > "${FILES_DIR}/usr/sbin/harrywrt-pkg-snapshot" <<'EOF'
#!/bin/sh
# Record user-installed packages (installed minus firmware baseline).
#   harrywrt-pkg-snapshot            update /etc/harrywrt/user-packages.list
#   harrywrt-pkg-snapshot --baseline record this firmware's own packages
DIR=/etc/harrywrt
BASE="$DIR/firmware-packages.list"
LIST="$DIR/user-packages.list"
PENDING="$DIR/pending-packages.list"   # failed to reinstall; kept until installed
mkdir -p "$DIR"

installed_explicit() {
  if [ -f /etc/apk/world ]; then
    # apk: explicitly requested packages (strip version constraints)
    sed -e 's/[<>=~].*//' -e '/^$/d' /etc/apk/world | sort -u
  elif [ -f /usr/lib/opkg/status ]; then
    # opkg: packages flagged "user installed"
    awk '/^Package:/{p=$2} /^Status:.*user installed/{print p}' /usr/lib/opkg/status | sort -u
  fi
}

if [ "$1" = "--baseline" ]; then
  installed_explicit > "$BASE.tmp" && mv -f "$BASE.tmp" "$BASE"
  exit 0
fi

[ -s "$BASE" ] || exit 0          # no baseline yet: nothing reliable to compare
{
  installed_explicit | grep -vxF -f "$BASE"
  # Packages that could not be reinstalled yet stay on the list, so they
  # are retried (e.g. once the Passwall2 repository has been enabled).
  [ -s "$PENDING" ] && cat "$PENDING"
} | sort -u > "$LIST.tmp"
if [ "$(cat "$LIST.tmp")" != "$(cat "$LIST" 2>/dev/null)" ]; then
  mv -f "$LIST.tmp" "$LIST"
else
  rm -f "$LIST.tmp"
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/usr/sbin/harrywrt-pkg-snapshot"

cat > "${FILES_DIR}/usr/sbin/harrywrt-pkg-restore" <<'EOF'
#!/bin/sh
# Reinstall packages from /etc/harrywrt/user-packages.list after a
# firmware upgrade. Runs once per firmware build (see init script).
DIR=/etc/harrywrt
LIST="$DIR/user-packages.list"
PENDING="$DIR/pending-packages.list"
LOG="$DIR/restore.log"
[ -s "$LIST" ] || exit 0

log() { echo "$(date '+%F %T') $*" >> "$LOG"; logger -t harrywrt "$*"; }

# Wait for connectivity (up to 10 minutes)
i=0
until ping -c1 -W3 downloads.openwrt.org >/dev/null 2>&1 \
   || wget -q -T 5 -O /dev/null http://www.msftconnecttest.com/connecttest.txt 2>/dev/null; do
  i=$((i + 1))
  [ "$i" -ge 60 ] && { log "restore: no network after 10 minutes, will retry next boot"; exit 1; }
  sleep 10
done

[ -x /usr/bin/harrywrt-mirror-check ] && /usr/bin/harrywrt-mirror-check >/dev/null 2>&1

if command -v apk >/dev/null 2>&1; then
  apk update >/dev/null 2>&1
  is_installed() { apk info -e "$1" >/dev/null 2>&1; }
  install_pkg()  { apk add "$1" >>"$LOG" 2>&1; }
else
  opkg update >/dev/null 2>&1
  is_installed() { opkg status "$1" 2>/dev/null | grep -q '^Status:.* installed'; }
  install_pkg()  { opkg install "$1" >>"$LOG" 2>&1; }
fi

ok=0; failed=""
log "restore: reinstalling packages from $LIST"
while read -r pkg; do
  [ -n "$pkg" ] || continue
  is_installed "$pkg" && continue
  if install_pkg "$pkg"; then ok=$((ok + 1)); else failed="$failed $pkg"; fi
done < "$LIST"

if [ -n "$failed" ]; then
  printf '%s\n' $failed > "$PENDING"
  log "restore: reinstalled $ok package(s); FAILED:$failed (not in the configured feeds?) — will retry at next boot; run harrywrt-pkg-restore to retry now, or delete $PENDING to give up"
else
  rm -f "$PENDING"
  log "restore: reinstalled $ok package(s)"
fi
/usr/sbin/harrywrt-pkg-snapshot
exit 0
EOF
chmod 0755 "${FILES_DIR}/usr/sbin/harrywrt-pkg-restore"

cat > "${FILES_DIR}/etc/init.d/harrywrt-pkg-restore" <<'EOF'
#!/bin/sh /etc/rc.common
# Once per firmware build: reinstall user packages in the background,
# then keep the snapshot up to date.
START=99

firmware_id() {
  cat /etc/openwrt_release /etc/harrywrt/firmware-packages.list 2>/dev/null | md5sum | cut -d' ' -f1
}

start() {
  mkdir -p /etc/harrywrt
  local id; id="$(firmware_id)"
  if [ -s /etc/harrywrt/user-packages.list ] && \
     { [ "$(cat /etc/harrywrt/.restored 2>/dev/null)" != "$id" ] || \
       [ -s /etc/harrywrt/pending-packages.list ]; }; then
    ( /usr/sbin/harrywrt-pkg-restore && echo "$id" > /etc/harrywrt/.restored ) &
  else
    /usr/sbin/harrywrt-pkg-snapshot
  fi
}
EOF
chmod 0755 "${FILES_DIR}/etc/init.d/harrywrt-pkg-restore"

# Preserve the user package list across sysupgrade
printf '%s\n' /etc/harrywrt/user-packages.list /etc/harrywrt/pending-packages.list \
  > "${FILES_DIR}/lib/upgrade/keep.d/harrywrt"

cat > "${FILES_DIR}/etc/uci-defaults/80-harrywrt-pkg-restore" <<'EOF'
#!/bin/sh
# First boot of this firmware: record its own package set, enable the
# restore service and a 30-minute snapshot job (busybox crond reads
# /etc/crontabs/root — not /etc/cron.d).
/usr/sbin/harrywrt-pkg-snapshot --baseline
/etc/init.d/harrywrt-pkg-restore enable >/dev/null 2>&1
mkdir -p /etc/crontabs
touch /etc/crontabs/root
grep -q 'harrywrt-pkg-snapshot' /etc/crontabs/root || \
  echo '*/30 * * * * /usr/sbin/harrywrt-pkg-snapshot' >> /etc/crontabs/root
/etc/init.d/cron enable >/dev/null 2>&1
/etc/init.d/cron restart >/dev/null 2>&1
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/80-harrywrt-pkg-restore"

# ------------------------------------------------------------
# 17) One-command Passwall2 signed repository (25.12 / apk)
#     Follows the Passwall2 README; lets users install and UPDATE
#     Passwall2 with signature verification instead of uploading
#     unsigned .apk files.
# ------------------------------------------------------------
cat > "${FILES_DIR}/usr/sbin/harrywrt-passwall-repo" <<'EOF'
#!/bin/sh
# harrywrt-passwall-repo enable | disable | status
FEEDS=/etc/apk/repositories.d/customfeeds.list
KEY=/etc/apk/keys/passwall.pub
KEY_URL="https://sourceforge.net/projects/openwrt-passwall-build/files/apk.pub"

if ! command -v apk >/dev/null 2>&1; then
  echo "The Passwall2 signed repository needs apk (OpenWrt 25.12 or newer)."
  exit 1
fi

. /etc/openwrt_release
release="${DISTRIB_RELEASE%.*}"
arch="$DISTRIB_ARCH"
BASE="https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-${release}/${arch}"

case "$1" in
enable)
  tmp="$(mktemp)"
  if ! wget -q -O "$tmp" "$KEY_URL" || ! grep -q -- '-----BEGIN PUBLIC KEY-----' "$tmp"; then
    rm -f "$tmp"
    echo "Could not download a valid Passwall2 signing key from $KEY_URL" >&2
    exit 1
  fi
  mkdir -p /etc/apk/keys /etc/apk/repositories.d
  mv -f "$tmp" "$KEY"
  touch "$FEEDS"
  sed -i '/openwrt-passwall-build/d' "$FEEDS"
  for feed in passwall_packages passwall_luci passwall2; do
    echo "${BASE}/${feed}/packages.adb" >> "$FEEDS"
  done
  echo "Passwall2 repository added for ${release} / ${arch}. Updating package index..."
  apk update
  echo "Install with:  apk add luci-app-passwall2"
  ;;
disable)
  [ -f "$FEEDS" ] && sed -i '/openwrt-passwall-build/d' "$FEEDS"
  rm -f "$KEY"
  echo "Passwall2 repository removed."
  ;;
status)
  if grep -qs 'openwrt-passwall-build' "$FEEDS"; then
    echo "enabled:"; grep 'openwrt-passwall-build' "$FEEDS"
  else
    echo "disabled"
  fi
  ;;
*)
  echo "Usage: harrywrt-passwall-repo enable | disable | status"
  exit 2
  ;;
esac
EOF
chmod 0755 "${FILES_DIR}/usr/sbin/harrywrt-passwall-repo"

echo "DIY script executed successfully for OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}."
