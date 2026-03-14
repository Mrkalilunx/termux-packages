termux_step_handle_buildarch() {
	[ "$TERMUX_ON_DEVICE_BUILD" = "true" ] && return

	# 如果 $TERMUX_PREFIX 已经存在，它可能是为不同的架构构建的
	local TERMUX_ARCH_FILE=/data/TERMUX_ARCH
	if [ -f "${TERMUX_ARCH_FILE}" ]; then
		local TERMUX_PREVIOUS_ARCH
		TERMUX_PREVIOUS_ARCH=$(cat $TERMUX_ARCH_FILE)
		if [ "$TERMUX_PREVIOUS_ARCH" != "$TERMUX_ARCH" ]; then
			local TERMUX_DATA_BACKUPDIRS=$TERMUX_TOPDIR/_databackups
			mkdir -p "$TERMUX_DATA_BACKUPDIRS"
			local TERMUX_DATA_PREVIOUS_BACKUPDIR=$TERMUX_DATA_BACKUPDIRS/$TERMUX_PREVIOUS_ARCH
			local TERMUX_DATA_CURRENT_BACKUPDIR=$TERMUX_DATA_BACKUPDIRS/$TERMUX_ARCH
			# 保存当前 /data（如果有旧备份则删除）
			if test -e "$TERMUX_DATA_PREVIOUS_BACKUPDIR"; then
				termux_error_exit "Directory already exists"
			fi
			if [ -d /data/data ]; then
				mv /data/data "$TERMUX_DATA_PREVIOUS_BACKUPDIR"
				if [ -d "${TERMUX_DATA_PREVIOUS_BACKUPDIR}/${TERMUX_APP_PACKAGE}/cgct" ]; then
					mkdir -p "/data/data/${TERMUX_APP_PACKAGE}"
					mv "${TERMUX_DATA_PREVIOUS_BACKUPDIR}/${TERMUX_APP_PACKAGE}/cgct" "/data/data/${TERMUX_APP_PACKAGE}"
				fi
			fi
			# 恢复新的（如果有）
			if [ -d "$TERMUX_DATA_CURRENT_BACKUPDIR" ]; then
				mv "$TERMUX_DATA_CURRENT_BACKUPDIR" /data/data
			fi
		fi
	fi

	# 跟踪我们正在构建的当前架构。
	echo "$TERMUX_ARCH" > $TERMUX_ARCH_FILE
}
