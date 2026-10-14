# 当前配置核对记录

更新：2026-10-13。以当前本地文件和 Mac 生效配置为准；不沿用旧的专项优先、下载直连结论。参考：[Sukka 博客](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)、[规则项目](https://github.com/SukkaW/Surge)、[Surge 首条命中语义](https://manual.nssurge.com/rules/overview.html)。

## 规则与参数

35 条主规则：32 条远程引用、2 条 Mac 进程、1 条 FINAL。EM=extended-matching，PM=pre-matching。

| 顺序 | 规则 | 策略/参数 |
|---|---|---|
| 1–4 | domainset/reject、non_ip/reject、reject-no-drop、reject-drop | REJECT 系列；Mac 专用；前三条 EM，最后 PM |
| 5 | quic-reject.list | REJECT-NO-DROP，EM；仅指定域名 UDP 443 |
| 6–7 | domainset/cdn、non_ip/cdn | Proxy |
| 8–9 | non_ip/stream、telegram | Stream / Telegram；Telegram EM |
| 10–11 | domainset/apple_cdn、non_ip/microsoft_cdn | DIRECT |
| 12–13 | domainset/download、non_ip/download | Proxy |
| 14–16 | non_ip/apple_cn、apple_services、microsoft | DIRECT / Apple / Microsoft |
| 17–18 | non_ip/ai、apple_intelligence | Intelligence，EM |
| 19–21 | non_ip/global、neteasemusic、wechat.list | Proxy / DIRECT / DIRECT；微信 EM |
| 22–24 | non_ip/domestic、direct、lan | DIRECT |
| 25–28 | ip/reject、telegram、stream、ai | REJECT-DROP / Telegram / Stream / Intelligence；no-resolve |
| 29 | ip/neteasemusic | DIRECT；允许解析 |
| 30–32 | ip/lan、domestic、china_ip | DIRECT；允许解析、双端共享 |
| 33–34 | WeChat、WeChatAppEx | DIRECT，Mac 专用 |
| 35 | FINAL | Proxy，dns-failed |

域名在 IP 前；国内 Apple/Microsoft CDN 在下载前；Apple 中国区在其他 Apple 服务前。未加入此前未获执行授权的 Apple 精确例外。

## 覆盖边界

- CDN 前置会覆盖交集中的 AI、Telegram、Microsoft 等后序专项规则，属于资源类型优先。
- AI、Apple Intelligence、Telegram、微信与 QUIC 拦截保留 EM；其他普通匹配不保证识别只有 IP + SNI 的目标。
- 当前主配置不含 china_ip_ipv6 规则，共享 General 为 ipv6=false、ipv6-vif=disabled；历史 IPv6 核验不代表当前配置。
- 海外与广告专项 IP（reject、telegram、stream、ai）启用 no-resolve，避免未命中域名提前触发本地 DNS；网易云与国内/内网 IP 保留允许解析以兜底国内长尾域名。DNS 失败走 FINAL，不继续匹配 Mac 微信进程。
- 广告主规则为 Mac 专用；历史 iPhone 检查记录了广告增强模块，但本轮手机未连接，不确认当前模块状态。模块独立于模板。
- IPv6 在共享 General；DNS 为 system + 加密 DNS，个人 AliDNS 标识仅在私有副本中保留。
- 模板删除 Keystore、证书引用、远程控制凭据及真实节点/订阅；保留 hostname-disabled，入口不配置旧 hostname 排除清单。

## 当前复核与验证边界（2026-10-13）

- 双端本地配置语法通过，Mac 生效配置、代表性域名和微信裸 IP 进程兜底匹配通过；不是媒体吞吐或全场景验收。
- 微信规则集为 36 条纯域名规则，主配置以 main 引用、外层 EM；无固定提交或外层 no-resolve 要求。已从 always-real-ip 移除 `*.qpic.cn`、`*.qlogo.cn`、`*.weixin.qq.com`、`*.wechat.com` 四个宽泛后缀（仅保留 `localhost.*.qq.com` 与 `localhost.*.weixin.qq.com` 本地登录回调），提升 Fake-IP 下域名与 QUIC 规则直接命中率。
- QUIC 拦截覆盖 qpic.cn、qlogo.cn、video.qq.com、weixin.qq.com、wechat.com（含 sni.cdn.wechat.com）的 UDP 443；不是全局 QUIC 开关，TCP 仍直连。
- Antigravity 的 iPhone 输出证明设备端规则匹配，不证明真实客户端已回退、回退耗时为零、使用 HTTP/2 或下载提速。UDP 拒绝是 ICMP Administratively Prohibited，见 [官方说明](https://manual.nssurge.com/policies/reject.html)。
- 本轮已删除私有 iPhone.conf 的临时管理接口字段，本地语法通过；手机未连接，需重新加载并验证设备侧监听关闭。Mac 6171、61700 无监听，不等于手机端口关闭。
- 不增加宽泛规则。若真实视频仍慢，针对实际 CDN 做同内容出口对照；尚未执行该对照。

## 历史双端验证（2026-10-01，非当前验收）

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

该验证早于后续 IP 参数、IPv6、微信和 QUIC 规则变化，不能称最新全部参数已双端实测。当时临时控制器清理记录仅适用于该次操作，不代表当前真机状态。当前公开模板仍需语法、脱敏与回归检查；未验证媒体吞吐、所有应用行为、网络切换或电池耗电。
