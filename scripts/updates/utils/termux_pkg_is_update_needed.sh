#!/bin/bash

termux_pkg_is_update_needed() {
	# 用法：termux_pkg_is_update_needed <current-version> <latest-version>
	if [[ -z "$1" ]] || [[ -z "$2" ]]; then
		termux_error_exit "${BASH_SOURCE[0]}: 至少需要 2 个参数"
	fi

	local CURRENT_VERSION="$1"
	local LATEST_VERSION="$2"

	# 这甚至是一个有效格式的版本号吗？
	if ! dpkg --validate-version "${LATEST_VERSION}" &> /dev/null; then
		echo "::warning::${TERMUX_PKG_NAME:-}: $(dpkg --validate-version "${LATEST_VERSION}" &> /dev/stdout)" >&2
		return 1
	fi

	# 比较版本。
	dpkg --compare-versions "${CURRENT_VERSION}" lt "${LATEST_VERSION}"
	DPKG_EXIT_CODE=$?
	case "$DPKG_EXIT_CODE" in
		0) ;;          # true.  需要更新。
		1) return 1 ;; # false. 不需要更新。
		*) termux_error_exit "Bad 'dpkg --compare-versions' exit code: $DPKG_EXIT_CODE - bad version numbers?" ;;
	esac
}

# 使其也可以用作命令行工具。`scripts/bin/apt-compare-versions` 是此文件的符号链接。
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# shellcheck source=scripts/build/termux_error_exit.sh
	declare -f termux_error_exit >/dev/null ||
		. "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../build/termux_error_exit.sh" # realpath 用于解析符号链接。

	if [[ "${1}" == "--help" ]]; then
		cat <<-EOF
			用法：$(basename "${BASH_SOURCE[0]}") [--help] <first-version> <second-version>] [version-regex]
				--help - 显示此帮助消息并退出
				<first-version> - 要比较的第一个版本
				<second-version> - 要比较的第二个版本
				[version-regex] - 可选的正则表达式，用于从给定版本中过滤版本号
		EOF
	fi

	# 以人类可读格式打印。
	first_version="$1"
	second_version="$2"
	version_regexp="${3:-}"
	if [[ -n "${version_regexp}" ]]; then
		first_version="$(grep -oP "${version_regexp}" <<<"${first_version}")"
		second_version="$(grep -oP "${version_regexp}" <<<"${second_version}")"
		if [[ -z "${first_version}" ]] || [[ -z "${second_version}" ]]; then
			termux_error_exit "Unable to parse version numbers using regexp '${version_regexp}'"
		fi
	fi
	if [[ "${first_version}" == "${second_version}" ]]; then
		echo "${first_version} = ${second_version}"
	else
		if termux_pkg_is_update_needed "${first_version}" "${second_version}"; then
			echo "${first_version} < ${second_version}"
		elif termux_pkg_is_update_needed "${second_version}" "${first_version}"; then
			echo "${first_version} > ${second_version}"
		else
			echo "${first_version} = ${second_version}"
		fi
	fi
fi
