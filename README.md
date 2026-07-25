# Surge 配置

个人 Surge 配置收藏，基于 [SukkaW/Surge](https://github.com/SukkaW/Surge) + [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script) 规则集。

## 文件说明

| 文件 | 说明 |
|------|------|
| `Surge.conf` | 通用配置模板（Mac / iPhone 通用，需替换节点和订阅） |
| `Shared.dconf` | 共享规则（代理节点 + 策略组 + 分流规则） |
| `bilibili.sgmodule` | Bilibili 增强模块 |

## 规则排序逻辑

按命中频率排序，减少规则遍历：

```
广告拦截 → 内网/国内直连 → 微信 → CDN → 流媒体 → AIGC → Telegram → Apple → Microsoft → 网易云 → 下载 → 海外 → IP规则 → FINAL
```

## 规则源

- [SukkaW/Surge](https://github.com/SukkaW/Surge) — 域名规则 + IP 规则
- [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script) — 微信规则
- 策略组 Smart 自动选优

## 使用方法

1. 将 `Surge.conf` 导入 Surge
2. 将 `Shared.dconf` 放入 iCloud Drive Surge 目录
3. 替换 `[Proxy]` 段为你的代理节点
4. 替换 `Flower Cloud` 订阅链接
5. 在 Surge UI 中配置 MITM 证书

## 从本地 Surge 同步到仓库

如果需要把当前设备上的 Surge 配置更新回仓库，可以运行：

```bash
scripts/sync-local-surge.sh /path/to/Surge
```

不传路径时，脚本会尝试查找 macOS 上常见的 Surge / iCloud Drive 配置目录，并同步 `Surge.conf`、`Shared.dconf`、`bilibili.sgmodule` 中存在的文件。同步后请检查 diff，确认没有误提交敏感订阅或节点信息。
