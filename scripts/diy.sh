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
# - [plus only] AdGuard Home DNS handoff (dnsmasq -> port 5353)
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
  AGH_BANNER_LINE=" AdGuard Home: http://192.168.1.1:3000 (default: admin/harrywrt)"$'\n'" Run: adguard-passwd newpassword  to change credentials!"$'\n'"---------------------------------------------------------------"
else
  AGH_BANNER_LINE=""
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
${AGH_BANNER_LINE}
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
# 10) [Plus only] AdGuard Home full pre-configuration
#     - Pre-written AdGuardHome.yaml (skips setup wizard)
#     - No password (consistent with LuCI behavior)
#     - DoH upstreams via IP (no domain resolution needed)
#     - dnsmasq moved to port 5353; AdGuard Home takes port 53
#     - UPnP installed but disabled by default — user opts in via LuCI
#     - LuCI menu entry pointing to port 3000
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then

# Generate bcrypt hash for default password 'harrywrt' at build time
# apache2-utils (htpasswd) is installed in the CI apt step
if ! command -v htpasswd >/dev/null 2>&1; then
  echo "[adguardhome] ERROR: htpasswd not found. Install apache2-utils." >&2
  exit 1
fi
AGH_PASS_HASH=$(htpasswd -bnBC 10 admin harrywrt | cut -d: -f2 | tr -d '\n')
if [[ -z "${AGH_PASS_HASH}" ]]; then
  echo "[adguardhome] ERROR: htpasswd returned empty hash" >&2
  exit 1
fi
echo "[adguardhome] Password hash generated successfully"
mkdir -p "${FILES_DIR}/etc/adguardhome"
cat > "${FILES_DIR}/etc/adguardhome/adguardhome.yaml" <<'EOF'
http:
  pprof:
    port: 6060
    enabled: false
  address: 0.0.0.0:3000
  session_ttl: 720h
users:
  - name: admin
    password: "AGH_PASS_HASH_PLACEHOLDER"
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: ""
theme: auto
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  anonymize_client_ip: false
  ratelimit: 20
  ratelimit_subnet_len_ipv4: 24
  ratelimit_subnet_len_ipv6: 56
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
  upstream_dns_file: ""
  bootstrap_dns:
    - 1.1.1.1
    - 8.8.8.8
  fallback_dns: []
  upstream_mode: parallel
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
  cache_enabled: true
  cache_size: 67108864
  cache_ttl_min: 180
  cache_ttl_max: 1800
  cache_optimistic: true
  cache_optimistic_answer_ttl: 30s
  cache_optimistic_max_age: 12h
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: true
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  bootstrap_prefer_ipv6: false
  upstream_timeout: 10s
  private_networks: []
  use_private_ptr_resolvers: false
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
  serve_plain_dns: true
  hostsfile_enabled: true
  pending_requests:
    enabled: true
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  port_dns_over_quic: 853
  port_dnscrypt: 0
  dnscrypt_config_file: ""
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
  strict_sni_check: false
querylog:
  dir_path: ""
  ignored: []
  interval: 24h
  size_memory: 1000
  enabled: true
  ignored_enabled: false
  file_enabled: true
statistics:
  dir_path: ""
  ignored: []
  interval: 24h
  enabled: true
  ignored_enabled: false
filters:
  - enabled: false
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: false
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  local_domain_name: lan
  dhcpv4:
    gateway_ip: ""
    subnet_mask: ""
    range_start: ""
    range_end: ""
    lease_duration: 86400
    icmp_timeout_msec: 1000
    options: []
  dhcpv6:
    range_start: ""
    lease_duration: 86400
    ra_slaac_only: false
    ra_allow_slaac: false
filtering:
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_services:
    schedule:
      time_zone: Local
    ids: []
  protection_disabled_until: null
  safe_search:
    enabled: false
    bing: true
    duckduckgo: true
    ecosia: true
    google: true
    pixabay: true
    yandex: true
    youtube: true
  blocking_mode: default
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  rewrites: []
  safebrowsing_cache_size: 1048576
  safesearch_cache_size: 1048576
  parental_cache_size: 1048576
  cache_time: 30
  filters_update_interval: 24
  blocked_response_ttl: 10
  filtering_enabled: true
  rewrites_enabled: true
  parental_enabled: false
  safebrowsing_enabled: false
  protection_enabled: true
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log:
  enabled: true
  file: ""
  max_backups: 0
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 34
EOF

# Inject the bcrypt password hash into the yaml
sed -i "s|AGH_PASS_HASH_PLACEHOLDER|${AGH_PASS_HASH}|" \
  "${FILES_DIR}/etc/adguardhome/adguardhome.yaml"

# Set correct permissions on config file
# adguardhome runs as unprivileged user (adguardh) via ujail
chmod 640 "${FILES_DIR}/etc/adguardhome/adguardhome.yaml"

# uci-defaults: restore pre-config at first boot
# The adguardhome package postinst may overwrite the config,
# so we restore from /rom (the read-only firmware copy) after postinst runs.
cat > "${FILES_DIR}/etc/uci-defaults/60-adguardhome-dns" <<'EOF'
#!/bin/sh
# Move dnsmasq off port 53 so AdGuard Home can bind it.
uci -q set dhcp.@dnsmasq[0].port=5353
uci -q commit dhcp

# Restore pre-configured AdGuardHome yaml from /rom in case postinst overwrote it
if [ -f /rom/etc/adguardhome/adguardhome.yaml ]; then
  mkdir -p /etc/adguardhome
  cp -f /rom/etc/adguardhome/adguardhome.yaml /etc/adguardhome/adguardhome.yaml
  chown root:adguardhome /etc/adguardhome/adguardhome.yaml 2>/dev/null || true
  chmod 640 /etc/adguardhome/adguardhome.yaml
fi

# Enable and start AdGuard Home
/etc/init.d/adguardhome enable 2>/dev/null || true

# Create a boot-time script to pre-create AdGuardHome data files
# /var/lib is tmpfs and cleared on every boot, so we must recreate on each boot
cat > /etc/init.d/adguardhome_prestart <<'INITEOF'
#!/bin/sh /etc/rc.common
START=18
STOP=90

start() {
    mkdir -p /var/lib/adguardhome/data/filters
    touch /var/lib/adguardhome/data/querylog.json
    chown -R adguardhome:adguardhome /var/lib/adguardhome 2>/dev/null || true
    chmod 750 /var/lib/adguardhome
    chmod 750 /var/lib/adguardhome/data
}
INITEOF
chmod 0755 /etc/init.d/adguardhome_prestart
/etc/init.d/adguardhome_prestart enable

/etc/init.d/adguardhome restart 2>/dev/null || true
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/60-adguardhome-dns"

# adguard-passwd helper script
# Usage: adguard-passwd <newpassword> [newusername]
mkdir -p "${FILES_DIR}/usr/bin"
cat > "${FILES_DIR}/usr/bin/adguard-passwd" <<'EOF'
#!/bin/sh
# adguard-passwd — Change AdGuard Home credentials
# Usage: adguard-passwd <newpassword> [newusername]

YAML="/etc/adguardhome/adguardhome.yaml"
NEW_PASS="$1"
NEW_USER="${2:-}"

if [ -z "$NEW_PASS" ]; then
    echo "Usage: adguard-passwd <newpassword> [newusername]"
    echo "Example: adguard-passwd mysecretpassword"
    echo "         adguard-passwd mysecretpassword myadmin"
    exit 1
fi

if [ ! -f "$YAML" ]; then
    echo "Error: AdGuard Home config not found at $YAML"
    exit 1
fi

# Auto-install apache-utils if htpasswd is not available
if ! command -v htpasswd >/dev/null 2>&1; then
    echo "htpasswd not found, installing apache-utils..."
    if command -v apk >/dev/null 2>&1; then
        apk update && apk add apache-utils
    elif command -v opkg >/dev/null 2>&1; then
        opkg update && opkg install apache-utils
    else
        echo "Error: Cannot install apache-utils. No package manager found."
        exit 1
    fi
fi

if ! command -v htpasswd >/dev/null 2>&1; then
    echo "Error: Failed to install apache-utils."
    exit 1
fi

HASH=$(htpasswd -bnBC 10 admin "${NEW_PASS}" | cut -d: -f2)

/etc/init.d/adguardhome stop
sed -i "s|password:.*|password: \"${HASH}\"|" "$YAML"

if [ -n "$NEW_USER" ]; then
    sed -i "s|    name:.*|    name: ${NEW_USER}|" "$YAML"
fi

/etc/init.d/adguardhome start
echo "Done. AdGuard Home credentials updated."
EOF
chmod 0755 "${FILES_DIR}/usr/bin/adguard-passwd"

# LuCI AdGuard Home entry — modern ucode view (24.10+ compatible)
# Uses a JS view that redirects to port 3000 using current hostname
mkdir -p "${FILES_DIR}/usr/share/luci/menu.d"
cat > "${FILES_DIR}/usr/share/luci/menu.d/adguardhome.json" <<'EOF'
{
  "admin/services/adguardhome": {
    "title": "AdGuard Home",
    "order": 60,
    "action": {
      "type": "view",
      "path": "adguardhome/redirect"
    }
  }
}
EOF

mkdir -p "${FILES_DIR}/www/luci-static/resources/view/adguardhome"
cat > "${FILES_DIR}/www/luci-static/resources/view/adguardhome/redirect.js" <<'EOF'
'use strict';
'require view';

return view.extend({
    render: function() {
        var host = window.location.hostname;
        var url = 'http://' + host + ':3000';
        var btn = E('a', {
            'href': url,
            'target': '_blank',
            'rel': 'noopener noreferrer',
            'style': 'display:inline-block;margin-top:1em;padding:0.5em 1.2em;background:#367fa9;color:#fff;text-decoration:none;border-radius:4px;font-size:1em;'
        }, 'Open AdGuard Home');
        return E('div', { 'style': 'padding:1em;' }, [
            E('h2', {}, 'AdGuard Home'),
            E('p', {}, 'AdGuard Home runs on port 3000. Click the button below to open it in a new tab.'),
            E('p', {}, [ E('code', {}, url) ]),
            btn,
            E('hr', {}),
            E('h3', {}, 'Change Username / Password'),
            E('p', {}, 'Use the built-in helper script over SSH (auto-installs dependencies if needed):'),
            E('pre', { 'style': 'background:#f4f4f4;padding:0.8em;border-radius:4px;font-size:0.9em;overflow-x:auto;' }, [
                '# Change password only\n',
                'adguard-passwd newpassword\n\n',
                '# Change both username and password\n',
                'adguard-passwd newpassword newusername'
            ])
        ]);
    },
    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
EOF

# Remove old Lua controller if present
rm -f "${FILES_DIR}/usr/lib/lua/luci/controller/adguardhome.lua"

fi

echo "DIY script executed successfully for OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}."
