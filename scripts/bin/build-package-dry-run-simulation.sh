#!/bin/bash

set -e -u

# 此脚本位于 '$TERMUX_SCRIPTDIR/scripts/bin/'。
TERMUX_SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; cd ../..; pwd)
DRY_RUN_SCRIPT_NAME=$(basename "$0")
BUILDSCRIPT_NAME="build-package.sh"
TERMUX_ARCH="aarch64"
TERMUX_DEBUG_BUILD="false"
TERMUX_PACKAGES_DIRECTORIES="
packages
root-packages
x11-packages
"

# 请与 'build-package.sh' 的第 468-547 行的逻辑保持同步。
declare -a PACKAGE_LIST=()
while (($# >= 1)); do
	case "$1" in
		*"/$BUILDSCRIPT_NAME") ;;
		-a)
			if [ $# -lt 2 ]; then
				echo "$DRY_RUN_SCRIPT_NAME: 选项 '-a' 需要一个参数"
				exit 1
			fi
			shift 1
			if [ -z "$1" ]; then
				echo "$DRY_RUN_SCRIPT_NAME: '-a' 的参数不应为空。"
				exit 1
			fi
			TERMUX_ARCH="$1"
			;;
		-d) TERMUX_DEBUG_BUILD="true" ;;
		-*) ;;
		*) PACKAGE_LIST+=("$1") ;;
	esac
	shift 1
done

# 请与 'build-package.sh' 的第 592-656 行的逻辑保持同步。
for ((i=0; i<${#PACKAGE_LIST[@]}; i++)); do
	TERMUX_PKG_NAME=$(basename "${PACKAGE_LIST[i]}")
	TERMUX_PKG_BUILDER_DIR=
	for package_directory in $TERMUX_PACKAGES_DIRECTORIES; do
		if [ -d "${TERMUX_SCRIPTDIR}/${package_directory}/${TERMUX_PKG_NAME}" ]; then
			TERMUX_PKG_BUILDER_DIR="${TERMUX_SCRIPTDIR}/$package_directory/$TERMUX_PKG_NAME"
			break
		fi
	done
	if [ -z "${TERMUX_PKG_BUILDER_DIR}" ]; then
		echo "$DRY_RUN_SCRIPT_NAME: 在任何启用的仓库中未找到包 $TERMUX_PKG_NAME。您是否正在尝试设置自定义仓库？"
		exit 1
	fi
	TERMUX_PKG_BUILDER_SCRIPT="$TERMUX_PKG_BUILDER_DIR/build.sh"

	# 请与 'scripts/build/termux_step_start_build.sh' 的第 2-50 行的逻辑保持同步。
	if [ "${TERMUX_ARCH}" != "all" ] && \
		grep -qE "^TERMUX_PKG_EXCLUDED_ARCHES=.*${TERMUX_ARCH}" "$TERMUX_PKG_BUILDER_SCRIPT"; then
		echo "$DRY_RUN_SCRIPT_NAME: 跳过为架构 $TERMUX_ARCH 构建 $TERMUX_PKG_NAME"
		continue
	fi

	if [ "${TERMUX_DEBUG_BUILD}" = "true" ] && \
		grep -qE "^TERMUX_PKG_HAS_DEBUG=.*false" "$TERMUX_PKG_BUILDER_SCRIPT"; then
		echo "$DRY_RUN_SCRIPT_NAME: 跳过为 $TERMUX_PKG_NAME 构建调试版本"
		continue
	fi

	echo "$DRY_RUN_SCRIPT_NAME: 结束 dry run 模拟（$BUILDSCRIPT_NAME 本应继续构建 $TERMUX_PKG_NAME）"
	exit 0
done

if [ ${#PACKAGE_LIST[@]} -gt 0 ]; then
	# 至少解析了一个包名称，但没有一个达到 "exit 0"，
	# 所以以返回值 85 (EX_C__NOOP) 退出，以表示不会构建任何包。
	echo "$DRY_RUN_SCRIPT_NAME: 结束 dry run 模拟（$BUILDSCRIPT_NAME 本应不会构建任何包）"
	exit 85 # EX_C__NOOP
fi

# 如果到达此点，则假设使用了无效或未在此脚本中实现的参数组合，
# 并且需要运行真实的 'build-package.sh' 以便其自己的解析器可以解释参数
# 并显示适当的消息。
echo "$DRY_RUN_SCRIPT_NAME: 结束 dry run 模拟（未知参数，传递给真实的 $BUILDSCRIPT_NAME 以获取更多信息）"
exit 0
