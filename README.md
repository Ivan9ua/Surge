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
| `youtube-enhance.qxrewrite` | Maasea YouTube 增强模块的 Quantumult X 原生转译版 |
| `google-cn-redirect.qxrewrite` | Sukka Google 中国 307 重定向模块的 Quantumult X 原生转译版 |

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

Mac 以 `[Sukka] Always Real IP Plus` 为主要 Host Lists 模块。为避免重复追加，请启用该模块，并停用 `Fix Windows No Network Alert` 与 `HTTP Download Optimization`；`Surge.conf` 只保留 Sukka 模块未覆盖的基础项和 `*.windowsupdate.com`。

## 在线模块

- [安装 Bilibili 去广告模块](https://raw.githubusercontent.com/Ivan9ua/Surge/main/bilibili.sgmodule)
- [安装 YouTube Enhance 受控版](https://raw.githubusercontent.com/Ivan9ua/Surge/main/youtube-enhance-bounded.sgmodule)
- [安装 Quantumult X YouTube Enhance](https://raw.githubusercontent.com/Ivan9ua/Surge/main/youtube-enhance.qxrewrite)
- [安装 Quantumult X Google 中国 307 重定向](https://raw.githubusercontent.com/Ivan9ua/Surge/main/google-cn-redirect.qxrewrite)

> 本仓库只保存脱敏模板；请勿提交节点地址、订阅链接、密钥或 MITM 证书。

## 安全同步与校验

不要直接把正在使用的 Surge 配置复制到公开仓库。需要同步时，使用带脱敏和失败保护的脚本：

```bash
scripts/sync-local-surge.sh "/path/to/Surge" --apply
```

脚本会先在临时目录删除 MITM 私钥材料，并将 Snell 地址、PSK 与订阅地址替换为占位符；只有完整校验通过后才会更新仓库文件。提交前可再次运行：

```bash
scripts/validate-public-config.sh
scripts/verify-remote-integrity.sh
```

CI 会检查整个 Git 历史，阻止凭据重新进入公开提交。可执行远程脚本尽量固定到上游提交；无法固定的 Bilibili 脚本使用 SHA-256 清单监控内容变化。

发现真实凭据进入 Git 历史时，删除当前文件并不足够：必须先轮换凭据，再重写历史并清理所有可达分支。详见 `SECURITY.md`。
