# Surge 双端配置

个人 Surge Mac / iPhone 脱敏模板，规则基于 [SukkaW/Surge](https://github.com/SukkaW/Surge)，另维护微信统一规则。同步日期：2026-10-01。

## 文件与使用

| 文件 | 用途 |
|---|---|
| Surge.conf | Mac 入口，对应私有 Mac.conf |
| iPhone.conf | iPhone 入口 |
| Shared-General.dconf | 共享 DNS、IPv6、网络检测与兼容设置 |
| Shared-Routing.dconf | 节点占位符、策略组、分流规则 |
| wechat.list | 微信域名及可见 SNI/Host 统一直连规则 |
| [BLOG-RULE-AUDIT.md](BLOG-RULE-AUDIT.md) | 最新规则顺序、参数和验证边界 |
| [SECURITY.md](SECURITY.md) | 安全同步与泄露处理 |

将四份配置放入同一 Surge 配置目录，分别导入设备入口。在自己的私有副本填写 example.com、YOUR_PROXY_PASSWORD、YOUR_SURGE_SUBSCRIPTION_URL；个人 AliDNS 已替换为通用 DoH。MITM 证书与 Keystore 已删除，需在设备 UI 单独生成和配置。不要将填写后的副本提交到仓库。

双端在 General 引用 Shared-General，在 Proxy、Proxy Group、Rule 各引用一次 Shared-Routing。category 仅用于展示，地区和机场订阅共享分类。ipv6=true、ipv6-vif=auto 放在共享 General。

## 规则排序与策略

主体按 [Sukka 博客](https://blog.skk.moe/post/i-have-my-unique-surge-setup/) 组织，加入个人微信和 Apple Intelligence 规则，并非每个参数都照搬博客：

广告 → CDN → 流媒体 → Telegram → Apple/Microsoft 国内 CDN → 下载 → Apple 中国区/其他服务 → Microsoft → AI/Apple Intelligence → 海外 → 网易云 → 微信 → 国内/直连 → 内网域名 → 广告/Telegram/流媒体/AI/网易云 IP → 内网/国内 IPv4/IPv6 → Mac 微信进程 → FINAL。

- 通用 CDN 和下载走 Proxy；交集以首条命中为准，不保证资源跟随服务专用出口。
- Apple/Microsoft 国内 CDN、Apple 中国区、微信、国内与内网规则走 DIRECT。
- AI 和 Apple Intelligence 使用 Intelligence,extended-matching；其他业务域名规则保留当前普通匹配。
- 所有主配置 IP 规则目前允许解析，未命中域名规则的目标可能发起本地 DNS，再按 IP 分流；失败由 FINAL,Proxy,dns-failed 兜底。
- 全局连通性测试用 HTTP，Hysteria 单独用 HTTPS。测试延迟不是实际吞吐保证。
- 保留 skip-proxy、真实 IP 兼容列表、网易云与 hostname-disabled。不新增 Apple 精确例外；不叠加 Telegram ASN/MTProto 入站规则。

## 微信

共享配置仅引用一次固定提交的 wechat.list，使用 DIRECT,extended-matching,no-resolve；sgshort.wechat.com、sgminorshort.wechat.com 由 DOMAIN-SUFFIX,wechat.com 覆盖，无独立代理例外。

32 条规则覆盖核心连接、媒体/上传、小程序、支付和定位；交叉核对 [Blackmatrix7](https://github.com/blackmatrix7/ios_rule_script/blob/master/rule/Surge/WeChat/WeChat.list)、[ACL4SSR](https://github.com/ACL4SSR/ACL4SSR/blob/master/Clash/Ruleset/Wechat.list)、[NobyDa](https://github.com/NobyDa/Script/blob/master/Surge/WeChat.list)。保留应用内 DNS 和朋友圈广告的逻辑排除，不引入通用腾讯大表、静态 IP/ASN、顶层 DOMAIN-KEYWORD 或内容改写。

微信规则不覆盖先前已命中的 CDN/海外策略；Mac WeChat/WeChatAppEx 进程只兜底此前未命中的请求，iPhone 没有进程兜底。规则判断中 DNS 失败直接进入 FINAL。

[在线微信规则](https://raw.githubusercontent.com/Ivan9ua/Surge/main/wechat.list)。固定提交仍在 main 历史可达；只改说明不必更新固定引用。

## 模块与验证

模块状态不随模板同步。当前个人双端启用 Sukka Always Real IP Plus、URL Redirect (Minimum)、Local DNS Mapping、Enhance Better ADBlock；Mac 另启用 iRingo News。主配置广告条目为 Mac 专用，iPhone 广告拦截依赖已启用模块。模块可追加 MITM hostname，基础入口不设置宽泛 hostname。

最近 USB 核验双端各 20 项代表性匹配一致，四条国内 IP 兜底及 AI EM 已实际加载。运行时 AI 选择美国、Telegram 新加坡、Proxy 香港；这些不是模板对地区的保证。随后最新本地又移除其余五条专项 IP 的 no-resolve，本次照实同步，未重新进行这些参数的双端端到端验收。不宣称所有软件、网速、网络切换或电池表现已经验证。

本仓库不维护 Bilibili/YouTube 模块；远程文件删除不会自动卸载设备模块。

## 安全同步

运行 `bash scripts/sync-local-surge.sh "/path/to/Surge" --apply`，先临时脱敏和完整校验，再更新公开模板。不要直接复制私有配置。提交前运行：

- `bash scripts/validate-public-config.sh`
- `bash scripts/test-dns-sanitization.sh`
- `bash scripts/validate-public-config.sh --history-ref HEAD`

校验包括凭据、证书、个人 DNS、顺序、AI EM、共享 IPv6 和 IP 参数，回归只用合成数据。CI 检查可达 Git 历史，不证明旧 PR 缓存、Fork 或他人克隆已经清理。凭据泄露须先轮换，再按 SECURITY.md 处理历史。
