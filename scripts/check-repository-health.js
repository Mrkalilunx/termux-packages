#!/usr/bin/env node
//
// 用于检查 apt 仓库和 termux-packages 之间差异的脚本
//
// 目前检查以下内容：
// - apt 仓库中缺少的包
// - apt 仓库和 termux-packages 中的版本不匹配
// - apt 仓库中不应该存在的包（这可能发生在包在 termux-packages 中被删除，
//   但没有从 apt 仓库中删除时）
//
import { readFile } from "node:fs/promises";
import { gunzip } from "node:zlib";
import { promisify } from "node:util";
import { execFile } from "node:child_process";
const gunzipAsync = promisify(gunzip);
const execFileAsync = promisify(execFile);

const archs = ["aarch64", "arm", "i686", "x86_64"];

if (process.argv.length != 3) {
  console.error("用法：");
  console.error("./scripts/check-repository-health.js <path-to-output>");
  console.error(
    "  其中 '<path-to-output>' 是 ./scripts/generate-apt-packages-list.sh 已运行的目录路径",
  );
  process.exit(1);
}

const outputDir = process.argv[2];

const repos = JSON.parse(await readFile("repo.json"));
if (repos.pkg_format != "debian") {
  console.error(`不支持的包格式：${repos.pkg_format}`);
  process.exit(1);
}
const repoPathMap = new Map();
for (const path in repos) {
  if (path == "pkg_format") continue;
  const repo = repos[path];
  if (repoPathMap.has(repo.name)) {
    console.error("多个仓库路径具有相同的仓库名称。");
    console.error(
      "这不应该发生。需要修复 repo.json 文件",
    );
    console.error(
      `仓库 "${repo.name}" 也存在于路径 "${path}"，而它已经存在于 "${repoPathMap.get(path)}"`,
    );
    process.exit(1);
  }
  repoPathMap.set(repo.name, path);
}

async function getAptPackages(
  repo,
  arch,
  errors,
  _proposedAutomatedFixes,
  proposedManualFixes,
  termuxPackages,
) {
  // https://wiki.debian.org/DebianRepository/Format#A.22Packages.22_Indices
  // Packages 文件是一个 gzip 压缩文件，包含包名称、描述、版本和其他信息的列表。
  // 不同的条目由额外的换行符分隔。

  // 首先获取仓库和架构的 Packages.gz 文件
  const url = `${repo.url}/dists/${repo.distribution}/${repo.component}/binary-${arch}/Packages.gz`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(
      `获取 ${url} 失败：${response.status} ${response.statusText}`,
    );
  }
  // gunzip 文件以获取实际内容
  const data = await gunzipAsync(await response.arrayBuffer());

  // 现在解析文件文件并生成包名称到其版本和仓库名称的映射。
  const aptPackages = new Map();
  let pkgName = undefined;
  let pkgVersion = undefined;
  let pkgFilename = undefined;
  data
    .toString()
    .split("\n")
    .forEach(async (line) => {
      // Package: <package-name>
      if (line.startsWith("Package: ")) {
        pkgName = line.substring("Package: ".length);
      }
      // Version: <package-version>
      else if (line.startsWith("Version: ")) {
        pkgVersion = line.substring("Version: ".length);
      } else if (line.startsWith("Filename: ")) {
        pkgFilename = line.substring("Filename: ".length);
      }
      // 新行表示包条目的结束
      else if (line == "") {
        if (pkgName && pkgVersion && pkgFilename) {
          if (aptPackages.has(pkgName)) {
            const currentTime = Math.floor(new Date().getTime() / 1000);
            let lastModified = currentTime;
            if (termuxPackages.has(pkgName)) {
              lastModified = termuxPackages.get(pkgName).lastModified;
            }
            // 只有当同一包的最旧 deb 文件超过 24 小时时，才将其视为错误。服务器上运行 aptly 的 cron 作业每 6 小时运行一次，24 小时更合理，以确保如果 cron 作业因某种原因失败，我们不会填充不应该存在的错误
            if (currentTime - lastModified >= 3600 * 24) {
              errors.push(
                `重复的包："${pkgName}"，在为 "${repo.name}" 的 "${arch}" 解析 Packages 文件时`,
              );
              proposedManualFixes.push(
                `重复的包 "${pkgName}" 可能会在 aptly 服务器上负责清理旧版本包的 cron 作业启动时自动删除。`,
              );
            }
            try {
              await execFileAsync("dpkg", [
                "--compare-versions",
                pkgVersion,
                "ge",
                aptPackages.get(pkgName).version,
              ]);
              aptPackages.get(pkgName).version = pkgVersion;
            } catch (e) {}
          } else {
            // 仅添加包版本。
            aptPackages.set(pkgName, {
              version: pkgVersion,
              filename: pkgFilename,
              repo: repo.name,
            });
          }
        }
        pkgName = undefined;
        pkgFilename = undefined;
        pkgVersion = undefined;
      }
    });
  // 文件末尾应该有额外的换行符，所以这永远不应该是 true，
  // 但为了以防万一，我们检查它以确保我们正确解析了文件。
  if (pkgName || pkgVersion || pkgFilename) {
    console.error(`${url} 中的不完整包条目`);
    process.exit(1);
  }

  return aptPackages;
}

// 返回包名称到其版本、仓库名称以及包是否可能具有 -static 子包的映射。
async function getTermuxPackages(
  arch,
  errors,
  _proposedAutomatedFixes,
  proposedManualFixes,
) {
  const termuxPackages = new Map();
  // "${outputDir}/apt-packages-list-${arch}.txt" 是由
  // `./scripts/generate-apt-packages-list.sh` 脚本生成的文件
  const data = await readFile(
    `${outputDir}/apt-packages-list-${arch}.txt`,
    "utf8",
  );
  data
    .trim()
    .split("\n")
    .forEach((line) => {
      let [pkgName, pkgRepo, pkgVersion, pkgMayHaveStaticSubpkg] =
        line.split(" ");
      if (termuxPackages.has(pkgName)) {
        errors.push(`termux-packages 中的重复包："${pkgName}"`);
        proposedManualFixes.push(
          `之前在 "${termuxPackages.get(pkgName).repo}" 中发现的重复包 "${pkgName}" 也存在于 "${pkgRepo}" 中，需要从 termux-packages 中删除`,
        );
      }
      const { stdout } = execFileAsync("git", [
        "log",
        "-1",
        "--format=%at",
        `${repoPathMap.get(pkgRepo)}`,
      ]);
      const lastModified = Number.parseInt(stdout);
      termuxPackages.set(pkgName, {
        version: pkgVersion,
        repo: pkgRepo,
        mayHaveStaticSubpkg: pkgMayHaveStaticSubpkg === "true",
        lastModified,
      });
    });
  return termuxPackages;
}

async function getErrorsForArch(arch) {
  const errors = [];
  // 这是一个 shell 脚本，维护者可以简单地在 aptly 服务器上运行它，
  // 以修复脚本能够找出修复方法的所有错误。
  const proposedAutomatedFixes = [];
  const proposedManualFixes = [];
  const termuxPackages = await getTermuxPackages(
    arch,
    errors,
    proposedAutomatedFixes,
    proposedManualFixes,
  );
  const aptPackages = new Map();
  for (const path in repos) {
    if (path == "pkg_format") continue;
    const repo = repos[path];

    // 获取 apt 仓库中的包列表，然后将它们添加到所有 apt 包的映射中
    const currentAptRepoPackages = await getAptPackages(
      repo,
      arch,
      errors,
      proposedAutomatedFixes,
      proposedManualFixes,
      termuxPackages,
    );
    for (const [pkgName, pkgInfo] of currentAptRepoPackages) {
      // 检查包是否应该首先存在于这个仓库中
      if (termuxPackages.has(pkgName)) {
        // 检查包是否在正确的仓库中
        if (termuxPackages.get(pkgName).repo != pkgInfo.repo) {
          // 如果不在正确的仓库中，则必须删除它
          errors.push(
            `包 "${pkgName}" 存在于 "${pkgInfo.repo}" 中，但应该在 "${termuxPackages.get(pkgName).repo}" 中`,
          );
          proposedAutomatedFixes.push(
            `aptly repo remove "${pkgInfo.repo}" "${pkgName} (=${pkgInfo.version}) {${arch}}"`,
          );
        } else {
          // 如果它在正确的仓库中，确保它与我们在 termux-packages 中的版本相同
          if (termuxPackages.get(pkgName).version != pkgInfo.version) {
            errors.push(
              `"${pkgName}" "${pkgInfo.version}"（在 apt 仓库中）!= "${termuxPackages.get(pkgName).version}"（在 termux-packages 中）`,
            );
            proposedManualFixes.push(
              `"${pkgInfo.repo}" 中的包 "${pkgName}" 在 apt 仓库上可能不是最新的，或者可能存在虚假版本`,
            );
          }
          aptPackages.set(pkgName, pkgInfo);
        }
      } else {
        // 如果是静态包，我们需要重复之前做的一些操作。
        // -static 包是自动生成的，因此当基础包的较新版本中不存在静态库时，它们可能在较新版本中不再存在
        if (pkgName.endsWith("-static")) {
          const basePkgName = pkgName.substring(
            0,
            pkgName.length - "-static".length,
          );
          if (termuxPackages.has(basePkgName)) {
            // 检查 TERMUX_PKG_NO_STATICSPLIT
            if (!termuxPackages.get(basePkgName).mayHaveStaticSubpkg) {
              errors.push(
                `"${pkgName}" ${pkgInfo.version}: 静态包不应该存在，因为父包 "${basePkgName}" 具有 TERMUX_PKG_NO_STATICSPLIT=true`,
              );
              proposedAutomatedFixes.push(
                `aptly repo remove "${pkgInfo.repo}" "${pkgName} (=${pkgInfo.version}) {${arch}}"`,
              );
            } else {
              if (termuxPackages.get(basePkgName).version != pkgInfo.version) {
                errors.push(
                  `"${pkgName}" "${pkgInfo.version}" != ${termuxPackages.get(basePkgName).version}，与父包预期的不同。-static 包可能在更新后停止存在。`,
                );
                proposedAutomatedFixes.push(
                  `aptly repo remove "${pkgInfo.repo}" "${pkgName} (=${pkgInfo.version}) {${arch}}"`,
                );
              }
              aptPackages.set(pkgName, pkgInfo);
            }
          } else {
            // 当父包从仓库中删除时会发生这种情况
            errors.push(
              `"${pkgName}" ${pkgInfo.version}: 静态包没有父包`,
            );
            proposedAutomatedFixes.push(
              `aptly repo remove "${pkgInfo.repo}" "${pkgName} (=${pkgInfo.version}) {${arch}}"`,
            );
          }
        } else {
          // 它不是静态包，并且在该仓库的 termux-packages 中不存在。所以它不应该存在
          errors.push(
            `"${pkgName}" "${pkgInfo.version}" 在 termux-packages 中不存在`,
          );
          proposedAutomatedFixes.push(
            `aptly repo remove "${pkgInfo.repo}" "${pkgName} (=${pkgInfo.version}) {${arch}}"`,
          );
        }
      }
    }
  }

  // 现在检查 apt 仓库中缺少但存在于 termux-packages 中的包
  for (const [termuxPkgName, termuxPkgInfo] of termuxPackages) {
    if (!aptPackages.has(termuxPkgName)) {
      errors.push(`"${termuxPkgName}" 在 apt 仓库中缺少`);
      proposedManualFixes.push(
        `"${termuxPkgInfo.repo}" 中的包 "${termuxPkgName}" 在 apt 仓库中缺少，它可能需要重新构建`,
      );
    } /* else {} */ // 我们已经检查了两个映射中都存在的包的版本
  }
  return {
    errors,
    proposedAutomatedFixes,
    proposedManualFixes,
  };
}

const promises = [];

for (const arch of archs) {
  promises.push(getErrorsForArch(arch));
}

const results = await Promise.all(promises);

let hasErrors = false;

for (let i = 0; i < archs.length; i++) {
  if (results[i].errors.length > 0) {
    console.log(`### 为 ${archs[i]} 发现的错误`);

    console.log("<details>");
    console.log("  <summary>错误：</summary>");
    console.log("");
    console.log("```");
    console.log(results[i].errors.join("\n"));
    console.log("");
    console.log("```");
    console.log("</details>");

    console.log("\n\n");

    console.log("<details>");
    console.log("  <summary>建议的自动修复：</summary>");
    console.log("");
    console.log("```sh");
    console.log(results[i].proposedAutomatedFixes.join("\n"));
    console.log("");
    console.log("```");
    console.log("</details>");
    console.log("\n\n");

    console.log("<details>");
    console.log("  <summary>建议的手动修复：</summary>");
    console.log("");
    console.log("```");
    console.log(results[i].proposedManualFixes.join("\n"));
    console.log("");
    console.log("```");
    console.log("</details>");
    console.log("\n\n\n\n");
    hasErrors = true;
  }
}

if (hasErrors) {
  process.exit(1);
}
