# shellcheck shell=bash
termux_repology_auto_update() {
	local latest_version
	latest_version="$(termux_repology_api_get_latest_version "${TERMUX_PKG_NAME}")"
	# 如果包未被 repology 跟踪或已经是最新的，Repology api 返回 null。
	if [[ "${latest_version}" == "null" ]]; then
		echo "INFO: Already up to date." # 由于我们从自动更新中排除了 Termux 独有的包，
		# 因此此包应该被 repology 跟踪并已经是最新的。
		return 0
	fi
	termux_pkg_upgrade_version "${latest_version}"
}
