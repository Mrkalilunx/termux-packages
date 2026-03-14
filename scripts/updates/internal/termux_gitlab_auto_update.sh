# shellcheck shell=bash
# 用于托管在 gitlab 实例上的包的默认算法。
termux_gitlab_auto_update() {
	local latest_tag
	latest_tag="$(termux_gitlab_api_get_tag)"

	if [[ -z "${latest_tag}" ]]; then
		termux_error_exit "无法从 ${TERMUX_PKG_SRCURL} 获取标签"
	fi
	termux_pkg_upgrade_version "${latest_tag}"
}
