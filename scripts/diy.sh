#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap (Argon remains optional)
# - Fix Go toolchain policy for geoview: GOTOOLCHAIN=auto
# - First boot: musl loader symlink fix
# - First boot: dynamic procd guardian for config.apply behavior
# ============================================================

# Guard: must be run from inside the openwrt/ source directory
if [[ "$(basename "$PWD")" != "openwrt" ]]; then
  echo "ERROR: diy.sh must be run from within the openwrt/ directory (current: $PWD)" >&2
  exit 1
fi

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy for geoview
#
#    Root cause: GOTOOLCHAIN=local is set in the OpenWrt golang
#    build framework (golang-package.mk / golang-build.sh), which
#    all Go packages inherit. geoview requires Go >= 1.24 but the
#    system Go on ubuntu-22.04 runners is 1.23.x, so we must
#    switch the framework to GOTOOLCHAIN=auto to allow it to
#    download the required toolchain version at build time.
#
#    Strategy:
#      1) Patch the golang framework files (primary fix)
#      2) Also inject GOTOOLCHAIN=auto directly into geoview's
#         Makefile as a double-insurance
#      3) Validate with a warning-only approach (never exit 1)
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

# Also scan for any remaining GOTOOLCHAIN=local in the golang lang dir
# (covers version-specific subdirs like golang-1.23/, golang-1.24/, etc.)
while IFS= read -r -d '' f; do
  if grep -qE '\bGOTOOLCHAIN=local\b' "$f"; then
    sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$f"
    echo "[patch] Additional file patched: $f"
  fi
done < <(find feeds/packages/lang/golang -type f \( -name "*.mk" -o -name "*.sh" \) -print0 2>/dev/null)

# Double-insurance: inject GOTOOLCHAIN=auto into geoview Makefile directly
GEOVIEW_MK_CANDIDATES=(
  "feeds/passwall_packages/geoview/Makefile"
  "feeds/packages/net/geoview/Makefile"
)
for mk in "${GEOVIEW_MK_CANDIDATES[@]}"; do
  if [ -f "$mk" ]; then
    echo "[patch] Found geoview Makefile: $mk"
    if ! grep -qE '\bGOTOOLCHAIN\b' "$mk"; then
      # Inject after the first GO_PKG line, or at end of variable block
      sed -i '/^include.*golang-package/i export GOTOOLCHAIN=auto' "$mk"
      echo "[patch] Injected GOTOOLCHAIN=auto into: $mk"
    else
      sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$mk"
      echo "[patch] Updated GOTOOLCHAIN in: $mk"
    fi
  fi
done

# Sanity check: warn (not fail) if GOTOOLCHAIN=local is still present anywhere
remaining=$(grep -RInE '\bGOTOOLCHAIN=local\b' feeds/packages/lang/golang 2>/dev/null || true)
if [[ -n "$remaining" ]]; then
  echo "[patch] WARNING: GOTOOLCHAIN=local still found in golang framework:" >&2
  echo "$remaining" | head -n 20 >&2
  echo "[patch] This may cause geoview build failure if Go >= 1.24 is required." >&2
else
  echo "[patch] Confirmed: no GOTOOLCHAIN=local remaining in golang framework."
fi

echo "[patch] Go toolchain patch complete."

# ------------------------------------------------------------
# 1) System defaults (hostname, timezone)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/config/system" <<'EOF'
config system
  option hostname 'HarryWrt'
  option timezone 'HKT-8'
  option zonename 'Asia/Hong_Kong'
  option ttylogin '0'
  option log_proto 'stderr'
  option conloglevel '8'
  option cronloglevel '5'
EOF

# ------------------------------------------------------------
# 2) SSH login banner
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/banner" <<'EOF'
---------------------------------------------------------------
 _   _                           _  _   _  ____  _____
| | | | __ _ _ __ _ __ _   _    | || | | ||  _ \|_   _|
| |_| |/ _` | '__| '__| | | |   | || |_| || |_) | | |
|  _  | (_| | |  | |  | |_| |   |__   _  ||  _ <  | |
|_| |_|\__,_|_|  |_|   \__, |      |_| |_||_| \_\ |_|
                       |___/
---------------------------------------------------------------
 HarryWrt 24.10.5 | Clean Edition | Stable Base
 Based on OpenWrt | No Bloatware | Performance Focused
---------------------------------------------------------------
EOF

# ------------------------------------------------------------
# 3) MOTD (post-login message)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<'EOF'
HarryWrt 24.10.5 - Clean Edition (based on OpenWrt)
EOF

# ------------------------------------------------------------
# 4) UCI defaults: branding + release description
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<'EOF'
#!/bin/sh
set -eu

DESC="HarryWrt 24.10.5 Clean (based on OpenWrt)"

if [ -f /etc/openwrt_release ]; then
  sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='${DESC}'/" /etc/openwrt_release 2>/dev/null || true
fi

if [ -f /etc/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /etc/os-release 2>/dev/null || true
fi

if [ -f /usr/lib/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /usr/lib/os-release 2>/dev/null || true
fi

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap (stock-like)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-force-default-theme" <<'EOF'
#!/bin/sh
set -eu

if command -v uci >/dev/null 2>&1; then
  uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
  uci -q commit luci || true
fi

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-force-default-theme"

# ------------------------------------------------------------
# 6) First boot: musl loader symlink fix (runtime binary loader)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix" <<'EOF'
#!/bin/sh
set -eu
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix"

# ------------------------------------------------------------
# 7) First boot: dynamic procd guardian (no build-time init.d files)
#    Uses printf to avoid nested heredoc issues on BusyBox sh.
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-harrywrt-guardian" <<'EOF'
#!/bin/sh
set -eu

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
  '  [ -x /etc/init.d/firewall ] && /etc/init.d/firewall reload >/dev/null 2>&1 || true' \
  '  sleep 2' \
  '  [ -x /etc/init.d/passwall2 ] && /etc/init.d/passwall2 restart >/dev/null 2>&1 || true' \
  '}' \
  > /etc/init.d/harrywrt_guardian

chmod 0755 /etc/init.d/harrywrt_guardian
/etc/init.d/harrywrt_guardian enable >/dev/null 2>&1 || true
/etc/init.d/harrywrt_guardian start  >/dev/null 2>&1 || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-harrywrt-guardian"

# ------------------------------------------------------------
# 8) Optional first boot kick for passwall2 (only if installed)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/98-passwall2-autofix" <<'EOF'
#!/bin/sh
if [ -x /etc/init.d/passwall2 ] && [ ! -f /etc/passwall2_init_done ]; then
  /etc/init.d/firewall restart >/dev/null 2>&1 || true
  sleep 2
  /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
  touch /etc/passwall2_init_done
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/98-passwall2-autofix"

echo "DIY script executed successfully."
