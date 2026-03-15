termux_step_setup_variables() {
	: "${TERMUX_ARCH:="aarch64"}" # arm、aarch64、i686 或 x86_64。
	: "${TERMUX_OUTPUT_DIR:="${TERMUX_SCRIPTDIR}/output"}"
	: "${TERMUX_DEBUG_BUILD:="false"}"
	: "${TERMUX_FORCE_BUILD:="false"}"
	: "${TERMUX_FORCE_BUILD_DEPENDENCIES:="false"}"
	: "${TERMUX_INSTALL_DEPS:="false"}"
	: "${TERMUX_PKG_MAKE_PROCESSES:="8"}"
	: "${TERMUX_PKGS__BUILD__RM_ALL_PKGS_BUILT_MARKER_AND_INSTALL_FILES:="true"}"
	: "${TERMUX_PKGS__BUILD__RM_ALL_PKG_BUILD_DEPENDENT_DIRS:="false"}"
	: "${TERMUX_PKG_API_LEVEL:="24"}"
	: "${TERMUX_CONTINUE_BUILD:="false"}"
	: "${TERMUX_QUIET_BUILD:="false"}"
	: "${TERMUX_WITHOUT_DEPVERSION_BINDING:="false"}"
	: "${TERMUX_SKIP_DEPCHECK:="false"}"
	: "${TERMUX_GLOBAL_LIBRARY:="false"}"
	: "${TERMUX_TOPDIR:="$HOME/.termux-build"}"
	: "${TERMUX_PACMAN_PACKAGE_COMPRESSION:="xz"}"

	if [ -z "${TERMUX_PACKAGE_FORMAT-}" ]; then
		if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ] && [ -n "${TERMUX_APP_PACKAGE_MANAGER-}" ]; then
			TERMUX_PACKAGE_FORMAT="$([ "${TERMUX_APP_PACKAGE_MANAGER-}" = "apt" ] && echo "debian" || echo "${TERMUX_APP_PACKAGE_MANAGER-}")"
		else
			TERMUX_PACKAGE_FORMAT="debian"
		fi
	fi

	case "${TERMUX_PACKAGE_FORMAT-}" in
		debian) export TERMUX_PACKAGE_MANAGER="apt";;
		pacman) export TERMUX_PACKAGE_MANAGER="pacman";;
		*) termux_error_exit "不支持的包格式 \"${TERMUX_PACKAGE_FORMAT-}\"。仅支持 'debian' 和 'pacman' 格式";;
	esac

	# 默认包库基础
	if [ -z "${TERMUX_PACKAGE_LIBRARY-}" ]; then
		export TERMUX_PACKAGE_LIBRARY="bionic"
	fi

	if [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
		termux_build_props__set_termux_prefix_dir_and_sub_variables "$TERMUX__PREFIX_GLIBC"
		if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ] && [ "$TERMUX_PREFIX" != "$CGCT_DEFAULT_PREFIX" ]; then
			export CGCT_APP_PREFIX="$TERMUX_PREFIX"
		fi
		if ! termux_package__is_package_name_have_glibc_prefix "$TERMUX_PKG_NAME"; then
			TERMUX_PKG_NAME="$(termux_package__add_prefix_glibc_to_package_name "${TERMUX_PKG_NAME}")"
		fi
	fi

	if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
		# 对于设备上构建，不支持交叉编译，因此我们可以
		# 在 $TERMUX_TOPDIR 下存储有关已构建包的信息。
		TERMUX_BUILT_PACKAGES_DIRECTORY="$TERMUX_TOPDIR/.built-packages"
		TERMUX_PKGS__BUILD__RM_ALL_PKGS_BUILT_MARKER_AND_INSTALL_FILES="false"

		if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ]; then
			# 不支持没有 termux-exec 的设备上构建。
			if [[ ":${LD_PRELOAD:-}:" != ":${TERMUX__PREFIX__LIB_DIR}/libtermux-exec"*".so:" ]]; then
				termux_error_exit "不支持没有 termux-exec 的设备上构建。"
			fi
		fi
	else
		TERMUX_BUILT_PACKAGES_DIRECTORY="/data/data/.built-packages"
	fi

	# TERMUX_PKG_MAINTAINER 应该在包的 build.sh 中显式设置。
	: "${TERMUX_PKG_MAINTAINER:="default"}"

	termux_step_setup_arch_variables
	TERMUX_REAL_ARCH="$TERMUX_ARCH"
	TERMUX_REAL_HOST_PLATFORM="$TERMUX_HOST_PLATFORM"

	if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ]; then
		if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ] && [ ! -d "$NDK" ]; then
			termux_error_exit "NDK ($NDK) 未指向目录！"
		fi

		if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ] && ! grep -s -q "Pkg.Revision = $TERMUX_NDK_VERSION_NUM" "$NDK/source.properties"; then
			termux_error_exit "NDK 版本错误 - 我们需要 $TERMUX_NDK_VERSION"
		fi
	elif [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
		if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
			if [ -n "${LD_PRELOAD-}" ]; then
				unset LD_PRELOAD
			fi
			if [ ! -d "${TERMUX_PREFIX}/bin" ]; then
				termux_error_exit "未安装 glibc 组件，运行 './scripts/setup-termux-glibc.sh'"
			fi
		else
			if [ ! -d "${CGCT_DIR}/${TERMUX_ARCH}/bin" ]; then
				termux_error_exit "未找到 cgct 工具，运行 './scripts/setup-cgct.sh'"
			fi
		fi
	fi

	# 可以给 --build configure 标志的构建元组：
	TERMUX_BUILD_TUPLE=$(sh "$TERMUX_SCRIPTDIR/scripts/config.guess")

	# 我们不将 build-tools/$TERMUX_ANDROID_BUILD_TOOLS_VERSION/ 中的所有内容放入 PATH
	# 以避免那里的 arm-linux-androideabi-ld 与独立工具链中的
	# 冲突。
	TERMUX_D8=$ANDROID_HOME/build-tools/$TERMUX_ANDROID_BUILD_TOOLS_VERSION/d8

	TERMUX_COMMON_CACHEDIR="$TERMUX_TOPDIR/_cache"
	TERMUX_ELF_CLEANER=$TERMUX_COMMON_CACHEDIR/termux-elf-cleaner

	export prefix=${TERMUX_PREFIX}
	export PREFIX=${TERMUX_PREFIX}

	# Explicitly export in case the default was set.
	export TERMUX_ARCH=${TERMUX_ARCH}

	if [ "${TERMUX_PACKAGES_OFFLINE-false}" = "true" ]; then
		# 在"离线"模式下，从包含 build.sh 脚本的目录存储/选取缓存。
		TERMUX_PKG_CACHEDIR=$TERMUX_PKG_BUILDER_DIR/cache
	else
		TERMUX_PKG_CACHEDIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/cache
	fi
	TERMUX_PKG_CMAKE_BUILD=Ninja # Which cmake generator to use
	TERMUX_PKG_ANTI_BUILD_DEPENDS="" # 这不能用于"解决"循环依赖
	TERMUX_PKG_BREAKS="" # https://www.debian.org/doc/debian-policy/ch-relationships.html#s-binarydeps
	TERMUX_PKG_BUILDDIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/build
	TERMUX_PKG_BUILD_DEPENDS=""
	TERMUX_PKG_BUILD_IN_SRC=false
	TERMUX_PKG_BUILD_MULTILIB=false # multilib 编译（为 64 位设备编译 32 位包）
	TERMUX_PKG_BUILD_ONLY_MULTILIB=false # 指定包仅通过 multilib 编译编译。如果启用了 multilib 编译并且 `TERMUX_PKG_EXCLUDED_ARCHES` 变量包含 `arm` 和 `i686` 值，则自动启用。
	TERMUX_PKG_MULTILIB_BUILDDIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/multilib-build # 如果启用了 multilib 编译，32 位包的组装组件的路径
	TERMUX_PKG_CONFFILES=""
	TERMUX_PKG_CONFLICTS="" # https://www.debian.org/doc/debian-policy/ch-relationships.html#s-conflicts
	TERMUX_PKG_DEPENDS=""
	TERMUX_PKG_DESCRIPTION="FIXME:Add description"
	TERMUX_PKG_DISABLE_GIR=false # termux_setup_gir
	TERMUX_PKG_ESSENTIAL=false
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS=""
	TERMUX_PKG_EXTRA_HOSTBUILD_CONFIGURE_ARGS=""
	TERMUX_PKG_EXTRA_MAKE_ARGS=""
	TERMUX_PKG_EXTRA_UNDEF_SYMBOLS_TO_CHECK="" # 空格分隔的未定义符号，用于在 termux_step_massaging 中检查
	TERMUX_PKG_FORCE_CMAKE=false # 如果包有 autotools 以及 cmake，则设置此项以首选 cmake
	TERMUX_PKG_GIT_BRANCH="" # 除非定义此变量，否则分支默认为 'v$TERMUX_PKG_VERSION'
	TERMUX_PKG_HAS_DEBUG=true # 如果调试版本不存在或不起作用，则设置为 false，例如对于基于 python 的包
	TERMUX_PKG_HOMEPAGE=""
	TERMUX_PKG_HOSTBUILD=false # 如果应该在 TERMUX_PKG_HOSTBUILD_DIR 中进行主机构建，则设置此项：
	TERMUX_PKG_HOSTBUILD_DIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/host-build
	TERMUX_PKG_LICENSE_FILE="" # 从 $TERMUX_PKG_SRCDIR 到 LICENSE 文件的相对路径。它安装在 $TERMUX_PREFIX/share/$TERMUX_PKG_NAME 中。
	TERMUX_PKG_MASSAGEDIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/massage
	TERMUX_PKG_METAPACKAGE=false
	TERMUX_PKG_NO_ELF_CLEANER=false # 设置为 true 以禁用在构建的二进制文件上运行 termux-elf-cleaner
	TERMUX_PKG_NO_REPLACE_GUESS_SCRIPTS=false # 如果为 true，则在源目录中不查找和替换 config.guess 和 config.sub
	TERMUX_PKG_NO_SHEBANG_FIX=false # 如果为 true，则跳过根据 TERMUX_PREFIX 修复 shebang
	TERMUX_PKG_NO_SHEBANG_FIX_FILES="" # 要从修复 shebang 中排除的文件
	TERMUX_PKG_NO_STRIP=false # 设置为 true 以禁用剥离二进制文件
	TERMUX_PKG_NO_STATICSPLIT=false
	TERMUX_PKG_STATICSPLIT_EXTRA_PATTERNS=""
	TERMUX_PKG_PACKAGEDIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/package
	TERMUX_PKG_PLATFORM_INDEPENDENT=false
	TERMUX_PKG_PRE_DEPENDS=""
	TERMUX_PKG_PROVIDES="" #https://www.debian.org/doc/debian-policy/#virtual-packages-provides
	TERMUX_PKG_RECOMMENDS="" # https://www.debian.org/doc/debian-policy/ch-relationships.html#s-binarydeps
	TERMUX_PKG_REPLACES=""
	TERMUX_PKG_REVISION="0" # http://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version
	TERMUX_PKG_RM_AFTER_INSTALL=""
	TERMUX_PKG_SHA256=""
	TERMUX_PKG_SRCDIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/src
	TERMUX_PKG_SUGGESTS=""
	TERMUX_PKG_TMPDIR=$TERMUX_TOPDIR/$TERMUX_PKG_NAME/tmp
	TERMUX_PKG_UNDEF_SYMBOLS_FILES="" # 维护者承认这些文件具有未定义的符号，不会导致包损坏，例如：all, *.elf, ./path/to/file。"error" 表示始终将结果打印为错误
	TERMUX_PKG_NO_OPENMP_CHECK=false # 如果为 true，则跳过 openmp 检查
	TERMUX_PKG_SERVICE_SCRIPT=() # 填充条目，如：（"daemon name" '要执行的脚本'）。脚本使用 -e 回显，因此可以包含 \n 以用于多行
	TERMUX_PKG_GROUPS="" # https://wiki.archlinux.org/title/Pacman#Installing_package_groups
	TERMUX_PKG_ON_DEVICE_BUILD_NOT_SUPPORTED=false # 如果包不支持在设备上编译，则不应在设备上编译此包
	TERMUX_PKG_SETUP_PYTHON=false # 设置 python 以编译包
	TERMUX_PYTHON_VERSION="$( # 获取 python 的最新版本
		if [[ "${TERMUX_PACKAGE_LIBRARY}" == "bionic" ]]; then
			. "$TERMUX_SCRIPTDIR/packages/python/build.sh"
		else # glibc
			. "$TERMUX_SCRIPTDIR/gpkg/python/build.sh"
		fi
		echo "$_MAJOR_VERSION"
	)"
	TERMUX_PKG_PYTHON_TARGET_DEPS="" # 要通过 pip3 安装的 python 模块
	TERMUX_PKG_PYTHON_CROSS_BUILD_DEPS="" # 要通过 build-pip 安装的 python 模块
	TERMUX_PKG_PYTHON_COMMON_BUILD_DEPS="" # 要通过 pip3 或 build-pip 安装的 python 模块
	TERMUX_PKG_PYTHON_RUNTIME_DEPS="" # 要在 debscriptps 中通过 pip3 安装的 python 模块
	TERMUX_PYTHON_CROSSENV_PREFIX="$TERMUX_TOPDIR/python${TERMUX_PYTHON_VERSION}-crossenv-prefix-$TERMUX_PACKAGE_LIBRARY-$TERMUX_ARCH" # python 模块依赖项位置（仅用于非设备）
	TERMUX_PYTHON_CROSSENV_BUILDHOME="$TERMUX_PYTHON_CROSSENV_PREFIX/build/lib/python${TERMUX_PYTHON_VERSION}"
	TERMUX_PYTHON_HOME=$TERMUX__PREFIX__LIB_DIR/python${TERMUX_PYTHON_VERSION} # python 库的位置
	TERMUX_LLVM_VERSION="$( # 获取 LLVM 的最新版本
		if [[ "${TERMUX_PACKAGE_LIBRARY}" == "bionic" ]]; then
			. "$TERMUX_SCRIPTDIR/packages/libllvm/build.sh"
		else # glibc
			. "$TERMUX_SCRIPTDIR/gpkg/llvm/build.sh"
		fi
		echo "$TERMUX_PKG_VERSION"
	)"
	TERMUX_LLVM_MAJOR_VERSION="${TERMUX_LLVM_VERSION%%.*}"
	TERMUX_LLVM_NEXT_MAJOR_VERSION="$((TERMUX_LLVM_MAJOR_VERSION + 1))"
	TERMUX_PKG_MESON_NATIVE=false
	TERMUX_PKG_CMAKE_CROSSCOMPILING=true
	TERMUX_PROOT_EXTRA_ENV_VARS="" # termux_setup_proot 中 proot 命令的额外环境变量

	unset CFLAGS CPPFLAGS LDFLAGS CXXFLAGS
	unset TERMUX_MESON_ENABLE_SOVERSION # setenv to enable SOVERSION suffix for shared libs built with Meson
}

# Setting architectural information according to the `TERMUX_ARCH` variable
termux_step_setup_arch_variables() {
	if [ "x86_64" = "$TERMUX_ARCH" ] || [ "aarch64" = "$TERMUX_ARCH" ]; then
		TERMUX_ARCH_BITS=64
	else
		TERMUX_ARCH_BITS=32
	fi

	if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ]; then
		TERMUX_HOST_PLATFORM="${TERMUX_ARCH}-linux-android"
	else
		TERMUX_HOST_PLATFORM="${TERMUX_ARCH}-linux-gnu"
	fi
	if [ "$TERMUX_ARCH" = "arm" ]; then
		TERMUX_HOST_PLATFORM="${TERMUX_HOST_PLATFORM}eabi"
		if [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
			TERMUX_HOST_PLATFORM="${TERMUX_HOST_PLATFORM}hf"
		fi
	fi
}
