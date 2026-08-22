# Surge 配置

个人 Surge 脱敏配置模板，基于 [SukkaW/Surge](https://github.com/SukkaW/Surge) 规则集，并维护微信域名与 IP 补充规则。

## 文件说明

| 文件 | 说明 |
|------|------|
| `Surge.conf` | Mac 配置模板 |
| `iPhone.conf` | iPhone 配置模板 |
| `Shared-Routing.dconf` | 共享路由（代理节点 + 策略组 + 分流规则） |
| `Shared-General.dconf` | 共享 General（Mac / iPhone 公共设置） |
| `wechat-direct.list` | 微信补充域名直连规则 |
| `wechat-ip.list` | 微信精确 IPv4/IPv6 直连规则（不使用 ASN） |
| `bilibili.sgmodule` | Bilibili 去广告模块（无伪造会员） |
| `youtube-enhance-bounded.sgmodule` | YouTube 增强模块（正文上限 2 MiB） |

## 规则排序逻辑

按“广告优先、专用规则早于通用规则、域名规则早于 IP 规则”排序：

```
广告域名 → 内网 → AI → 流媒体 → Telegram → Apple → Microsoft → 网易云 → 下载 → 微信补充 → CDN → 国内 → 海外 → 广告 IP → 微信精确 IP → AI/Telegram/流媒体 IP → 国内 IPv4/IPv6 → FINAL
```

## 规则源

- [SukkaW/Surge](https://github.com/SukkaW/Surge) — 域名规则 + IP 规则
- `wechat-direct.list` / `wechat-ip.list` — 基于实际连接审计与公开微信规则集交叉核对维护的补充规则
- 策略组 Smart 自动选优

## 使用方法

1. Mac 导入 `Surge.conf`，iPhone 导入 `iPhone.conf`。
2. 将 `Shared-Routing.dconf` 与 `Shared-General.dconf` 放入 iCloud Drive 的 Surge 目录，确保与设备配置同目录。
3. 将 `Shared-Routing.dconf` 中的 `example.com`、`YOUR_SNELL_PSK` 和 `YOUR_SURGE_SUBSCRIPTION_URL` 替换为自己的值。
4. 将 Mac/iPhone 模板中的全零 MTProto `secret` 替换为设备自己的 32 位十六进制密钥。
5. 在 Surge UI 中生成并配置设备自己的 MITM 证书。

### 微信规则收录范围

`wechat-direct.list` 已交叉核对 [Blackmatrix7 WeChat](https://github.com/blackmatrix7/ios_rule_script/blob/master/rule/Surge/WeChat/WeChat.list)、[ACL4SSR Wechat](https://github.com/ACL4SSR/ACL4SSR/blob/master/Clash/Ruleset/Wechat.list) 与 [NobyDa WeChat](https://github.com/NobyDa/Script/blob/master/Surge/WeChat.list)，补入核心登录、媒体/上传、HTTP DNS、小程序、微信支付和定位相关域名；共享规则中已经将它放在广告规则之后、通用 CDN 之前。

`wechat-ip.list` 收录现有观测网段、Blackmatrix7/NobyDa 交叉出现的 IPv4/IPv6 网段，以及 ACL4SSR 的精确 IPv4 端点，全部使用 `no-resolve`。当前不使用 `IP-ASN,132203`，也不使用 233 条数字 IP 的 `DOMAIN-KEYWORD`：这两类规则会把非微信腾讯流量一并直连，且不利于广告规则优先级。

以下内容明确不并入微信直连规则：`trace.qq.com`、`beacon.qq.com`、`btrace.qq.com` 等追踪/广告端点；小程序去广告的 URL Rewrite、Body Rewrite、Map Local、Script、MITM 模块；以及 Blackmatrix7 的通用 Tencent 大清单。它们分别属于拦截、内容改写或广义腾讯业务，不是媒体上传的必要路由。
### IPv6 与 MTProto

- Mac 与 iPhone 均使用 `ipv6 = true`、`ipv6-vif = auto`。
- 中国 IPv6 由 Sukka `china_ip_ipv6.conf` 直连。
- `[MTProto]` 使用 Sukka 每日更新的数据中心映射；其独立 `ipv6 = false` 不受主网络 IPv6 设置影响。

### Mac 模块兼容说明

Mac 以 `[Sukka] Always Real IP Plus` 为主要 Host Lists 模块。为避免重复追加，请启用该模块，并停用 `Fix Windows No Network Alert` 与 `HTTP Download Optimization`；`Surge.conf` 只保留 Sukka 模块未覆盖的基础项和 `*.windowsupdate.com`。

## 在线规则与模块

- [微信补充域名规则](https://raw.githubusercontent.com/Ivan9ua/Surge/main/wechat-direct.list)
- [微信精确 IP 规则](https://raw.githubusercontent.com/Ivan9ua/Surge/main/wechat-ip.list)
- [安装 Bilibili 去广告模块](https://raw.githubusercontent.com/Ivan9ua/Surge/main/bilibili.sgmodule)
- [安装 YouTube Enhance 受控版](https://raw.githubusercontent.com/Ivan9ua/Surge/main/youtube-enhance-bounded.sgmodule)

> 本仓库只保存脱敏模板；请勿提交节点地址、订阅链接、密钥或 MITM 证书。

## 安全同步与校验

不要直接把正在使用的 Surge 配置复制到公开仓库。需要同步时，使用带脱敏和失败保护的脚本：

```bash
scripts/sync-local-surge.sh "/path/to/Surge" --apply
```

脚本会先在临时目录删除 MITM 与远程控制凭据，并将 Snell 地址、PSK、订阅地址及 MTProto secret 替换为占位符；只有完整校验通过后才会更新仓库文件。提交前可再次运行：

```bash
scripts/validate-public-config.sh
scripts/verify-remote-integrity.sh
```

CI 会检查整个 Git 历史，阻止凭据重新进入公开提交。可执行远程脚本尽量固定到上游提交；无法固定的 Bilibili 脚本使用 SHA-256 清单监控内容变化。

发现真实凭据进入 Git 历史时，删除当前文件并不足够：必须先轮换凭据，再重写历史并清理所有可达分支。详见 `SECURITY.md`。
