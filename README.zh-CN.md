# omarchy-remote

在任何浏览器里使用你的 [Omarchy](https://omarchy.org) 桌面：在家、在手机上，或者分享给别人。不需要容器、不需要 Kubernetes，也不需要用户系统。

```
浏览器 ──► Tailscale（私有）─┐
      └─► Pangolin（公开）──┴─► noVNC :6080 ──► wayvnc :5900 ──► Hyprland
```

- **wayvnc** 把 Hyprland 桌面画面传出去，并把键盘鼠标操作送回来。
- **noVNC** 把它变成网页（自动连接、自动缩放）。
- 两者都只监听 `127.0.0.1`，发布之前外部完全访问不到：
  - **Tailscale**：只对你自己设备开放的私有 HTTPS 地址，点对点直连，最快。
  - **Pangolin**：挂在你自己域名上的公网地址，前面有登录保护（邮箱验证码）。家里不需要公网 IP，也不用开端口。
- 没接显示器？会自动创建一块虚拟屏幕。

## 安装

在 Omarchy 机器上，用普通用户执行：

```bash
curl -fsSL https://raw.githubusercontent.com/second-state/omarchy-remote/main/install.sh | bash
```

它会安装 `wayvnc`，把 noVNC 下载到 `~/.local/share/omarchy-remote/`，并启动两个随桌面自启的用户服务（`omarchy-remote-vnc`、`omarchy-remote-web`）。

## 发布

### 私有访问：Tailscale

```bash
omarchy-remote tailscale on
# -> https://<机器名>.<tailnet>.ts.net
```

在任何登录了同一 Tailscale 账号的设备上打开这个地址即可。

### 带登录的公网访问：Pangolin

1. 在 [app.pangolin.net](https://app.pangolin.net) 注册免费账号（也可以自己部署 Pangolin），添加一个 **站点（Site）**，复制站点 ID 和密钥。
2. 在 Omarchy 机器上执行：
   ```bash
   omarchy-remote pangolin connect   # 依次输入 ID 和密钥（密钥不会显示在屏幕上）
   ```
3. 在后台新建一个 **公开 HTTP 资源**，目标填这个站点上的 `http://127.0.0.1:6080`。
4. 在 **认证** 里开启 **电子邮件白名单**，加入允许访问的邮箱。
5. 建议使用自己的域名：**域名 → 添加 → 单个域（CNAME）**，然后在你的 DNS 服务商那里添加两条 CNAME 记录，并关闭代理（Cloudflare 里选“仅 DNS”）。

## 常用命令

```
omarchy-remote status                 查看运行状态和访问地址
omarchy-remote tailscale on|off
omarchy-remote pangolin connect|status|logs|disconnect
omarchy-remote quality 0-9            数值越低，慢网速下越流畅
omarchy-remote restart
omarchy-remote uninstall
```

端口、画质等设置可以写在 `~/.config/omarchy-remote/config` 里覆盖默认值。

## 常见问题

| 现象 | 原因 / 解决 |
|---|---|
| Mac 打开 `*.ts.net` 地址报 `DNS_PROBE_FINISHED_NXDOMAIN` | Mac 没用 Tailscale 的 DNS。开启 *Use Tailscale DNS settings*，或只对 ts.net 生效：`echo "nameserver 100.100.100.100" \| sudo tee /etc/resolver/ts.net` |
| Pangolin 免费域名（`*.tunneled.to` 等）报 `ERR_CONNECTION_RESET` | 部分运营商或网络会拦截免费隧道域名，换成自己的域名即可。 |
| 页面打开了但一直是黑屏或灰屏 | 当前网络拦截了 WebSocket（原因同上），或者服务没在运行：`omarchy-remote status`。 |
| Pangolin 日志出现 `Secret is incorrect` | 复制的密钥被隐藏了，或者已经重新生成过。到后台重新生成，再执行一次 `omarchy-remote pangolin connect`。 |
| 速度慢 | 自己用时走 Tailscale 地址（直连），别走 Pangolin（中转）；或者 `omarchy-remote quality 4`。 |
| 重启后连不上 | 桌面必须已经登录（服务跟随图形会话启动）。全盘加密解锁或登录界面会挡住远程访问。 |

## 安全提示

- 通过登录的人拥有你桌面的**完全控制权**。
- wayvnc 没有密码，只监听本机；这台机器上的其他本地用户也能连上它。
- 所有远程用户看到的是**同一个**桌面（暂不支持多用户独立会话）。

## 计划

- Omarchy Quattro 插件：状态栏小组件 + 面板（见 [`plugin/`](plugin/)）
- 专门给远程用的 1080p 虚拟屏幕
- 基于 Sunshine + Moonlight 的低延迟串流
- 反向代理局域网里的其他设备（`nas.example.com` 等）

## 许可

MIT。noVNC（MPL-2.0）、wayvnc（ISC）和 Pangolin CLI（AGPL-3.0 / 商业授权）是单独下载的，各自保留原有许可。
