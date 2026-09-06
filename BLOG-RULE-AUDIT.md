# 当前 GitHub 项目与本地规则对照

核对日期：2026-09-06。以最新本地配置为准；本表替代此前博客对照结论。上游：[SukkaW/Surge](https://github.com/SukkaW/Surge)，源码提交 `81632ebcfaa6a2469721d63e7be16639db319f63`（2026-09-05）。另读取实际发布规则正文，不能把源码提交时间视为所有构建文件的更新时间。

32 个 Sukka 规则 URL 已下载检查，均有有效内容；Mac 中对应资源全部 Ready。初次部分请求返回 403，curl 重试成功，未因此更改用户规则源。域名集使用 DOMAIN-SET，其余使用 RULE-SET。下表 EM 为 extended-matching、PM 为 pre-matching；策略组当前选择是设备状态，不写死为某地区。

| 顺序 | 当前规则/相对路径 | 策略 | 参数/平台 | 当前项目对照 |
|---|---|---|---|---|
| 1 | non_ip/reject-drop.conf | REJECT-DROP | PM | 类型和匹配参数一致；采用本地策略 |
| 2 | domainset/reject.conf | REJECT | EM、IOS-ONLY | 类型和匹配参数一致；采用本地策略 |
| 3 | domainset/reject.conf | REJECT | EM、MACOS-ONLY | 类型和匹配参数一致；采用本地策略 |
| 4 | non_ip/reject.conf | REJECT | EM、MACOS-ONLY | 类型和匹配参数一致；采用本地策略 |
| 5 | non_ip/reject-no-drop.conf | REJECT-NO-DROP | EM、MACOS-ONLY | 类型和匹配参数一致；采用本地策略 |
| 6 | non_ip/lan.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 7 | non_ip/ai.conf | Intelligence | 普通 | 类型和匹配参数一致；采用本地策略 |
| 8 | non_ip/apple_intelligence.conf | Intelligence | EM | 类型和匹配参数一致；采用本地策略 |
| 9 | non_ip/stream.conf | Stream | 普通 | 类型和匹配参数一致；采用本地策略 |
| 10 | non_ip/telegram.conf | Telegram | 普通 | 类型和匹配参数一致；采用本地策略 |
| 11 | non_ip/apple_cn.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 12 | domainset/apple_cdn.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 13 | non_ip/apple_services.conf | Apple | 普通 | 类型和匹配参数一致；采用本地策略 |
| 14 | non_ip/microsoft_cdn.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 15 | non_ip/microsoft.conf | Microsoft | 普通 | 类型和匹配参数一致；采用本地策略 |
| 16 | sgshort.wechat.com | Proxy | EM | 个人微信海外例外 |
| 17 | sgminorshort.wechat.com | Proxy | EM | 个人微信海外例外 |
| 18 | 微信固定版本远程规则（完整地址见配置） | DIRECT | EM、no-resolve | 个人固定版本；保留 EM/no-resolve |
| 19 | non_ip/neteasemusic.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 20 | domainset/download.conf | Proxy | 普通 | 类型和匹配参数一致；采用本地策略 |
| 21 | non_ip/download.conf | Proxy | 普通 | 类型和匹配参数一致；采用本地策略 |
| 22 | domainset/cdn.conf | Proxy | 普通 | 类型和匹配参数一致；采用本地策略 |
| 23 | non_ip/cdn.conf | Proxy | 普通 | 类型和匹配参数一致；采用本地策略 |
| 24 | non_ip/domestic.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 25 | non_ip/direct.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 26 | non_ip/global.conf | Proxy | 普通 | 类型和匹配参数一致；采用本地策略 |
| 27 | ip/reject.conf | REJECT-DROP | 普通 | 类型和匹配参数一致；采用本地策略 |
| 28 | ip/ai.conf | Intelligence | 普通 | 类型和匹配参数一致；采用本地策略 |
| 29 | ip/telegram.conf | Telegram | 普通 | 类型和匹配参数一致；采用本地策略 |
| 30 | ip/telegram_asn.conf | Telegram | 普通 | 可选 ASN 补充，位于官方 CIDR 后 |
| 31 | ip/stream.conf | Stream | 普通 | 类型和匹配参数一致；采用本地策略 |
| 32 | ip/neteasemusic.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 33 | ip/lan.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 34 | ip/domestic.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 35 | ip/china_ip.conf | DIRECT | 普通 | 类型和匹配参数一致；采用本地策略 |
| 36 | ip/china_ip_ipv6.conf | DIRECT | MACOS-ONLY | 个人兜底/平台选择 |
| 37 | WeChat | DIRECT | MACOS-ONLY | Mac 微信进程兜底 |
| 38 | WeChatAppEx | DIRECT | MACOS-ONLY | Mac 微信进程兜底 |
| 39 | FINAL | Proxy | dns-failed | 个人兜底/平台选择 |

## 判断与保留边界

- 未发现本次手动修改引入的语法错误、无效规则地址或错误规则类型。主配置共 39 条记录，包含互斥的平台广告条目；域名业务规则在 IP 规则之前，国内 Apple/微软 CDN 在通用下载前。专用业务规则早于通用 CDN 是个人优先级，并非照搬 README 小节顺序。
- 当前上游所引用条目的匹配参数均与本地一致。博客曾建议的广泛 EM 不再作为校验器的硬性要求。微信属于个人扩展。
- 基础广告域名在 iPhone 也已启用 EM：本次校准“双端扩展匹配”和“官方 CIDR 与 ASN 补充”两条注释，未改动有效规则。上游对移动端广告大表有性能提醒；保留用户选择，不宣称耗电改善。
- Telegram ASN 正文含 5 条 IP-ASN 及上游标记域名。它扩大识别范围但不是所有媒体慢载的修复；官方 CIDR 优先。ASN 与 GeoIP 国家库的更新独立，依据 [Surge 官方文档](https://manual.nssurge.com/rules/ip.html)。
- Apple CDN 使用现行 domainset/apple_cdn.conf，未采用已废弃的 non_ip 路径。主域和 ruleset-mirror.skk.moe 都是上游认可地址，镜像本身不应被称为无效。
- 原 GitHub 三条后缀规则删除后，主站命中 global，raw.githubusercontent.com 和 github.githubassets.com 命中 cdn，当前均走 HK。
- 普通规则不再借助 EM 匹配额外 SNI/Host；合成样本 1.1.1.1 + api.openai.com SNI 命中 FINAL→HK，而域名 api.openai.com 命中 Intelligence→US。这是用户最新选择的实际覆盖差异。

## 本次验证

双端本地配置与公开模板通过 Surge 语法检查；Mac 当前生效规则抽样：Telegram 域名/官方 IP→SG，Apple/微软 CDN、网易云、微信媒体域名→DIRECT，微信海外例外与通用下载→HK。32 项 Sukka 远程规则均 Ready。微信固定版本及其完整性沿用既有维护流程。

General、Mac/iPhone 入口、节点和策略组已一起经过脱敏同步；与仓库相同的文件不制造空改动。Keystore、订阅、PSK、私有 DNS 标识未发布。iPhone 尚未做实时控制验收，本次未验证真实媒体吞吐、ASN 独立命中的收益或电池消耗。
