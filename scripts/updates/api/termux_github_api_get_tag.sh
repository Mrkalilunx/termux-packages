# shellcheck shell=bash
termux_github_api_get_tag() {
	if [[ -z "${GITHUB_TOKEN:-}" ]]; then
		# 需要使用 GraphQL API。
		termux_error_exit "GITHUB_TOKEN 环境变量未设置。"
	fi

	local user repo project tag_type
	tag_type="$TERMUX_PKG_UPDATE_TAG_TYPE"

	# 示例：
	# https://github.com/vim/vim/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz
	#        _="https:"
	#        _=""
	#        _="github.com"
	#     user="vim"
	#     repo="vim"
	#        _="archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz"
	IFS='/' read -r _ _ _ user repo _ <<< "${TERMUX_PKG_SRCURL}"
	project="${user}/${repo}"

	if [[ -z "${tag_type}" ]]; then # 如果未设置，则根据 URL 决定。
		if [[ "${TERMUX_PKG_SRCURL:0:4}" == "git+" ]]; then
			tag_type="newest-tag" # 获取最新标签。
		elif [[ -n "$TERMUX_PKG_UPDATE_VERSION_REGEXP" ]]; then
			tag_type="latest-regex" # 获取最新发布标签。
		else
			tag_type="latest-release-tag" # 获取最新发布标签。
		fi
	fi

	local -a curl_opts=(
		-H "X-GitHub-Api-Version: 2022-11-28"
		-H "Accept: application/vnd.github.v3+json"
		-H "Authorization: token ${GITHUB_TOKEN}"
		-A "Termux update checker 1.1 (github.com/termux/termux-packages)"
		--silent
		--location
		--retry 10
		--retry-delay 1
		--write-out '|%{http_code}'
	)
	local -a graphql_request=(
		-X POST
		-d "$(
			cat <<-EOF | tr '\n' ' '
				{
					"query": "query {
						repository(owner: \"${project%/*}\", name: \"${project##*/}\") {
							refs(refPrefix: \"refs/tags/\", first: 1, orderBy: {
								field: TAG_COMMIT_DATE, direction: DESC
							})
							{
								edges {
									node {
										name
									}
								}
							}
						}
					}"
				}
			EOF
		)"
	)

	local jq_filter api_path
	case "${tag_type}" in
		newest-tag)
			# 我们大量使用 graphql，因此应该减慢请求速度以避免达到 github 的速率限制。
			sleep 1
			curl_opts+=("${graphql_request[@]}")
			api_path="graphql"
			jq_filter='.data.repository.refs.edges[0].node.name'
		;;
		latest-release-tag)
			api_path="repos/${project}/releases/latest"
			jq_filter=".tag_name"
		;;
		latest-regex)
			# 我们大量使用 graphql，因此应该减慢请求速度以避免达到 github 的速率限制。
			sleep 1
			curl_opts+=("${graphql_request[@]}")
			# 按标签提交日期获取 20 个最新标签
			curl_opts[-1]="${curl_opts[-1]/first: 1/first: 20}"
			api_path="graphql"
			jq_filter='.data.repository.refs.edges[].node.name'
		;;
		*)
			termux_error_exit <<-EndOfError
				错误：无效的 TERMUX_PKG_UPDATE_TAG_TYPE：'${tag_type}'。
				允许的值：'newest-tag'、'latest-release-tag'、'latest-regex'。
			EndOfError
		;;
	esac

	# 组装 API 请求的完整 URL
	local api_url="https://api.github.com/${api_path}"
	local http_code response
	response="$(curl "${curl_opts[@]}" "${api_url}")"

	http_code="${response##*|}"
	# echo 会插入控制字符，jq 不喜欢这样。
	response="$(printf "%s\n" "${response%|*}")"

	local tag_name=""
	case "${http_code}" in
		200)
			tag_name="$(jq --exit-status --raw-output "${jq_filter}" <<< "${response}")"
		;;
		404)
			termux_error_exit <<-EndOfError
				未找到 '${tag_type}'。(${api_url})
				HTTP 代码：${http_code}
				尝试使用 '$(
					if [[ "${tag_type}" == "newest-tag" ]]; then
						echo "latest-release-tag"
					else
						echo "newest-tag"
					fi
				)'。
			EndOfError
		;;
		*)
			if jq --exit-status "has(\"message\") and .message == \"Not Found\"" <<< "${response}"; then
				termux_error_exit <<-EndOfError
					未找到 '${tag_type}'。(${api_url})
					HTTP 代码：${http_code}
					尝试使用 '$(
						if [[ "${tag_type}" == "newest-tag" ]]; then
							echo "latest-release-tag"
						else
							echo "newest-tag"
						fi
					)'。
				EndOfError
			fi
		;;
	esac
	echo "${tag_name}"
}
