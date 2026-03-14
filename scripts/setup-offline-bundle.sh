#!/usr/bin/env bash
##
## 下载所有包源代码并尽可能安装所有构建工具，
## 以便它们可以离线使用。
##

set -e -u

if [ "$(uname -o)" = "Android" ] || [ "$(uname -m)" != "x86_64" ]; then
	echo "此脚本仅支持 x86_64 GNU/Linux 系统。"
	exit 1
fi

export TERMUX_SCRIPTDIR="$(dirname "$(readlink -f "$0")")/../"
mkdir -p "$TERMUX_SCRIPTDIR"/build-tools

. "$TERMUX_SCRIPTDIR"/scripts/properties.sh
: "${TERMUX_PKG_MAKE_PROCESSES:="$(nproc)"}"
export TERMUX_PKG_MAKE_PROCESSES
export TERMUX_PACKAGES_OFFLINE=true
export TERMUX_ARCH=aarch64
export TERMUX_ON_DEVICE_BUILD=false
export TERMUX_PKG_TMPDIR="$TERMUX_SCRIPTDIR/build-tools/_tmp"
export TERMUX_COMMON_CACHEDIR="$TERMUX_PKG_TMPDIR"
export TERMUX_HOST_PLATFORM=aarch64-linux-android
export TERMUX_ARCH_BITS=64
export TERMUX_BUILD_TUPLE=x86_64-pc-linux-gnu
export TERMUX_PKG_API_LEVEL=24
export TERMUX_TOPDIR="$HOME/.termux-build"
export TERMUX_PYTHON_CROSSENV_PREFIX="$TERMUX_TOPDIR/python-crossenv-prefix"
export TERMUX_PYTHON_VERSION=$(. "$TERMUX_SCRIPTDIR/packages/python/build.sh"; echo "$_MAJOR_VERSION")
export TERMUX_PYTHON_HOME=$TERMUX_PREFIX/lib/python${TERMUX_PYTHON_VERSION}
export CC=gcc CXX=g++ LD=ld AR=ar STRIP=strip PKG_CONFIG=pkg-config
export CPPFLAGS="" CFLAGS="" CXXFLAGS="" LDFLAGS=""
export TERMUX_PACKAGE_LIBRARY=bionic
mkdir -p "$TERMUX_PKG_TMPDIR"

# 构建工具。
. "$TERMUX_SCRIPTDIR"/scripts/build/termux_download.sh
(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_cargo_c.sh
	termux_setup_cargo_c
)
(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_cmake.sh
	termux_setup_cmake
)
# GHC 失败。暂时跳过。
#(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_ghc.sh
#	termux_setup_ghc
#)
(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_golang.sh
	termux_setup_golang
)
(
	. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_ninja.sh
	. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_meson.sh
	termux_setup_meson
)
(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_protobuf.sh
	termux_setup_protobuf
)
#(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_python_pip.sh
#	termux_setup_python_pip
#)
# 离线 rust 尚不支持。
#(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_rust.sh
#	termux_setup_rust
#)
(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_swift.sh
	termux_setup_swift
)
(. "$TERMUX_SCRIPTDIR"/scripts/build/setup/termux_setup_zig.sh
	termux_setup_zig
)
(test -d "$TERMUX_SCRIPTDIR"/build-tools/android-sdk && test -d "$TERMUX_SCRIPTDIR"/build-tools/android-ndk && exit 0
	"$TERMUX_SCRIPTDIR"/scripts/setup-android-sdk.sh
)
rm -rf "${TERMUX_PKG_TMPDIR}"

# 包源代码。
for repo_path in $(jq --raw-output 'del(.pkg_format) | keys | .[]' $TERMUX_SCRIPTDIR/repo.json); do
	for p in "$TERMUX_SCRIPTDIR"/$repo_path/*; do
		(
			. "$TERMUX_SCRIPTDIR"/scripts/build/get_source/termux_step_get_source.sh
			. "$TERMUX_SCRIPTDIR"/scripts/build/get_source/termux_git_clone_src.sh
			. "$TERMUX_SCRIPTDIR"/scripts/build/get_source/termux_download_src_archive.sh
			. "$TERMUX_SCRIPTDIR"/scripts/build/get_source/termux_unpack_src_archive.sh

			# 在 termux_step_get_source.sh 中禁用归档提取。
			termux_extract_src_archive() {
				:
			}

			TERMUX_PKG_NAME=$(basename "$p")
			TERMUX_PKG_BUILDER_DIR="${p}"
			TERMUX_PKG_CACHEDIR="${p}/cache"
			TERMUX_PKG_METAPACKAGE=false

			# 将一些变量设置为虚拟值以避免错误。
			TERMUX_PKG_TMPDIR="${TERMUX_PKG_CACHEDIR}/.tmp"
			TERMUX_PKG_SRCDIR="${TERMUX_PKG_CACHEDIR}/.src"
			TERMUX_PKG_BUILDDIR="$TERMUX_PKG_SRCDIR"
			TERMUX_PKG_HOSTBUILD_DIR="$TERMUX_PKG_TMPDIR"
			TERMUX_PKG_GIT_BRANCH=""
			TERMUX_DEBUG_BUILD=false


			mkdir -p "$TERMUX_PKG_CACHEDIR" "$TERMUX_PKG_TMPDIR" "$TERMUX_PKG_SRCDIR"
			cd "$TERMUX_PKG_CACHEDIR"

			. "${p}"/build.sh || true
			if ! ${TERMUX_PKG_METAPACKAGE}; then
				echo "正在下载 '$TERMUX_PKG_NAME' 的源代码..."
				termux_step_get_source

				# 删除虚拟 src 和 tmp 目录。
				rm -rf "$TERMUX_PKG_TMPDIR" "$TERMUX_PKG_SRCDIR"
			fi
		)
	done
done

# 标记以告诉 build-package.sh 启用离线模式。
touch "$TERMUX_SCRIPTDIR"/build-tools/.installed
