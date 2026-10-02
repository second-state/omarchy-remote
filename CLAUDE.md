# omarchy-remote — notes for Claude Code

## What this is
Expose any local service on an Omarchy machine (model API, web app, desktop) with one command and a chosen auth mode — no containers/K8s/user system.
Core: `omarchy-remote expose <name> <port> --auth login|token|password|none | --private`.
Public path: Pangolin resource `<name>.<NS-delegated domain>` → site tunnel → 127.0.0.1:<port>. Private path: `tailscale serve --https=<port>`.
Built-in service: browser remote desktop (noVNC :6080 → wayvnc :5900 → Hyprland).
Long-term goal: a lightweight personal cloud on top of Omarchy (no Kubernetes, containers, or heavyweight user system):
"your own computer, managed by AI, reachable anywhere". Planned: zero-config access via a shared domain + self-hosted
Pangolin relay, an entry page, browser file access, agent skills to manage it in plain language, LAN-device proxying,
per-user desktops, and distribution through the Omarchy plugin marketplace.

## Layout
- `bin/omarchy-remote` — the CLI (bash). All logic lives here.
- `install.sh` — one-line installer: clones to `~/.local/share/omarchy-remote/src`, links the CLI into `~/.local/bin`, runs `setup`.
- `plugin/` — planned Quattro plugin (bar-widget + panel, QML). It must only call the CLI, never need privileges.
- `README.md` / `README.zh-CN.md` — user docs; keep both in sync.

## Conventions
- CLI runs as the desktop user; use `sudo` only for pacman, `tailscale serve`, and `pangolin service`.
- Pangolin automation goes through the Integration API (`pg_api`), key in `~/.config/omarchy-remote/pangolin.key` (0600, passed to curl via `-K <(...)`, never argv); org/site/domain ids in `pangolin.env`.
- Resources created by `expose` are named `omarchy-remote:<name>:<auth>`; `list` relies on that.
- Local services bind to 127.0.0.1 only. Never expose 5900/6080 on other interfaces.
- systemd **user** units: `omarchy-remote-vnc.service`, `omarchy-remote-web.service` (WantedBy=graphical-session.target).
- Must pass `shellcheck install.sh bin/omarchy-remote` (CI enforces it).
- Bump `VERSION` in the CLI for releases.

## Development setup
- Code is edited on the developer's Mac. The Omarchy test machine is reached over **Tailscale SSH**.
- Machine-specific details (hostname, user, URLs) go in `CLAUDE.local.md` — gitignored, never commit them.
- To test on the machine: push a branch, then on the machine run
  `OMARCHY_REMOTE_REF=<branch> bash install.sh` (or `git pull` in the src dir + `omarchy-remote setup`).

## Hard rules
- Never read, print, store, or type Pangolin site secrets, Tailscale auth keys, or passwords. The user enters them.
- Don't change Tailscale ACLs, Pangolin auth settings, or DNS without asking.
- Ask before anything that would cut off remote access to the test machine (stopping tailscale, the pangolin-site service, or rebooting).

## Gotchas learned
- macOS may not use Tailscale DNS → `*.ts.net` NXDOMAIN; per-domain fix: `/etc/resolver/ts.net` → `100.100.100.100`.
- Free Pangolin domains (`*.tunneled.to`) are reset by some ISPs; use a custom domain (CNAME, DNS-only / unproxied).
- Pangolin "Secret is incorrect" = masked or regenerated secret; regenerate and reconnect.
- Pangolin CLI: unit is `pangolin-site`; `pangolin service install|uninstall|status|logs site`; flags `--disable-clients --disable-ssh`.
- `tailscale ssh` may fail with "REMOTE HOST IDENTIFICATION HAS CHANGED": it checks against the host keys in the netmap (OpenSSH's), but Tailscale SSH presents its own key. Use plain `ssh <user>@<tailscale-ip>` instead (port 22 on the Tailscale IP is still served by Tailscale SSH).
- Pangolin API spec: `https://api.pangolin.net/v1/openapi.json`. Responses are `{data, success, error, message, status}`.
- `--auth login` admits Pangolin org members via SSO without an email code — test the OTP flow in a private window.
- A new Pangolin hostname takes ~30s (certificate); a deleted one may answer for a few seconds.
- Only NS-delegated Pangolin domains can host `<name>.<domain>`; CNAME "single domain" entries cannot.
- When testing `password`/`token` modes, keep generated credentials in a 0600 file on the test machine and read them there; don't print them into the session.
- noVNC settings live in `$NOVNC_DIR/defaults.json`; `index.html` symlinks to `vnc.html` so `/` opens the desktop.

## Roadmap
1. ~~Verify `setup` end-to-end on the test machine~~ — done 2026-10-02 (legacy units migrated, desktop reachable via Tailscale and Pangolin).
2. Survive reboot: auto-login / disk unlock so remote access comes back unattended.
3. Dedicated 1080p headless output for remote sessions.
4. Quattro plugin (status + copy URL + toggle).
5. Sunshine + Moonlight low-latency mode; reverse-proxy other LAN devices.
