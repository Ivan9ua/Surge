# Surge 配置

个人 Surge 脱敏配置模板，基于 [SukkaW/Surge](https://github.com/SukkaW/Surge) 规则集，并维护微信域名与可见 SNI 补充规则。

## 文件说明

| 文件 | 说明 |
|------|------|
| `Surge.conf` | Mac 配置模板 |
| `iPhone.conf` | iPhone 配置模板 |
| `Shared-Routing.dconf` | 共享路由（代理节点 + 策略组 + 分流规则） |
| `Shared-General.dconf` | 共享 General（Mac / iPhone 公共设置） |
| `wechat.list` | 微信域名与可见 SNI 统一直连规则 |

## 规则排序逻辑

按“广告优先、专用规则早于通用规则、域名规则早于 IP 规则”排序：

```
广告域名 → 内网 → AI → 流媒体 → Telegram → Apple → Microsoft → 微信统一直连 → 网易云 → 下载 → CDN → 国内 → 海外 → 广告 IP → AI/Telegram/流媒体 IP → 国内 IPv4 → Mac 国内 IPv6 → 微信进程兜底 → FINAL
```

## 规则源

- [SukkaW/Surge](https://github.com/SukkaW/Surge) — 域名规则 + IP 规则
- `wechat.list` — 基于实际连接审计与公开微信规则集交叉核对维护的单一远程规则
- 策略组 Smart 自动选优

## 使用方法

1. Mac 导入 `Surge.conf`，iPhone 导入 `iPhone.conf`。
2. 将 `Shared-Routing.dconf` 与 `Shared-General.dconf` 放入 iCloud Drive 的 Surge 目录，确保与设备配置同目录。
3. 将 `Shared-Routing.dconf` 中的 `example.com`、`YOUR_SNELL_PSK` 和 `YOUR_SURGE_SUBSCRIPTION_URL` 替换为自己的值。
4. 在 Surge UI 中为 Mac 与 iPhone 分别生成并配置自己的 MITM 证书和 Keystore；公开模板不会保存该部分。

### 微信规则收录范围

`wechat.list` 已交叉核对 [Blackmatrix7 WeChat](https://github.com/blackmatrix7/ios_rule_script/blob/master/rule/Surge/WeChat/WeChat.list)、[ACL4SSR Wechat](https://github.com/ACL4SSR/ACL4SSR/blob/master/Clash/Ruleset/Wechat.list) 与 [NobyDa WeChat](https://github.com/NobyDa/Script/blob/master/Surge/WeChat.list)，统一收录核心登录、媒体/上传、小程序、微信支付与定位域名。共享配置只引用一次，固定到已验证且仍可由仓库 `main` 历史访问的提交，并使用 `no-resolve,extended-matching`：域名及可见 SNI 直连，国内 IP 由后续中国 IP 规则直连，海外 IP 交由最终代理策略；实测直连延迟较高的 `sgminorshort.wechat.com` 与 `sgshort.wechat.com` 被精确排除并交由代理，四个应用内 DNS 端点和 `wxsnsdy` 朋友圈广告端点通过逻辑排除继续交由 Sukka 广告规则处理。

当前使用 `extended-matching` 识别直接连接 IP 时暴露的 TLS/QUIC SNI；不使用静态 IP、`IP-ASN,132203` 或顶层 `DOMAIN-KEYWORD`，避免将非微信腾讯流量一并直连。

以下内容明确不并入微信直连规则：`trace.qq.com`、`beacon.qq.com`、`btrace.qq.com` 等追踪/广告端点；小程序去广告的 URL Rewrite、Body Rewrite、Map Local、Script、MITM 模块；以及 Blackmatrix7 的通用 Tencent 大清单。它们分别属于拦截、内容改写或广义腾讯业务，不是媒体上传的必要路由。
### IPv6 与 Telegram

- Mac 使用 `ipv6 = true`、`ipv6-vif = auto`，中国 IPv6 由 Sukka `china_ip_ipv6.conf` 直连。
- iPhone 使用 `ipv6 = false`、`ipv6-vif = disabled`，不加载中国 IPv6 规则。
- Telegram 仅保留域名与官方 IP 出站分流；不配置 `PROTOCOL,MTProto,Telegram` 入站规则。

### Mac 模块兼容说明

Mac 以 `[Sukka] Always Real IP Plus` 为主要 Host Lists 模块。为避免重复追加，请启用该模块，并停用 `Fix Windows No Network Alert` 与 `HTTP Download Optimization`；`Surge.conf` 只保留 Sukka 模块未覆盖的基础项和 `*.windowsupdate.com`。

## 在线规则

- [微信统一直连规则](https://raw.githubusercontent.com/Ivan9ua/Surge/main/wechat.list)

> 本仓库不再维护 Bilibili 与 YouTube Surge 模块；已安装的设备模块不会因远程文件删除自动卸载，请在 Surge 模块列表中手动移除。

> 本仓库只保存脱敏模板；请勿提交节点地址、订阅链接、密钥或 MITM 证书。

## 安全同步与校验

不要直接把正在使用的 Surge 配置复制到公开仓库。需要同步时，使用带脱敏和失败保护的脚本：

```bash
scripts/sync-local-surge.sh "/path/to/Surge" --apply
```

脚本会先在临时目录删除 MITM Keystore、证书引用与远程控制凭据，并将 Snell 地址、PSK、订阅地址及可能存在的 MTProto secret 替换为占位符；只有完整校验通过后才会更新仓库文件。提交前可再次运行：

```bash
scripts/validate-public-config.sh
```

CI 会检查整个 Git 历史，阻止凭据重新进入公开提交。

发现真实凭据进入 Git 历史时，删除当前文件并不足够：必须先轮换凭据，再重写历史并清理所有可达分支。详见 `SECURITY.md`。
