# RunPod noVNC Desktop Setup

Spin up a full XFCE desktop on a [RunPod](https://runpod.io) instance and access it from your browser via [noVNC](https://novnc.com/) — no local VNC client required.

## What this does

`setup_novnc.sh` installs and configures, in one shot:

- **XFCE4** — a lightweight desktop environment
- **TigerVNC** — the VNC server that renders the desktop
- **noVNC + websockify** — bridges VNC to a browser-accessible web page

The result: open a URL in your browser, log in with a password, and you have a full Linux desktop running inside your pod.

## Prerequisites

- A running RunPod pod (Ubuntu/Debian-based image, root access)
- Ability to expose an HTTP port on that pod from the RunPod dashboard

## Quick start

1. Copy `script.sh` into your pod (via the web terminal, `scp`, or by cloning this repo).
2. Run it:

   ```bash
   bash script.sh <your-password> <port>
   ```

   Example:

   ```bash
   bash script.sh 123123 8080
   ```

   Both arguments are optional — defaults are password `changeme123` and port `8080`. **Always set your own password.**

3. In the RunPod dashboard, go to **Edit Pod → Expose HTTP Ports** and add the port you used (e.g. `8080`).
4. Open the generated proxy URL in your browser:

   ```
   https://<pod-id>-8080.proxy.runpod.net/vnc.html
   ```

5. Enter your VNC password. You should land on an XFCE desktop.

## Installing Firefox (optional)

Once your desktop is up, install a browser inside it:

```bash
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:mozillateam/ppa

cat << 'EOF' > /etc/apt/preferences.d/mozilla-firefox
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

apt-get update
apt-get install -y firefox
```

This uses the Mozilla Team PPA rather than the default `apt` package, which on many Ubuntu images just installs a non-functional snap wrapper. Launch it from an XFCE terminal with `firefox`.

## Persistence

RunPod pods are **not persistent by default** — a restarted or recreated container loses everything installed by this script. You have two options:

- **Re-run the script** every time you get a fresh container (simplest, a few minutes each time).
- **Bake it into a custom Docker image**: install everything once in a `Dockerfile`, push it to a registry, and use that image as your pod's base — the desktop is then ready immediately on every launch. This is the recommended approach if you use this setup regularly.

## How it works / troubleshooting notes

- **`xstartup` must use `exec startxfce4`, not `startxfce4 &`.** Backgrounding the desktop process makes the startup script exit immediately, which VNC treats as "session ended" and kills the desktop within seconds. The script here is already written correctly, but if you edit `~/.vnc/xstartup` by hand, keep this in mind.
- **websockify is launched with `nohup ... & disown`.** RunPod's web terminal is a `docker exec` session — anything backgrounded with a plain `&` dies the moment that session disconnects. `nohup` + `disown` fully detaches the process so noVNC keeps running independent of your terminal tab.
- **Command not found after a pod restart?** The container was recreated (check the hostname/container ID in your prompt) — nothing persisted. Just re-run `setup_novnc.sh`.
- **"Waiting for service to respond" on the RunPod proxy page** usually means nothing is listening on the port you exposed. Check `ps aux | grep websockify` and the log at `/var/log/websockify.log`.
- **Blank grey screen after connecting** usually means `xstartup` didn't launch XFCE — check `~/.vnc/<hostname>:1.log` for errors.

## Useful commands

```bash
# Restart the VNC server
vncserver -kill :1
vncserver :1 -geometry 1280x720 -depth 24

# Check what's running
vncserver -list
ps aux | grep websockify

# View logs
tail -f /var/log/websockify.log
tail -f ~/.vnc/$(hostname):1.log
```
