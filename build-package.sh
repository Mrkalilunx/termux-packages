#!/bin/bash

# 设置 TMPDIR 环境变量
: "${TMPDIR:=/tmp}"
export TMPDIR

# 设置 build-package.sh 调用深度
# 如果是根调用，则创建一个文件来存储通过递归调用 build-package.sh 在任何时刻已编译的包及其依赖项列表
if (( ${TERMUX_BUILD_PACKAGE_CALL_DEPTH-0} )); then
	export TERMUX_BUILD_PACKAGE_CALL_DEPTH=$((TERMUX_BUILD_PACKAGE_CALL_DEPTH+1))
else
	TERMUX_BUILD_PACKAGE_CALL_DEPTH=0
	TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH="${TMPDIR}/build-package-call-built-packages-list-$(date +"%Y-%m-%d-%H.%M.%S.")$((RANDOM%1000))"
	TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH="${TMPDIR}/build-package-call-building-packages-list-$(date +"%Y-%m-%d-%H.%M.%S.")$((RANDOM%1000))"
	export TERMUX_BUILD_PACKAGE_CALL_DEPTH TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH
	echo -n " " > "$TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH"
	touch "$TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH"
fi

set -euo pipefail

cd "$(realpath "$(dirname "$0")")"
TERMUX_SCRIPTDIR=$(pwd)
export TERMUX_SCRIPTDIR

# 将当前进程的 pid 存储到文件中，供 docker__run_docker_exec_trap 使用
# shellcheck source=scripts/utils/docker/docker.sh
source "$TERMUX_SCRIPTDIR/scripts/utils/docker/docker.sh"
docker__create_docker_exec_pid_file

# 加载 `termux_package` 库
# shellcheck source=scripts/utils/termux/package/termux_package.sh
source "$TERMUX_SCRIPTDIR/scripts/utils/termux/package/termux_package.sh"

export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -c log.showSignature=false log -1 --pretty=%ct 2>/dev/null || date "+%s")}

if [[ "$(uname -o)" == "Android" || -e "/system/bin/app_process" ]]; then
	if [[ "$(id -u)" == "0" ]]; then
		echo "此脚本不支持以 root 身份在设备上执行。"
		exit 1
	fi

	# 此变量告诉构建系统的所有部分
	# 构建正在设备上执行
	export TERMUX_ON_DEVICE_BUILD=true
else
	export TERMUX_ON_DEVICE_BUILD=false
fi

# 自动启用离线源代码和构建工具集
# 离线 termux-packages 捆绑包可以通过执行
# 脚本 ./scripts/setup-offline-bundle.sh 创建
if [[ -f "${TERMUX_SCRIPTDIR}/build-tools/.installed" ]]; then
	export TERMUX_PACKAGES_OFFLINE=true
fi

# 锁文件，防止在同一环境中并行运行
TERMUX_BUILD_LOCK_FILE="${TMPDIR}/.termux-build.lck"
if [[ ! -e "$TERMUX_BUILD_LOCK_FILE" ]]; then
	touch "$TERMUX_BUILD_LOCK_FILE"
fi

TERMUX_REPO_PKG_FORMAT="$(jq --raw-output '.pkg_format // "debian"' "${TERMUX_SCRIPTDIR}/repo.json")"
export TERMUX_REPO_PKG_FORMAT

# 用于内部使用的特殊变量。它强制脚本忽略
# 锁文件
: "${TERMUX_BUILD_IGNORE_LOCK:=false}"

# 记录错误消息并以错误代码退出的实用函数
# shellcheck source=scripts/build/termux_error_exit.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_error_exit.sh"

# 使用预期校验和下载资源的实用函数
# shellcheck source=scripts/build/termux_download.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_download.sh"

# 通过 proot 在 termux 环境下运行二进制文件的实用函数
# shellcheck source=scripts/build/setup/termux_setup_proot.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_proot.sh"

# 设置 blueprint-compiler 的实用函数（可能被 gnome-calculator 和 epiphany 使用）
# shellcheck source=scripts/build/setup/termux_setup_bpc.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_bpc.sh"

# 安装必要的包以使 CGCT 完全运行
# shellcheck source=scripts/build/termux_step_setup_cgct_environment.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_setup_cgct_environment.sh"

# 设置 capnproto 的实用函数（可能被 bitcoin 使用）
# shellcheck source=scripts/build/setup/termux_setup_capnp.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_capnp.sh"

# 设置 Cargo C-ABI 助手的实用函数
# shellcheck source=scripts/build/setup/termux_setup_cargo_c.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_cargo_c.sh"

# 设置 pkg-config 包装器的实用函数
# shellcheck source=scripts/build/setup/termux_setup_pkg_config_wrapper.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_pkg_config_wrapper.sh"

# 设置 Crystal 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_crystal.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_crystal.sh"

# 设置 DotNet 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_dotnet.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_dotnet.sh"

# 设置 Flang 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_flang.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_flang.sh"

# 设置针对 Android 的 GHC 交叉编译器工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_ghc.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_ghc.sh"

# 设置 GHC iserv 以交叉编译 haskell-template 的实用函数
# shellcheck source=scripts/build/setup/termux_setup_ghc_iserv.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_ghc_iserv.sh"

# 设置 cabal-install 的实用函数（可能被 ghc 工具链使用）
# shellcheck source=scripts/build/setup/termux_setup_cabal.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_cabal.sh"

# 设置 jailbreak-cabal 的实用函数。它用于从 Cabal 包中移除版本约束
# shellcheck source=scripts/build/setup/termux_setup_jailbreak_cabal.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_jailbreak_cabal.sh"

# 设置 GObject 内省交叉环境的实用函数
# shellcheck source=scripts/build/setup/termux_setup_gir.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_gir.sh"

# 设置 GN 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_gn.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_gn.sh"

# 为使用 golang 的包设置 go 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_golang.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_golang.sh"

# 设置 LDC 交叉环境的实用函数
# shellcheck source=scripts/build/setup/termux_setup_ldc.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_ldc.sh"

# 设置非集成（GNU Binutils）as 的实用函数
# shellcheck source=scripts/build/setup/termux_setup_no_integrated_as.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_no_integrated_as.sh"

# 设置 build-python 用于交叉编译 Python 和 crossenv 的实用函数
# shellcheck source=scripts/build/setup/termux_setup_build_python.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_build_python.sh"

# 为 python 包设置 python 的实用函数
# shellcheck source=scripts/build/setup/termux_setup_python_pip.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_python_pip.sh"

# 为使用 rust 的包设置 rust 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_rust.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_rust.sh"

# 为使用 swift 的包设置 swift 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_swift.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_swift.sh"

# 设置当前 xmake 构建系统的实用函数
# shellcheck source=scripts/build/setup/termux_setup_xmake.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_xmake.sh"

# 为使用 zig 的包设置 zig 工具链的实用函数
# shellcheck source=scripts/build/setup/termux_setup_zig.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_zig.sh"

# 设置当前 ninja 构建系统的实用函数
# shellcheck source=scripts/build/setup/termux_setup_ninja.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_ninja.sh"

# 设置 Node.js JavaScript 运行时的实用函数
# shellcheck source=scripts/build/setup/termux_setup_nodejs.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_nodejs.sh"

# 设置当前 meson 构建系统的实用函数
# shellcheck source=scripts/build/setup/termux_setup_meson.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_meson.sh"

# 设置当前 cmake 构建系统的实用函数
# shellcheck source=scripts/build/setup/termux_setup_cmake.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_cmake.sh"

# 设置 protobuf 的实用函数：
# shellcheck source=scripts/build/setup/termux_setup_protobuf.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_protobuf.sh"

# 设置 tree-sitter CLI 当前版本的实用函数
# shellcheck source=scripts/build/setup/termux_setup_treesitter.sh
source "$TERMUX_SCRIPTDIR/scripts/build/setup/termux_setup_treesitter.sh"

# 设置构建所使用的变量。包不应覆盖这些变量
# shellcheck source=scripts/build/termux_step_setup_variables.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_setup_variables.sh"

# 保存和恢复可能在构建之间更改的构建设置
# shellcheck source=scripts/build/termux_step_handle_buildarch.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_handle_buildarch.sh"

# 从 build.sh 获取 TERMUX_PKG_VERSION 的函数
# shellcheck source=scripts/build/termux_extract_dep_info.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_extract_dep_info.sh"

# 下载 .deb 的函数（使用 termux_download 函数）
# shellcheck source=scripts/build/termux_download_deb_pac.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_download_deb_pac.sh"

# 下载并提取多个 Ubuntu 包的函数（使用 termux_download 函数）
# shellcheck source=scripts/build/termux_download_ubuntu_packages.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_download_ubuntu_packages.sh"

# 下载 InRelease，验证其签名，然后通过哈希下载 Packages.xz 的脚本
# shellcheck source=scripts/build/termux_get_repo_files.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_get_repo_files.sh"

# 下载或构建依赖项。包不应覆盖
# shellcheck source=scripts/build/termux_step_get_dependencies.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_get_dependencies.sh"

# 下载编译用的 python 依赖模块
# shellcheck source=scripts/build/termux_step_get_dependencies_python.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_get_dependencies_python.sh"

# 处理构建期间需要运行的配置脚本。包不应覆盖
# shellcheck source=scripts/build/termux_step_override_config_scripts.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_override_config_scripts.sh"

# 删除旧的 src 和 build 文件夹并创建新的
# shellcheck source=scripts/build/termux_step_setup_build_folders.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_setup_build_folders.sh"

# 加载包构建脚本并开始构建。包不应覆盖
# shellcheck source=scripts/build/termux_step_start_build.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_start_build.sh"

# 清理已构建包的文件。包不应覆盖
# shellcheck source=scripts/build/termux_step_start_build.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_cleanup_packages.sh"

# 下载或构建依赖项。包不应覆盖
# shellcheck source=scripts/build/termux_step_create_timestamp_file.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_create_timestamp_file.sh"

# 在加载 $TERMUX_PKG_BUILDER_SCRIPT 后立即运行。包可以覆盖
# shellcheck source=scripts/build/get_source/termux_step_get_source.sh
source "$TERMUX_SCRIPTDIR/scripts/build/get_source/termux_step_get_source.sh"

# 如果 TERMUX_PKG_SRCURL 以 "git+" 开头，则从 termux_step_get_source 运行
# shellcheck source=scripts/build/get_source/termux_step_get_source.sh
source "$TERMUX_SCRIPTDIR/scripts/build/get_source/termux_git_clone_src.sh"

# 如果 TERMUX_PKG_SRCURL 不以 "git+" 开头，则从 termux_step_get_source 运行
# shellcheck source=scripts/build/get_source/termux_download_src_archive.sh
source "$TERMUX_SCRIPTDIR/scripts/build/get_source/termux_download_src_archive.sh"

# 在 termux_download_src_archive 之后从 termux_step_get_source 运行
# shellcheck source=scripts/build/get_source/termux_unpack_src_archive.sh
source "$TERMUX_SCRIPTDIR/scripts/build/get_source/termux_unpack_src_archive.sh"

# 包在获取包源代码后可以执行的钩子
# 从 $TERMUX_PKG_SRCDIR 调用
termux_step_post_get_source() {
	return
}

# 可选的主机构建。包不应覆盖
# shellcheck source=scripts/build/termux_step_handle_host_build.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_handle_host_build.sh"

# 执行主机构建。将在 $TERMUX_PKG_HOSTBUILD_DIR 中调用
# 在 termux_step_post_get_source() 之后和 termux_step_patch_package() 之前
# shellcheck source=scripts/build/termux_step_host_build.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_host_build.sh"

# 设置独立的 Android NDK 工具链。从 termux_step_setup_toolchain 调用
# shellcheck source=scripts/build/toolchain/termux_setup_toolchain_29.sh
source "$TERMUX_SCRIPTDIR/scripts/build/toolchain/termux_setup_toolchain_29.sh"

# 设置独立的 Android NDK 23c 工具链。从 termux_step_setup_toolchain 调用
# shellcheck source=scripts/build/toolchain/termux_setup_toolchain_23c.sh
source "$TERMUX_SCRIPTDIR/scripts/build/toolchain/termux_setup_toolchain_23c.sh"

# 设置独立的 Glibc GNU 工具链。从 termux_step_setup_toolchain 调用
# shellcheck source=scripts/build/toolchain/termux_setup_toolchain_gnu.sh
source "$TERMUX_SCRIPTDIR/scripts/build/toolchain/termux_setup_toolchain_gnu.sh"

# 运行 termux_step_setup_toolchain_${TERMUX_NDK_VERSION}。包不应覆盖
# shellcheck source=scripts/build/termux_step_setup_toolchain.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_setup_toolchain.sh"

# 应用包的所有 *.patch 文件。包不应覆盖
# shellcheck source=scripts/build/termux_step_patch_package.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_patch_package.sh"

# 用我们的 autotools build-aux/config.{sub,guess} 替换以添加 android 目标
# shellcheck source=scripts/build/termux_step_replace_guess_scripts.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_replace_guess_scripts.sh"

# 供包脚本覆盖。在 $TERMUX_PKG_BUILDDIR 中调用
termux_step_pre_configure() {
	return
}

# 设置配置参数并运行 $TERMUX_PKG_SRCDIR/configure。此函数从 termux_step_configure 调用
# shellcheck source=scripts/build/configure/termux_step_configure_autotools.sh
source "$TERMUX_SCRIPTDIR/scripts/build/configure/termux_step_configure_autotools.sh"

# 设置配置参数并运行 cmake。此函数从 termux_step_configure 调用
# shellcheck source=scripts/build/configure/termux_step_configure_cmake.sh
source "$TERMUX_SCRIPTDIR/scripts/build/configure/termux_step_configure_cmake.sh"

# 设置配置参数并运行 meson。此函数从 termux_step_configure 调用
# shellcheck source=scripts/build/configure/termux_step_configure_meson.sh
source "$TERMUX_SCRIPTDIR/scripts/build/configure/termux_step_configure_meson.sh"

# 设置配置参数并运行 cabal。此函数从 termux_step_configure 调用
# shellcheck source=scripts/build/configure/termux_step_configure_cabal.sh
source "$TERMUX_SCRIPTDIR/scripts/build/configure/termux_step_configure_cabal.sh"

# 配置包
# shellcheck source=scripts/build/configure/termux_step_configure.sh
source "$TERMUX_SCRIPTDIR/scripts/build/configure/termux_step_configure.sh"

# 配置步骤后包的钩子
termux_step_post_configure() {
	return
}

# 构建包，使用 ninja 或 make
# shellcheck source=scripts/build/termux_step_make.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_make.sh"

# 安装包，使用 ninja、make 或 cargo
# shellcheck source=scripts/build/termux_step_make_install.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_make_install.sh"

# 供包脚本覆盖的钩子函数
termux_step_post_make_install() {
	return
}

# 将 hooks (alpm-hooks) 和 hook-scripts 安装到 pacman 包中
# shellcheck source=scripts/build/termux_step_install_pacman_hooks.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_install_pacman_hooks.sh"

# 如果设置了数组 TERMUX_PKG_SERVICE_SCRIPT，则添加服务脚本
# shellcheck source=scripts/build/termux_step_install_service_scripts.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_install_service_scripts.sh"

# 将包的 LICENSE 链接/复制到 $TERMUX_PREFIX/share/$TERMUX_PKG_NAME/
# shellcheck source=scripts/build/termux_step_install_license.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_install_license.sh"

# 将已安装的文件 cp（通过 tar）到处理目录的函数
# shellcheck source=scripts/build/termux_step_copy_into_massagedir.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_copy_into_massagedir.sh"

# 为子包创建 {pre,post}install, {pre,post}rm-scripts 的钩子函数
# shellcheck source=scripts/build/termux_step_create_subpkg_debscripts.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_create_subpkg_debscripts.sh"

# 创建所有子包。从 termux_step_massage 运行
# shellcheck source=scripts/build/termux_create_debian_subpackages.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_create_debian_subpackages.sh"

# 创建所有子包。从 termux_step_massage 运行
# shellcheck source=scripts/build/termux_create_pacman_subpackages.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_create_pacman_subpackages.sh"

# 运行各种清理/修复的函数
# shellcheck source=scripts/build/termux_step_massage.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_massage.sh"

# 在 termux_step_massage 期间运行 strip 符号的函数
# shellcheck source=scripts/build/termux_step_strip_elf_symbols.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_strip_elf_symbols.sh"

# 在 termux_step_massage 期间运行 termux-elf-cleaner 的函数
# shellcheck source=scripts/build/termux_step_elf_cleaner.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_elf_cleaner.sh"

# 处理步骤前包的钩子
termux_step_pre_massage() {
	return
}

# 处理步骤后包的钩子
termux_step_post_massage() {
	return
}

# 创建 {pre,post}install, {pre,post}rm-scripts 和类似脚本的函数
# shellcheck source=scripts/build/termux_step_create_debscripts.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_create_debscripts.sh"

# 为 python 包生成 debscripts 的函数
# shellcheck source=scripts/build/termux_step_create_python_debscripts.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_create_python_debscripts.sh"

# 将 Debian 维护者脚本转换为 pacman 兼容的安装钩子
# 这仅在创建 pacman 包时使用
# shellcheck source=scripts/build/termux_step_create_pacman_install_hook.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_create_pacman_install_hook.sh"

# 创建构建 deb 文件。包脚本不应覆盖
# shellcheck source=scripts/build/termux_step_create_debian_package.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_create_debian_package.sh"

# 创建构建 .pkg.tar.xz 文件。包脚本不应覆盖
# shellcheck source=scripts/build/termux_step_create_pacman_package.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_create_pacman_package.sh"

# 从 `.alternatives` 文件处理 'update-alternatives' 条目
# 包脚本不应覆盖
# shellcheck source=scripts/build/termux_step_update_alternatives.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_update_alternatives.sh"

# 完成构建。包脚本不应覆盖
# shellcheck source=scripts/build/termux_step_finish_build.sh
source "$TERMUX_SCRIPTDIR/scripts/build/termux_step_finish_build.sh"

################################################################################

# shellcheck source=scripts/properties.sh
source "$TERMUX_SCRIPTDIR/scripts/properties.sh"

if [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
	# 设置 TERMUX_APP_PACKAGE_MANAGER
	# shellcheck source=/dev/null
	source "$TERMUX_PREFIX/bin/termux-setup-package-manager"

	# 对于设备构建不支持交叉编译
	# 目标架构必须与当前使用的环境相同
	case "$TERMUX_APP_PACKAGE_MANAGER" in
		"apt") TERMUX_ARCH=$(dpkg --print-architecture);;
		"pacman") TERMUX_ARCH=$(pacman-conf Architecture);;
	esac
	export TERMUX_ARCH
fi

# 检查包是否在已编译列表中
termux_check_package_in_built_packages_list() {
	[[ ! -f "$TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH" ]] && \
		termux_error_exit "文件 '$TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH' 未找到。"
	# 比 `grep -q $word $file` 稍微快一点
	[[ " $(< "$TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH") " == *" $1 "* ]]
	return $?
}

# 如果包不在列表中，则将其添加到已构建包列表
termux_add_package_to_built_packages_list() {
	if ! termux_check_package_in_built_packages_list "$1"; then
		echo -n "$1 " >> "$TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH"
	fi
}

# 检查包是否在编译列表中
termux_check_package_in_building_packages_list() {
	[[ ! -f "$TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH" ]] && \
		termux_error_exit "文件 '$TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH' 未找到。"
	# 比 `grep -q $word $file` 稍微快一点
	[[ $'\n'"$(<"$TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH")"$'\n' == *$'\n'"$1"$'\n'* ]]
	return $?
}

# 配置多库编译的变量（TERMUX_ARCH, TERMUX__PREFIX__INCLUDE_DIR, TERMUX__PREFIX__LIB_DIR）
termux_conf_multilib_vars() {
	# 将 64 位架构类型更改为其对应的 32 位类型，在 `TERMUX_ARCH` 变量中
	case "$TERMUX_ARCH" in
		"aarch64") TERMUX_ARCH="arm";;
		"x86_64") TERMUX_ARCH="i686";;
		*) termux_error_exit "无法为 ${TERMUX_ARCH} 架构设置多库架构。"
	esac
	TERMUX__PREFIX__INCLUDE_SUBDIR="$TERMUX__PREFIX__MULTI_INCLUDE_SUBDIR"
	TERMUX__PREFIX__INCLUDE_DIR="$TERMUX__PREFIX__MULTI_INCLUDE_DIR"
	TERMUX__PREFIX__LIB_SUBDIR="$TERMUX__PREFIX__MULTI_LIB_SUBDIR"
	TERMUX__PREFIX__LIB_DIR="$TERMUX__PREFIX__MULTI_LIB_DIR"
}

# 运行正常编译和多库编译的函数
termux_run_base_and_multilib_build_step() {
	case "${1}" in
		termux_step_configure|termux_step_make|termux_step_make_install) local func="${1}";;
		*) termux_error_exit "不支持的函数 '${1}'。"
	esac
	cd "$TERMUX_PKG_BUILDDIR"
	if [[ "$TERMUX_PKG_BUILD_ONLY_MULTILIB" == "false" ]]; then
		"${func}"
	fi
	if [[ "$TERMUX_PKG_BUILD_MULTILIB" == "true" ]]; then
		(
			termux_step_setup_multilib_environment
			"${func}_multilib"
		)
	fi
}

# 特殊钩子，防止在包构建脚本中使用 "sudo"
# build-package.sh 不应执行任何特权操作
sudo() {
	termux_error_exit "不要在构建脚本中使用 'sudo'。构建环境应通过 ./scripts/setup-ubuntu.sh 配置。"
}

_show_usage() {
	echo "用法: ./build-package.sh [选项] PACKAGE_1 PACKAGE_2 ..."
	echo
	echo "通过在 output/ 文件夹中创建 .deb 文件来构建包"
	echo
	echo "可用选项:"
	[[ "$TERMUX_ON_DEVICE_BUILD" = "false" ]] && echo "  -a 要构建的架构: aarch64(默认), arm, i686, x86_64 或 all。"
	echo "  -c 继续之前的构建"
	echo "  -C 在磁盘空间不足时清理已构建的包"
	echo "  -d 使用调试符号构建"
	echo "  -D 构建 disabled-packages/ 中的已禁用包"
	echo "  -f 强制构建，即使包已经构建"
	echo "  -F 强制构建，即使包及其依赖项已经构建"
	[[ "$TERMUX_ON_DEVICE_BUILD" = "false" ]] && echo "  -i 下载并提取依赖项而不是构建它们"
	echo "  -I 下载并提取依赖项而不是构建它们，保留现有的 $TERMUX_BASE_DIR 文件"
	echo "  -L 包及其依赖项将基于相同的库"
	echo "  -q 静默构建"
	echo "  -Q 详细构建 -- 设置 -x 调试输出和函数跟踪"
	echo "  -r 删除所有包构建依赖目录，'-f/-F'"
	echo "     标志本身不会删除，例如包含"
	echo "     包源代码和主机构建目录的缓存目录。如果未传递 '-f/-F'"
	echo "     标志则忽略"
	echo "  -w 安装没有版本绑定的依赖项"
	echo "  -s 跳过依赖检查"
	echo "  -o 指定放置构建包的目录。默认: output/"
	echo "  --format 指定包输出格式 (debian, pacman)"
	echo "  --library 指定包的库 (bionic, glibc)"
	exit 1
}

declare -a PACKAGE_LIST=()

(( $# )) || _show_usage
while (( $# )); do
	case "$1" in
		--) shift 1; break;;
		-h|--help) _show_usage;;
		--format)
			if [[ -z "${2-}" ]]; then
				termux_error_exit "./build-package.sh: 选项 '--format' 需要参数"
			fi
			shift 1
			export TERMUX_PACKAGE_FORMAT="$1"
		;;
		--library)
			if [[ -z "${2-}" ]]; then
				termux_error_exit "./build-package.sh: 选项 '--library' 需要参数"
			fi
			shift 1
			export TERMUX_PACKAGE_LIBRARY="$1"
		;;
		-a)
			if [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
				termux_error_exit "./build-package.sh: 选项 '-a' 不支持设备构建"
			fi
			if [[ -z "${2-}" ]]; then
				termux_error_exit "./build-package.sh: 选项 '-a' 需要参数"
			fi
			shift 1
			export TERMUX_ARCH="$1"
		;;
		-d) export TERMUX_DEBUG_BUILD=true;;
		-D) TERMUX_IS_DISABLED=true;;
		-f) TERMUX_FORCE_BUILD=true;;
		-F) TERMUX_FORCE_BUILD_DEPENDENCIES=true && TERMUX_FORCE_BUILD=true;;
		-i)
			if [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
				termux_error_exit "./build-package.sh: 选项 '-i' 不支持设备构建"
			fi
			export TERMUX_INSTALL_DEPS=true
		;;
		-I)
			export TERMUX_INSTALL_DEPS=true
			export TERMUX_PKGS__BUILD__RM_ALL_PKGS_BUILT_MARKER_AND_INSTALL_FILES=false
		;;
		-L) export TERMUX_GLOBAL_LIBRARY=true;;
		-q) export TERMUX_QUIET_BUILD=true;;
		-Q) export PS4='+$0 \[\e[32m\]${FUNCNAME[0]:-<global scope>}${FUNCNAME[*]:+()}:$LINENO\[\e[0m\] '; set -x;;
		-r) export TERMUX_PKGS__BUILD__RM_ALL_PKG_BUILD_DEPENDENT_DIRS=true;;
		-w) export TERMUX_WITHOUT_DEPVERSION_BINDING=true;;
		-s) export TERMUX_SKIP_DEPCHECK=true;;
		-o)
			if [[ -z "${2-}" ]]; then
				termux_error_exit "./build-package.sh: 选项 '-o' 需要参数"
			fi
			shift 1
			TERMUX_OUTPUT_DIR="$(realpath -m "$1")"
		;;
		-c) TERMUX_CONTINUE_BUILD=true;;
		-C) TERMUX_CLEANUP_BUILT_PACKAGES_ON_LOW_DISK_SPACE=true;;
		-*) termux_error_exit "./build-package.sh: 非法选项 '$1'";;
		*) PACKAGE_LIST+=("$1");;
	esac
	shift 1
done
unset -f _show_usage

# 依赖项应该仅在它们为相同包名构建时才从仓库使用
if [[ "$TERMUX_REPO_APP__PACKAGE_NAME" != "$TERMUX_APP_PACKAGE" ]]; then
	echo "忽略 -i 选项以下载依赖项，因为仓库包名 ($TERMUX_REPO_APP__PACKAGE_NAME) 不等于应用包名 ($TERMUX_APP_PACKAGE)"
	TERMUX_INSTALL_DEPS=false
fi

case "$TERMUX_REPO_PKG_FORMAT" in
	debian|pacman) :;;
	*) termux_error_exit "repo.json 文件中错误指定了 'pkg_format'。仅支持 'debian' 和 'pacman' 格式";;
esac

if [[ -n "${TERMUX_PACKAGE_FORMAT-}" ]]; then
	case "${TERMUX_PACKAGE_FORMAT-}" in
		debian|pacman) :;;
		*) termux_error_exit "不支持的包格式 \"${TERMUX_PACKAGE_FORMAT-}\"。仅支持 'debian' 和 'pacman' 格式";;
	esac
fi

if [[ -n "${TERMUX_PACKAGE_LIBRARY-}" ]]; then
	case "${TERMUX_PACKAGE_LIBRARY-}" in
		bionic|glibc) :;;
		*) termux_error_exit "不支持的库 \"${TERMUX_PACKAGE_LIBRARY-}\"。仅支持 'bionic' 和 'glibc' 库";;
	esac
fi

if [[ "${TERMUX_INSTALL_DEPS-false}" = "true" || "${TERMUX_PACKAGE_LIBRARY-bionic}" = "glibc" ]]; then
	# 设置用于验证依赖项完整性的 PGP 密钥
	# 密钥从我们的密钥环包获取
	gpg --list-keys 2C7F29AE97891F6419A9E2CDB0076E490B71616B > /dev/null 2>&1 || {
		gpg --import "$TERMUX_SCRIPTDIR/packages/termux-keyring/grimler.gpg"
		gpg --no-tty --command-file <(echo -e "trust\n5\ny") --edit-key 2C7F29AE97891F6419A9E2CDB0076E490B71616B
	}
	gpg --list-keys CC72CF8BA7DBFA0182877D045A897D96E57CF20C > /dev/null 2>&1 || {
		gpg --import "$TERMUX_SCRIPTDIR/packages/termux-keyring/termux-autobuilds.gpg"
		gpg --no-tty --command-file <(echo -e "trust\n5\ny") --edit-key CC72CF8BA7DBFA0182877D045A897D96E57CF20C
	}
	gpg --list-keys 998DE27318E867EA976BA877389CEED64573DFCA > /dev/null 2>&1 || {
		gpg --import "$TERMUX_SCRIPTDIR/packages/termux-keyring/termux-pacman.gpg"
		gpg --no-tty --command-file <(echo -e "trust\n5\ny") --edit-key 998DE27318E867EA976BA877389CEED64573DFCA
	}
fi

for (( i=0; i < ${#PACKAGE_LIST[@]}; i++ )); do
	# 以下命令必须在锁下执行以防止运行
	# "./build-package.sh" 的多个实例
	#
	# 为每个包提供合理的环境，
	# 构建在显式的子 shell 中完成
	# shellcheck disable=SC2031
	(
		if [[ "$TERMUX_BUILD_IGNORE_LOCK" != "true" ]]; then
			flock -n 5 || termux_error_exit "同一环境中已有另一个构建正在运行"
		fi
		(
		# 处理 'all' 架构：
		if [[ "$TERMUX_ON_DEVICE_BUILD" == "false" && -n "${TERMUX_ARCH+x}" && "${TERMUX_ARCH}" == 'all' ]]; then
			_SELF_ARGS=()
			[[ "${TERMUX_CLEANUP_BUILT_PACKAGES_ON_LOW_DISK_SPACE:-}" == "true" ]] && _SELF_ARGS+=("-C")
			[[ "${TERMUX_DEBUG_BUILD:-}" == "true" ]] && _SELF_ARGS+=("-d")
			[[ "${TERMUX_IS_DISABLED:-}" == "true" ]] && _SELF_ARGS+=("-D")
			[[ "${TERMUX_FORCE_BUILD:-}" == "true" && "${TERMUX_FORCE_BUILD_DEPENDENCIES:-}" != "true" ]] && _SELF_ARGS+=("-f")
			[[ "${TERMUX_FORCE_BUILD:-}" == "true" && "${TERMUX_FORCE_BUILD_DEPENDENCIES:-}" == "true" ]] && _SELF_ARGS+=("-F")
			[[ "${TERMUX_INSTALL_DEPS:-}" == "true" && "${TERMUX_PKGS__BUILD__RM_ALL_PKGS_BUILT_MARKER_AND_INSTALL_FILES:-}" != "false" ]] && _SELF_ARGS+=("-i")
			[[ "${TERMUX_INSTALL_DEPS:-}" == "true" && "${TERMUX_PKGS__BUILD__RM_ALL_PKGS_BUILT_MARKER_AND_INSTALL_FILES:-}" == "false" ]] && _SELF_ARGS+=("-I")
			[[ "${TERMUX_GLOBAL_LIBRARY:-}" == "true" ]] && _SELF_ARGS+=("-L")
			[[ -n "${TERMUX_OUTPUT_DIR:-}" ]] && _SELF_ARGS+=("-o" "$TERMUX_OUTPUT_DIR")
			[[ "${TERMUX_PKGS__BUILD__RM_ALL_PKG_BUILD_DEPENDENT_DIRS:-}" == "true" ]] && _SELF_ARGS+=("-r")
			[[ "${TERMUX_WITHOUT_DEPVERSION_BINDING:-}" == "true" ]] && _SELF_ARGS+=("-w")
			[[ -n "${TERMUX_PACKAGE_FORMAT:-}" ]] && _SELF_ARGS+=("--format" "$TERMUX_PACKAGE_FORMAT")
			[[ -n "${TERMUX_PACKAGE_LIBRARY:-}" ]] && _SELF_ARGS+=("--library" "$TERMUX_PACKAGE_LIBRARY")

			for arch in 'aarch64' 'arm' 'i686' 'x86_64'; do
				env TERMUX_ARCH="$arch" TERMUX_BUILD_IGNORE_LOCK=true ./build-package.sh \
					"${_SELF_ARGS[@]}" "${PACKAGE_LIST[i]}"
			done
			exit
		fi

		# 检查要构建的包：
		TERMUX_PKG_NAME="$(basename "${PACKAGE_LIST[i]}")"
		TERMUX_PKG_BUILDER_DIR=""
		if [[ ${PACKAGE_LIST[i]} == *"/"* ]]; then
			# 此仓库外目录的路径：
			if [[ ! -d "${PACKAGE_LIST[i]}" ]]; then termux_error_exit "'${PACKAGE_LIST[i]}' 似乎是路径但不是目录"; fi
			TERMUX_PKG_BUILDER_DIR="$(realpath "${PACKAGE_LIST[i]}")"
		else
			# 包名：
			# FIXME: TERMUX_PACKAGES_DIRECTORIES 应该被制成数组
			for package_directory in $TERMUX_PACKAGES_DIRECTORIES; do
				if [[ -d "${TERMUX_SCRIPTDIR}/${package_directory}/${TERMUX_PKG_NAME}" ]]; then
					export TERMUX_PKG_BUILDER_DIR="${TERMUX_SCRIPTDIR}/$package_directory/$TERMUX_PKG_NAME"
					break
				elif [[ -n "${TERMUX_IS_DISABLED=""}" && -d "${TERMUX_SCRIPTDIR}/disabled-packages/${TERMUX_PKG_NAME}" ]]; then
					export TERMUX_PKG_BUILDER_DIR="$TERMUX_SCRIPTDIR/disabled-packages/$TERMUX_PKG_NAME"
					break
				fi
			done
			if [[ -z "${TERMUX_PKG_BUILDER_DIR}" ]]; then
				termux_error_exit "在任何启用的仓库中未找到包 $TERMUX_PKG_NAME。您是否尝试设置自定义仓库？"
			fi
		fi
		export TERMUX_PKG_BUILDER_DIR
		TERMUX_PKG_BUILDER_SCRIPT=$TERMUX_PKG_BUILDER_DIR/build.sh
		if [[ ! -f "$TERMUX_PKG_BUILDER_SCRIPT" ]]; then
			termux_error_exit "包目录 $TERMUX_PKG_BUILDER_DIR 中没有 build.sh 脚本！"
		fi

		termux_step_setup_variables
		termux_step_handle_buildarch

		termux_step_cleanup_packages
		termux_step_start_build

		if ! termux_check_package_in_building_packages_list "${TERMUX_PKG_BUILDER_DIR#"${TERMUX_SCRIPTDIR}/"}"; then
			echo "${TERMUX_PKG_BUILDER_DIR#"${TERMUX_SCRIPTDIR}/"}" >> "$TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH"
		fi

		if [[ "$TERMUX_CONTINUE_BUILD" == "false" ]]; then
			termux_step_get_dependencies
			if [[ "$TERMUX_PACKAGE_LIBRARY" == "glibc" ]]; then
				termux_step_setup_cgct_environment
			fi
			termux_step_override_config_scripts
		fi

		termux_step_create_timestamp_file

		if [[ "$TERMUX_CONTINUE_BUILD" == "false" ]]; then
			cd "$TERMUX_PKG_CACHEDIR"
			termux_step_get_source
			cd "$TERMUX_PKG_SRCDIR"
			termux_step_post_get_source
			termux_step_handle_host_build
		fi

		termux_step_setup_toolchain

		if [[ "$TERMUX_CONTINUE_BUILD" == "false" ]]; then
			termux_step_get_dependencies_python
			termux_step_patch_package
			termux_step_replace_guess_scripts
			cd "$TERMUX_PKG_SRCDIR"
			termux_step_pre_configure
		fi

		# 即使在继续构建时，我们可能也需要设置路径
		# 到工具，所以需要运行配置步骤的一部分
		termux_run_base_and_multilib_build_step termux_step_configure

		if [[ "$TERMUX_CONTINUE_BUILD" == "false" ]]; then
			cd "$TERMUX_PKG_BUILDDIR"
			termux_step_post_configure
		fi
		termux_run_base_and_multilib_build_step termux_step_make
		termux_run_base_and_multilib_build_step termux_step_make_install
		cd "$TERMUX_PKG_BUILDDIR"
		termux_step_post_make_install
		termux_step_install_pacman_hooks
		termux_step_install_service_scripts
		termux_step_install_license
		cd "$TERMUX_PKG_MASSAGEDIR"
		termux_step_copy_into_massagedir
		cd "$TERMUX_PKG_MASSAGEDIR/$TERMUX_PREFIX_CLASSICAL"
		termux_step_pre_massage
		cd "$TERMUX_PKG_MASSAGEDIR/$TERMUX_PREFIX_CLASSICAL"
		termux_step_massage
		cd "$TERMUX_PKG_MASSAGEDIR/$TERMUX_PREFIX_CLASSICAL"
		termux_step_post_massage
		# 在最后阶段（当包归档时）最好使用系统的命令
		if [[ "$TERMUX_ON_DEVICE_BUILD" = "false" ]]; then
			export PATH="/usr/bin:$PATH"
		fi
		cd "$TERMUX_PKG_MASSAGEDIR"
		case "$TERMUX_PACKAGE_FORMAT" in
			debian) termux_step_create_debian_package;;
			pacman) termux_step_create_pacman_package;;
			*) termux_error_exit "未知的包格式 '$TERMUX_PACKAGE_FORMAT'。";;
		esac
		# 保存已编译包的列表以供进一步使用
		if termux_check_package_in_building_packages_list "${TERMUX_PKG_BUILDER_DIR#"${TERMUX_SCRIPTDIR}/"}"; then
			sed -i "\|^${TERMUX_PKG_BUILDER_DIR#"${TERMUX_SCRIPTDIR}/"}$|d" "$TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH"
		fi
		termux_add_package_to_built_packages_list "$TERMUX_PKG_NAME"
		termux_step_finish_build
		) 5>&-
	) 5< "$TERMUX_BUILD_LOCK_FILE"
done

# 删除存储已编译包列表的文件
if (( ! TERMUX_BUILD_PACKAGE_CALL_DEPTH )); then
	rm "$TERMUX_BUILD_PACKAGE_CALL_BUILT_PACKAGES_LIST_FILE_PATH"
	rm "$TERMUX_BUILD_PACKAGE_CALL_BUILDING_PACKAGES_LIST_FILE_PATH"
fi
