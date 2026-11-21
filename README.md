# Surge 双端单文件配置

个人 Surge Mac / iPhone 公开脱敏模板。更新：2026-11-22，完成严格公开白名单脱敏映射（外置私有映射表）、全量 `extended-matching` 闭环对齐、微信/AI 规则集瘦身，并正式删除已弃用的 `quic-reject.list`。不发布真实节点、订阅、个人 DNS 标识、管理密钥或证书，也不将模板视为当前设备完整运行态。

## 文件与使用

| 文件 | 用途 |
|---|---|
| [Surge.conf](Surge.conf) | 唯一主配置：网络、DNS、节点、策略组、分流、Host、MITM 与 IP Rewrite 通用设置 |
| [wechat.list](wechat.list) | 11 条微信纯域名差量直连规则，配合 `domestic.conf` 在线引用 |
| [ai-extra.list](ai-extra.list) | 32 条纯域名 AI/Agent 补充规则；与 Sukka AI 配合 |
| [AI-EXTRA.md](AI-EXTRA.md) | AI 补充范围、来源、排序与验证边界 |
| [RULESET-MAINTENANCE.md](RULESET-MAINTENANCE.md) | 2026-11-22 规则集维护、双端运行态样本与校验护栏 |
| [BLOG-RULE-AUDIT.md](BLOG-RULE-AUDIT.md) | 2026-11-22 规则顺序、45 条主规则核对与未验证边界 |
| [SECURITY.md](SECURITY.md) | 脱敏同步、白名单校验与泄露处理 |
| [scripts/](scripts/) | 同步、安全校验及合成数据回归测试 |

主配置没有 `#!include`，不再维护 `Mac.conf`、`iPhone.conf` 或两份 Shared 分离配置。`wechat.list` 与 `ai-extra.list` 在仓库独立维护；已弃用的 `quic-reject.list` 已彻底删除且禁止重新入库。

1. 将 `Surge.conf` 复制到自己的私有 Surge iCloud 配置目录。
2. 仅在私有副本为两个 VLESS 节点分别填写服务器地址和对应的 SNI（模板均为 `example.com`），替换 UUID（`00000000-0000-0000-0000-000000000000`）、`reality-public-key` / `reality-short-id`、`Hikyaku` 的 `exec` 路径与 `addresses`（`198.51.100.1`）以及 `YOUR_SURGE_SUBSCRIPTION_URL`；公开别名 `VLESS-1`、`VLESS-2`、`Hikyaku` 对应私有节点，个人 AliDNS 标识已替换为通用 DoH。
3. 双端均选中同一份 iCloud `Surge.conf`，分别确认自动重载开启。仍使用旧入口的设备须先切换，再清理旧文件。
4. 如需共用 MITM CA，只在私有配置或系统钥匙串配置证书与 `ca-keystore-name`，并在两台设备分别安装和信任。公开模板没有证书，不能直接覆盖现有生产配置。
5. 修改后分别确认设备实际加载结果。iCloud 同步、Surge 重载、证书信任、在线规则刷新不是同一个步骤，不保证后台立即生效。

`#!MACOS-ONLY` 隔离 Mac 独占外置节点 `Hikyaku`、Mac 全量广告重规则（`reject-drop` / `domainset/reject` / `reject-no-drop`，而轻量 374 行 `non_ip/reject.conf` 由双端共享以统一拦截微信 HTTPDNS 与广告域）及五条微信进程兜底（含 `/Applications/WeChat.app/` Bundle 前缀）。已删除 Mac Testing 段与 `[Ponte]` 段；非中性 `US` Smart 权重保留。模块状态、系统证书信任和运行时策略选择不由单文件完整管理。旧配置先移至私有归档，禁止上传归档。

## 当前策略

排序参考 [Sukka 博客](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)，并非逐项照搬：

云元数据双层拦截 → 广告与 HTTPDNS（Mac 全量 + iPhone 共享轻量 `non_ip/reject.conf`）→ CDN → 流媒体 → Telegram → Apple/Microsoft 国内 CDN → `dl.wechat.com` 直连 / 下载与更新 → AI 补充/Sukka AI/Apple Intelligence → Apple 中国区/其他服务 → Microsoft → 海外 → 微信差量 → 国内/直连 → 内网域名 → 专项 IP → 内网/国内 IPv4 & IPv6 → Mac 微信进程 → FINAL。

- 广告主规则按 Sukka 原则将 `non_ip/reject-drop.conf` 置于广告组首位（Mac），与 `domainset/reject.conf` 均联合启用 `pre-matching,extended-matching`，并放开轻量 `non_ip/reject.conf` 双端共享以统一拦截微信私有 HTTPDNS（`dns.wechat.com`、`dns/udns/aedns.weixin.qq.com`）与朋友圈广告（`wxsnsdy`）；CDN 和下载走 Proxy，并在 `domainset/download.conf` 前新增 `DOMAIN,dl.wechat.com,DIRECT,extended-matching`。
- Apple/Microsoft 国内 CDN、Apple 中国区、微信、国内与内网走 DIRECT；其他服务由各自策略组选择。在 `global.conf` 之前为 `ipv4-ip.api.skk.moe`、`ipv6-ip.api.skk.moe`、`ip.api.skk.moe` 指定直走 `VLESS-1`，以规避部分机场节点访问该接口时的 TLS EOF。已移除被 `domestic.conf` 全量覆盖的 `non_ip/neteasemusic.conf`，仅保留 `ip/neteasemusic.conf`（补 `,no-resolve`）兜底国内独有音乐 IP。
- 广告、`cdn`、`stream`、`telegram`、`apple_cdn`、`microsoft_cdn`、`dl.wechat.com`、`download`、`ai-extra`、`ai`、`apple_intelligence`、`Apple` 全段（含 `captive.apple.com` 与 `apple_cn`）、`Microsoft`、`SKK IP API`、`global`、微信差量以及 `non_ip/domestic.conf`、`non_ip/direct.conf` 均启用 `extended-matching`，防止裸 IP HTTP/SNI 请求绕过直连、指定出口或拦截规则。
- 广告、Telegram、流媒体、AI 与网易云音乐的专项 IP 与前置云元数据 IP `169.254.169.254/32` 使用 `no-resolve`；国内及内网 IP 允许解析（`ip/domestic.conf` 保留与 Sukka 模板对称）。DNS 失败使用 `FINAL,Proxy,dns-failed`，可能早于进程兜底返回。
- DoH 上游仅保留公共/私人阿里 DNS + 单路腾讯 `1.12.12.12`（移除同商冗余的 `120.53.53.53`，减少重复查询和 429；蜂窝切换仍需观察）。`always-real-ip` 已剔除 `musicapi.taihe.com` 与 `mdn.open.wo.cn` 两条无解析死域，并将 `*.126.net` 精准收窄为 `*.music.126.net`；`skip-proxy` 移除 Enhanced Mode 下不再需要的 5 段历史公网 CIDR（`162.14.0.0/16`、`211.99.96.0/19`、`162.159.192/193/195.0/24`），保留内网段与国内银联/App 例外。
- 当前 `ipv6=true`、`ipv6-vif=auto`，并已在末尾 IP 规则加入 `china_ip_ipv6.conf` 处理国内 IPv6 直连；不宣称可单独解决特定运营商或下载限速问题。
- 全局测试使用 HTTP，延迟不等于吞吐。地区与机场订阅同属 `节点选择` 分类。
- 策略组依次为 Proxy、Intelligence、Stream、Telegram、Apple、Microsoft、HK、TW、JP、SG、US、Subscription。地区选项统一为 HK、TW、JP、SG、US；AI 组保留 US 首位，其余地区按相同相对顺序排列，`Stream` 由代理组接管。
- DNS 劫持仅配置 `8.8.8.8:53`、`8.8.4.4:53`；主配置 `[Host]` 保留 DoH 引导映射（公开版使用 `dns.alidns.com = 223.5.5.5, 223.6.6.6`），设备启用的 Local DNS Mapping 模块另行提供国内规则分流映射。
- `[General]` 通过 `tun-included-routes = 169.254.169.254/32` 配合 `[IP Rewrite]`（`169.254.169.254 = reject`）及前置 `IP-CIDR,169.254.169.254/32,REJECT-NO-DROP,no-resolve,pre-matching` 完成云元数据探测双层阻断；保留 `skip-proxy`、`always-real-ip`（含多级 `time.*.apple.com`）、网易云、`hostname-disabled`。

## 微信与 QUIC

主配置仅引用一次 `main/wechat.list`，使用 `DIRECT,extended-matching`。自 2026-11-21 起，`wechat.list` 按 Sukka 差量原则瘦身为 **11 条纯 `DOMAIN`/`DOMAIN-SUFFIX` 规则**（配合已启用 `extended-matching` 的 `non_ip/domestic.conf`）：仅保留 Sukka 未覆盖的微信海外（`wechat.com` 等）、支付（`tenpay.com`、`wechatpay.com`、`wechatpay.cn`）、小程序（`servicewechat.com`）、开放网关（`wxgateway.com`）、企业微信（`wecom.work`）及微信生态（`wetype.cn`、`iot-tencent.com`、`wechatlegal.net`、`slife.xy-asia.com`）；已清除与 `domainset/reject.conf` 冲突的 5 条规则、24 条被 `domestic.conf` 覆盖的重叠项及无有效解析的历史条目，并取消规则集内 `AND/NOT` 排除逻辑（微信 HTTPDNS 与朋友圈广告统一交由主配置顶部 `reject` 规则双端拦截）。`dl.wechat.com` 在 `download.conf` 前显式直连；不使用通用腾讯大表、静态 IP/ASN 或顶层 `DOMAIN-KEYWORD`。

Mac 的 WeChat、WeChatAppEx、XPlayer、WeChatHelper 和 `/Applications/WeChat.app/` 路径前缀只兜底前面未命中的请求，不覆盖更早的 CDN/海外规则；iPhone 不应用进程规则。always-real-ip 已移除四个宽泛微信媒体后缀，保留本地登录回调例外。

已彻底撤回 `qpic.cn`、`qlogo.cn`、`video.qq.com`、`weixin.qq.com` 四条内联 UDP 443 硬拒绝，并删除仓库中已弃用的 `quic-reject.list` 文件（校验脚本同步禁止再次引用或恢复该文件）。双端代表性 UDP 443 域名及携带可见 SNI 的请求按当前规则直连。自有 `wechat.list` 覆盖微信差量域名，Sukka `domestic.conf` 覆盖包括 `qpic.cn`、`qlogo.cn` 和朋友圈视频在内的常见微信媒体域名。这不影响独立广告规则，也不等于启用 `block-quic=adaptive`。

此前用户反馈的局部 UDP 拒绝、SG 出口及 Wi-Fi/热点对照均未明显改善慢视频，未证明硬拒绝有稳定收益，因此彻底清理不再保留。用户近期反馈 iPhone 视频已明显改善，但不能将改善归因于删除规则。若未来确有实测必要，仅在独立新规则分支中验证，不恢复未经验证的宽泛拦截。

## 模块与验证

2026-11-22 仓库安全加固与文档同步：将私有节点/订阅组名称映射外迁至本机 `$HOME/.config/surge-public-sync/aliases.map`，并将公开校验升级为严格名称白名单与中性图标校验；正式删除已弃用的 `quic-reject.list`，同步更新全部维护脚本、回归测试与文档至最新双端单文件状态。

2026-11-21 `extended-matching` 闭环收口：为 Mac `non_ip/reject-drop.conf`（联合 `pre-matching`）与双端 `non_ip/global.conf` 补齐 `,extended-matching`。Mac 端 `rule explain` 实测裸 IP + `sni=beacon.qq.com` / `telemetry.mozilla.org` 精准命中 `reject-drop.conf`（`REJECT-DROP`），双端实测国内公网裸 IP + `sni=www.google.com` 精准命中 `global.conf`（`Proxy`），iPhone 内存约 24.1 MB。

2026-11-21 P2 规则 SNI 对齐与洁癖精简：同步为 `captive.apple.com`、`apple_cn.conf`、`apple_services.conf`、`microsoft.conf` 与 3 条 `*.api.skk.moe` 补齐 `,extended-matching`，将 `always-real-ip` 中 `*.126.net` 收窄为 `*.music.126.net`，并自 `skip-proxy` 移除 5 段历史公网 CIDR（保留 `udp-priority = false` 与 Mac `non_ip/reject-no-drop.conf`）。同时合入 `ai-extra.list`（32 条）并于双端定向刷新；Mac（`surge-cli`）与 iPhone（MCP）均实测 SNI 分流与扩展内存（~23.7 MB）正常。

2026-11-21 双端全字段与运行态审计优化落地：移除同属 DNSPod 的重复 DoH `120.53.53.53` 以消除高频 429、为 Mac `domainset/reject.conf` 及双端 `apple_cdn` / `microsoft_cdn` 补齐 `extended-matching`、清理 `non_ip/neteasemusic.conf` 与两条无解析死域（`musicapi.taihe.com`、`mdn.open.wo.cn`）、为 `ip/neteasemusic.conf` 补 `,no-resolve`（保留 `ip/domestic.conf` 对称结构）、从 `ai-extra.list` 移除 3 条已被 `domainset/cdn.conf` 遮蔽条目（35 → 32 条），并增补 Mac 微信 App Bundle 前缀规则 `PROCESS-NAME,/Applications/WeChat.app/,DIRECT #!MACOS-ONLY`。Mac（`surge-cli`）与 iPhone（MCP）均实测 SNI 分流、DoH diagnostics、微信子进程匹配及内存（~23.8 MB）正常。

2026-11-21 微信规则 Sukka 原则瘦身与双端统一：放开轻量 `non_ip/reject.conf`（374 行）双端共享、新增 `DOMAIN,dl.wechat.com,DIRECT,extended-matching` 绕过 `download.conf`、为 `non_ip/domestic.conf` 与 `non_ip/direct.conf` 补齐 `,extended-matching`，并将 `wechat.list` 精简为 11 条纯域名差量集（剔除 5 条与 `domainset/reject.conf` 冲突项及 24 条重叠项，补入实测访问的 `wxgateway.com`）。Mac（`surge-cli`）与 iPhone（MCP）均已实测验证：`dl.wechat.com`、`sgshort.wechat.com`、`mmbiz.qpic.cn` 命中 `DIRECT`，`dns.wechat.com`、`dns.weixin.qq.com`、`udns.weixin.qq.com`、`wxsnsdy.wxs.qq.com` 均前置命中 `REJECT`，iPhone 扩展内存约 24.7 MB、运行正常。

2026-11-21 广告排序对齐与 AI 补充扩充：调整 Mac 端 `#!MACOS-ONLY` 广告组将 `non_ip/reject-drop.conf` 上移至首位，`rule explain` 实测 `telemetry.mozilla.org`、`mobile.events.data.microsoft.com`、`beacon.qq.com` 已恢复直接命中 `REJECT-DROP`（iPhone 同步加载）。同时从实测漏网流量与第三方线索人工筛选 13 条纯净 AI/MCP/Agent 域（含 `metaaivm.com`、`context7.com`、`nousresearch.com`、`perplexity.com`、`huggingface.co` 及精确主机 `jetski-webchannel.googleapis.com` 等）补入 `ai-extra.list`（22 → 35 条）。

2026-11-20 双端 Core `6013000`（Mac `6.13.0 (12910)` + iPhone `6.100.0 (4041)`）连续运行 4 小时以上实测：双端配置与 `[Rule]` 已同步一致（`169.254.169.254/32` 双层阻断及 3 条 `api.skk.moe` 规则均生效），6.13 Smart 组新算法、IPv6 双栈及默认 TLS `client-fingerprint=auto`（`apple-26`）均稳定运行、零代理握手失败；外置连接桥接脚本亦已消除单标签主机名漏网。

2026-11-19 双端实测与公开脚本适配：Mac 6.12.0 (12900) 与 iPhone iOS 6.100.0 (4034) 已同步单文件配置（Core 6012000，无 `[Ponte]`，`[Keystore]` 外迁）。Mac 启用 Sukka 4 件套与 iRingo News / TV app，iPhone 启用 Sukka 4 件套与 Youtube (Music) Enhance；Mac 共用 CA（`MITM-iPhone-CA`）真实 HTTPS MITM 重定向验签通过（系统 TLS 验证正常），`169.254.169.254/32` 精准纳入 VIF 路由与前置 `no-resolve,pre-matching` 规则对直连 VIF 与代理端口均已验证生效，同时未触发域名规则额外 DNS 查询。同步更新 `scripts/sync-local-surge.sh`、`scripts/validate-public-config.sh` 与 `scripts/test-dns-sanitization.sh`，补全对 VLESS（UUID / REALITY）与 `external` 节点的脱敏、校验及回归测试。

2026-10-14 历史模块快照（注：自 2026-11-21 起已改为双端共享轻量 `non_ip/reject.conf`）：该历史快照记录时双端均启用 Sukka Always Real IP Plus、URL Redirect (Minimum)、Local DNS Mapping、Enhance Better ADBlock；Mac 另启用 iRingo News，iPhone 另启用 Youtube (Music) Enhance。模块独立管理，可追加规则与 MITM hostname；模板不包含模块启用记录，模块也不等于完整域名广告拦截。

2026-11-01 整理后核验：Mac 6.11.0（12660）、iPhone iOS 6 Beta（4004）的 General、Proxy Group、Rule 内容一致，手机手动策略选择未变化；微信媒体抽样 DIRECT，ChatGPT 与 Apple Intelligence 抽样进入 Intelligence。该结果仅证明代表性规则命中，不证明媒体吞吐或地区解锁。

私有配置使用 iPhone MCP 管理接口，公开同步会移除整组 HTTP API/MCP 设置和全部管理密钥。自建 Mac 连接工具与 USB 转发保存在仓库之外，不随模板发布。该手机构建的热点无线管理端口不可达，已验证热点上网同时通过 USB 转发调用 MCP；临时 External Controller 与热点访问测试项已清理。

2026-10-14 双端现场核验：Mac 6.11.0（12510）、iPhone Beta 5.102.0（3870）均加载单文件；删除 QUIC 引用后分别 44/44、40/40 远程资源就绪。微信媒体 TCP/QUIC 为 DIRECT，AI、Telegram、下载与独立广告代表性匹配正常。Mac 直连 HTTPS 200、AI 探测 204；iPhone DIRECT 200、Proxy/Intelligence 204。临时 USB 管理设置已清理，未发布控制器凭据。

Mac 共用 CA 信任与代表性 MITM 请求已验证；旧 Mac CA 已移除，当前 CA 保留。iPhone 系统证书信任开关、应用证书固定未逐项审计。没有新的同视频吞吐对照，也未全量验收所有应用、节点、耗电、网络切换或 iRingo News 界面功能。公开模板的原生语法与合成回归测试不能替代这些业务验收。

## 安全同步与维护

```bash
bash scripts/sync-local-surge.sh "/path/to/private/Surge" --apply
bash scripts/validate-public-config.sh
bash scripts/test-dns-sanitization.sh
bash scripts/validate-public-config.sh --history-ref HEAD
```

脚本要求源目录存在独立完整的 Surge.conf，先临时脱敏及校验，再覆盖公开模板；缺少源文件或校验失败即停止。私有节点名与订阅策略组名通过仅保存在本机的 `$HOME/.config/surge-public-sync/aliases.map`（或 `SURGE_ALIAS_MAP`）映射为公开白名单别名，绝不写入公开仓库。在线规则文件（`wechat.list`、`ai-extra.list`）保留仓库版本，已弃用的 `quic-reject.list` 禁止重新入库，不从私有目录或历史备份隐式复制。不要直接复制私有配置，也不要在仓库填写生产凭据。

CI 逐个检查维护脚本语法，并校验单文件结构、凭据与证书、个人 DNS、平台隔离、微信进程兜底、规则顺序、Smart 权重格式、公开名称白名单、`quic-reject.list` 删除状态及可达 Git 历史。额外配置、备份文件和文档中的管理或订阅字段也纳入发布检查。Linux 无原生 Surge 时仅执行静态校验；原生语法与真实业务测试需分别进行。历史扫描不证明旧 PR 缓存、Fork 或他人克隆已经清理；泄露后先轮换，再按安全策略处理。
