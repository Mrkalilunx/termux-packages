termux_step_setup_build_folders() {
	# 以下目录可能包含具有只读权限的文件，
	# 这使它们不可删除。我们需要修复
	# 那些文件。
	[ -d "$TERMUX_PKG_BUILDDIR" ] && chmod +w -R "$TERMUX_PKG_BUILDDIR" || true
	[ -d "$TERMUX_PKG_MULTILIB_BUILDDIR" ] && chmod +w -R "$TERMUX_PKG_MULTILIB_BUILDDIR" || true
	[ -d "$TERMUX_PKG_SRCDIR" ] && chmod +w -R "$TERMUX_PKG_SRCDIR" || true
	if [ "$TERMUX_SKIP_DEPCHECK" = false ] && \
		   [ "$TERMUX_INSTALL_DEPS" = true ] && \
		   [ "$TERMUX_PKG_METAPACKAGE" = false ] && \
		   [ "$TERMUX_PKGS__BUILD__RM_ALL_PKGS_BUILT_MARKER_AND_INSTALL_FILES" = true ] && \
		   [ "$TERMUX_ON_DEVICE_BUILD" = false ]; then
		# 从 $TERMUX_PREFIX 中删除所有先前提取/构建的文件：
		rm -fr "$TERMUX_PREFIX_CLASSICAL"
		rm -f "$TERMUX_BUILT_PACKAGES_DIRECTORY"/*
	fi

	# 清理旧的构建状态：
	rm -Rf "$TERMUX_PKG_BUILDDIR" \
		"$TERMUX_PKG_MULTILIB_BUILDDIR" \
		"$TERMUX_PKG_SRCDIR"

	# 清理旧的打包状态：
	rm -Rf "$TERMUX_PKG_PACKAGEDIR" \
		"$TERMUX_PKG_TMPDIR" \
		"$TERMUX_PKG_MASSAGEDIR"

	# 清理包含包源代码和主机构建目录的缓存目录
	if [ "$TERMUX_FORCE_BUILD" = true ] && \
			[ "$TERMUX_PKGS__BUILD__RM_ALL_PKG_BUILD_DEPENDENT_DIRS" = true ]; then
		rm -Rf "$TERMUX_PKG_CACHEDIR" "$TERMUX_PKG_HOSTBUILD_DIR"
	fi

	# 创建所需的目录，但不创建 `TERMUX_PKG_SRCDIR`，因为它
	# 将在构建期间创建。如果创建了 `TERMUX_PKG_SRCDIR`，
	# 那么 `TERMUX_PKG_SRCURL`（如 `zip` 的）将在
	# `termux_extract_src_archive()` 中提取到子目录。
	# 如果 `TERMUX_PKG_BUILD_IN_SRC` 为 `true`，则 `TERMUX_PKG_BUILDDIR`
	# 将等于 `TERMUX_PKG_SRCDIR`，因此在这种情况下不要创建它。
	if [ "$TERMUX_PKG_BUILDDIR" != "$TERMUX_PKG_SRCDIR" ]; then
		mkdir -p "$TERMUX_PKG_BUILDDIR"
	fi
	mkdir -p "$TERMUX_COMMON_CACHEDIR" \
		 "$TERMUX_COMMON_CACHEDIR-$TERMUX_ARCH" \
		 "$TERMUX_COMMON_CACHEDIR-all" \
		 "$TERMUX_OUTPUT_DIR" \
		 "$TERMUX_PKG_PACKAGEDIR" \
			"$TERMUX_PKG_TMPDIR" \
			"$TERMUX_PKG_CACHEDIR" \
			"$TERMUX_PKG_MASSAGEDIR"
	if [ "$TERMUX_PKG_BUILD_MULTILIB" = "true" ] && [ "$TERMUX_PKG_BUILD_ONLY_MULTILIB" = "false" ]; then
		mkdir -p "$TERMUX_PKG_MULTILIB_BUILDDIR"
	fi
	if [ "$TERMUX_PACKAGE_LIBRARY" = "bionic" ]; then
		mkdir -p $TERMUX_PREFIX/{bin,etc,lib,libexec,share,share/LICENSES,tmp,include}
	elif [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
		mkdir -p "$TERMUX_PREFIX"/{bin,etc,lib,share,share/LICENSES,include}
		mkdir -p "$TERMUX_PREFIX_CLASSICAL"/{bin,etc,tmp}
	fi

	# 需要在 termux_step_start_build 中创建 `BUILDING_IN_SRC.txt` 文件
	if [ "$TERMUX_PKG_BUILDDIR_ORIG" != "$TERMUX_PKG_BUILDDIR" ]; then
		rm -Rf "$TERMUX_PKG_BUILDDIR_ORIG"
		mkdir -p "$TERMUX_PKG_BUILDDIR_ORIG"
	fi
}
