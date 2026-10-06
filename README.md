# omarchy-remote

Reach the services on your [Omarchy](https://omarchy.org) machine from anywhere — a local
model API, a web app you are building, or the desktop itself — with one command and a login
of your choice. No containers, no Kubernetes, no public IP, no open ports.

```
                         ┌─► 127.0.0.1:11434  (e.g. a model API)
browser / app ─► Pangolin ┼─► 127.0.0.1:3000   (e.g. your web app)
   (public + login)       └─► 127.0.0.1:6080   (the desktop, via noVNC)
your own devices ─► Tailscale (private, peer-to-peer)
```

```bash
omarchy-remote expose app 3000
# -> https://<machine>.<tailnet>.ts.net:3000 (default: Tailscale, only your own devices)
omarchy-remote expose app 3000 --auth login --allow friend@example.com
# -> https://app.home.example.com (public; browser login, your friend gets an email code)
omarchy-remote expose ai 11434 --auth bearer
# -> https://ai.example.com       (public; OpenAI-style clients send "Authorization: Bearer <key>")
```

Private URLs go through **Tailscale** (free for personal use, no domain needed). Public URLs
go through **Pangolin** (browser login, tokens, passwords) or **Cloudflare** (API keys checked
at Cloudflare's edge — works with OpenAI-compatible clients and SDKs, including streaming).

How your service runs (a binary, a script, a container) is up to you — `expose` only needs a
port on `127.0.0.1`. The tool also ships a browser remote desktop as a ready-made service.

[中文说明](README.zh-CN.md)

## Install

Run as your normal user on the Omarchy machine:

```bash
curl -fsSL https://raw.githubusercontent.com/second-state/omarchy-remote/main/install.sh | bash
```

This also sets up the remote desktop: it installs `wayvnc`, downloads noVNC to
`~/.local/share/omarchy-remote/`, and starts two user services (`omarchy-remote-vnc` on
`127.0.0.1:5900`, `omarchy-remote-web` on `127.0.0.1:6080`) that start with your desktop.
Nothing is reachable from outside until you expose it.

To update later, run the same command again.

## One-time setup: Tailscale (private URLs)

Requires Tailscale installed and logged in on this machine (`sudo pacman -S tailscale`,
`sudo systemctl enable --now tailscaled`, `sudo tailscale up`). The first time you publish,
Tailscale may print a link asking you to enable Serve / HTTPS certificates for your tailnet —
open it, approve, and run the command again.

Optional, so `expose` doesn't need sudo: `sudo tailscale set --operator=$USER`.

## One-time setup: Pangolin (public URLs)

[Pangolin](https://pangolin.net) is the tunnel and login layer. You need an account
([app.pangolin.net](https://app.pangolin.net), or self-hosted Pangolin ≥ 1.22.0) and a domain.

1. **Connect this machine as a site.** In the dashboard: Sites → Add site, copy the Site ID
   and Secret, then:
   ```bash
   omarchy-remote pangolin connect   # prompts for ID and secret (secret is not echoed)
   ```
   If the Pangolin CLI is missing, this first downloads and runs its official installer
   (`https://static.pangolin.net/get-cli.sh`).
2. **Delegate a subdomain to Pangolin**, so every new service gets an address automatically.
   Dashboard: Domains → Add domain → **Domain delegation (NS)**, e.g. `home.example.com`. Then
   at your DNS provider add the NS records it shows for `home` (usually
   `ns1/ns2/ns3.pangolin-ns.net`). Your main domain stays where it is.
3. **Create an API key** (Organization → API Keys) with read/write on resources, targets,
   domains, sites and access tokens, then:
   ```bash
   omarchy-remote pangolin login     # asks for the org ID and the key (hidden)
   ```
   The key is stored in `~/.config/omarchy-remote/pangolin.key` (mode 600).

## One-time setup: Cloudflare (public URLs, API keys)

Needs a domain on Cloudflare (the free plan is enough). Services get `https://<name>.<domain>`
(one level below the domain, so Cloudflare's free certificate covers them).

1. Create an API token: My Profile → API Tokens → Create Token → Custom token, with
   **Account: Cloudflare Tunnel (Edit)** and **Zone: DNS (Edit), Zone WAF (Edit), Zone (Read)**,
   limited to your account and that zone.
2. On the Omarchy machine:
   ```bash
   omarchy-remote cloudflare login   # asks for the token (hidden) and the domain
   ```
   The first `expose` creates a tunnel named `omarchy-remote-<hostname>`, downloads
   `cloudflared` if needed, and runs it as the user service `omarchy-remote-tunnel`.

Existing DNS records are never overwritten — pick a name that isn't in use.

## Expose a service

```bash
omarchy-remote expose <name> <port>                 # private: https://<machine>.ts.net:<port>
omarchy-remote expose <name> <port> --auth <mode>   # public:  https://<name>.<your-domain>
omarchy-remote list
omarchy-remote unexpose <name>
```

Without `--auth` the URL is private (Tailscale). With `--auth` it is public, through the
provider in `--via pangolin|cloudflare`, or the default set with
`omarchy-remote config set public <provider>` (initially `pangolin`; `--auth bearer` always
uses Cloudflare).

| `--auth` | For | How to get in | Share with someone | Providers |
|---|---|---|---|---|
| `login` | people, in a browser | login page: members of your Pangolin org sign in with their account; others get an email code | `--allow a@x.com,b@y.com` | Pangolin |
| `token` | programs / APIs | headers `P-Access-Token-Id` + `P-Access-Token`, or `?p_token=<id>.<token>` | give them the token | Pangolin |
| `password` | programs and browsers | HTTP Basic: `curl -u user:pass …` or `https://user:pass@host/` | give them the password | Pangolin |
| `bearer` | programs, OpenAI-style clients | `Authorization: Bearer <key>` (e.g. `base_url=https://ai.example.com/v1`, `api_key=<key>`) | give them the key | Cloudflare |
| `none` | everyone | no login — requires `--yes-public` | share the URL | Pangolin, Cloudflare |

Passwords, tokens and keys are generated for you and **printed once** — save them.

A new Pangolin address needs about 30 seconds for its certificate (404 / connection errors until
then). `expose --auth bearer` waits until Cloudflare refuses keyless requests before it reports
success (usually 10–30 s). After `unexpose`, an address may keep answering for a few seconds.

> `bearer` uses one Cloudflare WAF custom rule per service; the free plan allows 5 custom rules
> per domain (shared with any rules you made yourself). Anyone who can open your Cloudflare
> dashboard can read the keys in those rules.

### The remote desktop

```bash
omarchy-remote expose desktop 6080
omarchy-remote expose desktop 6080 --auth login --allow you@example.com
```

Opening the URL connects automatically and scales the desktop to your window.
No monitor attached? The desktop service tries to create a headless (virtual) output.

## Bar widget (Omarchy plugin)

```bash
omarchy plugin add https://github.com/second-state/omarchy-remote-plugin --enable
```

Shows what this machine exposes, with copy/open buttons for each URL
([details](https://github.com/second-state/omarchy-remote-plugin)).

## Commands

```
omarchy-remote expose <name> <port>   private URL via Tailscale
omarchy-remote expose <name> <port> --auth login|token|password|none [--allow emails] [--user name] [--via pangolin]
omarchy-remote expose <name> <port> --auth bearer|none [--via cloudflare]
omarchy-remote unexpose <name>
omarchy-remote config set public pangolin|cloudflare
omarchy-remote list                   show exposed services
omarchy-remote status                 desktop services and connections
omarchy-remote pangolin connect|login|status|logs|disconnect
omarchy-remote cloudflare login|status
omarchy-remote tailscale on|off       publish the desktop at https://<machine>.ts.net/ (tailnet only)
omarchy-remote quality 0-9            desktop image quality; lower = faster on slow links
omarchy-remote restart
omarchy-remote uninstall
```

Settings can be overridden in `~/.config/omarchy-remote/config` (ports, noVNC quality, etc.).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `DNS_PROBE_FINISHED_NXDOMAIN` on a `*.ts.net` URL (macOS) | Your Mac isn't using Tailscale DNS. Enable *Use Tailscale DNS settings*, or only for ts.net: `echo "nameserver 100.100.100.100" \| sudo tee /etc/resolver/ts.net` |
| New URL returns 404 or won't connect | The certificate is still being issued; wait ~30 s. |
| New Cloudflare URL: "server not found" on one device only | That device looked the name up before it existed and cached the miss (up to 30 min). Wait, or flush its DNS cache. |
| `--auth login` opens without asking for a code | You are already signed in to Pangolin in that browser (org members get in directly). Try a private window. |
| `ERR_CONNECTION_RESET` on a free Pangolin domain (`*.tunneled.to` …) | Some ISPs/networks block free tunnel domains. Use your own domain. |
| Desktop page loads but stays black/grey | The WebSocket is blocked on that network (same cause as above), or the services are down: `omarchy-remote status`. |
| Pangolin log: `Secret is incorrect` | The secret was masked or regenerated. Regenerate it in the dashboard and run `omarchy-remote pangolin connect` again. |
| `Not logged in to Pangolin` / `HTTP 401: Invalid API key` | Run `omarchy-remote pangolin login` (again) with a valid API key. |
| Desktop is slow | Use a private (Tailscale) URL — direct — instead of Pangolin (relayed), or `omarchy-remote quality 4`. |
| Nothing works after reboot | The desktop must be logged in (services start with the graphical session). Disk encryption / login screen will block remote access. If you installed 0.2 or earlier, re-run the installer: it fixes a unit-ordering bug that stopped the desktop web service from starting at login. |

## Security notes

- Exposed services only need to listen on `127.0.0.1`; Pangolin reaches them through the site tunnel.
- Treat tokens and passwords like keys: anyone who has one gets in. To revoke, `unexpose` and expose again.
- Anyone who passes the desktop login gets **full control** of your desktop session.
- wayvnc has no password and listens on localhost; any local user on the machine could connect to it.
- All remote desktop users see the **same** desktop (multi-user sessions are not supported yet).

## Roadmap

- Dedicated 1080p virtual output for remote sessions
- Low-latency streaming via Sunshine + Moonlight

## License

MIT. noVNC (MPL-2.0), wayvnc (ISC) and the Pangolin CLI (AGPL-3.0 / commercial) are
downloaded separately and keep their own licenses.
