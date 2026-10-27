# 规则集维护核对

核对日期：2026-10-26。范围为本仓库自有规则、维护检查和 Mac 当前引用；不全量同步私有主配置，不改节点、订阅、证书或策略组选择。

## 当前结果

| 文件 | 有效规则 | 核对结果 |
|---|---:|---|
| wechat.list | 36 | GitHub Raw、GitHub API 与本地仓库一致；无重复，保留三条广告/应用内 DNS 排除逻辑 |
| ai-extra.list | 22 | GitHub Raw、GitHub API 与本地仓库一致；无重复，仅 DOMAIN/DOMAIN-SUFFIX |
| quic-reject.list | 0 | 空兼容地址保持停用，未恢复 UDP 443 硬拒绝 |

本轮没有足够证据增删业务域名，三份规则文件内容保持不变。Raw 与 API 现场比对优先于搜索引擎缓存。维护日期不表示全部域名已完成真实业务验收。

## Mac 运行态样本

- wechat.list 与 ai-extra.list 在线资源均为 ready。
- sgshort.wechat.com、sgminorshort.wechat.com、c2c.cdn.wechat.com、wximg.qq.com、qpic.cn 命中微信规则 DIRECT。
- dns.weixin.qq.com、udns.weixin.qq.com、wxsnsdy.wxs.qq.com 命中前置广告拒绝，未被微信直连放行。
- Muse、微软 Copilot 命中 AI 补充；Apple Relay 命中 Apple Intelligence。策略选择是运行态，不据此改写公开模板。
- files.oaiusercontent.com 与 www.claudeusercontent.com 仍先命中 CDN → Proxy → HK。保留已确认的资源优先取舍，不称所有 AI 资源统一美国。

## 本次修复的维护缺陷

1. 微信关键条目由子串检查改为整行检查，避免 `weixin.com.invalid` 被误认作 `weixin.com`。
2. 新增去重检查，避免重复条目在总数不变时掩盖其他域名的丢失。
3. 检查纯域名行格式及三条已固定的逻辑排除数量，拒绝规则集内误带策略字段；已存在的三条逻辑表达式继续由精确断言保护。

三个隔离夹具分别在旧实现下复现误放行，修复后与原有脱敏、失败不覆盖、AI 边界及 QUIC 停用回归一起通过。没有增加依赖、后台服务或新工作流。

## 验证边界

脚本语法、原生配置检查、工作区 diff 和可达 HEAD 历史模式扫描通过。未连接 iPhone，未复测微信视频吞吐、AI 登录/附件/授权/付款或 GitHub Copilot。历史模式扫描不是平台缓存、Fork 和旧 PR 引用清理证明。
