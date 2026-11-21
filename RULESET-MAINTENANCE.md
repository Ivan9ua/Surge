# 规则集维护核对

核对日期：2026-11-22。范围为本仓库自有规则集、公开配置脱敏维护护栏与双端核对状态；不含私有主配置凭据，不代替全业务手工回归。

## 当前规则集状态

| 文件 | 有效规则 | 核对结果 |
|---|---:|---|
| [wechat.list](wechat.list) | 11 | 纯 `DOMAIN` / `DOMAIN-SUFFIX` 差量集；无重复、无逻辑排除、无 Sukka 广告冲突项，配合前置 `non_ip/reject.conf` 与 `non_ip/domestic.conf` 使用 |
| [ai-extra.list](ai-extra.list) | 32 | 纯 `DOMAIN` / `DOMAIN-SUFFIX` 补充集；无重复、无已被 `domainset/cdn.conf` 遮蔽条目，不含通用共享登录/支付后缀或静态 IP |
| `quic-reject.list` | 已删除 | 已彻底弃用并从仓库移除；校验脚本禁止在主配置中引用或将同名文件重新入库 |

### `wechat.list` 瘦身原则（2026-11-21 起）

1. **Sukka 差量原则**：仅保留 `non_ip/domestic.conf` 未覆盖的微信核心、海外、支付、小程序、企业微信及周边生态域（含 `wxgateway.com`、`slife.xy-asia.com` 等 11 条）；剔除 24 条重叠项与无有效解析的历史条目。
2. **广告/HTTPDNS 统一前置拦截**：移除曾与 `domainset/reject.conf` 冲突的 5 条规则及规则集内 `AND/NOT` 排除逻辑；轻量 `non_ip/reject.conf` 已开放 Mac 与 iPhone 双端共享，统一在微信差量规则之前拦截微信 HTTPDNS 与朋友圈广告域。
3. **下载前置直连**：`dl.wechat.com` 通过主配置内联 `DOMAIN,dl.wechat.com,DIRECT,extended-matching` 置于 `domainset/download.conf` 之前直连。

### `ai-extra.list` 收录边界

1. 置于 `domainset/cdn.conf` / `download.conf` 之后、`non_ip/ai.conf` 与 `apple_intelligence.conf` 之前，以 `Intelligence,extended-matching` 引用。
2. 不得引入静态 IP/CIDR/ASN、`auth0.com`/`stripe.com`/`googleapis.com` 等共享登录支付域，以及 `oaiusercontent.com` 等已被前置 `domainset/cdn.conf` 完全遮蔽的死规则。

## 双端运行态核对（2026-11-21 / Core 6013000）

- Mac（`Surge 6.13.0`）与 iPhone（`Surge 6.100.0`）外部规则集均已就绪，扩展内存与 DoH 运行稳定。
- 代表性规则匹配验证：`dl.wechat.com`、`sgshort.wechat.com`、`mmbiz.qpic.cn` 命中 `DIRECT`；`dns.wechat.com`、`dns.weixin.qq.com`、`udns.weixin.qq.com`、`wxsnsdy.wxs.qq.com` 命中前置 `REJECT`；`telemetry.mozilla.org`、`beacon.qq.com`（Mac 端及 SNI 场景）命中 `REJECT-DROP`；裸 IP + `www.google.com` SNI 命中 `global.conf` → `Proxy`。
- 公开别名脱敏映射通过仓库外 `$HOME/.config/surge-public-sync/aliases.map`（或 `SURGE_ALIAS_MAP`）执行，`Surge.conf` `[Proxy]` 与订阅策略组均受公开命名白名单和中性图标检查约束。

## 自动化维护与回归护栏

[scripts/validate-public-config.sh](scripts/validate-public-config.sh) 与 [scripts/test-dns-sanitization.sh](scripts/test-dns-sanitization.sh) 已覆盖以下回归项：

1. 整行格式与去重校验：拒绝规则集混入策略字段、重复条目、注释伪造以及 `wechat.list`（11 条）/ `ai-extra.list`（32 条）数量漂移。
2. 互斥与死规则拦截：拒绝 `quic-reject.list` 文件回归或主配置重新出现 QUIC 硬拒绝；拒绝 `ai-extra.list` 重新引入 IP 规则、宽泛共享后缀或已被 `cdn.conf` 遮蔽的条目；拒绝 `wechat.list` 重新引入 Sukka 广告冲突域。
3. 脱敏与白名单护栏：校验非占位凭据、个人 AliDNS 子域、`/Users/` 本机路径、MITM Keystore、带引号的 Smart `policy-priority`，以及私有节点名或机场图标泄漏；校验失败时禁止覆盖公开模板。

## 验证边界

脚本语法（`bash -n`）、`validate-public-config.sh --history`、合成夹具回归测试、`surge-cli --check` 与 GitHub Actions CI 已验证模板结构与规则集约束；离线校验不能替代特定运营商网络下的视频吞吐实测，也不涵盖全部第三方应用登录/付款链路。
