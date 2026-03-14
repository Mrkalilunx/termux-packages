# shellcheck shell=bash

# 注意：Repology 有时返回 "1.0-1" 作为最新版本，即使 "1.0" 才是最新的。
# 这发生在 repology 跟踪的任何仓库将 "1.0-1" 指定为最新版本时。
#
# 例如：
# 最新 lua:lpeg 版本（截至 2021-11-20T12:21:31）是 "1.0.2"，但 MacPorts 指定为 "1.0.2-1"。
# 因此 repology 返回 "1.0.2-1" 作为最新版本。
#
# 但希望所有这些都可以通过设置 TERMUX_PKG_UPDATE_VERSION_REGEXP 来避免。
#
termux_repology_api_get_latest_version() {
	if [[ -z "$1" ]]; then
		termux_error_exit "用法：${FUNCNAME[0]} PKG_NAME"
	fi

	# 为什么使用 `--arg`？请参阅：https://stackoverflow.com/a/54674832/15086226；`sub` 删除前导 'v'
	jq -r --arg pkg "$1" '.[$pkg] // "null" | sub("^v";"")' "$TERMUX_REPOLOGY_DATA_FILE"
}
