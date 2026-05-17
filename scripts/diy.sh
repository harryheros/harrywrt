#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# HarryWrt DIY Script (Multi-version / Multi-platform / Multi-profile)
#
# Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE]
#   e.g. diy.sh 24.10.6 x86_64 clean
#        diy.sh 25.12.4 aarch64 plus
#
# - Branding (banner / motd / DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap
# - Go toolchain GOTOOLCHAIN=auto patch (for geoview)
# - First boot: musl loader symlink fix (arch-aware)
# - First boot: passwall2 guardian service
# - First boot: clean non-existent passwall_packages feed
# - First boot: patch LuCI package manager (apk trust + mirror auto-detect)
# - NTP configuration preserved
# - [plus only] HTTPS DNS Proxy pre-configured (disabled by default)
# - [plus only] UPnP disabled by default
# =============================================================

HARRYWRT_VER="${1:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE]}"
TARGET="${2:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE]}"
PROFILE="${3:-clean}"

# Guard: must be run from inside the openwrt source directory
if [[ ! -f "Makefile" ]] || ! grep -q "TOPDIR:=" Makefile 2>/dev/null; then
  echo "ERROR: diy.sh must be run from within the openwrt source directory (current: $PWD)" >&2
  exit 1
fi

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

echo "============================================================"
echo " HarryWrt DIY: OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}"
echo "============================================================"

# Derive human-readable edition label
case "${PROFILE}" in
  plus)  EDITION="Plus" ;;
  *)     EDITION="Clean" ;;
esac

# ------------------------------------------------------------
# 0a) 25.12+: replace luci-app-opkg with luci-app-package-manager
#     The config files use luci-app-opkg for compatibility with 24.10.
#     On 25.12+, opkg is replaced by apk; swap the package in .config.
# ------------------------------------------------------------
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
  if [ -f ".config" ]; then
    sed -i 's/CONFIG_PACKAGE_luci-app-opkg=y/CONFIG_PACKAGE_luci-app-package-manager=y/' .config
    echo "[patch] 25.12: luci-app-opkg -> luci-app-package-manager"
  fi
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
CRONLOGLEVEL=5
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
  CRONLOGLEVEL=7
fi

cat > "${FILES_DIR}/etc/config/system" <<EOF
config system
  option hostname 'HarryWrt'
  option timezone 'HKT-8'
  option zonename 'Asia/Hong_Kong'
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
  PLUS_BANNER_LINE=" DoH available: Services → HTTPS DNS Proxy (disabled by default)"$'\n'"---------------------------------------------------------------"
else
  PLUS_BANNER_LINE=""
fi

cat > "${FILES_DIR}/etc/banner" <<EOF
---------------------------------------------------------------
 _   _                          __        __     _
| | | | __ _ _ __ _ __ _   _   \ \      / /_ __| |_
| |_| |/ _\` | '__| '__| | | |   \ \ /\ / / '__| __|
|  _  | (_| | |  | |  | |_| |    \ V  V /| |  | |_
|_| |_|\__,_|_|  |_|   \__, |     \_/\_/ |_|   \__|
                        |___/
---------------------------------------------------------------
 HarryWrt ${HARRYWRT_VER} | ${EDITION} Edition | ${TARGET}
 Based on OpenWrt | No Bloatware | Performance Focused
---------------------------------------------------------------
${PLUS_BANNER_LINE}
EOF

# ------------------------------------------------------------
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<EOF
HarryWrt ${HARRYWRT_VER} - ${EDITION} Edition (based on OpenWrt) [${TARGET}]
EOF

# ------------------------------------------------------------
# 4) UCI defaults: branding
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<EOF
#!/bin/sh
DESC="HarryWrt ${HARRYWRT_VER} ${EDITION} (based on OpenWrt)"

if [ -f /etc/openwrt_release ]; then
  sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='\${DESC}'/" /etc/openwrt_release 2>/dev/null || true
fi
if [ -f /etc/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"\${DESC}\"/" /etc/os-release 2>/dev/null || true
fi
if [ -f /usr/lib/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"\${DESC}\"/" /usr/lib/os-release 2>/dev/null || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/50-force-default-theme" <<'EOF'
#!/bin/sh
if command -v uci >/dev/null 2>&1; then
  uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
  uci -q commit luci || true
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
  x86_64)   MUSL_LOADER="ld-musl-x86_64.so.1" ;;
  aarch64)  MUSL_LOADER="ld-musl-aarch64.so.1" ;;
  *)        MUSL_LOADER="" ;;
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
# 7) First boot: passwall2 guardian (procd service)
#
#    Passwall2 has its own hotplug (98-passwall2) and init.d
#    with START=99 + boot delay. The guardian complements this
#    by handling config.change triggers that passwall2's own
#    hotplug doesn't cover.
#
#    NOTE: We removed the old 98-passwall2-autofix script
#    because passwall2's own init.d boot() already handles
#    first-boot with a configurable delay.
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/95-harrywrt-guardian" <<'EOF'
#!/bin/sh

# Create the guardian init.d service using printf
# (avoids nested heredoc issues on BusyBox ash)
printf '%s\n' \
  '#!/bin/sh /etc/rc.common' \
  'START=99' \
  'USE_PROCD=1' \
  '' \
  'service_triggers() {' \
  '  procd_add_config_trigger "config.change" "firewall" /etc/init.d/harrywrt_guardian restart' \
  '  procd_add_config_trigger "config.change" "passwall2" /etc/init.d/harrywrt_guardian restart' \
  '}' \
  '' \
  'start_service() {' \
  '  # Wait for firewall to be fully loaded' \
  '  local i=0' \
  '  while [ $i -lt 10 ]; do' \
  '    nft list ruleset >/dev/null 2>&1 && break' \
  '    sleep 1' \
  '    i=$((i+1))' \
  '  done' \
  '  [ -x /etc/init.d/passwall2 ] && {' \
  '    local enabled=$(uci -q get passwall2.@global[0].enabled)' \
  '    [ "$enabled" = "1" ] && /etc/init.d/passwall2 restart >/dev/null 2>&1 || true' \
  '  }' \
  '}' \
  > /etc/init.d/harrywrt_guardian

chmod 0755 /etc/init.d/harrywrt_guardian
/etc/init.d/harrywrt_guardian enable >/dev/null 2>&1 || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/95-harrywrt-guardian"

# ------------------------------------------------------------
# 8) First boot: clean non-existent passwall_packages feed
#
#    The passwall_packages feed is added at build time to
#    compile dependencies, but the URL gets baked into the
#    firmware's apk/opkg repository config. Since OpenWrt's
#    official download server doesn't host this feed, apk
#    will fail when refreshing repos (even for local installs).
#    This script removes the phantom feed entry on first boot.
# ------------------------------------------------------------
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed" <<'EOF'
#!/bin/sh
# Remove passwall_packages feed — does not exist on official repos
for f in /etc/apk/repositories.d/*.list; do
  [ -f "$f" ] || continue
  sed -i '/passwall_packages/d' "$f"
done
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed"
else
cat > "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed" <<'EOF'
#!/bin/sh
# Remove passwall_packages feed — does not exist on official repos
if [ -f /etc/opkg/distfeeds.conf ]; then
  sed -i '/passwall_packages/d' /etc/opkg/distfeeds.conf
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed"
fi

# ------------------------------------------------------------
# 9) First boot: patch LuCI package manager for local .apk
#    install (25.12+ only)
#
#    OpenWrt 25.12 switched from opkg to apk (Alpine Package
#    Keeper). Unlike opkg, apk enforces signature verification
#    on ALL packages — including local uploads via LuCI. This
#    breaks the "upload .apk → install" workflow that users
#    expect from 24.10's seamless .ipk experience.
#
#    This patch modifies /usr/libexec/package-manager-call to:
#    1) Add --allow-untrusted --force-non-repository for local
#       .apk installs (restores 24.10 upload-install behavior)
#    2) Auto-detect repo mirror on every "update" — if official
#       server is unreachable (3s timeout), temporarily switch
#       to TUNA mirror before refreshing. This runs each time,
#       so it adapts to the user's actual network environment
#       without modifying config files at first boot.
# ------------------------------------------------------------
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager" <<'PATCHEOF'
#!/bin/sh
PMC="/usr/libexec/package-manager-call"
[ -f "$PMC" ] || exit 0

# Only patch once
grep -q 'allow-untrusted' "$PMC" && exit 0

# Patch 1: allow local .apk install without signature check
sed -i '/action="add"/a\\t\t\t\t\tcmd="$cmd --allow-untrusted --force-non-repository"' "$PMC"

# Patch 2: auto-detect mirror on "update" action
# Insert a mirror check function and hook it into the update path.
# We add a helper function at the top of the script, then call it
# before apk update runs.
sed -i '/^case "\$action" in/i\
_harrywrt_mirror_check() {\
  OFFICIAL="downloads.openwrt.org"\
  MIRROR="mirrors.tuna.tsinghua.edu.cn/openwrt"\
  # Quick connectivity test (3s timeout)\
  if wget -q -O /dev/null --timeout=3 "https://${OFFICIAL}" 2>/dev/null; then\
    # Official reachable — restore if previously switched\
    for f in /etc/apk/repositories.d/*.list; do\
      [ -f "$f" ] || continue\
      sed -i "s|${MIRROR}|${OFFICIAL}|g" "$f"\
    done\
  else\
    # Official unreachable — switch to mirror\
    for f in /etc/apk/repositories.d/*.list; do\
      [ -f "$f" ] || continue\
      sed -i "s|${OFFICIAL}|${MIRROR}|g" "$f"\
    done\
  fi\
}' "$PMC"

# Hook the mirror check into the "update" action
sed -i '/action="update"/a\\t\t\t\t\t_harrywrt_mirror_check' "$PMC"

exit 0
PATCHEOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager"
else
# 24.10 (opkg): only need mirror auto-detect, no signature issue
cat > "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager" <<'PATCHEOF'
#!/bin/sh
PMC="/usr/libexec/package-manager-call"
[ -f "$PMC" ] || exit 0

# Only patch once
grep -q '_harrywrt_mirror_check' "$PMC" && exit 0

# Add mirror auto-detect function and hook into update
sed -i '/^case "\$action" in/i\
_harrywrt_mirror_check() {\
  OFFICIAL="downloads.openwrt.org"\
  MIRROR="mirrors.tuna.tsinghua.edu.cn/openwrt"\
  if wget -q -O /dev/null --timeout=3 "https://${OFFICIAL}" 2>/dev/null; then\
    if [ -f /etc/opkg/distfeeds.conf ]; then\
      sed -i "s|${MIRROR}|${OFFICIAL}|g" /etc/opkg/distfeeds.conf\
    fi\
  else\
    if [ -f /etc/opkg/distfeeds.conf ]; then\
      sed -i "s|${OFFICIAL}|${MIRROR}|g" /etc/opkg/distfeeds.conf\
    fi\
  fi\
}' "$PMC"

# For opkg, hook into the "update" action in the install|update|upgrade|remove case
sed -i '/install|update|upgrade|remove)/a\\t\t[ "$action" = "update" ] && _harrywrt_mirror_check' "$PMC"

exit 0
PATCHEOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager"
fi

# ------------------------------------------------------------
# 10) [Plus only] https-dns-proxy pre-configuration
#     - Installed but disabled by default
#     - User opts in via LuCI Services → HTTPS DNS Proxy
#     - Pre-configured with Cloudflare and Quad9 as upstream
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then

# uci-defaults: pre-configure https-dns-proxy with sensible defaults
cat > "${FILES_DIR}/etc/uci-defaults/60-https-dns-proxy" <<'EOF'
#!/bin/sh
# Pre-configure https-dns-proxy with Cloudflare and Quad9
# Service is disabled by default — user opts in via LuCI
uci -q set https-dns-proxy.@https-dns-proxy[0]=https-dns-proxy 2>/dev/null || \
  uci -q add https-dns-proxy https-dns-proxy
uci -q set https-dns-proxy.@https-dns-proxy[0].address='https://1.1.1.1/dns-query'
uci -q set https-dns-proxy.@https-dns-proxy[0].listen_addr='127.0.0.1'
uci -q set https-dns-proxy.@https-dns-proxy[0].listen_port='5053'
uci -q commit https-dns-proxy 2>/dev/null || true
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/60-https-dns-proxy"

fi

echo "DIY script executed successfully for OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}."

