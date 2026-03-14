# shellcheck shell=bash
termux_pkg_auto_update() {
	if [[ -n "${__CACHED_TAG:-}" ]]; then
		termux_pkg_upgrade_version "${__CACHED_TAG}"
		return $?
	fi

	# 示例：
	# https://github.com/vim/vim/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz
	#            _="https:"
	#            _=""
	# project_host="github.com"
	#            _="vim/vim/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz"
	local project_host
	IFS='/' read -r _ _ project_host _ <<< "${TERMUX_PKG_SRCURL}"

	# gitlab.gnome.org 从 2026 年 1 月开始响应来自 GitHub Actions 的 API 请求时
	# 返回 HTTP 403 错误。
	# 在 GitHub Actions 中失败的命令示例：
	# curl https://gitlab.gnome.org/api/v4/projects/GNOME%2Fvte/releases/permalink/latest
	# 参见：https://github.com/termux/termux-packages/issues/28242
	if [[ -z "${TERMUX_PKG_UPDATE_METHOD}" ]]; then
		if [[ "${project_host}" == "github.com" ]]; then
			TERMUX_PKG_UPDATE_METHOD="github"
		elif [[ "$TERMUX_PKG_SRCURL" == *"/-/archive/"* && "$TERMUX_PKG_SRCURL" != *"gitlab.gnome.org"* ]]; then
			TERMUX_PKG_UPDATE_METHOD="gitlab"
		else
			TERMUX_PKG_UPDATE_METHOD="repology"
		fi
	fi

	case "${TERMUX_PKG_UPDATE_METHOD}" in
		github)
			if [[ "${project_host}" != "${TERMUX_PKG_UPDATE_METHOD}.com" ]]; then
				termux_error_exit <<-EndOfError
					源 URL 的主机名不是 ${TERMUX_PKG_UPDATE_METHOD}.com，但已被
					配置为使用 ${TERMUX_PKG_UPDATE_METHOD} 的方法。
				EndOfError
			fi
			termux_github_auto_update
		;;
		gitlab)
			termux_gitlab_auto_update
		;;
		repology)
			termux_repology_auto_update
		;;
		*)
			termux_error_exit <<-EndOfError
				TERMUX_PKG_UPDATE_METHOD 的值 '${TERMUX_PKG_UPDATE_METHOD}' 错误。

				可以是 'github'、'gitlab' 或 'repology'
			EndOfError
		;;
	esac
}
