# shellcheck shell=bash

termux_gitlab_api_get_tag() {
	local api_host project tag_type
	tag_type="$TERMUX_PKG_UPDATE_TAG_TYPE"

	# 示例：
	# https://gitlab.freedesktop.org/xorg/app/xeyes/-/archive/xeyes-${TERMUX_PKG_VERSION}/xeyes-xeyes-${TERMUX_PKG_VERSION}.tar.gz
	#        _="https:"
	#        _=""
	# api_host="gitlab.freedesktop.org"
	#  project="xorg/app/xeyes/-/archive/xeyes-${TERMUX_PKG_VERSION}/xeyes-xeyes-${TERMUX_PKG_VERSION}.tar.gz"
	IFS='/' read -r _ _ api_host project <<< "${TERMUX_PKG_SRCURL}"
	# 某些项目（如 `xeyes`）位于子命名空间中，例如 'xorg/app/xeyes' 而不是 'xorg/xeyes'
	# 在 '/-/' 处切割项目部分是获取 URL 项目部分的更可靠方法。
	project="${project%/-/*}"

	if [[ -z "${tag_type}" ]]; then # 如果未设置，则根据 URL 决定。
		if [[ "${TERMUX_PKG_SRCURL:0:4}" == "git+" ]]; then
			tag_type="newest-tag" # 获取最新标签。
		elif [[ -n "$TERMUX_PKG_UPDATE_VERSION_REGEXP" ]]; then
			tag_type="latest-regex" # 获取最新发布标签。
		else
			tag_type="latest-release-tag" # 获取最新发布标签。
		fi
	fi

	# 如果仓库可公开访问，则无需身份验证即可访问 Gitlab API。
	# Gitlab 实例的默认速率限制为每个仓库每分钟 300 个请求，
	# 对于未经过身份验证的用户和非受保护路径，这应该足够满足我们的需求。
	# 请参阅：https://docs.gitlab.com/administration/settings/rate_limits_on_raw_endpoints/
	local -a curl_opts=(
		-A "Termux update checker 1.1 (github.com/termux/termux-packages)"
		--silent
		--location
		--retry 10
		--retry-delay 1
		--write-out '|%{http_code}'
	)

	local jq_filter api_path
	case "${tag_type}" in
		newest-tag)
			api_path="repository/tags"
			jq_filter=".[0].name"
		;;
		latest-release-tag)
			api_path="releases/permalink/latest"
			jq_filter=".tag_name"
		;;
		latest-regex)
			api_path="repository/tags"
			jq_filter=".[].name"
		;;
		*)
			termux_error_exit <<-EndOfError
				错误：无效的 TERMUX_PKG_UPDATE_TAG_TYPE：'${tag_type}'。
				允许的值：'newest-tag'、'latest-release-tag'、'latest-regex'。
			EndOfError
		;;
	esac

	# 在项目名称中将斜杠 '/' 替换为 '%2F'，这是 Gitlab API 所要求的。
	local api_url="https://${api_host}/api/v4/projects/${project//\//%2F}/${api_path}"
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
