# AI / Agent 补充规则

更新：2026-11-21。ai-extra.list 共32条，作为 Sukka AI 和 Apple Intelligence 的补充，而非完整替代。仅 DOMAIN / DOMAIN-SUFFIX；引用到 Intelligence 并启用 extended-matching。域名集合不是访问控制白名单，也不是可用性或地区资格保证。

## 收录与来源

| 产品 | 范围与理由 | 依据 |
|---|---|---|
| Meta Muse | muse.ai、metaaivm.com（专用Agent VM）、museai.com；与已有meta.ai不同，不收共享域meta.graph.meta.com | [Meta公告](https://about.fb.com/news/2026/09/introducing-muse-personal-ai-agent/) 与实测流量 |
| Antigravity / Gemini Code Assist | 仅精确主机 jetski-webchannel.googleapis.com、cloudaicompanion.googleapis.com，绝不扩大到 googleapis.com | 实测活跃连接与 [Google Cloud文档](https://cloud.google.com/gemini/docs/codeassist/overview) |
| MCP 与 AI 研发工具 | context7.com、tavily.com、gemini-api-docs-mcp.dev、nousresearch.com；含实测高频漏入FINAL的MCP及模型工具域 | 实测流量与 [Context7](https://context7.com/)、[Tavily](https://tavily.com/)、[Nous Research](https://nousresearch.com/) |
| Perplexity | perplexity.com、pplx.ai；实测未命中通用列表而落入FINAL | [Perplexity](https://www.perplexity.ai/) |
| Hugging Face | hf.co、hf.space、huggingface.co；模型与Space权重下载及访问 | [Hugging Face](https://huggingface.co/) |
| Microsoft Copilot | copilot.microsoft.com、copilot.cloud.microsoft、copilot.com，新旧产品入口 | [微软文档](https://support.microsoft.com/en-us/microsoft-365-copilot/what-is-microsoft-copilot-app) |
| GitHub Copilot | githubcopilot.com；api.github.com 及 copilot-proxy/origin-tracker.githubusercontent.com 已由 Sukka AI / domainset/cdn.conf 承担 | [官方白名单](https://docs.github.com/en/copilot/reference/copilot-allowlist-reference) |
| Claude内容 | claudeusercontent.com，产品内容域候选 | [ACL4SSR列表](https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/Ruleset/AI.list)；本轮无完整官方白名单或真实附件请求验收 |
| Cursor | cursor.com、cursorapi.com、cursorvm.com；cursor.sh由Sukka承担 | [官方网络文档](https://cursor.com/docs/enterprise/network-configuration) |
| Windsurf/Codeium | codeium.com、codeiumdata.com、windsurf.com产品范围 | [官方网络排障](https://docs.devin.ai/desktop/troubleshooting/windsurf-common-issues) |
| Manus | manus.im及api.manus.ai；不是Meta Muse | [官网](https://manus.im/)、[API文档](https://open.manus.ai/docs/v2/introduction) |
| Genspark / Devin / Augment | genspark.ai、devin.ai、augmentcode.com产品入口 | [Genspark](https://www.genspark.ai/)、[Devin](https://docs.devin.ai/)、[Augment](https://www.augmentcode.com/) |
| Lovable / Bolt | lovable.dev、bolt.new产品入口，不收整个用户发布平台 | [Lovable](https://lovable.dev/)、[Bolt](https://bolt.new/) |

产品入口或官方网络文档证明域名用途，不证明每个接口都必须通过美国出口，也不证明附属第三方服务全部覆盖。产品后缀仍可能匹配文档、更新、遥测、扩展市场和任务内容。

## 顺序及边界

```ini
# 保留原有广告、CDN、下载等前置规则
RULE-SET,https://raw.githubusercontent.com/Ivan9ua/Surge/main/ai-extra.list,Intelligence,extended-matching
RULE-SET,https://ruleset.skk.moe/List/non_ip/ai.conf,Intelligence,extended-matching
RULE-SET,https://ruleset.skk.moe/List/non_ip/apple_intelligence.conf,Intelligence,extended-matching
# 然后是 Apple 中国区和 Apple/Microsoft 通用规则，IP 段仍靠后
```

- 不添加整套 facebook.com、instagram.com、whatsapp.net、googleapis.com、microsoft.com、auth0.com、stripe.com或云服务商ASN。
- 不增加MITM hostname、脚本、QUIC硬拒绝或修改策略组选择。
- 前置模块和CDN/下载规则仍可能先命中，不承诺所有AI关联请求统一出口；登录等共享服务保留原有策略；其中 `oaiusercontent.com` 与 `copilot-proxy/origin-tracker.githubusercontent.com` 因已被前置 `domainset/cdn.conf` 完全覆盖而移除，保持零死规则。
- Muse的云VM或其他云端Agent访问第三方站点的请求不经过本机Surge，不能靠本机分流规则控制其完整任务网络。
- 更新远程列表和更新主配置顺序是两件事；设备需加载最新共享配置并刷新新增资源。

## 检查

维护检查要求32条不重复纯域名规则、正确引用和顺序，回归测试拒绝IP混入、共享认证后缀扩大、已被前置CDN遮蔽条目及引用丢失。离线原生语法和静态命中检查不等于实际登录、上传、授权、付款或全部Agent功能验收；不宣称提速倍数或100%覆盖。
