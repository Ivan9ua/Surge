# 当前配置核对记录

更新：2026-10-14。以单文件 Surge.conf 和 Mac 实际生效配置为准。参考：[Sukka 排序](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)、[首条命中语义](https://manual.nssurge.com/rules/overview.html)。本次是架构同步及文档修正，不新增性能优化规则。

## 规则与参数

源文件共 37 条主规则：32 条在线引用、4 条 Mac 进程、1 条 FINAL。iPhone 排除 4 条 Mac 广告及 4 条进程规则后为 29 条。这是源文件计数，不含模块注入内容。EM=extended-matching，PM=pre-matching。

| 顺序 | 规则 | 策略/参数 |
|---|---|---|
| 1–4 | domainset/reject、non_ip/reject、reject-no-drop、reject-drop | REJECT 系列；Mac 专用；前三条 EM，最后 PM |
| 5 | quic-reject.list | REJECT-NO-DROP，EM；指定域名 UDP 443 硬拒绝 |
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
| 30–32 | ip/lan、domestic、china_ip | DIRECT；允许解析 |
| 33–36 | WeChat、WeChatAppEx、XPlayer、WeChatHelper | DIRECT，Mac 专用；位于 FINAL 前 |
| 37 | FINAL | Proxy，dns-failed |

## 设计边界

- CDN/下载资源类型优先，可能覆盖后序业务交集。域名规则与进程规则均不能证明具体 CDN 的下载健康。
- no-resolve 只限制所附 IP 规则为匹配域名触发解析，后序允许解析规则仍可查询 DNS。DNS 失败使用 FINAL，不保证走到进程兜底。
- 主配置关闭 IPv6，不引用 china_ip_ipv6；DNS 为 system + 加密 DNS。该选择不是下载或 DNS 污染问题已解决的证据。
- 微信集为 36 条纯域名规则，保留广告/DNS 逻辑排除；已移除四个宽泛微信 always-real-ip 后缀，保留本地登录回调。
- QUIC 集为 5 条，覆盖 qpic.cn、qlogo.cn、video.qq.com、weixin.qq.com、wechat.com；是规则级硬拒绝，不等于 Adaptive QUIC，也不保证客户端回退。[拒绝策略说明](https://manual.nssurge.com/policies/reject.html)
- 广告主规则为 Mac 专用，iPhone 覆盖依赖设备模块；模块状态、证书信任和运行时策略选择不由模板完整管理。

## 本轮验收与未完成项

- 私有主配置无 include，旧入口及分离文件已移至私有归档；公开仓库移除对应旧模板，微信及 QUIC 在线 URL 不变。
- Mac 6.11.0（12510）重载成功，合并前后有效配置一致，45/45 资源就绪。微信媒体 TCP 为 DIRECT、OpenAI 为 Intelligence、Telegram 为 Telegram；直连 HTTPS 探测返回 200。策略组当时选择美国/新加坡，不是模板对运行时选择的保证。
- 共用 CA 的 Mac 系统信任校验通过；公开模板不含证书、Keystore 或引用。旧 Mac CA 清理仍受系统授权限制，不能写成已完成。
- 本轮 iPhone 未连接，新入口、自动重载、模块状态与管理接口关闭未做新真机验收；Mac 语法检查不能代替这些事项。
- 此前局部 UDP 拒绝、SG 出口及 Wi-Fi/热点对照未明显改善用户报告的慢视频。本轮无新的同内容吞吐结果，不能称朋友圈视频问题已修复，也不继续堆叠宽泛规则。
- 2026-10-01 的历史双端匹配早于后续 IP、IPv6、微信和 QUIC 修改，仅作历史记录，不替代本轮验收。

安全校验与回归命令见 [README](README.md#安全同步与维护)。发布后须区分 GitHub CI、设备资源刷新与真实业务验收。
