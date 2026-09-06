# 博客与本地规则逐项对照

核对日期：2026-09-06。来源：[Sukka 配置博客](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)，文章更新于 2026-01-02。

本表记录实际采用的配置，不代表完全复制作者的个人网络环境。所有表中相对路径均以 `https://ruleset.skk.moe/List/` 开头；配置已统一从镜像域名切换到该官方域名。EM 表示 `extended-matching`，PM 表示 `pre-matching`。策略组的实际手动选择属于设备状态，表中 US/HK/SG 是本次 Mac 核验时的选择，不能代替 iPhone 现场核验。

## 逐条映射

| 当前顺序 | 实际地址或规则 | 策略 | 标志/平台 | 对照结论 |
|---|---|---|---|---|
| 1 | non_ip/reject-drop.conf | REJECT-DROP | PM、EM | 博客 EM；保留个人广告优先 PM |
| 2 | domainset/reject.conf | REJECT | iOS | 与博客普通域名匹配一致 |
| 3 | domainset/reject.conf | REJECT | EM、Mac | 个人 Mac 广告扩展识别 |
| 4 | non_ip/reject.conf | REJECT | EM、Mac | 博客参数；保留平台差异 |
| 5 | non_ip/reject-no-drop.conf | REJECT-NO-DROP | EM、Mac | 博客参数；保留平台差异 |
| 6 | non_ip/lan.conf | DIRECT | 无 EM | 一致 |
| 7 | DOMAIN-SUFFIX,github.com | Proxy（HK） | 无 EM | 个人下载例外 |
| 8 | DOMAIN-SUFFIX,githubusercontent.com | Proxy（HK） | 无 EM | 个人下载例外 |
| 9 | DOMAIN-SUFFIX,githubassets.com | Proxy（HK） | 无 EM | 个人下载例外 |
| 10 | non_ip/ai.conf | Intelligence（US） | EM | 对应 AI 美国出口建议 |
| 11 | non_ip/apple_intelligence.conf | Intelligence（US） | EM | 现行项目补充，博客未单列 |
| 12 | non_ip/stream.conf | Stream（默认 HK） | EM | 博客策略占位符映射到现有组 |
| 13 | non_ip/telegram.conf | Telegram（SG） | EM | 博客策略占位符映射到现有组 |
| 14 | non_ip/apple_cn.conf | DIRECT | 无 EM | 与博客一致，保留最新本地选择 |
| 15 | domainset/apple_cdn.conf | DIRECT | DOMAIN-SET、无 EM | 使用现行有效路径，见下文 |
| 16 | non_ip/apple_services.conf | Apple（US） | EM | 博客策略占位符映射到现有组 |
| 17 | non_ip/microsoft_cdn.conf | DIRECT | 无 EM | 与博客一致，保留最新本地选择 |
| 18 | non_ip/microsoft.conf | Microsoft（HK） | EM | 博客策略占位符映射到现有组 |
| 19 | DOMAIN,sgshort.wechat.com | Proxy（HK） | EM | 个人已验证例外 |
| 20 | DOMAIN,sgminorshort.wechat.com | Proxy（HK） | EM | 个人已验证例外 |
| 21 | 微信固定版本远程规则 | DIRECT | EM、no-resolve | 个人规则，完整 URL 见共享配置 |
| 22 | non_ip/neteasemusic.conf | DIRECT | EM | 保留个人网易云直连需求 |
| 23 | domainset/download.conf | Proxy（HK） | EM | 本次从 DIRECT 改为代理，位于国内 CDN 后 |
| 24 | non_ip/download.conf | Proxy（HK） | EM | 本次从 DIRECT 改为代理，位于国内 CDN 后 |
| 25 | domainset/cdn.conf | Proxy（HK） | EM | 使用现有通用代理承接 CDN |
| 26 | non_ip/cdn.conf | Proxy（HK） | EM | 使用现有通用代理承接 CDN |
| 27 | non_ip/domestic.conf | DIRECT | EM | 一致 |
| 28 | non_ip/direct.conf | DIRECT | EM | 一致 |
| 29 | non_ip/global.conf | Proxy（HK） | EM | 博客策略占位符映射到现有组 |
| 30 | ip/reject.conf | REJECT-DROP | 无 EM | 一致 |
| 31 | ip/ai.conf | Intelligence（US） | 无 EM | 现行项目补充 |
| 32 | ip/telegram.conf | Telegram（SG） | 无 EM | 保留官方 IP 分流 |
| 33 | ip/stream.conf | Stream（默认 HK） | 无 EM | 保留媒体 IP 分流 |
| 34 | ip/neteasemusic.conf | DIRECT | 无 EM | 个人明确保留 |
| 35 | ip/lan.conf | DIRECT | 无 EM | 一致 |
| 36 | ip/domestic.conf | DIRECT | 无 EM | 一致 |
| 37 | ip/china_ip.conf | DIRECT | 无 EM | 一致，保留 DNS 解析兜底 |
| 38 | ip/china_ip_ipv6.conf | DIRECT | 无 EM、Mac | 保留 Mac IPv6 需求 |
| 39 | PROCESS-NAME,WeChat | DIRECT | Mac | 个人兜底；DNS 失败可能提前进入 FINAL |
| 40 | PROCESS-NAME,WeChatAppEx | DIRECT | Mac | 同上 |
| 41 | FINAL | Proxy（HK） | dns-failed | 一致 |

## 地址、排序与边界

- 博客的 `non_ip/apple_cdn.conf` 返回 HTTP 200，但正文仅含废弃说明，明确合并到 `domainset/apple_cdn`。因此采用 `DOMAIN-SET,https://ruleset.skk.moe/List/domainset/apple_cdn.conf,DIRECT`。HTTP 成功不能代表规则仍有效。
- 保持用户确定的整体顺序，确保国内 Apple/微软 CDN 在通用下载前，业务域名在通用域名和 IP 前。博客各小节的介绍顺序不直接作为完整可执行配置排序。
- 最新本地已撤掉 Apple 中国区/CDN、微软 CDN 的 EM，本次保留。仅有 IP＋SNI 的 CDN 请求可能被后续 Apple/Microsoft 服务规则代理；这是显式保留的匹配边界，不能宣称所有 CDN 场景均直连。
- EM 只能利用可见域名信息，不能识别不存在或加密的 SNI，也不能修复实际节点丢包和媒体重试。
- 规则源切换到主域会重新建立下载缓存；上线后需确认资源 Ready。换源不等于改善连接速度。

## 未自动引入的博客选项

搜狗、独立测速、按国家拆分的流媒体、iCloud Private Relay 分类未有新增需求，保持不添加。Telegram 进程 REJECT-DROP 未引入：用户仍在排查媒体连接，不能无依据屏蔽未知连接。保留微信例外、GitHub规则、网易云及双端平台差异。

General 继续使用个人选择的 AliDNS DoH（公开模板已脱敏）、既有 DNS Mapping 模块、扩大后的 skip-proxy 和博客测速地址。农行域名仍排除；不引入旧版 vif-mode，也不改变双端 IPv6 设置。

## 验证范围

双端配置检查验证语法；Mac 规则模拟验证域名及 IP＋SNI 的策略归属，资源状态验证远程下载。这些均不代替 iPhone 实际加载、真实媒体吞吐或电池测试。

本次结果：41 条主配置记录完成对照，Mac 所列远程资源均 Ready；`dl.google.com` → HK，`officecdn.microsoft.com` / `swcdn.apple.com` / `www.icloud.com.cn` → DIRECT，`api.openai.com` → US，`telegram.org` → SG。微软 CDN 的 IP＋SNI 模拟仍进入 Microsoft → HK，与上述保留边界一致。全规则扫描样本约 4.03 毫秒。
