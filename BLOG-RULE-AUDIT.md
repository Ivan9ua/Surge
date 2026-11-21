# 配置核对记录

## 2026-10-22 AI 专项更新

- 新增 ai-extra.list：22 条 DOMAIN/DOMAIN-SUFFIX，覆盖 Meta Muse、Copilot、内容域名及 Agent 产品扩展；不含 IP/ASN、宽泛关键词或整套共享登录/支付服务。
- 公开模板及私有配置的 AI 补充、Sukka AI、Apple Intelligence 移到 Apple 中国区及 Apple/Microsoft 通用规则之前，保持原有 CDN/下载规则优先。
- 公开模板现为37条主规则；本地另有云元数据拦截和 captive.apple.com 例外，保留本地已有修改，未借本次发布覆盖其他配置或全面重新同步私有源。
- 维护脚本增加 AI 文件传递、纯域名断言和关键引用/顺序回归。范围与来源见 [AI-EXTRA.md](AI-EXTRA.md)。
- 本轮不验收所有 AI 应用登录、授权、付费、媒体或云端任务；下面的双端结果是2026-10-14历史快照，不代表本轮iPhone已验证。

## 2026-10-14 历史核对快照

更新：2026-10-14。以当前私有单文件和双端有效配置为依据。参考：[Sukka 排序](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)、[首条命中语义](https://manual.nssurge.com/rules/overview.html)。本次发布同步已验证的删除与精简结果，不新增提速规则。

## 规则与参数

源文件共 36 条主规则：31 条在线引用、4 条 Mac 进程、1 条 FINAL。iPhone 排除 4 条 Mac 广告及 4 条进程规则后为 28 条；不含模块注入内容。EM=extended-matching，PM=pre-matching。

| 顺序 | 规则 | 策略/参数 |
|---|---|---|
| 1–4 | domainset/reject、non_ip/reject、reject-no-drop、reject-drop | REJECT 系列；Mac 专用；前三条 EM，最后 PM |
| 5–6 | domainset/cdn、non_ip/cdn | Proxy |
| 7–8 | non_ip/stream、telegram | Stream / Telegram；Telegram EM |
| 9–10 | domainset/apple_cdn、non_ip/microsoft_cdn | DIRECT |
| 11–12 | domainset/download、non_ip/download | Proxy |
| 13–15 | non_ip/apple_cn、apple_services、microsoft | DIRECT / Apple / Microsoft |
| 16–17 | non_ip/ai、apple_intelligence | Intelligence，EM |
| 18–20 | non_ip/global、neteasemusic、wechat.list | Proxy / DIRECT / DIRECT；微信 EM |
| 21–23 | non_ip/domestic、direct、lan | DIRECT |
| 24–27 | ip/reject、telegram、stream、ai | REJECT-DROP / Telegram / Stream / Intelligence；no-resolve |
| 28 | ip/neteasemusic | DIRECT；允许解析 |
| 29–31 | ip/lan、domestic、china_ip | DIRECT；允许解析 |
| 32–35 | WeChat、WeChatAppEx、XPlayer、WeChatHelper | DIRECT，Mac 专用；位于 FINAL 前 |
| 36 | FINAL | Proxy，dns-failed |

## 取舍与精简

- 撤回全部四条内联微信相关 UDP 443 硬拒绝，不保留远程 QUIC 引用。旧 quic-reject.list 的五条规则全部清空，仅保留原 URL 兼容响应；旧缓存仍需设备刷新。
- 微信远程集保持 36 条纯域名规则、DIRECT 与 EM，保留广告/DNS 逻辑排除；不增加全腾讯、静态 IP 或 ASN 大表。
- Mac Testing 段按用户最新编辑保持删除。移除显式默认日志、超时、加密 DNS 跟随、Mac ICMP/hosts 参数，以及 include-all-proxies=0、Smart 中性权重和默认跳端口间隔；没有删除有效的非中性优先级。
- HK/TW/JP/SG 保留高级 0.95、实验性 1.05；US 保留高级 0.95、实验性 1.10。现场核对精简前后实际权重和策略选择未变；模板不保证运行时一直选择同一节点。
- ipv6=false、ipv6-vif=disabled；udp-priority=false 保留，不把它当作可删的默认值。

## 设计边界

- CDN/下载资源类型优先，可能覆盖后序业务交集。微信域名规则与 Mac 进程兜底不能证明具体 CDN 下载健康。
- no-resolve 只限制所附 IP 规则触发解析，后序国内/内网规则仍允许解析；DNS 失败可使用 FINAL，不能保证进入进程兜底。
- 模块、证书信任、运行时策略选择独立于主配置；iPhone 四条主配置广告规则排除，不代表停用了其广告模块。
- 删除自定义硬拒绝不是启用 Adaptive QUIC，也不是允许所有 UDP；独立广告策略与不支持 UDP 时的 REJECT 行为仍在。

## 已验证结果

- Mac 6.11.0（12510）、iPhone Beta 5.102.0（3870）单文件加载；删除后远程资源分别 44/44、40/40 就绪。
- 双端 qpic.cn、qlogo.cn、video.qq.com、weixin.qq.com 的 UDP 443 域名及 IP/SNI 代表性匹配均为微信集 DIRECT；wechat.com 媒体域名的 TCP/QUIC 亦为 DIRECT。AI、Telegram、下载与独立广告代表性匹配正常。
- Mac Apple HTTPS 200、Intelligence 204；iPhone DIRECT 200、Proxy/Intelligence 204。微信公众页原生 HEAD 遇到服务端 HTTP/2 bodyless response 异常，改用经过 Surge 系统代理的 curl GET 返回 200、TLS 校验通过，不能把原 HEAD 异常写成微信不可用。
- Mac 当前共享 CA 系统信任正常；Google.cn 代表性 MITM 与本地重定向、unpkg 有效资源请求通过，普通 Apple 请求未被该 CA 签发。旧 Mac CA 已清理，当前 CA 保留。
- 双端四个 Sukka 模块已核对；Mac 另有 iRingo News，iPhone 另有 Youtube (Music) Enhance。临时 USB 管理接口及转发已关闭，私有源文件恢复，无永久控制器字段。

## 未验证与效果边界

- 用户反馈 iPhone 朋友圈视频已明显改善；没有新的同一未缓存视频、同 CDN、同网络吞吐对照，不能归因于删规则或宣布慢视频根因已解决。此前局部 UDP 拒绝、SG 出口及 Wi-Fi/热点对照均未明显改善。
- 未重新验收 Mac 同视频播放、所有节点和应用、耗电、网络切换、iRingo News 界面功能；未直接审计 iPhone 系统 CA 信任开关或所有应用的证书固定。
- 发布只更新公开模板、规则兼容地址和维护检查，不覆盖两端生产凭据或重新启用管理接口。GitHub CI、设备缓存刷新与真实业务验收须区分。

安全校验与回归命令见 [README](README.md#安全同步与维护)。可达 Git 历史扫描不证明旧 PR 缓存、Fork 或他人克隆已被平台清理。
