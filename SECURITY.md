# 安全策略

本仓库是公开的 Surge 脱敏模板仓库。任何代理地址、订阅链接、PSK、MTProto secret、远程控制密码、令牌、MITM 证书或私钥材料都不得提交。

## 提交前检查

```bash
scripts/validate-public-config.sh
scripts/verify-remote-integrity.sh
```

本地真实配置仅能通过 `scripts/sync-local-surge.sh <目录> --apply` 同步。该脚本先在临时目录脱敏并校验，校验失败时不会覆盖仓库文件。

## 泄露响应

如果凭据曾进入任何 Git 提交：

1. 立即轮换对应凭据或证书。
2. 检查所有分支、标签、PR 和 Fork 是否仍可访问旧对象。
3. 使用 `git filter-repo` 或干净根提交重写历史。
4. 强制更新远端后重新扫描完整历史。
5. 通知已有克隆的使用者重新克隆，不要把旧历史推回远端。

不要在 Issue 或 PR 中粘贴真实凭据。安全问题请通过 GitHub 仓库所有者的私密联系方式报告。
