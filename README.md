# kiosk

Turns a fresh Ubuntu Server box (x86_64, Intel iGPU) into a full-screen Chrome kiosk, using cage as the Wayland compositor and systemd to keep it alive. Chrome's DevTools (CDP) port is exposed on the LAN through socat so a controller can drive the screen remotely.

## Install

```bash
git clone <this-repo> kiosk
cd kiosk
sudo ./setup.sh http://your-page-url
```

Re-running is safe. Existing `/etc/kiosk.conf` and `/etc/default/kiosk-cdp` are left alone.

## What it sets up

| Piece | Where | Does |
|---|---|---|
| `kiosk` user | `/home/kiosk` | Runs the browser, in `video`, `render`, `input` groups |
| `kiosk.sh` | `/usr/local/bin/kiosk.sh` | Launches Chrome with kiosk + VA-API flags |
| `kiosk.service` | `/etc/systemd/system/` | Runs `cage -- kiosk.sh` on tty1, restarts on crash |
| `kiosk-cdp.service` | `/etc/systemd/system/` | socat `0.0.0.0:9223` -> `127.0.0.1:9222` |
| PAM | `/etc/pam.d/cage` | Gives the service a logind session and seat |
| Config | `/etc/kiosk.conf` | `KIOSK_URL`, `EXTRA_FLAGS` |
| CDP config | `/etc/default/kiosk-cdp` | `CDP_LISTEN_PORT`, `CDP_TARGET_PORT` |

## Day to day

```bash
# change the page
sudo nano /etc/kiosk.conf && sudo systemctl restart kiosk

# logs
sudo journalctl -u kiosk -f
sudo journalctl -u kiosk-cdp -f

# check CDP from another machine (use the IP, not a hostname)
curl http://<kiosk-ip>:9223/json/version
```

## Notes

- Chrome comes from Google's .deb, not the Ubuntu snap.
- Chrome uses its own profile dir (`~/.config/kiosk-chrome`). Since Chrome 136, `--remote-debugging-port` is ignored on the default profile.
- CDP on 9223 is unauthenticated and gives full control of the browser. Keep the box on a trusted network, or firewall it: `sudo ufw allow from <controller-ip> to any port 9223`.
- `intel-media-va-driver-non-free` lives in the `multiverse` component. Make sure it is enabled.
- Verify hardware video decode with `sudo -u kiosk vainfo` or `sudo intel_gpu_top` while a video plays.
