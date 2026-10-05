# omarchy-remote

在任何地方访问你 [Omarchy](https://omarchy.org) 电脑上的服务：本地模型的 API、你正在开发的网页，或者桌面本身。一条命令暴露出去，再选一种登录方式。不需要容器、不需要 Kubernetes、不需要公网 IP，也不用开端口。

```
                         ┌─► 127.0.0.1:11434  （比如模型 API）
浏览器 / 程序 ─► Pangolin ┼─► 127.0.0.1:3000   （比如你的网页）
   （公网 + 登录）        └─► 127.0.0.1:6080   （桌面，通过 noVNC）
你自己的设备 ─► Tailscale（私有，点对点直连）
```

```bash
omarchy-remote expose app 3000
# -> https://<机器名>.<tailnet>.ts.net:3000（默认走 Tailscale，只有你自己的设备能访问）
omarchy-remote expose app 3000 --auth login --allow friend@example.com
# -> https://app.home.example.com（公网；浏览器登录，朋友用邮箱验证码进入）
omarchy-remote expose ai 11434 --auth token
# -> https://ai.home.example.com （公网；程序带访问令牌调用）
```

私有地址走 **Tailscale**（个人使用免费，不需要域名）。公网地址走 **Pangolin**；Cloudflare 作为另一个选择正在计划中（`--via cloudflare`）。

服务怎么跑（二进制、脚本还是容器）由你决定，`expose` 只要求它在 `127.0.0.1` 上监听一个端口。工具还自带一个浏览器远程桌面，作为现成的服务。

## 安装

在 Omarchy 机器上，用普通用户执行：

```bash
curl -fsSL https://raw.githubusercontent.com/second-state/omarchy-remote/main/install.sh | bash
```

安装时会顺带配好远程桌面：安装 `wayvnc`，把 noVNC 下载到 `~/.local/share/omarchy-remote/`，并启动两个随桌面自启的用户服务（`omarchy-remote-vnc` 在 `127.0.0.1:5900`，`omarchy-remote-web` 在 `127.0.0.1:6080`）。在你执行 expose 之前，外部什么都访问不到。

以后要升级，再执行一次同样的命令即可。

## 一次性配置：Tailscale（私有地址）

前提：这台机器已经装好并登录了 Tailscale（`sudo pacman -S tailscale`、`sudo systemctl enable --now tailscaled`、`sudo tailscale up`）。第一次发布时，Tailscale 可能会打印一个链接，要求你为 tailnet 开启 Serve / HTTPS 证书：打开链接批准后，再执行一次命令。

可选：执行一次 `sudo tailscale set --operator=$USER`，以后 `expose` 就不需要 sudo。

## 一次性配置：Pangolin（公网地址）

[Pangolin](https://pangolin.net) 负责内网穿透和登录。你需要一个账号（[app.pangolin.net](https://app.pangolin.net)，或自建 Pangolin，版本不低于 1.22.0）和一个域名。

1. **把这台机器接入为站点。** 在后台：站点 → 添加站点，复制站点 ID 和密钥，然后执行：
   ```bash
   omarchy-remote pangolin connect   # 依次输入 ID 和密钥（密钥不会显示在屏幕上）
   ```
   如果还没装 Pangolin CLI，这条命令会先下载并运行它的官方安装脚本（`https://static.pangolin.net/get-cli.sh`）。
2. **把一个子域名委托给 Pangolin**，这样每个新服务都会自动获得地址。后台：域名 → 添加域 → **域委派（NS）**，比如填 `home.example.com`。然后到你的 DNS 服务商那里，为 `home` 添加后台显示的 NS 记录（通常是 `ns1/ns2/ns3.pangolin-ns.net`）。主域名不用迁移。
3. **创建 API 密钥**（组织 → API 密钥），勾选资源、目标、域名、站点和访问令牌的读写权限，然后执行：
   ```bash
   omarchy-remote pangolin login     # 输入组织 ID 和密钥（密钥不会显示）
   ```
   密钥保存在 `~/.config/omarchy-remote/pangolin.key`（权限 600）。

## 暴露一个服务

```bash
omarchy-remote expose <名字> <端口>                 # 私有：https://<机器名>.ts.net:<端口>
omarchy-remote expose <名字> <端口> --auth <方式>   # 公网：https://<名字>.<你的域名>
omarchy-remote list
omarchy-remote unexpose <名字>
```

不带 `--auth` 时是私有地址（Tailscale）。带了 `--auth` 就是公网地址，走 `--via pangolin|cloudflare` 指定的提供方；不写 `--via` 时用 `omarchy-remote config set public <提供方>` 设置的默认值（初始为 `pangolin`）。

| `--auth` | 给谁用 | 怎么进入 | 分享给别人 |
|---|---|---|---|
| `login` | 人，用浏览器 | 登录页：Pangolin 组织成员用账号直接登录，其他人用邮箱验证码 | `--allow a@x.com,b@y.com` |
| `token` | 程序 / API | 请求头 `P-Access-Token-Id` + `P-Access-Token`，或 `?p_token=<id>.<token>` | 把令牌发给对方 |
| `password` | 程序和浏览器都行 | HTTP Basic：`curl -u 用户:密码 …` 或 `https://用户:密码@域名/` | 把密码发给对方 |
| `none` | 所有人 | 不需要登录，必须加 `--yes-public` 确认 | 直接发地址 |

密码和令牌由工具自动生成，**只显示一次**，请自己保存好。

新地址需要大约 30 秒签发证书，在此之前出现 404 或连不上是正常的。`unexpose` 之后，地址可能还会响应几秒，等 Pangolin 同步完就会失效。

> 限制：很多兼容 OpenAI 接口的客户端只能发送 `Authorization: Bearer <key>`。它们发不了 Pangolin 的令牌请求头，Bearer 头也会和 `password` 方式冲突。这类客户端目前请用私有地址（默认方式）。

### 远程桌面

```bash
omarchy-remote expose desktop 6080
omarchy-remote expose desktop 6080 --auth login --allow you@example.com
```

打开地址会自动连接，并按窗口大小缩放桌面。
没接显示器？桌面服务会尝试创建一块虚拟屏幕。

## 常用命令

```
omarchy-remote expose <名字> <端口>   通过 Tailscale 生成私有地址
omarchy-remote expose <名字> <端口> --auth login|token|password|none [--allow 邮箱] [--user 用户名] [--via pangolin|cloudflare]
omarchy-remote unexpose <名字>
omarchy-remote config set public pangolin|cloudflare
omarchy-remote list                   查看已暴露的服务
omarchy-remote status                 查看桌面服务和连接状态
omarchy-remote pangolin connect|login|status|logs|disconnect
omarchy-remote tailscale on|off       把桌面发布到 https://<机器名>.ts.net/（仅 tailnet）
omarchy-remote quality 0-9            桌面画质；数值越低，慢网速下越流畅
omarchy-remote restart
omarchy-remote uninstall
```

端口、画质等设置可以写在 `~/.config/omarchy-remote/config` 里覆盖默认值。

## 常见问题

| 现象 | 原因 / 解决 |
|---|---|
| Mac 打开 `*.ts.net` 地址报 `DNS_PROBE_FINISHED_NXDOMAIN` | Mac 没用 Tailscale 的 DNS。开启 *Use Tailscale DNS settings*，或只对 ts.net 生效：`echo "nameserver 100.100.100.100" \| sudo tee /etc/resolver/ts.net` |
| 新地址返回 404 或连不上 | 证书还在签发，等 30 秒左右。 |
| `--auth login` 没要求验证码就直接打开了 | 这个浏览器已经登录了 Pangolin（组织成员可直接进入）。用无痕窗口试。 |
| Pangolin 免费域名（`*.tunneled.to` 等）报 `ERR_CONNECTION_RESET` | 部分运营商或网络会拦截免费隧道域名，换成自己的域名即可。 |
| 桌面页面打开了但一直是黑屏或灰屏 | 当前网络拦截了 WebSocket（原因同上），或者服务没在运行：`omarchy-remote status`。 |
| Pangolin 日志出现 `Secret is incorrect` | 复制的密钥被隐藏了，或者已经重新生成过。到后台重新生成，再执行一次 `omarchy-remote pangolin connect`。 |
| `Not logged in to Pangolin` / `HTTP 401: Invalid API key` | 用有效的 API 密钥（重新）执行 `omarchy-remote pangolin login`。 |
| 桌面速度慢 | 自己用时走私有（Tailscale）地址，是直连；别走 Pangolin（中转）；或者 `omarchy-remote quality 4`。 |
| 重启后连不上 | 桌面必须已经登录（服务跟随图形会话启动）。全盘加密解锁或登录界面会挡住远程访问。如果装的是 0.2 或更早的版本，请重新执行安装命令：新版修复了一个导致桌面网页服务登录后起不来的启动顺序 bug。 |

## 安全提示

- 被暴露的服务只需要监听 `127.0.0.1`，Pangolin 通过站点隧道访问它们。
- 令牌和密码等同钥匙：谁拿到谁就能进。要作废，先 `unexpose` 再重新 expose。
- 通过桌面登录的人拥有你桌面的**完全控制权**。
- wayvnc 没有密码，只监听本机；这台机器上的其他本地用户也能连上它。
- 所有远程用户看到的是**同一个**桌面（暂不支持多用户独立会话）。

## 计划

- Omarchy Quattro 插件：状态栏小组件 + 面板（见 [`plugin/`](plugin/)）
- 专门给远程用的 1080p 虚拟屏幕
- 基于 Sunshine + Moonlight 的低延迟串流

## 许可

MIT。noVNC（MPL-2.0）、wayvnc（ISC）和 Pangolin CLI（AGPL-3.0 / 商业授权）是单独下载的，各自保留原有许可。
