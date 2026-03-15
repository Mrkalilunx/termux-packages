termux_step_configure_autotools() {
	if [ ! -e "$TERMUX_PKG_SRCDIR/configure" ]; then return; fi

	local ENABLE_STATIC="--enable-static"
	if [ "$TERMUX_PKG_EXTRA_CONFIGURE_ARGS" != "${TERMUX_PKG_EXTRA_CONFIGURE_ARGS/--disable-static/}" ]; then
		ENABLE_STATIC=""
	fi

	local DISABLE_NLS=""
	if [ "$TERMUX_PKG_EXTRA_CONFIGURE_ARGS" != "${TERMUX_PKG_EXTRA_CONFIGURE_ARGS/--disable-nls/}" ]; then
		# 如果软件包明确禁用了 nls，则禁用它
		DISABLE_NLS="--disable-nls"
	fi

	local ENABLE_SHARED="--enable-shared"
	if [ "$TERMUX_PKG_EXTRA_CONFIGURE_ARGS" != "${TERMUX_PKG_EXTRA_CONFIGURE_ARGS/--disable-shared/}" ]; then
		ENABLE_SHARED=""
	fi

	local HOST_FLAG="--host=$TERMUX_HOST_PLATFORM"
	if [ "$TERMUX_PKG_EXTRA_CONFIGURE_ARGS" != "${TERMUX_PKG_EXTRA_CONFIGURE_ARGS/--host=/}" ]; then
		HOST_FLAG=""
	fi

	local LIBEXEC_FLAG="--libexecdir=$TERMUX_PREFIX/libexec"
	if [ "$TERMUX_PKG_EXTRA_CONFIGURE_ARGS" != "${TERMUX_PKG_EXTRA_CONFIGURE_ARGS/--libexecdir=/}" ]; then
		LIBEXEC_FLAG=""
	fi

	local QUIET_BUILD=
	if [ "$TERMUX_QUIET_BUILD" = true ]; then
		QUIET_BUILD="--enable-silent-rules --silent --quiet"
	fi

	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ] && [ ! -d "$TERMUX_PKG_TMPDIR/config-scripts" ]; then
		# 某些软件包提供 $PKG-config 脚本，某些 configure 脚本会使用它而不是 pkg-config：
		mkdir "$TERMUX_PKG_TMPDIR/config-scripts"
		for f in $TERMUX_PREFIX/bin/*config; do
			if [[ -f "$f" && "$(head -c 4 "$f")" != "$(echo -ne '\0177ELF')" ]]; then
				cp "$f" "$TERMUX_PKG_TMPDIR/config-scripts"
			fi
		done
		export PATH=$TERMUX_PKG_TMPDIR/config-scripts:$PATH
	fi

	# 交叉编译时避免 gnulib 包装函数。参见
	# http://wiki.osdev.org/Cross-Porting_Software#Gnulib
	# https://gitlab.com/sortix/sortix/wikis/Gnulib
	# https://github.com/termux/termux-packages/issues/76
	local AVOID_GNULIB=""
	AVOID_GNULIB+=" ac_cv_func_nl_langinfo=yes"
	AVOID_GNULIB+=" ac_cv_func_calloc_0_nonnull=yes"
	AVOID_GNULIB+=" ac_cv_func_chown_works=yes"
	AVOID_GNULIB+=" ac_cv_func_getgroups_works=yes"
	AVOID_GNULIB+=" ac_cv_func_malloc_0_nonnull=yes"
	AVOID_GNULIB+=" ac_cv_func_posix_spawn=no"
	AVOID_GNULIB+=" ac_cv_func_posix_spawnp=no"
	AVOID_GNULIB+=" ac_cv_func_realloc_0_nonnull=yes"
	AVOID_GNULIB+=" am_cv_func_working_getline=yes"
	AVOID_GNULIB+=" gl_cv_func_dup2_works=yes"
	AVOID_GNULIB+=" gl_cv_func_fcntl_f_dupfd_cloexec=yes"
	AVOID_GNULIB+=" gl_cv_func_fcntl_f_dupfd_works=yes"
	AVOID_GNULIB+=" gl_cv_func_fnmatch_posix=yes"
	AVOID_GNULIB+=" gl_cv_func_getcwd_abort_bug=no"
	AVOID_GNULIB+=" gl_cv_func_getcwd_null=yes"
	AVOID_GNULIB+=" gl_cv_func_getcwd_path_max=yes"
	AVOID_GNULIB+=" gl_cv_func_getcwd_posix_signature=yes"
	AVOID_GNULIB+=" gl_cv_func_gettimeofday_clobber=no"
	AVOID_GNULIB+=" gl_cv_func_gettimeofday_posix_signature=yes"
	AVOID_GNULIB+=" gl_cv_func_link_works=yes"
	AVOID_GNULIB+=" gl_cv_func_lstat_dereferences_slashed_symlink=yes"
	AVOID_GNULIB+=" gl_cv_func_malloc_0_nonnull=yes"
	AVOID_GNULIB+=" gl_cv_func_memchr_works=yes"
	AVOID_GNULIB+=" gl_cv_func_mkdir_trailing_dot_works=yes"
	AVOID_GNULIB+=" gl_cv_func_mkdir_trailing_slash_works=yes"
	AVOID_GNULIB+=" gl_cv_func_mkfifo_works=yes"
	AVOID_GNULIB+=" gl_cv_func_mknod_works=yes"
	AVOID_GNULIB+=" gl_cv_func_realpath_works=yes"
	AVOID_GNULIB+=" gl_cv_func_select_detects_ebadf=yes"
	AVOID_GNULIB+=" gl_cv_func_snprintf_posix=yes"
	AVOID_GNULIB+=" gl_cv_func_snprintf_retval_c99=yes"
	AVOID_GNULIB+=" gl_cv_func_snprintf_truncation_c99=yes"
	AVOID_GNULIB+=" gl_cv_func_stat_dir_slash=yes"
	AVOID_GNULIB+=" gl_cv_func_stat_file_slash=yes"
	AVOID_GNULIB+=" gl_cv_func_strerror_0_works=yes"
	AVOID_GNULIB+=" gl_cv_func_strtold_works=yes"
	AVOID_GNULIB+=" gl_cv_func_symlink_works=yes"
	AVOID_GNULIB+=" gl_cv_func_tzset_clobber=no"
	AVOID_GNULIB+=" gl_cv_func_unlink_honors_slashes=yes"
	AVOID_GNULIB+=" gl_cv_func_unlink_honors_slashes=yes"
	AVOID_GNULIB+=" gl_cv_func_vsnprintf_posix=yes"
	AVOID_GNULIB+=" gl_cv_func_vsnprintf_zerosize_c99=yes"
	AVOID_GNULIB+=" gl_cv_func_wcrtomb_works=yes"
	AVOID_GNULIB+=" gl_cv_func_wcwidth_works=yes"
	AVOID_GNULIB+=" gl_cv_func_working_getdelim=yes"
	AVOID_GNULIB+=" gl_cv_func_working_mkstemp=yes"
	AVOID_GNULIB+=" gl_cv_func_working_mktime=yes"
	AVOID_GNULIB+=" gl_cv_func_working_strerror=yes"
	AVOID_GNULIB+=" gl_cv_header_working_fcntl_h=yes"
	AVOID_GNULIB+=" gl_cv_C_locale_sans_EILSEQ=yes"

	# 注意：我们不希望对 AVOID_GNULIB 加引号，因为我们需要单词扩展。
	# shellcheck disable=SC2086
	env $AVOID_GNULIB "$TERMUX_PKG_SRCDIR/configure" \
		--disable-dependency-tracking \
		--prefix="$TERMUX_PREFIX" \
		--libdir="$TERMUX__PREFIX__LIB_DIR" \
		--includedir="$TERMUX__PREFIX__INCLUDE_DIR" \
		--sbindir="$TERMUX_PREFIX/bin" \
		--disable-rpath --disable-rpath-hack \
		$HOST_FLAG \
		$TERMUX_PKG_EXTRA_CONFIGURE_ARGS \
		$DISABLE_NLS \
		$ENABLE_SHARED \
		$ENABLE_STATIC \
		$LIBEXEC_FLAG \
		$QUIET_BUILD \
		|| (termux_step_configure_autotools_failure_hook && false)
}

termux_step_configure_autotools_failure_hook() {
	false
}
