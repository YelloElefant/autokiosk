#!/usr/bin/env bash
# Kiosk launcher - run by cage as the "kiosk" user via kiosk.service.
# Config lives in /etc/kiosk.conf (KIOSK_URL, EXTRA_FLAGS).

set -u

KIOSK_URL="http://localhost"
EXTRA_FLAGS=""
[ -f /etc/kiosk.conf ] && . /etc/kiosk.conf

# Must NOT be Chrome's default profile dir: since Chrome 136, --remote-debugging-port
# is silently ignored when using the default user data dir.
PROFILE="$HOME/.config/kiosk-chrome"
PREFS="$PROFILE/Default/Preferences"

# After a power cut Chrome thinks it crashed and shows a "restore pages?" bar.
# Lie to it and say the last exit was clean.
if [ -f "$PREFS" ]; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]*"/"exit_type":"Normal"/' "$PREFS"
fi

exec /usr/bin/google-chrome-stable \
  --user-data-dir="$PROFILE" \
  --kiosk \
  --ozone-platform=wayland \
  --no-first-run \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=Translate \
  --password-store=basic \
  --check-for-update-interval=31536000 \
  --autoplay-policy=no-user-gesture-required \
  --ignore-gpu-blocklist \
  --enable-features=VaapiVideoDecoder,AcceleratedVideoDecodeLinuxGL \
  --remote-debugging-port=9222 \
  --remote-allow-origins=* \
  $EXTRA_FLAGS \
  "$KIOSK_URL"
