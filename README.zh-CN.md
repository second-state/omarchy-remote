# omarchy-remote

在任何地方访问你 [Omarchy](https://omarchy.org) 电脑上的服务：本地模型的 API、你正在开发的网页，或者桌面本身。一条命令暴露出去，再选一种登录方式。不需要容器、不需要 Kubernetes、不需要公网 IP，也不用开端口。

```
你自己的设备 ── Tailscale（私有，点对点直连）───┐    ┌─► 127.0.0.1:11434 （比如模型 API）
                                                ├────┼─► 127.0.0.1:3000  （比如你的网页）
任何人、任何程序 ── Cloudflare 或 Pangolin（公网）┘    └─► 127.0.0.1:6080  （桌面，通过 noVNC）
```

```bash
omarchy-remote expose app 3000
# -> https://<机器名>.<tailnet>.ts.net:3000（默认走 Tailscale，只有你自己的设备能访问）
omarchy-remote expose app 3000 --auth login --allow friend@example.com
# -> https://app.example.com     （公网；浏览器登录，朋友用邮箱验证码进入）
omarchy-remote expose ai 11434 --auth bearer
# -> https://ai.example.com      （公网；OpenAI 风格的客户端用 "Authorization: Bearer <key>" 调用）
```

私有地址走 **Tailscale**（个人使用免费，不需要域名）。公网地址走你选的提供方：**Cloudflare**（通过 Cloudflare Access 做浏览器登录和服务令牌，还能在 Cloudflare 边缘校验 API key，兼容 OpenAI 风格的客户端和 SDK，包括流式输出），或者 **Pangolin**（浏览器登录、访问令牌、密码）。两个都配或只配一个都行。

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

## 一次性配置：Cloudflare（公网地址）

需要一个托管在 Cloudflare 上的域名，免费版就够。服务地址是 `https://<名字>.<域名>`：只能在域名下一层，这样 Cloudflare 免费证书才能覆盖。

1. 创建 API 令牌：我的个人资料 → API 令牌 → 创建令牌 → 自定义令牌。权限选 **帐户：Cloudflare Tunnel（编辑）**，以及 **区域：DNS（编辑）、区域 WAF（编辑）、区域（读取）**，作用范围限定为你的帐户和这个域名。
   要用 `--auth login` 或 `--auth token`，还需要在这个帐户上开通 **Zero Trust**（免费版支持 50 个用户），并给令牌加上 **帐户：Access: Apps and Policies（编辑）、Access: Service Tokens（编辑）、Access: Organizations, Identity Providers, and Groups（编辑）**。第一个 `login` 服务会为你的 Zero Trust 组织开启邮箱验证码登录（如果还没开）。
2. 在 Omarchy 机器上执行：
   ```bash
   omarchy-remote cloudflare login   # 输入令牌（不会显示）并选择域名
   ```
   第一次 `expose` 时，会创建一条名为 `omarchy-remote-<主机名>` 的隧道；如果本机没有 `cloudflared`，会先下载它，然后用用户服务 `omarchy-remote-tunnel` 运行。

已有的 DNS 记录不会被覆盖，请选一个没有被占用的名字。

## 暴露一个服务

```bash
omarchy-remote expose <名字> <端口>                 # 私有：https://<机器名>.ts.net:<端口>
omarchy-remote expose <名字> <端口> --auth <方式> [--via cloudflare|pangolin]   # 公网：https://<名字>.<你的域名>
omarchy-remote list
omarchy-remote unexpose <名字>
```

不带 `--auth` 时是私有地址（Tailscale）。带了 `--auth` 就是公网地址，走 `--via cloudflare|pangolin` 指定的提供方；不写 `--via` 时用 `omarchy-remote config set public <提供方>` 设置的默认值。没设置时默认走 Cloudflare（如果这台机器只配了 Pangolin，就走 Pangolin；两个都配了时，`expose` 会提示它选了 Cloudflare）；`--auth bearer` 总是走 Cloudflare，`--auth password` 总是走 Pangolin。

| `--auth` | 给谁用 | 怎么进入 | 分享给别人 | 提供方 |
|---|---|---|---|---|
| `login` | 人，用浏览器 | 登录页，用邮箱验证码进入。Pangolin 上，组织成员也可以用账号直接登录 | `--allow a@x.com,b@y.com`（Cloudflare 上必填） | Cloudflare、Pangolin |
| `token` | 程序 / API | Cloudflare：请求头 `CF-Access-Client-Id` + `CF-Access-Client-Secret`。Pangolin：请求头 `P-Access-Token-Id` + `P-Access-Token`，或 `?p_token=<id>.<token>` | 把令牌发给对方 | Cloudflare、Pangolin |
| `password` | 程序和浏览器都行 | HTTP Basic：`curl -u 用户:密码 …` 或 `https://用户:密码@域名/` | 把密码发给对方 | Pangolin |
| `bearer` | 程序、OpenAI 风格的客户端 | `Authorization: Bearer <key>`（比如 `base_url=https://ai.example.com/v1`，`api_key=<key>`） | 把 key 发给对方 | Cloudflare |
| `none` | 所有人 | 不需要登录，必须加 `--yes-public` 确认 | 直接发地址 | Cloudflare、Pangolin |

密码、令牌和 key 都由工具自动生成，**只显示一次**，请自己保存好。

Pangolin 的新地址需要大约 30 秒签发证书，在此之前出现 404 或连不上是正常的。在 Cloudflare 上，`bearer`、`login`、`token` 三种方式的 `expose` 都会等到不带凭据的请求确实被拒绝后才报告成功（通常 10～30 秒）。`unexpose` 之后，地址可能还会响应几秒。

> 在 Cloudflare 上，每个 `login` 或 `token` 服务会建一个 Access 应用和一条策略（`token` 还会建一个服务令牌），名字都是 `omarchy-remote:<名字>`，`unexpose` 时一并删除。每个 `bearer` 服务占用一条 Cloudflare WAF 自定义规则。免费版每个域名最多 5 条，跟你自己建的规则共用。能打开你 Cloudflare 后台的人，都能看到这些规则里的 key。

### 远程桌面

```bash
omarchy-remote expose desktop 6080
omarchy-remote expose desktop 6080 --auth login --allow you@example.com
```

打开地址会自动连接，并按窗口大小缩放桌面。
没接显示器？桌面服务会尝试创建一块虚拟屏幕。

**浏览器里的快捷键。** 打字和大多数组合键都能传到桌面，但有三个例外：

- **Mac 上，Super 键是右边的 ⌘。** Omarchy 的快捷键都用 Super，但 noVNC 把**左** ⌘ 当成 Alt 发送（左 ⌥ 当成 AltGr）。请改按**右 ⌘**，比如右 ⌘ + Return 打开终端。
- **浏览器会先截走自己的快捷键。** ⌘W / Ctrl+W 关掉的是浏览器标签页（远程会话也随之断开），而不是远程窗口；⌘T、⌘N、⌘Q 及对应的 Ctrl 组合也到不了桌面；⌘1–9 / Ctrl+1–9 可能切换的是浏览器标签，而不是工作区。
- **操作系统也会截走一些：** macOS 上的 ⌘Tab、⌘Space；Windows 上的 Win 键、Win+L、Win+D。

遇到被截走的快捷键：打开 noVNC 侧边栏（左边缘的小把手）→ *Show extra keys* → 点亮 **Windows** 键（即 Super），再按另一个键。

## 状态栏小组件（Omarchy 插件）

```bash
omarchy plugin add https://github.com/second-state/omarchy-remote-plugin --enable
```

显示这台机器暴露了哪些服务，每个地址都可以一键复制或打开（[详情](https://github.com/second-state/omarchy-remote-plugin)）。

## 常用命令

```
omarchy-remote expose <名字> <端口>   通过 Tailscale 生成私有地址
omarchy-remote expose <名字> <端口> --auth login|token|bearer|none [--allow 邮箱] [--via cloudflare]
omarchy-remote expose <名字> <端口> --auth login|token|password|none [--allow 邮箱] [--user 用户名] [--via pangolin]
omarchy-remote unexpose <名字>
omarchy-remote config set public pangolin|cloudflare
omarchy-remote list                   查看已暴露的服务
omarchy-remote status                 查看桌面服务和连接状态
omarchy-remote pangolin connect|login|status|logs|disconnect
omarchy-remote cloudflare login|status
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
| Cloudflare 新地址只在某一台设备上报"找不到服务器" | 这台设备在记录创建之前查询过这个名字，缓存了"不存在"的结果（最长 30 分钟）。等一会儿，或者清一下它的 DNS 缓存。 |
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

- 专门给远程用的 1080p 虚拟屏幕
- 基于 Sunshine + Moonlight 的低延迟串流

## 许可

MIT。noVNC（MPL-2.0）、wayvnc（ISC）和 Pangolin CLI（AGPL-3.0 / 商业授权）是单独下载的，各自保留原有许可。
