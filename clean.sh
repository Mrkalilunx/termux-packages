#!/bin/bash
# clean.sh - 清理所有内容。
set -e -u

TERMUX_SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; pwd)

# 将当前进程的 pid 存储到文件中，供 docker__run_docker_exec_trap 使用
. "$TERMUX_SCRIPTDIR/scripts/utils/docker/docker.sh"; docker__create_docker_exec_pid_file

# 获取变量 CGCT_DIR
. "$TERMUX_SCRIPTDIR/scripts/properties.sh"

# 使用两种不同的方法检查脚本是否在 Android 上运行
# 出于安全考虑，防止在 Android 设备上执行潜在危险的
# 操作，如 'rm -rf /data/*'
if [ "$(uname -o)" = "Android" ] || [ -e "/system/bin/app_process" ]; then
	TERMUX_ON_DEVICE_BUILD=true
else
	TERMUX_ON_DEVICE_BUILD=false
fi

if [ "$(id -u)" = "0" ] && [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
	echo "此脚本不支持以 root 身份在设备上执行。"
	exit 1
fi

# 如果存在，则从 .termuxrc 读取设置
test -f "$HOME/.termuxrc" && . "$HOME/.termuxrc"
: "${TERMUX_TOPDIR:="$HOME/.termux-build"}"
: "${TMPDIR:=/tmp}"
export TMPDIR

# 锁文件。与 build-package.sh 中使用的相同
TERMUX_BUILD_LOCK_FILE="${TMPDIR}/.termux-build.lck"
if [ ! -e "$TERMUX_BUILD_LOCK_FILE" ]; then
	touch "$TERMUX_BUILD_LOCK_FILE"
fi

{
	if ! flock -n 5; then
		echo "由于您有未完成的构建正在运行，不清理构建目录。"
		exit 1
	fi

	if [ -d "$TERMUX_TOPDIR" ]; then
		chmod +w -R "$TERMUX_TOPDIR" || true
	fi

	# 对于设备构建，不应删除 Termux 应用数据目录
	if [[ "$TERMUX_ON_DEVICE_BUILD" == "false" ]]; then
		for variable_name in TERMUX__PREFIX TERMUX_APP__DATA_DIR CGCT_DIR; do
			variable_value="${!variable_name:-}"
			if [[ ! "$variable_value" =~ ^(/[^/]+)+$ ]]; then
				echo "运行 'clean.sh' 时，$variable_name '$variable_value' 不是根文件系统 '/' 下的绝对路径。" 1>&2
				exit 1
			fi
		done

		# 如果 `TERMUX__PREFIX` 在 `TERMUX_APP__DATA_DIR` 下，则
		# 只需删除整个 `TERMUX_APP__DATA_DIR`。否则，
		# 只删除 `TERMUX__PREFIX`，因为其父目录可能是
		# `TERMUX_REGEX__INVALID_TERMUX_PREFIX_PATHS` 中的关键目录
		# 这应该不是问题，因为包文件仅通过
		# `termux_step_copy_into_massagedir()` 从 `TERMUX_PREFIX_CLASSICAL` 打包
		if [[ "$TERMUX__PREFIX" == "$TERMUX_APP__DATA_DIR" ]] || \
			[[ "$TERMUX__PREFIX" == "$TERMUX_APP__DATA_DIR/"* ]]; then
			deletion_dir="$TERMUX_APP__DATA_DIR"
		else
			deletion_dir="$TERMUX__PREFIX"
		fi

		if [[ -e "$deletion_dir" ]]; then
			if [[ ! -d "$deletion_dir" ]]; then
				echo "运行 'clean.sh' 时，TERMUX__PREFIX 的删除目录 '$deletion_dir' 处存在非目录文件。" 1>&2
				exit 1
			fi

			# 如果删除目录在根文件系统 `/` 下或当前用户无法访问
			# 例如 Termux docker 中的 `builder` 用户
			# 无法访问 root 拥有的目录
			if [[ ! -r "$deletion_dir" ]] || [[ ! -w "$deletion_dir" ]] || [[ ! -x "$deletion_dir" ]]; then
				echo "运行 'clean.sh' 时，TERMUX__PREFIX 的删除目录 '$deletion_dir' 不可读、不可写或不可搜索。" 1>&2
				echo "尝试使用 'sudo' 运行 'clean.sh'。" 1>&2
				exit 1
			fi

			# 使用反斜杠转义 '\$[](){}|^.?+*'。
			cgct_dir_escaped="$(printf "%s" "$CGCT_DIR" | sed -zE -e 's/[][\.|$(){}?+*^]/\\&/g')"
			find "$deletion_dir" -mindepth 1 -regextype posix-extended ! -regex "^$cgct_dir_escaped(/.*)?" -delete 2>/dev/null || true
		fi

		# 删除已构建包的列表
		rm -Rf "/data/data/.built-packages"
	fi

	# 在删除父目录之前卸载 overlayfs
	[ -d "$TERMUX_TOPDIR" ] && for dir in $(find "$TERMUX_TOPDIR" -type d); do
		if mountpoint -q "$dir"; then
			umount "$dir"
		fi
	done

	# 如果 "$TERMUX_TOPDIR" 作为 Docker 卷挂载，我们不能使用 rm -Rf "$TERMUX_TOPDIR"
	if [ -d "$TERMUX_TOPDIR" ]; then
		find "$TERMUX_TOPDIR" -type f,l,b,c -delete
		find "$TERMUX_TOPDIR" -type d ! -path "$TERMUX_TOPDIR" -delete
	fi
} 5< "$TERMUX_BUILD_LOCK_FILE"
