# shellcheck disable=SC2031 # this warning is triggering erroneously because of the `$(. pkg/build.sh; echo "$var")`
termux_step_override_config_scripts() {
	if [[ "$TERMUX_ON_DEVICE_BUILD" = true || "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]]; then
		return
	fi

	# 使 $TERMUX_PREFIX/bin/sh 在构建器上可执行，以便构建脚本可以假设它在构建器和主机上都能工作：
	ln -sf /bin/sh "$TERMUX_PREFIX/bin/sh"

	# 此包或其构建是否依赖于 'libllvm'？
	if [[ "$TERMUX_PKG_DEPENDS" != "${TERMUX_PKG_DEPENDS/libllvm/}" ||
		"$TERMUX_PKG_BUILD_DEPENDS" != "${TERMUX_PKG_BUILD_DEPENDS/libllvm/}" ]]; then
		LLVM_DEFAULT_TARGET_TRIPLE="$TERMUX_HOST_PLATFORM"
		case "$TERMUX_ARCH" in
			"arm") LLVM_TARGET_ARCH=ARM;;
			"aarch64") LLVM_TARGET_ARCH=AArch64;;
			"i686") LLVM_TARGET_ARCH=X86;;
			"x86_64") LLVM_TARGET_ARCH=X86;;
		esac

		sed "$TERMUX_SCRIPTDIR/packages/libllvm/llvm-config.in" \
			-e "s|@TERMUX_PKG_VERSION@|$TERMUX_LLVM_VERSION|g" \
			-e "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" \
			-e "s|@LLVM_TARGET_ARCH@|$LLVM_TARGET_ARCH|g" \
			-e "s|@LLVM_DEFAULT_TARGET_TRIPLE@|$LLVM_DEFAULT_TARGET_TRIPLE|g" \
			-e "s|@TERMUX_ARCH@|$TERMUX_ARCH|g" \
			> "$TERMUX_PREFIX/bin/llvm-config"
		chmod 755 "$TERMUX_PREFIX/bin/llvm-config"
	fi

	# 此包或其构建是否依赖于 'postgresql'？
	if [[ "$TERMUX_PKG_DEPENDS" != "${TERMUX_PKG_DEPENDS/postgresql/}" ||
		"$TERMUX_PKG_BUILD_DEPENDS" != "${TERMUX_PKG_BUILD_DEPENDS/postgresql/}" ]]; then
		local postgresql_version
		postgresql_version="$(. "$TERMUX_SCRIPTDIR/packages/postgresql/build.sh"; echo "$TERMUX_PKG_VERSION")"
		sed "$TERMUX_SCRIPTDIR/packages/postgresql/pg_config.in" \
			-e "s|@POSTGRESQL_VERSION@|$postgresql_version|g" \
			-e "s|@TERMUX_HOST_PLATFORM@|$TERMUX_HOST_PLATFORM|g" \
			-e "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" \
			> "$TERMUX_PREFIX/bin/pg_config"
		chmod 755 "$TERMUX_PREFIX/bin/pg_config"
	fi

	# 此包或其构建是否依赖于 'aosp-libs' 或 'aosp-utils'？
	# 如果是这样，则完成从 /system 到 $TERMUX_PREFIX/opt/aosp 的符号链接链，
	# 否则中断符号链接 /system，以防止使用纯传统 Autotools 交叉编译的包
	#（如 guile）的 i686 和 x86_64 构建出现
	# "checking whether we are cross compiling... no"
	# 后跟
	# "configure: error: No iconv support.  Please recompile libunistring with iconv enabled."
	# 如果 Autotools 交叉编译临时 conftest 二进制文件由于存在
	# /system/lib(64)/libc.so 和 /system/bin/linker(64) 而设法在 Ubuntu 中运行，
	# 而这些文件仅用于具有 'aosp-libs' 构建依赖项的包。
	# 有关更多信息，请参见 scripts/setup-ubuntu.sh 和 scripts/build/setup/termux_setup_proot.sh。
	rm -f "$TERMUX_APP__DATA_DIR/aosp"
	case "$TERMUX_PKG_DEPENDS $TERMUX_PKG_BUILD_DEPENDS" in
		*aosp-libs*|*aosp-utils*)
			ln -sf "$TERMUX_PREFIX/opt/aosp" "$TERMUX_APP__DATA_DIR/aosp"
		;;
	esac
}
