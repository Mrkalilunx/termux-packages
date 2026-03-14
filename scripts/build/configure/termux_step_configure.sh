termux_step_configure() {
	[ "$TERMUX_PKG_METAPACKAGE" = "true" ] && return

	# 此检查应该在 autotools 检查之上，因为 haskell 软件包也使用 configure 脚本，
	# 这些脚本应该由其自己的构建系统执行。
	if ls "${TERMUX_PKG_SRCDIR}"/*.cabal &>/dev/null || ls "${TERMUX_PKG_SRCDIR}"/cabal.project &>/dev/null; then
		[ "$TERMUX_CONTINUE_BUILD" == "true" ] && return
		termux_step_configure_cabal
	elif [ "$TERMUX_PKG_FORCE_CMAKE" = "false" ] && [ -f "$TERMUX_PKG_SRCDIR/configure" ]; then
		if [ "$TERMUX_CONTINUE_BUILD" == "true" ]; then
			return
		fi
		termux_step_configure_autotools
	elif [ "$TERMUX_PKG_FORCE_CMAKE" = "true" ] || [ -f "$TERMUX_PKG_SRCDIR/CMakeLists.txt" ]; then
		termux_setup_cmake
		if [ "$TERMUX_PKG_CMAKE_BUILD" = Ninja ]; then
			termux_setup_ninja
		fi

		# 某些软件包（例如 swift）在内部使用 cmake，
		# 但无法通过我们的 termux_step_configure_cmake 函数进行配置
		#（CMakeLists.txt 不在 src 目录中）
		if [ -f "$TERMUX_PKG_SRCDIR/CMakeLists.txt" ] &&
			[ "$TERMUX_CONTINUE_BUILD" == "false" ]; then
			termux_step_configure_cmake
		fi
	elif [ -f "$TERMUX_PKG_SRCDIR/meson.build" ]; then
		if [ "$TERMUX_CONTINUE_BUILD" == "true" ]; then
			return
		fi
		termux_step_configure_meson
	fi
}

termux_step_configure_multilib() {
	termux_step_configure
}
