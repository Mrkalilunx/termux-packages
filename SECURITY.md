# 安全政策和程序

Termux 团队非常重视所有安全漏洞，我们鼓励外部各方和用户报告这些问题。我们也是安全透明度的坚定信仰者，我们根据负责任的披露时间表，公开披露我们自己团队发现或由其他人报告的所有漏洞。

# 报告错误或安全漏洞

Termux 团队和社区非常重视所有安全漏洞。如果报告有效，我们将在 3 个工作日内确认报告。

termux 包或 termux 基础设施的安全问题应在 termux/termux-packages 中报告，而应用程序中的安全问题应在 [termux/termux-app](https://github.com/termux/termux-app) 中报告。

## 通过 GitHub 安全建议报告安全漏洞（首选）

报告安全漏洞的首选方式是通过 [GitHub 安全建议](https://github.com/advisories)。这允许我们在保持报告机密性的同时协作修复漏洞。

要报告漏洞（[另请参阅文档](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)）：

1. 访问[安全选项卡](https://github.com/termux/termux-packages/security)
2. 点击报告漏洞并按照提供的步骤操作。

## 通过电子邮件报告

发送电子邮件（最好使用 gpg 加密）给根据 git 历史记录似乎负责受影响组件的维护者。您可以在 [termux-keyring 包](https://github.com/termux/termux-packages/tree/master/packages/termux-keyring) 中找到我们的公共 gpg 密钥。请直接在电子邮件中包含所有相关详细信息，并发送给多个维护者。我们将致力于在 3 个工作日内回复，提供进展更新，并可能要求提供更多详细信息。

## 包和分叉中的问题

如果您在包中发现了安全问题，例如 openssh，并且该问题也可以在非 termux 安装中重现，那么应将该问题报告给上游开发人员。

如果您使用的是 termux 的分叉，那么我们将很感激您首先验证该问题在我们提供的 termux 版本中是否可重现。这也有助于验证问题不是源自配置更改。

# 披露政策

当安全团队收到安全错误报告时，它将被分配给一名开发人员。此人员将协调修复和发布过程，包括以下步骤：

* 确认问题并确定受影响的环境。
* 准备修复。修复将尽快推送到仓库。

在修复可用大约 30 天后，问题将在 github 和 [https://termux.dev](https://termux.dev/en/posts/index.html) 上披露。

# 对此政策的评论

如果您对如何改进此过程或文档有建议，请提交拉取请求！
