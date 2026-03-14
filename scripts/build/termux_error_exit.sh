# shellcheck shell=bash
termux_error_exit() {
	if (( $# )); then
		printf '错误：%s\n' "$*"
	else # 从 stdin 读取。
		printf '%s\n' "$(cat -)"
	fi
	exit 1
} >&2
