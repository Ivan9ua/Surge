# 当前配置核对记录

更新：2026-10-01。以同步时最新本地文件为准；不沿用旧的专项优先、下载直连结论。参考：[Sukka 博客](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)、[规则项目](https://github.com/SukkaW/Surge)、[Surge 首条命中语义](https://manual.nssurge.com/rules/overview.html)。

## 规则与参数

35 条主规则：32 条远程引用、2 条 Mac 进程、1 条 FINAL。EM=extended-matching，PM=pre-matching。

| 顺序 | 规则 | 策略/参数 |
|---|---|---|
| 1–4 | domainset/reject、non_ip/reject、reject-no-drop、reject-drop | REJECT 系列；Mac 专用；前三条 EM，最后 PM |
| 5–6 | domainset/cdn、non_ip/cdn | Proxy |
| 7–8 | non_ip/stream、telegram | Stream / Telegram |
| 9–10 | domainset/apple_cdn、non_ip/microsoft_cdn | DIRECT |
| 11–12 | domainset/download、non_ip/download | Proxy |
| 13–15 | non_ip/apple_cn、apple_services、microsoft | DIRECT / Apple / Microsoft |
| 16–17 | non_ip/ai、apple_intelligence | Intelligence，EM |
| 18–20 | non_ip/global、neteasemusic、wechat.list | Proxy / DIRECT / DIRECT；微信 EM、no-resolve |
| 21–23 | non_ip/domestic、direct、lan | DIRECT |
| 24–28 | ip/reject、telegram、stream、ai、neteasemusic | REJECT-DROP / Telegram / Stream / Intelligence / DIRECT；允许解析 |
| 29–32 | ip/lan、domestic、china_ip、china_ip_ipv6 | DIRECT；允许解析、双端共享 |
| 33–34 | WeChat、WeChatAppEx | DIRECT，Mac 专用 |
| 35 | FINAL | Proxy，dns-failed |

域名在 IP 前；国内 Apple/Microsoft CDN 在下载前；Apple 中国区在其他 Apple 服务前。未加入此前未获执行授权的 Apple 精确例外。

## 覆盖边界

- CDN 前置会覆盖交集中的 AI、Telegram、Microsoft 等后序专项规则，属于资源类型优先。
- AI、Apple Intelligence、微信保留 EM；其他普通匹配不保证识别只有 IP + SNI 的目标。
- 四条国内兜底和 AI EM 已通过双端运行验证；随后本地其余五条专项 IP 也移除了 no-resolve，本次不恢复旧值。
- 未收录域名可能本地解析；不能声称绝对无 DNS 泄漏。DNS 失败走 FINAL，不继续匹配 Mac 微信进程。
- 广告主规则为 Mac 专用；iPhone 的广告增强模块已在最近 USB 核验中确认启用。模块独立于模板。
- IPv6 在共享 General；DNS 为 system + 加密 DNS，个人 AliDNS 标识仅在私有副本中保留。
- 模板删除 Keystore、证书引用、远程控制凭据及真实节点/订阅；保留 hostname-disabled，入口不配置旧 hostname 排除清单。

## 最近双端验证

2026-10-01 USB 读取 iPhone 生效规则并核验五项参数，双端各 20 项代表性匹配一致：

| 样本 | 结果 |
|---|---|
| api.qweather.com、内网 IP、中国 IPv6 IP | DIRECT |
| ChatGPT/OpenAI 域名、IP + ChatGPT SNI | Intelligence → US |
| 微信短连接、媒体、企业微信 API | DIRECT |
| Telegram API / 官方 IP | Telegram → SG |
| oaistatic.com、cdn-telegram.org、GitHub 下载资源 | CDN → Proxy → HK |
| cn.apple.com、天气、微软国内更新域名 | DIRECT |
| res-h3.public.cdn.office.net | CDN → Proxy → HK，覆盖后面的微软国内 CDN |

该验证早于随后五条专项 IP 参数变化，不能称最新全部参数已双端实测。临时控制器、USB 转发和端口已清理。当前公开模板需通过语法、脱敏、回归和可达历史检查；未验证媒体吞吐、所有应用行为、网络切换或电池耗电。微信固定提交内容未变。
