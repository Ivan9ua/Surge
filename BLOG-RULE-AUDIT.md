# 配置核对记录

更新：2026-11-22。以当前单文件 [Surge.conf](Surge.conf) 与双端 Core `6013000` 核对结果为准。参考：[Sukka 排序](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)、[首条命中语义](https://manual.nssurge.com/rules/overview.html)。

## 规则数量与平台隔离

源文件 `[Rule]` 共 **45 条有效主规则**：32 条远程规则集（`RULE-SET` / `DOMAIN-SET`）、7 条内联域名/IP 规则、5 条 Mac 微信进程规则、1 条 `FINAL`。

- **Mac（加载全部 45 条）**：启用全部 `#!MACOS-ONLY` 广告重规则及 Mac 微信进程兜底。
- **iPhone（排除 8 条 `#!MACOS-ONLY` 后加载 37 条，不含设备本地模块注入）**：仅共享轻量 374 行 `non_ip/reject.conf` 统一拦截微信 HTTPDNS 与朋友圈广告，控制 Network Extension 内存占用。

> 注：下表中 `EM` = `extended-matching`，`PM` = `pre-matching`。

## 规则顺序（45 条）

| 序号 | 规则 / 规则集 | 策略 / 参数 | 作用域 |
|---:|---|---|---|
| 1–2 | `DOMAIN,metadata.google.internal`、`IP-CIDR,169.254.169.254/32` | `REJECT-NO-DROP,pre-matching`（IP 另带 `no-resolve`） | 双端 |
| 3–4 | `non_ip/reject-drop`、`domainset/reject` | `REJECT-DROP` / `REJECT`；`PM,EM` | Mac 专用 |
| 5 | `non_ip/reject` | `REJECT,EM`（统一拦截微信 HTTPDNS 与广告域） | 双端共享 |
| 6 | `non_ip/reject-no-drop` | `REJECT-NO-DROP,EM` | Mac 专用 |
| 7–8 | `domainset/cdn`、`non_ip/cdn` | `Proxy,EM` | 双端 |
| 9–10 | `non_ip/stream`、`non_ip/telegram` | `Stream,EM` / `Telegram,EM` | 双端 |
| 11–12 | `domainset/apple_cdn`、`non_ip/microsoft_cdn` | `DIRECT,EM` | 双端 |
| 13 | `DOMAIN,dl.wechat.com` | `DIRECT,EM`（先于下载规则避免被代理截胡） | 双端 |
| 14–15 | `domainset/download`、`non_ip/download` | `Proxy,EM` | 双端 |
| 16–18 | [ai-extra.list](ai-extra.list)（32 条）、`non_ip/ai`、`apple_intelligence` | `Intelligence,EM` | 双端 |
| 19–21 | `captive.apple.com`、`non_ip/apple_cn`、`non_ip/apple_services` | `DIRECT,EM` / `Apple,EM` | 双端 |
| 22 | `non_ip/microsoft` | `Microsoft,EM` | 双端 |
| 23–25 | `ipv4-ip.api.skk.moe`、`ipv6-ip.api.skk.moe`、`ip.api.skk.moe` | `VLESS-1,EM`（避开部分订阅节点 TLS EOF） | 双端 |
| 26 | `non_ip/global` | `Proxy,EM` | 双端 |
| 27 | [wechat.list](wechat.list)（11 条纯域名 Sukka 差量） | `DIRECT,EM` | 双端 |
| 28–29 | `non_ip/domestic`、`non_ip/direct` | `DIRECT,EM` | 双端 |
| 30 | `non_ip/lan` | `DIRECT` | 双端 |
| 31–35 | `ip/reject`、`ip/telegram`、`ip/stream`、`ip/ai`、`ip/neteasemusic` | 对应策略 + `no-resolve`（移除被全覆盖的 `non_ip/neteasemusic.conf`） | 双端 |
| 36–39 | `ip/lan`、`ip/domestic`、`ip/china_ip`、`ip/china_ip_ipv6` | `DIRECT`（允许 DNS 解析；保留 `ip/domestic` 与 Sukka 模板对称） | 双端 |
| 40–44 | `PROCESS-NAME`：`WeChat`、`WeChatAppEx`、`XPlayer`、`WeChatHelper`、`/Applications/WeChat.app/` | `DIRECT` | Mac 专用 |
| 45 | `FINAL` | `Proxy,dns-failed` | 双端 |

## 参数取舍与近期精简（2026-11-19 ~ 2026-11-24）

- **网络与 DNS**：启用 `ipv6 = true`、`ipv6-vif = auto`；保留 `udp-priority = false`。DoH 演进为阿里 DNS + 跨厂商 360 公共 DoH（`https://doh.360.cn/dns-query`，配 `[Host]` `doh.360.cn = server:101.198.198.198` 引导；彻底下线易在双栈 `A+AAAA` 并发下触发 `429` 的 `120.53.53.53` 与 `1.12.12.12`）。
- **节点与测速口径**：全组统一使用全局纯 HTTP `proxy-test-url`（不给单节点额外配置 `https://` `test-url`，防止热 TLS 二次请求计分不对称）；保持省略 VLESS `client-fingerprint` 与 `ecn`（默认 `auto`，兼容 `6.13.0` 原生 `apple-26` 与自适应 ECN），不用 `ech-config`（与 REALITY 互斥）。
- **`always-real-ip` 与 `skip-proxy`**：`always-real-ip` 移除两条 NXDOMAIN 死域（`musicapi.taihe.com`、`mdn.open.wo.cn`）与四个宽泛微信后缀，并将 `*.126.net` 收窄为 `*.music.126.net`；`skip-proxy` 移除 Enhanced Mode 下无需保留的 5 段历史公网 CIDR。
- **云元数据双层拦截**：`tun-included-routes = 169.254.169.254/32` 配合 `[IP Rewrite]`（`169.254.169.254 = reject`）及顶部两条 `pre-matching` 规则共同阻断探测，且不触发额外 DNS 解析。
- **QUIC 与微信规则**：彻底撤回四条内联 UDP 443 硬拒绝并删除仓库中已弃用的 `quic-reject.list`；`wechat.list` 按 Sukka 差量原则瘦身至 11 条纯域名规则；`ai-extra.list` 剔除 3 条被 `domainset/cdn.conf` 遮蔽条目后保持 32 条。
- **Smart 权重与策略组**：`HK` / `TW` / `JP` / `SG` / `US` 统一为显式加引号的 `policy-priority="..."`；公开模板订阅组统一脱敏为 `Subscription` 并替换中性图标，`[Proxy]` 与订阅策略组采用外置 `aliases.map` + 公开白名单校验。
- **已清理历史项**：删除 Mac `[Testing]` 段与 `[Ponte]` 段；外迁 `[Keystore]` 与 HTTP API/MCP 管理字段（不写入公开仓库）。

## 设计边界

- CDN/下载资源类型规则靠前，可能优先于后序业务交集；`dl.wechat.com` 已显式前置至下载规则之前直连。
- `no-resolve` 仅阻止所附专项 IP 规则触发 DNS 解析，后序国内/内网 IP 规则仍允许解析；DNS 失败进入 `FINAL,Proxy,dns-failed`，不保证回落到微信进程规则。
- 除 `lan.conf` 与末尾允许解析的国内 IP 段外，全部主要域名/规则集均已统一启用 `extended-matching`，避免已知裸 IP 请求或纯 SNI 握手绕过预期策略。
- 撤销微信 UDP 443 硬拒绝不等于开启 `block-quic=adaptive` 也不代表放行全部 UDP 流量。

## 已验证结果与未验证边界

- **2026-11-24 多日审计与 DNS/Smart 调优（Mac `6.13.0 Build 12920` / iPhone `6.100.0 Build 4042`）**：验证 `12920` 用户态 `Network.framework` 栈（`tfo_heuristics_disable` 归零、`ECN` 自适应启用且零报错）与 `45` 条 `[Rule]` 多日准确分流；移除 VLESS 单点 HTTPS `test-url` 覆写并将副 DoH 切换为 `https://doh.360.cn/dns-query` 后，Mac `surge-cli reload` 与 `diagnostics` 实测双路 DoH（`15 ms` / `33 ms`）全部健康。
- **2026-11-21 双端连续运行复核**：Mac `6.13.0` 与 iPhone `6.100.0`（Core `6013000`）外部规则集全部就绪，DoH 高频 429 消除；Mac `surge-cli rule explain` 与 iPhone 实测已验证裸 IP + SNI 命中 `reject-drop.conf` 与 `global.conf`、`dl.wechat.com` / `sgshort.wechat.com` / `mmbiz.qpic.cn` 命中 `DIRECT`、微信 HTTPDNS 与朋友圈广告域前置命中 `REJECT`，iPhone 扩展内存维持约 24 MB 区间。
- **仓库重建与 CI 护栏（2026-11-22）**：公开仓库已完成单根清理重建、全历史扫描与 `test-dns-sanitization.sh` / `surge-cli --check` 验证，`raw.githubusercontent.com` 在线规则可正常拉取。
- **未验证边界**：未在当前周期内对同一未缓存视频、同 CDN 与同运营商网络执行吞吐对照；未逐项审计 iPhone 系统 CA 信任与所有第三方应用的证书固定（Certificate Pinning）。历史扫描不替代各自设备上的实时配置加载与真实业务验收。
