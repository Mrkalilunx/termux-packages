# shellcheck shell=bash
# 接收 GraphQL 查询片段列表
termux_github_graphql() {
	local -a GITHUB_GRAPHQL_QUERIES=( "$@" )
	local pkg_json; pkg_json="$(jq -c -n '$ARGS.positional' --args "${__GITHUB_PACKAGES[@]}")"

	# 如果没有要进行的 github graphql 查询，则什么也不做，否则会出现此错误：
	# termux_github_graphql.sh: line 12: GITHUB_GRAPHQL_QUERIES[$BATCH * $BATCH_SIZE]: unbound variable
	if (( ${#GITHUB_GRAPHQL_QUERIES[@]} == 0 )); then
		return
	fi

	# 用于获取标签的批处理大小，100 似乎始终有效。
	local BATCH BATCH_SIZE=100
	# echo "# vim: ft=graphql" > /tmp/query-12345 # 取消注释以调试 GraphQL 查询
	# echo "# $(date -Iseconds)" >> /tmp/query-12345
	for (( BATCH = 0; ${#GITHUB_GRAPHQL_QUERIES[@]} >= BATCH_SIZE * BATCH ; BATCH++ )); do

		echo "Starting batch $BATCH at: ${GITHUB_GRAPHQL_QUERIES[$BATCH * $BATCH_SIZE]//\/}" >&2

		# JSON 字符串不能包含制表符或换行符
		# 所以让 shellcheck 闭嘴，不要抱怨单引号中的转义
		local QUERY

		# 使用我们的两个片段开始 GraphQL 查询，以从发布和 refs/tags 获取最新标签
		# 这些仅在需要时定义。

		# _latest_release_tag 从查询的仓库返回 latestRelease.tagName
		grep -q '_latest_release_tag' <<< "${GITHUB_GRAPHQL_QUERIES[@]:$BATCH * $BATCH_SIZE:$BATCH_SIZE}" && {
			QUERY+="$(printf '%s\n' \
			'fragment _latest_release_tag on Repository {' \
			'  latestRelease { tagName }' \
			'}')"
		}

		# _latest_regex 按提交日期返回 (20) 个最新标签
		grep -q '_latest_regex' <<< "${GITHUB_GRAPHQL_QUERIES[@]:$BATCH * $BATCH_SIZE:$BATCH_SIZE}" && {
			QUERY+="$(printf '%s\n' \
			'fragment _latest_regex on Repository {' \
			'  refs( refPrefix: \"refs/tags/\" first: 20 orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {' \
			'    nodes { name }' \
			'  }' \
			'}')"
		}

		# _newest_tag 按提交日期返回 (1) 个最新标签
		grep -q '_newest_tag' <<< "${GITHUB_GRAPHQL_QUERIES[@]:$BATCH * $BATCH_SIZE:$BATCH_SIZE}" && {
			QUERY+="$(printf '%s\n' \
			'fragment _newest_tag on Repository {' \
			'  refs( refPrefix: \"refs/tags/\" first: 1 orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {' \
			'    nodes { name }' \
			'  }' \
			'}')"
		}

		QUERY+='query {'

		# 用我们需要查询更新的包仓库填充查询主体
		# 最后获取速率限制使用情况
		printf -v QUERY '%s\n' \
				"${QUERY}" \
				"${GITHUB_GRAPHQL_QUERIES[@]:$BATCH * $BATCH_SIZE:$BATCH_SIZE}" \
				'ratelimit: rateLimit { cost limit remaining used resetAt }' \
				'}' \

		# echo "# Batch: $BATCH" >> /tmp/query-12345 # 取消注释以调试 GraphQL 查询
		# printf '%s' "${QUERY}"  >> /tmp/query-12345 # 取消注释以调试 GraphQL 查询

		# 我们大量使用 graphql，因此应该减慢请求速度以避免达到 github 的速率限制。
		sleep 5

		local response
		# 尝试最多 3 次获取批处理，GitHub 的 GraphQL API 有时可能不太可靠。
		if ! response="$(printf '{ "query": "%s" }' "${QUERY//
\n'/ }" | curl -fL \
			--retry 3 --retry-delay 5 \
			--no-progress-meter \
			-H "Authorization: token ${GITHUB_TOKEN}" \
			-H 'Accept: application/vnd.github.v3+json' \
			-H 'Content-Type: application/json' \
			-X POST \
			--data @- \
			https://api.github.com/graphql)"; then
			{
				printf '\t%s\n' \
					"Did not receive a clean API response." \
					"Need to run a manual sanity check on the response."
				if ! jq <<< "$response"; then
					printf '\t%s\n' "Doesn't seem to be valid JSON, skipping batch."
					continue
				fi
				printf '\t%s\n' "Seems to be valid JSON, let's try parsing it."
			} >&2
		fi

		unset QUERY
		ret="$(jq -r --argjson pkgs "$pkg_json" '
			.data                                          # From the data: table
			| del(.ratelimit)                              # Remove the ratelimit: table
			| to_entries[]                                 # Convert the remaining entries to an array
			| .key as $alias                               # Save key to variable
			| ($alias | ltrimstr("_") | tonumber) as $idx  # Extract iterator from bash array
			| .value | (                                   # For each .value
				.latestRelease?.tagName                    # Print out the tag name of the latest release
				// (.refs.nodes | map(.name) | join("\n")) # or of the tags
				// empty                                   # If neither exists print nothing
			) as $tag                                      # Save to variable
			| select($tag != "")                           # Filter out empty strings
			| ($pkgs[$idx] | split("/")[-1]) as $pkgName   # Get package name from bash array
			| "GIT|\($pkgName)|\($tag)"                    # Print results
			' <<< "$response" 2>/dev/null)" || {
			echo "此响应有问题"
		}
		# # Uncomment for debugging GraphQL queries
		# jq '.' <<< "$response" >> /tmp/query-12345
		# echo "$ret" >> /tmp/query-12345
		echo "$ret"
	done
}
