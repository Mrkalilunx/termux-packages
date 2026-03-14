#!/bin/bash
# build-all.sh - 按照由 buildorder.py 指定的构建顺序构建所有包的脚本

set -e -u -o pipefail

TERMUX_SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; pwd)

# 将当前进程的 pid 存储到文件中，供 docker__run_docker_exec_trap 使用
source "$TERMUX_SCRIPTDIR/scripts/utils/docker/docker.sh"; docker__create_docker_exec_pid_file

if [ "$(uname -o)" = "Android" ] || [ -e "/system/bin/app_process" ]; then
	echo "此脚本不支持在设备上执行。"
	exit 1
fi

# 如果存在，则从 .termuxrc 读取设置
test -f "$HOME"/.termuxrc && . "$HOME"/.termuxrc
: ${TERMUX_TOPDIR:="$HOME/.termux-build"}
: ${TERMUX_ARCH:="aarch64"}
: ${TERMUX_FORMAT:="debian"}
: ${TERMUX_DEBUG_BUILD:=""}
: ${TERMUX_INSTALL_DEPS:="-s"}
# 除非设置为 -i，否则将 TERMUX_INSTALL_DEPS 设置为 -s

_show_usage() {
	echo "用法: ./build-all.sh [-a ARCH] [-d] [-i] [-o DIR] [-f FORMAT]"
	echo "构建所有包。"
	echo "  -a 要构建的架构: aarch64(默认), arm, i686, x86_64 或 all。"
	echo "  -d 使用调试符号构建。"
	echo "  -i 构建依赖项。"
	echo "  -o 指定 deb 目录。默认: debs/。"
	echo "  -f 指定包格式: debian(默认) 或 pacman。"
	exit 1
}

while getopts :a:hdio:f: option; do
case "$option" in
	a) TERMUX_ARCH="$OPTARG";;
	d) TERMUX_DEBUG_BUILD='-d';;
	i) TERMUX_INSTALL_DEPS='-i';;
	o) TERMUX_OUTPUT_DIR="$(realpath -m "$OPTARG")";;
	f) TERMUX_FORMAT="$OPTARG";;
	h) _show_usage;;
	*) _show_usage >&2 ;;
esac
done
shift $((OPTIND-1))
if [ "$#" -ne 0 ]; then _show_usage; fi

case "$TERMUX_ARCH" in
	all|aarch64|arm|i686|x86_64);;
	*) echo "错误: 无效的架构 '$TERMUX_ARCH'" 1>&2; exit 1;;
esac

case "$TERMUX_FORMAT" in
	debian|pacman);;
	*) echo "错误: 无效的格式 '$TERMUX_FORMAT'" 1>&2; exit 1;;
esac

BUILDSCRIPT=$(dirname "$0")/build-package.sh
BUILDALL_DIR=$TERMUX_TOPDIR/_buildall-$TERMUX_ARCH
BUILDORDER_FILE=$BUILDALL_DIR/buildorder.txt
BUILDSTATUS_FILE=$BUILDALL_DIR/buildstatus.txt

if [ -e "$BUILDORDER_FILE" ]; then
	echo "使用现有的构建顺序文件: $BUILDORDER_FILE"
else
	mkdir -p "$BUILDALL_DIR"
	"$TERMUX_SCRIPTDIR/scripts/buildorder.py" > "$BUILDORDER_FILE"
fi
if [ -e "$BUILDSTATUS_FILE" ]; then
	echo "从以下位置继续构建: $BUILDSTATUS_FILE"
fi

exec &>	>(tee -a "$BUILDALL_DIR"/ALL.out)
trap 'echo 错误: 参见 $BUILDALL_DIR/${PKG}.out' ERR

while read -r PKG PKG_DIR; do
	# 检查构建状态（使用 grep 有点粗糙，但有效）
	if [ -e "$BUILDSTATUS_FILE" ] && grep -q "^$PKG\$" "$BUILDSTATUS_FILE"; then
		echo "跳过 $PKG"
		continue
	fi

	# 开始构建
	if [ -n "${TERMUX_DEBUG_BUILD}" ]; then
		echo "\"$BUILDSCRIPT\" -a \"$TERMUX_ARCH\" $TERMUX_DEBUG_BUILD --format \"$TERMUX_FORMAT\" --library $(test "${PKG_DIR%/*}" = "gpkg" && echo "glibc" || echo "bionic") ${TERMUX_OUTPUT_DIR+-o $TERMUX_OUTPUT_DIR} $TERMUX_INSTALL_DEPS \"$PKG_DIR\""
	fi

	echo -n "正在构建 $PKG... "
	BUILD_START=$(date "+%s")
	"$BUILDSCRIPT" -a "$TERMUX_ARCH" $TERMUX_DEBUG_BUILD --format "$TERMUX_FORMAT" \
		--library $(test "${PKG_DIR%/*}" = "gpkg" && echo "glibc" || echo "bionic") \
		${TERMUX_OUTPUT_DIR+-o $TERMUX_OUTPUT_DIR} $TERMUX_INSTALL_DEPS "$PKG_DIR" \
		&> "$BUILDALL_DIR"/"${PKG}".out
	BUILD_END=$(date "+%s")
	BUILD_SECONDS=$(( BUILD_END - BUILD_START ))
	echo "完成，耗时 $BUILD_SECONDS 秒"

	# 更新构建状态
	echo "$PKG" >> "$BUILDSTATUS_FILE"
done<"${BUILDORDER_FILE}"

# 更新构建状态
rm -f "$BUILDSTATUS_FILE"
echo "构建完成"
