# Omarchy plugin (planned)

A Quattro plugin (`bar-widget` + `panel`) that shows remote-access status and the
current URL, with buttons to copy the link and toggle Tailscale publishing.

It will only call the `omarchy-remote` CLI — all privileged setup stays in the CLI,
so the plugin itself needs no extra permissions.
