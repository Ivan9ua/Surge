# Surge 双端单文件配置

个人 Surge Mac / iPhone 公开脱敏模板。更新：2026-10-14。基于当前私有 `Surge.conf` 同步，保留分流语义，不发布真实节点、订阅、个人 DNS 标识或证书。

## 文件与使用

| 文件 | 用途 |
|---|---|
| [Surge.conf](Surge.conf) | 唯一主配置：网络、DNS、Host、Ponte、Testing、节点、策略组、分流与 MITM 通用设置 |
| [wechat.list](wechat.list) | 36 条微信纯域名规则，由主配置在线引用 |
| [quic-reject.list](quic-reject.list) | 5 条指定域名 UDP 443 拒绝规则，由主配置在线引用 |
| [BLOG-RULE-AUDIT.md](BLOG-RULE-AUDIT.md) | 规则顺序、已验证结果与未验证边界 |
| [SECURITY.md](SECURITY.md) | 脱敏同步与泄露处理 |
| [scripts/](scripts/) | 同步、安全校验及合成数据回归测试 |

主配置没有 `#!include`，不再维护 `Mac.conf`、`iPhone.conf` 或两份 Shared 分离配置。两个 `.list` 是在线规则集，不是额外设备配置；保留原 URL，避免中断现有引用。

1. 将 `Surge.conf` 复制到自己的私有 Surge iCloud 配置目录。
2. 仅在私有副本替换 `example.com`、`YOUR_PROXY_PASSWORD`、`YOUR_SURGE_SUBSCRIPTION_URL`；Hysteria 普通密码、Gecko 密码分别按服务端要求填写。个人 AliDNS 标识已替换为通用 DoH。
3. 双端均选中同一份 iCloud `Surge.conf`，分别确认自动重载开启。仍使用旧入口的设备须先切换，再清理旧文件。
4. 如需共用 MITM CA，只在私有配置保留证书与 Keystore，并在两台设备分别安装和信任。公开模板没有证书，不能直接覆盖现有生产配置。
5. 修改后分别确认设备实际加载结果。iCloud 同步、Surge 重载、证书信任、在线规则刷新不是同一个步骤，不保证后台立即生效。

`#!MACOS-ONLY` 隔离 Mac 广告主规则、四条微信进程兜底及专用网络/测速参数。模块状态、系统证书信任和运行时策略选择不由单文件完整管理。旧配置先移至私有归档，禁止上传归档。

## 当前策略

排序参考 [Sukka 博客](https://blog.skk.moe/post/i-have-my-unique-surge-setup/)，并非逐项照搬：

广告 → 指定域名 UDP 443 拦截 → CDN → 流媒体 → Telegram → Apple/Microsoft 国内 CDN → 下载 → Apple 中国区/其他服务 → Microsoft → AI/Apple Intelligence → 海外 → 网易云 → 微信 → 国内/直连 → 内网域名 → 专项 IP → 内网/国内 IPv4 → Mac 微信进程 → FINAL。

- CDN 和下载走 Proxy；首条命中可能先于服务专项规则，不保证同一应用全部请求同出口。
- Apple/Microsoft 国内 CDN、Apple 中国区、微信、国内与内网走 DIRECT；其他服务由各自策略组选择。
- AI、Apple Intelligence、Telegram、微信和 QUIC 规则保留 `extended-matching`。
- 广告、Telegram、流媒体、AI 的专项 IP 使用 `no-resolve`；网易云、国内及内网 IP 允许解析。DNS 失败使用 `FINAL,Proxy,dns-failed`，可能早于进程兜底返回。
- 当前 `ipv6=false`、`ipv6-vif=disabled`，不宣称能解决 DNS 污染或下载慢。
- 全局测试使用 HTTP，Hysteria 单独使用 HTTPS；延迟不等于吞吐。地区与机场订阅同属 `节点选择` 分类。
- 保留 skip-proxy、真实 IP 兼容列表、网易云、hostname-disabled；不新增 Apple 精确例外、Telegram ASN 或 MTProto 入站。

## 微信与 QUIC

主配置仅引用一次 `main/wechat.list`，使用 `DIRECT,extended-matching`。`sgshort.wechat.com`、`sgminorshort.wechat.com` 由 `DOMAIN-SUFFIX,wechat.com` 覆盖，无单独代理例外。规则涵盖核心连接、媒体/上传、小程序、支付、定位、企业微信和微信输入法，保留应用内 DNS 与朋友圈广告的逻辑排除；不使用通用腾讯大表、静态 IP/ASN 或顶层 DOMAIN-KEYWORD。

Mac 的 WeChat、WeChatAppEx、XPlayer、WeChatHelper 只兜底前面未命中的请求，不覆盖更早的 CDN/海外规则；iPhone 不应用进程规则。always-real-ip 已移除四个宽泛微信媒体后缀，保留本地登录回调例外。

QUIC 规则覆盖 qpic.cn、qlogo.cn、video.qq.com、weixin.qq.com、wechat.com 的 UDP 443，包含聊天及朋友圈部分媒体域名。它是 **REJECT-NO-DROP 规则级硬拒绝，不是 block-quic=adaptive**；不会自动在 1 秒后放行 QUIC-only 客户端，亦不保证回退、HTTP/2 或提速。[拒绝策略说明](https://manual.nssurge.com/policies/reject.html)

本次保持当前本地分流不变，没有扩大或撤回拦截。此前用户反馈的局部 UDP 拒绝、SG 出口及 Wi-Fi/热点对照均未明显改善慢视频，不能宣称根因已解决。在线规则随 main 发布及设备资源刷新生效，不是修改 README 就已在设备生效。

## 模块与验证

当前 Mac 启用 Sukka Always Real IP Plus、URL Redirect (Minimum)、Local DNS Mapping、Enhance Better ADBlock，以及 iRingo News。模块独立管理，可追加规则与 MITM hostname；主配置不保留旧的宽泛 hostname 排除清单。iPhone 的主配置广告条目被平台条件排除，需另确认其广告模块状态。

2026-10-14：Mac 6.11.0（12510）加载单文件 Surge.conf；合并前后有效内容一致，45/45 远程资源就绪。微信媒体 TCP、OpenAI、Telegram 的代表性分流通过，直连 HTTPS 探测成功。公开模板另经过脱敏、原生配置检查及合成回归测试。

本轮 iPhone 未连接，未验收新入口、自动重载、模块或临时管理接口关闭；Mac 语法通过不等于手机实机通过。也未重新验收朋友圈视频吞吐、所有应用、耗电或网络切换。历史双端记录不作为当前完整验收。

## 安全同步与维护

```bash
bash scripts/sync-local-surge.sh "/path/to/private/Surge" --apply
bash scripts/validate-public-config.sh
bash scripts/test-dns-sanitization.sh
bash scripts/validate-public-config.sh --history-ref HEAD
```

脚本要求源目录存在独立完整的 Surge.conf，先临时脱敏及校验，再覆盖公开模板；缺少源文件或校验失败即停止。两份在线规则保留仓库版本，不从私有目录或历史备份隐式复制。不要直接复制私有配置，也不要在仓库填写生产凭据。

CI 检查单文件结构、凭据/证书、个人 DNS、平台隔离、四个微信进程、规则顺序、关键参数及可达 Git 历史。Linux 无原生 Surge 时仅执行静态校验；原生语法与真实业务测试需分别进行。历史扫描不证明旧 PR 缓存、Fork 或他人克隆已经清理；泄露后先轮换，再按安全策略处理。
