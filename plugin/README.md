# Omarchy Remote — Omarchy shell plugin

A bar icon and panel for [omarchy-remote](../README.md): it lists every service this machine
exposes (Tailscale, Pangolin, Cloudflare) with its URL, provider and auth mode, and lets you
copy or open each URL. The icon is dimmed when nothing is exposed.

The plugin only runs `~/.local/bin/omarchy-remote list --json` (every 60 s by default, and when
the panel opens). It needs no privileges and never changes anything; exposing and removing
services stays in the CLI.

## Install (development)

```bash
ID=io.github.second-state.omarchy-remote
mkdir -p ~/.config/omarchy/plugins/$ID
cp manifest.json Panel.qml ~/.config/omarchy/plugins/$ID/
omarchy plugin validate ~/.config/omarchy/plugins/$ID
omarchy plugin enable $ID
```

`omarchy plugin add <git-url>` expects `manifest.json` at the repository root, so marketplace
distribution needs this folder published as its own repository.

## Use

- Click the icon to open the panel; right-click refreshes.
- In the panel: click a row (or Enter) copies its URL; the arrow button (or `O`) opens it; `R` refreshes.
- Scripts and tests can read the plugin's state while the screen is locked:
  `qs ipc -p /usr/share/omarchy/shell call omarchy-remote state`

Requires `wl-copy` (wl-clipboard) and `xdg-open`, both present on Omarchy.
