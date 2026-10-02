# omarchy-remote

Use your [Omarchy](https://omarchy.org) desktop from any browser — at home, on your
phone, or shared with someone else — without containers, Kubernetes, or a user system.

```
browser ──► Tailscale (private) ─┐
        └─► Pangolin (public) ───┴─► noVNC :6080 ──► wayvnc :5900 ──► Hyprland
```

- **wayvnc** streams the Hyprland desktop and sends keyboard/mouse back.
- **noVNC** turns it into a web page (auto-connect, auto-scale).
- Both listen on `127.0.0.1` only. Nothing is reachable until you publish it:
  - **Tailscale** — private HTTPS URL for your own devices. Peer-to-peer, fastest.
  - **Pangolin** — public URL on your own domain, behind a login (email one-time code).
    No public IP or open ports needed.
- No monitor attached? A headless (virtual) output is created automatically.

[中文说明](README.zh-CN.md)

## Install

Run as your normal user on the Omarchy machine:

```bash
curl -fsSL https://raw.githubusercontent.com/second-state/omarchy-remote/main/install.sh | bash
```

This installs `wayvnc`, downloads noVNC to `~/.local/share/omarchy-remote/`, and starts
two user services (`omarchy-remote-vnc`, `omarchy-remote-web`) that start with your desktop.

## Publish

### Private: Tailscale

```bash
omarchy-remote tailscale on
# -> https://<machine>.<tailnet>.ts.net
```

Open the URL on any device logged into your tailnet.

### Public with login: Pangolin

1. Create a free account at [app.pangolin.net](https://app.pangolin.net) (or self-host Pangolin)
   and add a **Site**. Copy the Site ID and Secret.
2. On the Omarchy machine:
   ```bash
   omarchy-remote pangolin connect   # prompts for ID and secret (secret is not echoed)
   ```
3. In the dashboard, add a **public HTTP resource** targeting `http://127.0.0.1:6080` on that site.
4. Under **Authentication**, enable **Email whitelist** and add the people you allow.
5. Recommended: use your own domain (**Domains → Add → Single domain (CNAME)**, then add the
   two CNAME records at your DNS provider with proxying **off** / "DNS only").

## Commands

```
omarchy-remote status                 show what's running and where
omarchy-remote tailscale on|off
omarchy-remote pangolin connect|status|logs|disconnect
omarchy-remote quality 0-9            lower = faster on slow links
omarchy-remote restart
omarchy-remote uninstall
```

Settings can be overridden in `~/.config/omarchy-remote/config` (ports, noVNC quality, etc.).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `DNS_PROBE_FINISHED_NXDOMAIN` on a `*.ts.net` URL (macOS) | Your Mac isn't using Tailscale DNS. Enable *Use Tailscale DNS settings*, or only for ts.net: `echo "nameserver 100.100.100.100" \| sudo tee /etc/resolver/ts.net` |
| `ERR_CONNECTION_RESET` on a free Pangolin domain (`*.tunneled.to` …) | Some ISPs/networks block free tunnel domains. Use your own domain. |
| Page loads but stays black/grey | The WebSocket is blocked on that network (same cause as above), or the services are down: `omarchy-remote status`. |
| Pangolin log: `Secret is incorrect` | The secret was masked or regenerated. Regenerate it in the dashboard and run `omarchy-remote pangolin connect` again. |
| Slow | Use the Tailscale URL (direct) instead of Pangolin (relayed), or `omarchy-remote quality 4`. |
| Nothing works after reboot | The desktop must be logged in (services start with the graphical session). Disk encryption / login screen will block remote access. |

## Security notes

- Anyone who passes the login gets **full control** of your desktop session.
- wayvnc has no password and listens on localhost; any local user on the machine could connect to it.
- All remote users see the **same** desktop (multi-user sessions are not supported yet).

## Roadmap

- Omarchy Quattro plugin: bar widget + panel (see [`plugin/`](plugin/))
- Dedicated 1080p virtual output for remote sessions
- Low-latency streaming via Sunshine + Moonlight
- Reverse-proxy other LAN devices (`nas.example.com`, …)

## License

MIT. noVNC (MPL-2.0), wayvnc (ISC) and the Pangolin CLI (AGPL-3.0 / commercial) are
downloaded separately and keep their own licenses.
