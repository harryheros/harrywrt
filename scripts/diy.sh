#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# HarryWrt DIY Script (Multi-version / Multi-platform)
#
# Usage: diy.sh <OWRT_VERSION> <TARGET>
#   e.g. diy.sh 24.10.6 x86_64
#        diy.sh 25.12.2 aarch64
#
# - Branding (banner / motd / DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap
# - Go toolchain GOTOOLCHAIN=auto patch (for geoview)
# - First boot: musl loader symlink fix (arch-aware)
# - First boot: passwall2 guardian service
# - First boot: clean non-existent passwall_packages feed
# - First boot: patch LuCI apk local install (25.12+)
# - NTP configuration preserved
# =============================================================

HARRYWRT_VER="${1:?Usage: diy.sh <OWRT_VERSION> <TARGET>}"
TARGET="${2:?Usage: diy.sh <OWRT_VERSION> <TARGET>}"

# Guard: must be run from inside the openwrt source directory
if [[ ! -f "Makefile" ]] || ! grep -q "TOPDIR:=" Makefile 2>/dev/null; then
  echo "ERROR: diy.sh must be run from within the openwrt source directory (current: $PWD)" >&2
  exit 1
fi

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

echo "============================================================"
echo " HarryWrt DIY: OpenWrt ${HARRYWRT_VER} / ${TARGET}"
echo "============================================================"

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
cat > "${FILES_DIR}/etc/banner" <<EOF
---------------------------------------------------------------
 _   _                          __        __     _
| | | | __ _ _ __ _ __ _   _   \ \      / /_ __| |_
| |_| |/ _\` | '__| '__| | | |   \ \ /\ / / '__| __|
|  _  | (_| | |  | |  | |_| |    \ V  V /| |  | |_
|_| |_|\__,_|_|  |_|   \__, |     \_/\_/ |_|   \__|
                        |___/
---------------------------------------------------------------
 HarryWrt ${HARRYWRT_VER} | Clean Edition | ${TARGET}
 Based on OpenWrt | No Bloatware | Performance Focused
---------------------------------------------------------------
EOF

# ------------------------------------------------------------
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<EOF
HarryWrt ${HARRYWRT_VER} - Clean Edition (based on OpenWrt) [${TARGET}]
EOF

# ------------------------------------------------------------
# 4) UCI defaults: branding
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<EOF
#!/bin/sh
DESC="HarryWrt ${HARRYWRT_VER} Clean (based on OpenWrt)"

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
  '  [ -x /etc/init.d/passwall2 ] && /etc/init.d/passwall2 restart >/dev/null 2>&1 || true' \
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
#    This patch modifies /usr/libexec/package-manager-call to
#    automatically add --allow-untrusted --force-non-repository
#    flags when apk installs a local file (/tmp/upload.apk).
#    This restores the 24.10-equivalent behavior: upload a
#    package via LuCI web UI, click install, done.
# ------------------------------------------------------------
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/92-patch-apk-local-install" <<'PATCHEOF'
#!/bin/sh
PMC="/usr/libexec/package-manager-call"
[ -f "$PMC" ] || exit 0

# Only patch once
grep -q 'allow-untrusted' "$PMC" && exit 0

# Patch: in the install→add case branch, append --allow-untrusted
# and --force-non-repository to the cmd variable. This makes LuCI
# upload-install work like opkg did in 24.10 (no signature check).
sed -i '/action="add"/a\\t\t\t\t\tcmd="$cmd --allow-untrusted --force-non-repository"' "$PMC"

exit 0
PATCHEOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/92-patch-apk-local-install"
fi

echo "DIY script executed successfully for OpenWrt ${HARRYWRT_VER} / ${TARGET}."
