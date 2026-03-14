# 贡献

Termux 是一个开源应用程序，它建立在用户的贡献之上。
然而，大部分工作由 Termux 维护者在业余时间完成，
因此只完成优先任务。

开发者维基可在 https://github.com/termux/termux-packages/wiki 获取。

## 您如何为 Termux 项目做出贡献

- **报告问题**

  如果您发现了问题，请告知社区。

  请做好准备，问题可能不会立即得到解决。我们将忽略
  "快速解决"、"急需解决方案"等说法。请保持耐心。

  避免挖掘和评论旧的、已关闭的问题。仔细阅读它们
  - 很可能它们已经给出了解决方案。如果不起作用，则打开一个新问题。
  请注意，我们将锁定真正过时的问题。

  您只能报告在我们官方包中发生的问题。不要
  提交在第三方软件中发生的问题 - 我们将忽略它们。

  不接受传统 Termux 安装（Android 5.x / 6.x）的错误报告。
  我们已经放弃了对这些 Android 操作系统版本的支持。

- **检查现有包的潜在问题**

  包中可能存在未发现的错误。例如：未指定的
  依赖项、未加前缀的硬编码 FHS 路径、崩溃等。

  如果您无法提交带有修复问题的补丁的拉取请求，您可以
  打开新的[问题](https://github.com/termux/termux-packages/issues/new/choose)。

- **修复已知错误**

  查看https://github.com/termux/termux-packages/issues。有许多
  问题标签为 `bug report` 或 `help wanted`。它们都在等待
  解决。

- **提交新包**

  有许多未解决的[包请求](https://github.com/termux/termux-packages/issues?q=is%3Aissue+is%3Aopen+label%3A%22package+request%22)。
  注意标记为 `help wanted` 的票证。

- **保持现有包为最新**

  包不会自动更新。有人需要更新构建
  脚本和补丁。通常由维护者处理，但事情经常
  过时。

  有关详细信息，请参阅[更新包](#更新包)。

- **托管包仓库镜像**

  Termux 产生大量流量。镜像有助于减少主服务器的负载，
  提供更好的下载速度并消除单点故障。

- **捐赠**

  有关详细信息，请参阅 https://github.com/termux/termux-packages/wiki/Donate。

## 请求新包

如果您正在寻找特定包但在我们的仓库中未找到，您可以请求它。

打开一个新的[问题](https://github.com/termux/termux-packages/issues/new/choose)
填写 `package request` 模板。您至少需要提供
包描述及其主页和源仓库的 URL。请记住
，您的请求不会立即得到处理。

请求的包必须符合我们的[打包策略](#打包策略)。

## 打包策略

Termux 仓库中已经添加了超过 1000 个包。所有
这些都需要维护、保持最新。与主要发行版不同，
我们的开发团队很小，我们的服务器磁盘空间也有限。

为了以合理的质量提供服务，请求的包应该
满足以下条件：

- **包必须是活跃、知名的项目**

  主要 Linux 发行版中可用的软件更有可能被
  包含在 Termux 仓库中。我们不会接受过时的、死寂的项目
  以及没有活跃社区的项目。

- **包必须在广泛认可的开源许可下获得许可**

  软件应在 Apache、BSD、GNU GPL、MIT 或其他知名
  开源许可下获得许可。源代码可用但在非免费条件下
  分发的软件将根据具体情况进行处理。

  闭源、包含仅二进制组件或在最终用户许可协议下
  分发的软件不被接受。

- **不能通过特定语言的包管理器安装**

  这些包应该通过特定语言的包管理器安装，
  例如：

  - `cargo`
  - `cpan`
  - `dotnet tool`
  - `gem`
  - `npm`
  - `pip`

  为 Node.js、Perl、Ruby 打包模块是有问题的，尤其是
  在涉及交叉编译本机扩展时。

- **不占用太多磁盘空间**

  生成的包的大小应小于 100 MiB。

  由于软件为 4 种 CPU 架构（aarch64、arm、
  i686、x86_64）编译，实际磁盘使用量是单个
  .deb 文件大小的 4 倍。我们的磁盘空间有限，更倾向于
  多个小包而不是一个大包。

  例外情况是根据具体情况做出的，仅针对提供
  重要功能的包。

- **不提供重复功能**

  请避免提交与已存在的包功能重复的包。

  仓库中无用的包越多，整体打包和服务
  质量就越差 - 还记得我们的资源有限吗？

- **不提供黑客、钓鱼、垃圾邮件、间谍、ddos 功能**

  我们不接受仅用于破坏或隐私侵犯目的的包，
   包括但不限于渗透测试、钓鱼、暴力破解、
   短信/电话轰炸、DDoS 攻击、OSINT。

**重要**：独立库包主要对开发人员感兴趣，
除非需要作为另一个包的依赖项，否则我们不会打包它们。
这不是一个严格的规则，但需要确保仓库干净，
并为普通 Termux 用户提供有用的内容。

需要 root 权限才能工作或依赖于仅在 SELinux 宽松模式下可用的功能
或需要自定义固件的包在专用的
[apt 仓库](https://packages-cf.termux.dev/apt/termux-root/) 中处理，其构建
配方可在 [root-packages 目录](/root-packages) 中找到。
请记住，Termux 主要设计用于非 root 使用，如果
与 非 root 使用冲突或导致构建时问题，我们可能会从包中删除需要 root 的功能。

不符合此策略的包可以在用户仓库中请求：
https://github.com/termux-user-repository/tur

## 提交拉取请求

贡献者对其提交承担全部责任。维护者可以
提供一些帮助来修复您的拉取请求或给出一些建议，
但这并不意味着他们会代替您完成所有工作。

**最低要求：**

- 具有使用 Linux 发行版的经验，如 Debian（首选）、Arch、Fedora 等。
- 具有从源代码编译软件的经验。
- 良好的 shell 脚本编写技能。
- 您已阅读 https://github.com/termux/termux-packages/wiki。

如果您从未使用过 Linux 发行版或 Termux 是您首次接触
Linux 环境，我们强烈建议不要发送拉取请求，因为
我们将拒绝低质量的工作。

在提交新包时，不要忘记[打包策略](#打包策略)，否则
您的拉取请求将在未合并的情况下关闭。

不要发送破坏性更改，例如无故回退提交或
删除文件、创建垃圾内容等。此类拉取请求的作者可能会
被阻止为 [Termux](https://github.com/termux) 项目做出贡献。

### 提交新包：检查清单

除了违反[打包策略](#打包策略)之外，还有一些
在提交新包的拉取请求时可能犯的典型错误。请注意下面列出的内容。

1. **版本控制：格式**

   包版本必须以数字开头，除 `.`（点）、`-`（减号）、`+`（加号）外不应包含特殊字符。在某些情况下，允许使用冒号符号（`:`）- 用于指定 epoch。

   有效版本规范的示例：`1.0`、`20201001`、`10a`。

   带 epoch 的版本示例：`1:2.6.0`

2. **版本控制：如果使用特定的 Git 提交**

   如果您使用特定的 Git 提交，`TERMUX_PKG_VERSION` 必须包含提交日期。日期格式应为 `YYYY.MM.DD` 或 `YYYYMMDD`。

   永远不要使用 Git 哈希、分支名称或其他可能破坏包管理器中版本跟踪的内容！

3. **源 URL**

   源 URL 必须是确定性的，并保证它始终指向与
   `TERMUX_PKG_VERSION` 中指定的版本和
   `TERMUX_PKG_SHA256` 中的校验和匹配的内容。在极少数情况下，我们可以
   做出例外，但不要指望它适用于您的拉取请求。

   不要在源代码 URL 中硬编码版本。通过变量
   `${TERMUX_PKG_VERSION}` 引用它，并记住 Bash 支持切片和
   其他操作通过变量引用的内容的方法。

   示例：

   ```
   TERMUX_PKG_VERSION=1.0
   TERMUX_PKG_SRCURL=https://example.com/archive/package-${TERMUX_PKG_VERSION}.tar.gz
   ```

   ```
   TERMUX_PKG_VERSION=5:4.11.3
   TERMUX_PKG_SRCURL=https://example.com/archive/package-${TERMUX_PKG_VERSION:2}.tar.gz
   ```

4. **依赖项：构建工具**

   不要在包依赖项中指定通用构建工具。这包括
   像 `autoconf`、`automake`、`bison`、`clang`、`ndk-sysroot`
   和许多其他包。

5. **依赖项：构建和运行时**

   `TERMUX_PKG_DEPENDS` 应仅包含包运行时所需的依赖项。

   所有仅在构建时使用的依赖项，例如
   静态库，应在 `TERMUX_PKG_BUILD_DEPENDS` 中指定。

6. **补丁：格式**

   补丁是由 GNU diff 或 Git 生成的标准 diff 输出。请
   避免手动编辑补丁，特别是如果您不了解
   格式内部结构。

   补丁通常通过以下方式创建

   ```
   diff -uNr sourcedir sourcedir.mod > filename.patch
   ```

7. **补丁：硬编码路径引用**

   软件通常依赖于文件系统层次结构标准定义的路径：

   - `/bin`
   - `/etc`
   - `/home`
   - `/run`
   - `/sbin`
   - `/tmp`
   - `/usr`
   - `/var`

   这些路径在 Termux 中不存在，已被带前缀的
   等效项替换。Termux 安装前缀是

   ```
   /data/data/com.termux/files/usr
   ```

   可以被视为虚拟根文件系统。

   主目录存储在前缀之外：

   ```
   /data/data/com.termux/files/home
   ```

   不要硬编码主目录和前缀，分别使用快捷方式 `@TERMUX_HOME@` 和
   `@TERMUX_PREFIX@`。补丁文件在应用之前会被预处理。

   目录 `/run` 和 `/sbin` 应分别替换为
   `@TERMUX_PREFIX@/var/run` 和 `@TERMUX_PREFIX@/bin`。

8. **构建配置：编译器标志**

   除非为了使构建工作所必需，否则不应触及 `CFLAGS`、`CXXFLAGS`、`CPPFLAGS` 或 `LDFLAGS`
   变量。

9. **构建配置：autotools**

   `build-package.sh` 在正确配置
   包构建方面做了大量工作，使用 GNU Autotools。因此，您不需要
   指定像以下标志：

   - `--prefix`
   - `--host`
   - `--build`
   - `--disable-nls`
   - `--disable-rpath`

   以及其他一些标志。

   可以通过变量 `TERMUX_PKG_EXTRA_CONFIGURE_ARGS` 传递
   额外的 `./configure` 选项。

---

# 处理包

Termux 仓库中可用的所有软件都旨在与 Android
操作系统兼容，并由 Android NDK 构建。这经常会引入兼容性问题，因为
Android（特别是 Termux）不是标准平台。不要期望
有现成的包配方可用。

## 提交指南

提交消息应该描述所做的更改，以便维护者可以理解做了什么，以及对哪个包或范围，而无需查看代码更改。确保提交消息满足这些要求的一个好方法（但不是强制性的）是按照以下格式编写：

```
<commitType>(<repo>/<package>): (所做的更改摘要/更改的简短描述)

[可选但**强烈推荐**的提交消息，描述提交中所做的更改]

[Fixes (termux/repo)#<issue number>]
[Closes (termux/repo)#<pr number>]
```

其中：

- `<repo>` 可以是 `main`、`root` 或 `x11` 之一。它是包所在的仓库。
  此属性的其他定义可以在 `repo.json` 文件中定义为包目录的名称属性，删除 'termux-' 前缀（如果有）。
- `<package>` 是包的实际名称。

提交中的任何行**不应超过 80 个字符**。如果超过，请考虑使用不同的措辞或语言风格，以更好地总结所做的更改。

- `<commitType>` 描述提交的类型。提交类型：
  - `addpkg(<repo>/<package>)`：添加了一个新包。
    提交摘要应包含包的简短描述。可选的扩展提交消息可能包括包的使用说明和/或包含原因。
  - `bump(<repo>/<package>)`：更新了一个或多个包。
    提交摘要应包括包更新到的新版本/标签。可选的扩展提交消息可能包括新版本中的新功能列表，以及构建脚本和/或补丁的详细更改列表
  - `fix(<repo>/<package>)`：修复包中的 Termux 特定错误
    提交摘要应包含包之前错误行为的摘要。扩展提交消息可能包含对错误的更深入分析。
  - `dwnpkg(<repo>/<package>)`：由于构建问题或潜在错误，降级了一个或多个包
    提交摘要应证明降级包的合理性。如果摘要不能完全描述降级的原因，扩展提交消息应包含降级的完整原因。
  - `disable(<repo>/<package>)`：禁用了包。简短描述应包含禁用包的原因。
    如果原因不适合摘要，扩展提交消息应包含禁用的完整原因。
  - `enhance(<repo>/<package>)`：在包中启用之前未启用的功能。
    可选（但强烈推荐）的扩展提交消息可能包含已启用功能的详细摘要和基本用例
  - `chore`：任何清理更改或不以任何方式影响用户的更改。
  - `rebuild`：重新构建包以链接到较新版本的共享库
    特殊情况：
    - 当批量重建依赖于主要包（例如 openssl）的包时，考虑使用此格式：
      ```
      rebuild(deps:main/openssl): link against OpenSSL 3.0
      ```
  - `scripts(path/to/script)`：任何影响我们构建脚本或其他脚本的更改，这些脚本不是构建配方的一部分，包括工具链设置脚本。
  - `ci(action_file_without_extension)`：任何影响 GitHub Actions yaml 文件和/或仅由其使用的脚本的更改。

良好提交消息的示例：

1. ```
   bump(main/nodejs): v18.2.0
   ```

2. ```
   dwnpkg(main/htop): v2.2.0

   v3.x 需要访问 /proc/stat，现在被 Android 限制
   ```

3. ```
   enhance,bump(main/nodejs): v18.2.0 and use shared libuv

   # 描述使用共享 libuv 有益的技术原因
   ```

4. ```
   disable(main/nodejs): use LTS version instead

   PS: 这永远不会发生。只是一个例子 :P
   ```

5. ```
   ci(package_updates): panic on invalid versions
   ```

6. ```
   chore,scripts(bin/revbump): support passing path to build.sh

   之前只能重新定义 `repo.json` 中定义的包目录。
   现在您可以传递 build.sh 的路径
   ```

7. ```
   fix(main/nodejs{,-lts}): test failures for `process.report`

   这展示了一个示例，当作用域可以最小化时，如果它们属于
   同一个仓库，并且具有相同的开头，并且在性质上非常相似。

   对于 liblua 也可以使用 main/liblua{51,52,53,54}
   ```

8. ```
   fix(main/vim{,-python},x11/vim-gtk): cursor flickering under certain rare conditions

   虽然上面的提交消息相当长，并且超过了
   提交消息中一行的推荐长度。在所有三个包的更改非常相似的情况下，可能会接受此类提交。
   ```

### 刚开始接触开源的新手的特别说明

为了鼓励新贡献者并帮助他们为开源做出贡献，上述提交要求应该可选地放宽。在需要更改提交消息的情况下，PR 可以**Squashed and Merged**或从命令行手动合并。

#### 从命令行合并 PR 的说明

1. 建议使用 [GitHub CLI (`gh`)](https://cli.github.com) 来获取贡献者的分支。

   ```sh
   gh pr checkout <PR Number>
   ```

2. 检出分支后，修改提交消息，并可选择重新设置 master 分支的基准（如果必要）。

   手动合并时，请确保通过添加 `Co-authored-by: ` 行为原始补丁的作者提供适当的信用。有关更多详细信息，请参阅 https://docs.github.com/en/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-with-multiple-authors。还要添加 `Closes #<PR number>`。

   **注意**，仅当 PR 作者禁用了维护者推送到其分支的能力时，才需要 `Closes` 和 `Co-authored-by` 行。如果可能，建议强制推送到用户的分支，然后将更改推送到 master 分支，因为 GitHub UI 将检测到合并。

   ```sh
   git fetch
   git rebase origin/master

   git commit --amend # 将打开编辑器以修改提交消息

   # 如果可能，推送到 PR 作者的分支
   # 注意：如果使用 GitHub CLI 检出，
   # 则无需配置远程分支。
   # git push -f
   ```

3. 记下分支名称

   ```sh
   git branch
   ```

4. 手动合并分支

   ```sh
   git switch master

   # 注意，根据您的 git 配置，默认
   # 合并策略可能会有所不同。建议将
   # 合并策略作为标志传递给 git。
   git merge <branch name>
   ```

5. 祝贺用户发送他们的（可能是）第一个开源贡献！

6. 请注意，有时 GitHub UI 可能无法检测到合并，在这种情况下，请确保告诉贡献者他们的 PR 已手动合并，他们将在仓库贡献图中获得应有的信用。

## 基础

每个包都通过放置在目录 `./packages/<name>/` 中的 `build.sh` 脚本定义，其中 `<name>` 是包的实际名称，小写。文件 `build.sh` 是一个 shell (Bash) 脚本，它通过环境变量定义一些属性，如依赖项、描述、主页。有时它还用于覆盖我们构建系统中定义的默认打包步骤。

这是 `build.sh` 的示例：

```.sh
TERMUX_PKG_HOMEPAGE=https://example.com
TERMUX_PKG_DESCRIPTION="Termux package"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@github"
TERMUX_PKG_VERSION=1.0
TERMUX_PKG_SRCURL=https://example.com/sources-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=0000000000000000000000000000000000000000000000000000000000000000
TERMUX_PKG_DEPENDS="libiconv, ncurses"
```

它可以包含一些额外的变量：

- `TERMUX_PKG_BUILD_IN_SRC=true`

  如果包仅支持树内构建，请使用此变量，例如
  如果包使用原始 Makefile 而不是像 CMake 这样的构建系统。

- `TERMUX_PKG_PLATFORM_INDEPENDENT=true`

  此变量指定包是平台无关的，可以在
  任何设备上运行，无论 CPU 架构如何。

`TERMUX_PKG_LICENSE` 应使用 SPDX 许可标识符指定许可，
或可以包含值 "custom" 或 "non-free"。多个许可应该
用逗号分隔。

`TERMUX_PKG_SRCURL` 应仅包含官方源代码包的 URL。
仅在有充分理由的情况下才允许使用 fork。

有关 `build.sh` 变量的更多信息，您可以在[开发者维基](https://github.com/termux/termux-packages/wiki/Creating-new-package#table-of-available-package-control-fields)上阅读。

### 创建补丁文件

许多包需要无法通过配置构建系统完成的更改。在这种情况下，您需要直接修改源代码并获取以机器可读格式描述更改的文件。

我们使用由 GNU `diff`、`git` 或其他兼容实用程序生成的[统一格式](https://www.gnu.org/software/diffutils/manual/html_node/Detailed-Unified.html)制作的补丁。


> [!TIP]
> 大多数情况下，使用 `git diff` 将是生成或更新补丁的更简单方法。

**使用 `git diff` 制作补丁：**

1. 克隆包的源仓库：<br>
   <sup>（您可能希望将目录切换到 `/tmp` 以简化清理）</sup>

   ```bash
   # 示例：cURL
   git clone https://github.com/curl/curl
   ```

2. 检出最新版本：

   ```bash
   cd curl
   # 提示：您可以使用 `git describe` 来找出最新标签。
   git describe
   # 输出应该类似于：curl-8_12_1-118-gc10fd464e
   # 这由 <最后一个标签名称>-<自以来的提交数>-<当前检出的提交的哈希>组成
   git checkout curl-8_12_1
   ```

3. 进行更改：
   ```bash
   vim sourcefile.c
   ```

4. 生成补丁文件
   ```bash
   # 检查更改是否符合您的预期
   git diff
   # 写入文件
   git diff > /path/to/package-build/example.patch
   ```
> [!NOTE]
> If you are making multiple patches you may want to run `git reset HEAD --hard`.<br>
> After saving a patch to a file so you do not duplicate parts between different patches.
> Alternatively you can restrict what is included in the `git diff`
> 通过向 `git diff` 传递文件/目录名称列表来限制其中包含的内容。<br>
> 但是，这不会对同一文件的多个单独补丁起作用。

   如果项目不使用 Git，或者在发布 tarball 中进行重大添加。<br>
   您可能需要求助于。

<details><summary>使用 GNU <code>diff</code> 制作补丁：</summary>
<p>

1. 获取源代码，例如使用此命令：

   ```bash
   cd ./packages/your-package
   (source build.sh 2>/dev/null; curl -LO "$TERMUX_PKG_SRCURL")
   ```

2. 提取 tarball 并制作源代码树的副本：

   ```bash
   tar xf package-1.0.tar.gz
   cp -a package-1.0 package-1.0.mod
   ```

3. 将当前目录更改为源代码树：

   ```bash
   cd package-1.0.mod
   ```

4. 进行更改：

   ```bash
   vim sourcefile.c
   ```

5. 生成原始源和修改源之间的差异：

   ```bash
   cd ..
   diff -uNr package-1.0 package-1.0.mod > very-nice-improvement.patch
   ```

</p>
</details>
<br>

补丁文件名应该是不言自明的，这样其他人就能更容易理解您的补丁的作用。此外，最好将每个修改存储在单独的补丁文件中。

## 更新包

[![asciicast](https://asciinema.org/a/gVwMqf1bGbqrXmuILvxozy3IG.svg)](https://asciinema.org/a/gVwMqf1bGbqrXmuILvxozy3IG?autoplay=1&speed=2.0)

您可以通过访问 Termux 在 [Repology](https://repology.org/projects/?inrepo=termux&outdated=1) 上的页面来检查哪些包已过时。

### 常规包更新过程

通常，要更新包，您只需要修改几个变量并提交更改。

1. 将新版本值分配给 `TERMUX_PKG_VERSION`。注意不要
   意外删除 epoch（编号前缀，例如 `1:`、`2:`）。
2. 如果设置了 `TERMUX_PKG_REVISION` 变量，请删除它。修订版
   应仅在相同版本内的后续包构建中设置。
3. 下载源代码存档并计算 SHA-256 校验和：
   ```
   cd ./packages/${YOUR_PACKAGE}
   (source build.sh 2>/dev/null; curl -LO "$TERMUX_PKG_SRCURL")
   ```
4. 将新的校验和值分配给 `TERMUX_PKG_SHA256`。

### 处理补丁错误

对包引入的重大更改通常会使当前的补丁与较新的包版本不兼容。不幸的是，没有关于修复补丁问题的通用指南，因为解决方法总是基于引入到新源代码版本的更改。

您可以尝试以下几点：

1. 如果补丁修复了特定的已知上游问题，请检查项目的 VCS
   是否有修复该问题的提交。有可能不再需要该补丁。

2. 检查失败的补丁文件并手动将更改应用到源代码。
   仅当您理解源代码和补丁引入的更改时才这样做。

   重新生成补丁文件，例如：

   ```
   diff -uNr package-1.0 package-1.0.mod > previously-failed-patch-file.patch
   ```

始终检查您的拉取请求的 CI（Github Actions）状态。如果失败，则修复或关闭它。如果问题轻微，维护者可以自行修复。但他们不会重写您的整个提交。

## 在没有版本更改的情况下重新构建包

对补丁文件和构建配置选项的更改将意味着包重新构建。为了使包被识别为更新，应该设置构建编号。这是通过定义变量 `TERMUX_PKG_REVISION` 或在已设置时增加其值来完成的。

`TERMUX_PKG_REVISION` 应该正好设置在 `TERMUX_PKG_VERSION` 下方：

```.sh
TERMUX_PKG_VERSION=1.0
TERMUX_PKG_REVISION=4
```

如果包版本已更新，应删除 `TERMUX_PKG_REVISION`。

## 降级包或更改版本控制方案

如果需要降级包或需要更改版本控制方案，您需要设置或增加包 epoch。这是为了告诉包管理器强制将新版本识别为包更新。

Epoch 应该在与版本相同的变量中指定（`TERMUX_PKG_VERSION`），但其值将采用不同的格式（`{EPOCH}:{VERSION}`）：

```.sh
TERMUX_PKG_VERSION=1:5.0.0
```

请注意，如果您不是 @termux 协作者，拉取请求必须包含描述您提交包降级的原因。所有没有任何严肃原因提交包降级的拉取请求都将被拒绝。

## 常见构建问题

```
No files in package. Maybe you need to run autoreconf -fi before configuring?
```

这意味着构建系统无法找到 Makefile。根据项目，存在一些尝试的提示：

- 设置 `TERMUX_PKG_BUILD_IN_SRC=true` - 适用于仅 Makefile 的项目。
- 在 `termux_step_pre_configure` 中运行 `./autogen.sh` 或 `autoreconf -fi`。这
  适用于使用 Autotools 的项目。

```
No LICENSE file was installed for ...
```

当构建系统找不到许可文件时会发生此错误，应该通过 `TERMUX_PKG_LICENSE_FILE` 手动指定。
