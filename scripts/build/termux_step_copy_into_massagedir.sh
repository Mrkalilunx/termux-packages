termux_step_copy_into_massagedir() {
	local DEST="$TERMUX_PKG_MASSAGEDIR/$TERMUX_PREFIX_CLASSICAL"
	mkdir -p "$DEST"
	# 将构建期间更改的文件复制到 massagedir 以便处理它们
	tar -C "$TERMUX_PREFIX_CLASSICAL" -N "$TERMUX_BUILD_TS_FILE" --exclude='tmp' --exclude='__pycache__' -cf - . | \
		tar -C "$DEST" -xf -
}
