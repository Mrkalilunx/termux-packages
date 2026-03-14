# shellcheck shell=bash
# 用于托管在 github.com 上的包的默认算法
termux_github_auto_update() {
	local latest_tag
	latest_tag="$(termux_github_api_get_tag)"

	if [[ -z "${latest_tag}" ]]; then
		termux_error_exit "无法从 ${TERMUX_PKG_SRCURL} 获取标签"
	fi
	termux_pkg_upgrade_version "${latest_tag}"
}
