#!/bin/bash
set -euo pipefail

cd "$(realpath "$(dirname "$0")")/../.."

GITHUB_EVENT_NAME="${1:-}"
TARGET_ARCH="${2:-}"

unset PR WORKFLOW_ID

infoexit() {
	echo "$@"
	[[ -n "${PR:-}" && "${CI-false}" == "true" ]] && echo "::error ::重用 PR #${PR:-} ${WORKFLOW_ID:+"(workflow run ${WORKFLOW_ID})"} 构建产物失败，请参见 \`Gathering build summary\` 步骤日志。"
	exit 1
} >&2

# 通过 nameref 检查必需变量。
for var in OLD_COMMIT HEAD_COMMIT GITHUB_TOKEN GITHUB_EVENT_NAME TARGET_ARCH; do
	[[ -n "${!var:-}" ]] || infoexit "$var 未设置，不执行 CI 快速路径"
done

graphql_request() {
	local QUERY="${1}"
	# 向 GitHub 发送 GraphQL 并获取响应
	# GraphQL 请求内部不允许使用硬制表符或换行符，
	# 因为它被编码为 JSON 字符串，所以我们也应该转义引号。
	curl --silent \
		-H "Authorization: token ${GITHUB_TOKEN}" \
		-H "Accept: application/vnd.github.v3+json" \
		-H 'Content-Type: application/json' \
		-X POST \
		--data "{ \"query\": \"$(tr '\t\n' '  ' <<< "${QUERY//\"/\\\"\"}")\"}" \
		"https://api.github.com/graphql" \
	|| return $?
}

ci_artifact_url() {
	curl --silent \
		-H "Authorization: token ${GITHUB_TOKEN}" \
		-H "Accept: application/vnd.github.v3+json" \
		"https://api.github.com/repos/termux/termux-packages/actions/runs/${1}/artifacts" \
		| jq -r '[.artifacts[]? | select(.name | startswith("debs-'"${TARGET_ARCH}"'")) | .archive_download_url][0] // error' \
	|| return $?
}

download_ci_artifacts() {
	local WORKFLOW_ID="$1" CI_ARTIFACT_URL CI_ARTIFACT_ZIP
	CI_ARTIFACT_ZIP="$HOME/.termux-build/_cache/artifact-${WORKFLOW_ID}.zip"
	CI_ARTIFACT_URL="$(ci_artifact_url "${WORKFLOW_ID}")" || { echo "获取 CI 产物 URL 失败" >&2; return 1; }
	echo "CI 产物 URL 为 ${CI_ARTIFACT_URL}"

	mkdir -p "$(dirname "${CI_ARTIFACT_ZIP}")"
	# 重新下载不应该发生，但让我们假设产物已过时
	rm -f "${CI_ARTIFACT_ZIP}"
	curl \
		--fail \
		--show-error \
		--location \
		-H "Authorization: token $GITHUB_TOKEN" \
		"${CI_ARTIFACT_URL}" \
		--output "${CI_ARTIFACT_ZIP}" \
		|| { echo "下载 PR 产物失败。" >&2; return 1; }

	mkdir -p output
	unzip -p "${CI_ARTIFACT_ZIP}" '*.tar' | tar xvf - --wildcards --strip-components=1 -C output 'debs/*' --exclude='*.txt' --exclude='.placeholder' \
		|| { echo "解压 PR 产物失败。" >&2; return 1; }
}

mask_output() {
	# 仅在出错时打印输出
	local output
	if ! output=$("$@" 2>&1); then
		echo "$output"
		return 1
	fi
}


mask_output git fetch origin "$OLD_COMMIT:ref/tmp/$OLD_COMMIT" || infoexit "从 origin 获取 $OLD_COMMIT 失败，不执行 CI 快速路径"
readarray -t COMMITS < <(git rev-list --no-merges "$OLD_COMMIT..$HEAD_COMMIT" || :) || :

(( ${#COMMITS[*]} == 0 )) && infoexit "无法获取完整的提交历史。不执行 CI 快速路径。"

[[ "${GITHUB_EVENT_NAME:-}" == "push" ]] && {
	# 检查我们是否可以执行 CI 快速路径。
	# 我们需要确保所有提交都来自单个 PR，
	# 并确保构建系统或依赖项未被更改。
	# 如果是这样，我们可以重用 PR 检查产物并将其上传到 apt 仓库以节省一些 CI 时间

	readarray -t TERMUX_PACKAGE_DIRECTORIES < <(jq --raw-output 'del(.pkg_format) | keys | .[]' repo.json) || :

	# 我们应该获取此推送中所有提交的数据，以检查它们是否来自同一个 PR（如果有）
	RELATED_PRS_QUERY="
	query {
		repository(owner: \"termux\", name: \"termux-packages\") {
		$(
			for commit in \"${COMMITS[@]}\"; do
				# 为此提交添加一个查询，使用短哈希作为标签
				echo \"_${commit::7}: object(oid: \"${commit}\") { ...commitWithPR }\"
			done
		)
		}
	}

	fragment commitWithPR on Commit {
		associatedPullRequests(first: 1) { nodes { baseRefOid headRefOid } edges { node { title body number } } }
	}"

	RESPONSE="$(graphql_request "$RELATED_PRS_QUERY" || infoexit "无法查询提交的关联 PR，不执行 CI 快速路径")"

	# 确保响应有效并获取所有关联的 PR 编号
	readarray -t PRS < <(jq '.data.repository | to_entries[] | .value.associatedPullRequests.edges.[]?.node?.number?' <<< "$RESPONSE" | sort -u) \
		|| infoexit "GraphQL 响应无效，不执行 CI 快速路径"

	# 检查所有提交是否来自唯一的 PR，如果不是则退出
	(( ${#PRS[*]} == 0 )) && infoexit "推送没有关联的 PR，不执行 CI 快速路径"
	(( ${#PRS[*]}	> 1 )) && infoexit "推送包含来自多个 PR 的提交，不执行 CI 快速路径"

	PR="${PRS[0]}"
	read -rd' ' PR_HEAD_COMMIT PR_COMMIT_TITLE PR_COMMIT_BODY < <(jq -r '
		.data.repository[].associatedPullRequests |
			(.nodes[0].headRefOid,
			 .edges[0].node.title,
			 .edges[0].node.body)' <<< "$RESPONSE" || :)
	[[ -n "${PR_HEAD_COMMIT:-}" ]] || infoexit "读取关联 PR 头部提交失败，不执行 CI 快速路径"

	echo "::group::检测到 PR #${PRS[0]}: ${PR_COMMIT_TITLE} — https://github.com/termux/termux-packages/pull/${PRS[0]}"
	echo "${PR_COMMIT_BODY}"
	echo "::endgroup::"

	PR_CI_REUSE=0
	# 检查单提交和压缩的 PR，如果提交消息中包含 `[ci reuse]`
	if [[ "${#COMMITS[*]}" -eq 1 && "$(git log -1 --pretty=format:"%s%n%b" "${COMMITS[@]}")" == *"[ci reuse]"* ]]; then
		PR_CI_REUSE=1
		echo "提交主题或描述包含 [ci reuse]"
	else
		# 否则检查关联的 PR 标题和正文
		[[ "${PR_COMMIT_TITLE}${PR_COMMIT_BODY}" == *"[ci reuse]"* ]] && PR_CI_REUSE=1
		(( PR_CI_REUSE )) && echo "PR 描述包含 [ci reuse]"
	fi

	DIRS_REGEX="$(paste -sd'|' <<< "${TERMUX_PACKAGE_DIRECTORIES[@]}")" || exit 0

	# 获取 PR 提交树
	mask_output git fetch origin "$PR_HEAD_COMMIT:ref/tmp/$PR_HEAD_COMMIT" || infoexit "获取 PR 头部树失败，不执行 CI 快速路径"

	# 获取 PR 分支的共同祖先提交
	PR_MERGE_BASE="$(git merge-base "ref/tmp/$PR_HEAD_COMMIT" "$HEAD_COMMIT")" || infoexit "获取 PR 合并基点失败，不执行 CI 快速路径"

	# 在这里我们将 PR 的更改与推送的更改进行比较
	# 这是为了确保在 CI 被调用之后但在我们使用 GraphQL 和 `git fetch` 获取数据之前，
	# 没有人向 PR 分支注入额外的更改。
	# 我们无法将 `git diff --no-index` 应用于提交范围，因此我们将使用 sed 手动去除索引。
	diff -q \
			<(git diff "$PR_MERGE_BASE" "$PR_HEAD_COMMIT" | sed -n -E '/^diff --git a\// { p; n; /^index /!p; b } ; p') \
			<(git diff "$OLD_COMMIT" "$HEAD_COMMIT" | sed -n -E '/^diff --git a\// { p; n; /^index /!p; b } ; p') \
	|| infoexit "PR 头部与推送的提交更改不匹配，可能在 PR 合并后立即强制推送了 PR 引用。不执行 CI 快速路径。"

	# 获取自此 PR 分支以来所有更改的文件列表
	readarray -t PR_BASE_TO_HEAD_CHANGED_FILES < <(
		git diff-tree --name-only -r "$PR_MERGE_BASE..$OLD_COMMIT"
	) || :

	# 获取此 PR 更改的所有软件包列表
	readarray -t PR_CHANGED_PACKAGES < <(
		git diff-tree --name-only -r "$OLD_COMMIT..$HEAD_COMMIT" \
			| grep -E "^($DIRS_REGEX)/[^/]+/" \
			| sed -E "s#^(($DIRS_REGEX)/[^/]+)/.*#\1#" \
			| sort -u
	) || :
	echo "此 PR 更改的软件包: ${PR_CHANGED_PACKAGES[*]:-无}"

	# 获取自此 PR 分支以来所有更改的构建系统文件列表
	readarray -t PR_BASE_TO_HEAD_CHANGED_BUILDSYSTEM_FILES < <(
		grep -e "^scripts/" -e "^ndk-patches/" -e "^build-package.sh$" <<< "${PR_BASE_TO_HEAD_CHANGED_FILES[@]}"
	) || :
	echo "自 PR 分支以来更改的构建系统文件: ${PR_BASE_TO_HEAD_CHANGED_BUILDSYSTEM_FILES[*]:-无}"

	# 获取自此 PR 分支以来所有更改的软件包列表
	readarray -t PR_BASE_TO_HEAD_CHANGED_PACKAGES < <(
		echo "${PR_BASE_TO_HEAD_CHANGED_FILES[@]}" \
			| grep -E "^($DIRS_REGEX)/[^/]+/" \
			| sed -E "s#^(($DIRS_REGEX)/[^/]+)/.*#\1#" \
			| sort -u
	) || :
	echo "自 PR 分支以来更新的软件包: ${PR_BASE_TO_HEAD_CHANGED_PACKAGES[*]:-无}"

	# 获取此 PR 更改的所有软件包的所有依赖项集合
	readarray -t PR_CHANGED_PACKAGES_DEPS < <(
		for dep in "${PR_CHANGED_PACKAGES[@]:-}"; do
			./scripts/buildorder.py "$dep" "${TERMUX_PACKAGE_DIRECTORIES[@]}" 2>/dev/null | awk '{print $NF}'
		done | sort -u
	) || :
	echo "此 PR 更改的依赖项: ${PR_CHANGED_PACKAGES_DEPS[*]:-无}"

	# 获取自此 PR 分支以来更改的所有构建依赖项集合
	readarray -t PR_BASE_TO_HEAD_CHANGED_DEPS < <(
		grep -Fx \
			-f <(echo "${PR_BASE_TO_HEAD_CHANGED_PACKAGES[@]}") \
			- <<< "${PR_CHANGED_PACKAGES_DEPS[@]}"
	) || :
	echo "自 PR 分支以来这些软件包的依赖项更改: ${PR_BASE_TO_HEAD_CHANGED_DEPS[*]:-无}"

	if (( ${#PR_BASE_TO_HEAD_CHANGED_BUILDSYSTEM_FILES[*]} + ${#PR_BASE_TO_HEAD_CHANGED_DEPS[*]} + PR_CI_REUSE )); then

		# 同一个提交可以在多个 PR 甚至推送中使用
		WORKFLOW_PR_QUERY="
		query {
			repository(owner: \"termux\", name: \"termux-packages\") {
				object(oid: \"$PR_HEAD_COMMIT\") { ...workflowRun }
			}
		}

		fragment workflowRun on Commit {
			checkSuites(first: 32) { nodes { workflowRun { event file { path } databaseId } conclusion status } }
		}"

		RESPONSE="$(graphql_request "$WORKFLOW_PR_QUERY" || infoexit "执行 GraphQL 请求失败，不执行 CI 快速路径")"

		# 获取最新的、相关的、成功的 `packages.yml` 工作流运行。
		WORKFLOW_ID="$(
			jq -r '[.data.repository.object?.checkSuites?.nodes[]?
				| select(
				.workflowRun.event == "pull_request"
				and .workflowRun.file.path == ".github/workflows/packages.yml"
				and .conclusion == "SUCCESS"
				and .status == "COMPLETED")
				| .workflowRun.databaseId][0] // empty' <<< "$RESPONSE" || :
		)"
		if [[ -n "${WORKFLOW_ID}" ]]; then
			echo "我们可以安全地从 https://github.com/termux/termux-packages/actions/runs/${WORKFLOW_ID} 重用 CI 产物"
			if download_ci_artifacts "${WORKFLOW_ID}"; then
				# 通知 CI 跳过软件包构建，因为我们重用了 PR 产物。
				echo "skip-building=true" >> "${GITHUB_OUTPUT:-/dev/null}"
				echo "::notice::重用 PR #${PRS[0]} (workflow run ${WORKFLOW_ID}) 构建产物，构建已跳过。"
			else
				infoexit "下载和解压 PR 产物失败"
			fi
		else
			echo "我们可以安全地重用 CI 产物，但没有找到任何匹配的 CI 运行。"
		fi
	else
		echo "重用 PR 构建产物是不安全的"
	fi
}

[[ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]] && {
	# In the case of pull_requests we can reuse build artifacts of recent workflow runs
	# if user added more commits to existing PR after workflow finished running.
	(( ${#COMMITS[*]} > 128 )) && infoexit "Pull request has more than 128 commits, not attempting to reuse CI artifacts."

	# We intentionally do not check if workflow run is related to this specific PR
	# to allow CI reuse artifacts of other PRs in the case if current PR diverged from another PR branch.
	WORKFLOW_COMMITS_QUERY="
	query {
		repository(owner: \"termux\", name: \"termux-packages\") {
		$(
			for commit in "${COMMITS[@]}"; do
				# Add a query for this commit with the shorthash as the label
				echo "_${commit::7}: object(oid: \"${commit}\") { ...workflowRun }"
			done
		)
		}
	}

	fragment workflowRun on Commit {
		checkSuites(first: 32) { nodes { workflowRun { event file { path } databaseId } conclusion status } }
	}"

	RESPONSE="$(graphql_request "$WORKFLOW_COMMITS_QUERY" || infoexit "Failed to perform GraphQL request, not performing CI fast path")"

	# git rev-list prints commits in chronologically descending order, so we can check them as is.
	for commit in "${COMMITS[@]}"; do
		# Get the most recent successful `packages.yml` workflow run for this commit if any
		WORKFLOW_ID="$(
			jq -r '[.data.repository["_'"${commit::7}"'"].checkSuites?.nodes[]?
				| select(
					.workflowRun.event == "pull_request" and
					.workflowRun.file.path == ".github/workflows/packages.yml" and
					.conclusion == "SUCCESS" and
					.status == "COMPLETED"
				) | .workflowRun.databaseId][0] // empty' <<< "$RESPONSE"
		)"
		# No need to go on if we found a match.
		[[ -z "${WORKFLOW_ID:-}" ]] || break
	done
	if [[ -n "${WORKFLOW_ID}" ]]; then
		echo "We can safely reuse CI artifacts from https://github.com/termux/termux-packages/actions/runs/${WORKFLOW_ID}"
		echo "CI artifact URL is $(ci_artifact_url "${WORKFLOW_ID}" || infoexit "Failed to get CI artifact URL")"
	else
		echo "We can not reuse CI artifacts since no relevant CI runs were found"
	fi
}
