termux_step_start_build() {
	# shellcheck source=/dev/null
	source "$TERMUX_PKG_BUILDER_SCRIPT"
	# 主机构建标记的路径，供包有主机构建步骤时使用
	TERMUX_HOSTBUILD_MARKER="$TERMUX_PKG_HOSTBUILD_DIR/TERMUX_BUILT_FOR_$TERMUX_PKG_VERSION"

	if [ "$TERMUX_PKG_METAPACKAGE" = "true" ]; then
		# 元包没有源代码
		TERMUX_PKG_SKIP_SRC_EXTRACT=true
		# 通常元包也是依赖于平台的，但当它们依赖于可能不适用于所有架构的包时，
		# 将它们标记为这样并不总是正确的决定
		# TERMUX_PKG_PLATFORM_INDEPENDENT=true
	fi

	if [ -n "${TERMUX_PKG_EXCLUDED_ARCHES:=""}" ] && [ "$TERMUX_PKG_EXCLUDED_ARCHES" != "${TERMUX_PKG_EXCLUDED_ARCHES/$TERMUX_ARCH/}" ]; then
		echo "跳过为架构 $TERMUX_ARCH 构建 $TERMUX_PKG_NAME"
		exit 0
	fi

	if [ -n "$TERMUX_PKG_PYTHON_COMMON_BUILD_DEPS" ] || [[ "$TERMUX_ON_DEVICE_BUILD" = "false" && -n "$TERMUX_PKG_PYTHON_CROSS_BUILD_DEPS" ]] || [[ "$TERMUX_ON_DEVICE_BUILD" = "true" && -n "$TERMUX_PKG_PYTHON_TARGET_DEPS" ]]; then
		# 启用 python 设置
		TERMUX_PKG_SETUP_PYTHON=true
	fi
	if [ -z "$TERMUX_PKG_PYTHON_RUNTIME_DEPS" ]; then
		TERMUX_PKG_PYTHON_RUNTIME_DEPS="$TERMUX_PKG_PYTHON_TARGET_DEPS"
	fi
	if [ "$TERMUX_PKG_PYTHON_RUNTIME_DEPS" = "false" ]; then
		TERMUX_PKG_PYTHON_RUNTIME_DEPS=""
	fi

	TERMUX_PKG_FULLVERSION=$TERMUX_PKG_VERSION
	if [ "$TERMUX_PKG_REVISION" != "0" ] || [ "$TERMUX_PKG_FULLVERSION" != "${TERMUX_PKG_FULLVERSION/-/}" ]; then
		# "0" 是默认修订版，因此仅当上游版本本身包含 "-" 时才包括它
		TERMUX_PKG_FULLVERSION+="-$TERMUX_PKG_REVISION"
	fi
	# pacman 的完整格式版本
	local TERMUX_PKG_VERSION_EDITED=${TERMUX_PKG_VERSION//-/.}
	local INCORRECT_SYMBOLS=$(echo $TERMUX_PKG_VERSION_EDITED | grep -o '[0-9][a-z]')
	if [ -n "$INCORRECT_SYMBOLS" ]; then
		local TERMUX_PKG_VERSION_EDITED=${TERMUX_PKG_VERSION_EDITED//${INCORRECT_SYMBOLS:0:1}${INCORRECT_SYMBOLS:1:1}/${INCORRECT_SYMBOLS:0:1}.${INCORRECT_SYMBOLS:1:1}}
	fi
	TERMUX_PKG_FULLVERSION_FOR_PACMAN="${TERMUX_PKG_VERSION_EDITED}"
	if [ -n "$TERMUX_PKG_REVISION" ]; then
		TERMUX_PKG_FULLVERSION_FOR_PACMAN+="-${TERMUX_PKG_REVISION}"
	else
		TERMUX_PKG_FULLVERSION_FOR_PACMAN+="-0"
	fi

	if [ "$TERMUX_DEBUG_BUILD" = "true" ]; then
		if [ "$TERMUX_PKG_HAS_DEBUG" = "true" ]; then
			DEBUG="-dbg"
		else
			echo "跳过为 $TERMUX_PKG_NAME 构建调试版本"
			exit 0
		fi
	else
		DEBUG=""
	fi

	if [ "$TERMUX_DEBUG_BUILD" = "false" ] && [ "$TERMUX_FORCE_BUILD" = "false" ]; then
		if [ -e "$TERMUX_BUILT_PACKAGES_DIRECTORY/$TERMUX_PKG_NAME" ] &&
			[ "$(cat "$TERMUX_BUILT_PACKAGES_DIRECTORY/$TERMUX_PKG_NAME")" = "$TERMUX_PKG_FULLVERSION" ]; then
			echo "$TERMUX_PKG_NAME@$TERMUX_PKG_FULLVERSION 已构建 - 跳过（rm $TERMUX_BUILT_PACKAGES_DIRECTORY/$TERMUX_PKG_NAME 以强制重新构建）"
			exit 0
		elif [ "$TERMUX_ON_DEVICE_BUILD" = "true" ] &&
			([[ "$TERMUX_APP_PACKAGE_MANAGER" = "apt" && "$(dpkg-query -W -f '${db:Status-Status} ${Version}\n' "$TERMUX_PKG_NAME" 2>/dev/null)" = "installed $TERMUX_PKG_FULLVERSION" ]] ||
			 [[ "$TERMUX_APP_PACKAGE_MANAGER" = "pacman" && "$(pacman -Q $TERMUX_PKG_NAME 2>/dev/null)" = "$TERMUX_PKG_NAME $TERMUX_PKG_FULLVERSION_FOR_PACMAN" ]]); then
			echo "$TERMUX_PKG_NAME@$TERMUX_PKG_FULLVERSION 已安装 - 跳过"
			exit 0
		fi
	fi

	if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ] || [ "$TERMUX_ARCH_BITS" = "32" ]; then
		TERMUX_PKG_BUILD_MULTILIB=false
	fi
	if [ "$TERMUX_PKG_BUILD_MULTILIB" = "true" ] && [ $(tr ' ' '\n' <<< "${TERMUX_PKG_EXCLUDED_ARCHES//,/}" | grep -c -e '^arm$' -e '^i686$') = "2" ]; then
		TERMUX_PKG_BUILD_ONLY_MULTILIB=true
	fi

	echo "termux - 正在为架构 $TERMUX_ARCH 构建 $TERMUX_PKG_NAME..."
	test -t 1 && printf "\033]0;%s...\007" "$TERMUX_PKG_NAME"

	# 在 termux_step_host_build 之前避免导出 PKG_CONFIG_LIBDIR。
	termux_step_setup_pkg_config_libdir

	local TERMUX_PKG_BUILDDIR_ORIG="$TERMUX_PKG_BUILDDIR"
	if [ "$TERMUX_PKG_BUILD_IN_SRC" = "true" ]; then
		TERMUX_PKG_BUILDDIR=$TERMUX_PKG_SRCDIR
	fi
	if [ "$TERMUX_PKG_BUILD_MULTILIB" = "true" ] && [ "$TERMUX_PKG_BUILD_ONLY_MULTILIB" = "false" ] && ([ "$TERMUX_PKG_BUILD_IN_SRC" = "true" ] || [ "$TERMUX_PKG_MULTILIB_BUILDDIR" = "$TERMUX_PKG_BUILDDIR" ]); then
		termux_error_exit "无法在一个地方构建包的 32 位和 64 位版本，构建位置必须分开。"
	fi

	if [ "$TERMUX_CONTINUE_BUILD" == "true" ]; then
		# 如果包有主机构建步骤，请验证它已构建
		if [ "$TERMUX_PKG_HOSTBUILD" == "true" ] && [ ! -f "$TERMUX_HOSTBUILD_MARKER" ]; then
			termux_error_exit "无法继续此构建，缺少主机构建的工具"
		fi

		# 为设备上继续构建设置 TERMUX_ELF_CLEANER
		if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ] && [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
			TERMUX_ELF_CLEANER="$(command -v termux-elf-cleaner)"
		fi
		# 在进行继续构建时，可以跳过此函数中的其余部分
		return
	fi

	if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ] && [ "$TERMUX_PKG_ON_DEVICE_BUILD_NOT_SUPPORTED" = "true" ]; then
		termux_error_exit "包 '$TERMUX_PKG_NAME' 不适用于设备上构建。"
	fi

	# 删除并重新创建用于构建包的目录
	termux_step_setup_build_folders

	if [ "$TERMUX_PKG_BUILD_IN_SRC" = "true" ]; then
		# 创建一个文件供用户知道不包含任何构建文件的构建目录是预期行为
		echo "由于 TERMUX_PKG_BUILD_IN_SRC 设置为 true，在 src 中构建" > "$TERMUX_PKG_BUILDDIR_ORIG/BUILDING_IN_SRC.txt"
	fi

	if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ]; then
		if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
			case "$TERMUX_APP_PACKAGE_MANAGER" in
				"apt") apt install -y termux-elf-cleaner;;
				"pacman") pacman -S termux-elf-cleaner --needed --noconfirm;;
			esac
			TERMUX_ELF_CLEANER="$(command -v termux-elf-cleaner)"
		else
			local TERMUX_ELF_CLEANER_VERSION
			TERMUX_ELF_CLEANER_VERSION=$(bash -c ". $TERMUX_SCRIPTDIR/packages/termux-elf-cleaner/build.sh; echo \$TERMUX_PKG_VERSION")
			termux_download \
				"https://github.com/termux/termux-elf-cleaner/releases/download/v${TERMUX_ELF_CLEANER_VERSION}/termux-elf-cleaner" \
				"$TERMUX_ELF_CLEANER" \
				59645fb25b84d11f108436e83d9df5e874ba4eb76ab62948869a23a3ee692fa7
			chmod u+x "$TERMUX_ELF_CLEANER"
		fi

		# 某些包搜索 libutil、libpthread 和 librt，即使
		# 此功能由 libc 提供。提供
		# 库存根，以便此类配置检查成功。
		mkdir -p "$TERMUX_PREFIX/lib"
		for lib in libutil.so libpthread.so librt.so; do
			if [ ! -f $TERMUX_PREFIX/lib/$lib ]; then
				echo 'INPUT(-lc)' > $TERMUX_PREFIX/lib/$lib
			fi
		done
	fi
}

termux_step_setup_pkg_config_libdir() {
	export TERMUX_PKG_CONFIG_LIBDIR=$TERMUX__PREFIX__LIB_DIR/pkgconfig:$TERMUX_PREFIX/share/pkgconfig
}
