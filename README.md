# Surge 配置

个人 Surge 配置收藏，基于 [SukkaW/Surge](https://github.com/SukkaW/Surge) + [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script) 规则集。

## 文件说明

| 文件 | 说明 |
|------|------|
| `Surge.conf` | Mac 配置模板 |
| `iPhone.conf` | iPhone 配置模板 |
| `Shared.dconf` | 共享规则（代理节点 + 策略组 + 分流规则） |
| `bilibili.sgmodule` | Bilibili 去广告模块（无伪造会员） |
| `youtube-enhance-bounded.sgmodule` | YouTube 增强模块（正文上限 2 MiB） |

## 规则排序逻辑

按“业务白名单优先、专用规则早于通用规则”排序：

```
Bilibili 数据流白名单 → 微信 → 广告拦截 → 内网/国内直连 → AIGC → 流媒体 → Telegram → Apple 中国区 → Apple 服务 → Microsoft → 网易云 → 下载 → 通用 CDN → 海外 → IP规则 → FINAL
```

## 规则源

- [SukkaW/Surge](https://github.com/SukkaW/Surge) — 域名规则 + IP 规则
- [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script) — 微信规则
- 策略组 Smart 自动选优

## 使用方法

1. Mac 导入 `Surge.conf`，iPhone 导入 `iPhone.conf`。
2. 将 `Shared.dconf` 放入 iCloud Drive 的 Surge 目录，确保与设备配置同目录。
3. 将 `Shared.dconf` 中的 `example.com`、`YOUR_SNELL_PSK` 和 `YOUR_SURGE_SUBSCRIPTION_URL` 替换为自己的值。
4. 在 Surge UI 中生成并配置设备自己的 MITM 证书。

### Mac 模块兼容说明

`Surge.conf` 已内置 `[Sukka] Always Real IP Plus` 的独有 Host Lists 条目。为避免与 `Fix Windows No Network Alert`、`HTTP Download Optimization` 等模块重复追加，请不要同时启用 `[Sukka] Always Real IP Plus`。

## 在线模块

- [安装 Bilibili 去广告模块](https://raw.githubusercontent.com/Ivan9ua/Surge/main/bilibili.sgmodule)
- [安装 YouTube Enhance 受控版](https://raw.githubusercontent.com/Ivan9ua/Surge/main/youtube-enhance-bounded.sgmodule)
- [安装 Sukka Google 中国 307 重定向模块](https://ruleset.skk.moe/Modules/google_cn_307.sgmodule)

> 本仓库只保存脱敏模板；请勿提交节点地址、订阅链接、密钥或 MITM 证书。
