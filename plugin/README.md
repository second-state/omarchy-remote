# Omarchy shell plugin

The bar icon + panel for omarchy-remote lives in its own repository, because
`omarchy plugin add` needs `manifest.json` at the repository root:

**https://github.com/second-state/omarchy-remote-plugin**

```bash
omarchy plugin add https://github.com/second-state/omarchy-remote-plugin --enable
```

It reads `omarchy-remote list --json` (defined in `bin/omarchy-remote`). Keep that JSON
shape backward compatible: `services[]` with `name`, `provider`, `auth`, `url`, `target`;
`desktop.vnc` / `desktop.web`; `errors[]`; `version`.
