#!/usr/bin/env bash
# One-shot kiosk setup for Ubuntu Server (Intel iGPU).
# Run from the folder containing kiosk.sh, kiosk.service and kiosk-cdp.service:
#   sudo ./setup.sh [url]

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"

URL="${1:-http://localhost}"

echo "==> packages"
apt-get update
apt-get install -y cage libgl1-mesa-dri libegl1 mesa-va-drivers \
  intel-media-va-driver-non-free vainfo intel-gpu-tools \
  fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji wget socat

if ! command -v google-chrome-stable >/dev/null; then
  echo "==> google chrome (.deb, not the snap)"
  wget -qO /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt-get install -y /tmp/chrome.deb
  rm -f /tmp/chrome.deb
fi

echo "==> kiosk user"
if ! id kiosk >/dev/null 2>&1; then
  useradd -m -s /usr/sbin/nologin kiosk
fi
usermod -aG video,render,input kiosk

echo "==> launcher + config"
install -m 755 kiosk.sh /usr/local/bin/kiosk.sh
if [ ! -f /etc/kiosk.conf ]; then
  cat > /etc/kiosk.conf <<EOF
# Page the kiosk shows. Edit then: sudo systemctl restart kiosk
KIOSK_URL="$URL"
# Extra chrome flags, space separated
EXTRA_FLAGS=""
EOF
fi

echo "==> PAM (gives the service a real logind session + seat)"
cat > /etc/pam.d/cage <<'EOF'
auth           required        pam_unix.so nullok
account        required        pam_unix.so
session        required        pam_unix.so
session        required        pam_systemd.so
EOF

echo "==> systemd"
install -m 644 kiosk.service /etc/systemd/system/kiosk.service
systemctl daemon-reload
systemctl disable --now getty@tty1.service 2>/dev/null || true
systemctl enable --now kiosk.service

echo "==> CDP proxy (socat, LAN -> localhost:9222)"
if [ ! -f /etc/default/kiosk-cdp ]; then
  cat > /etc/default/kiosk-cdp <<'EOF2'
# Port other machines connect to
CDP_LISTEN_PORT=9223
# Chrome's local debug port (matches --remote-debugging-port in kiosk.sh)
CDP_TARGET_PORT=9222
# Only these source IPs may connect. Tighten to your controller, e.g. 192.168.1.50/32
CDP_ALLOW_RANGE=192.168.0.0/16
EOF2
fi
install -m 644 kiosk-cdp.service /etc/systemd/system/kiosk-cdp.service
systemctl daemon-reload
systemctl enable --now kiosk-cdp.service

echo
echo "==> VA-API check (want iHD + H264/HEVC/VP9 VLD lines)"
sudo -u kiosk vainfo 2>/dev/null | grep -E "Driver version|VLD" || echo "vainfo failed - check /dev/dri perms"

echo
echo "done. logs: journalctl -u kiosk -f"
echo "CDP from LAN: curl http://<this-ip>:9223/json   (allowed range in /etc/default/kiosk-cdp)"
echo "change page: sudo nano /etc/kiosk.conf && sudo systemctl restart kiosk"
