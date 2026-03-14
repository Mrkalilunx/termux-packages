termux_step_create_timestamp_file() {
	# 跟踪构建开始的时间，以便我们可以看到创建了哪些文件。
	# 我们首先通过 sleep/touch 开始，以便任何生成的文件
	#（来自 termux_step_override_config_scripts() 的 $TERMUX_PREFIX/bin/llvm-config）
	# 获得比 TERMUX_BUILD_TS_FILE 更旧的时间戳。
	sleep 0.1
	TERMUX_BUILD_TS_FILE=$TERMUX_PKG_TMPDIR/timestamp_$TERMUX_PKG_NAME
	touch "$TERMUX_BUILD_TS_FILE"
}
