termux_step_install_service_scripts() {
	array_length=${#TERMUX_PKG_SERVICE_SCRIPT[@]}
	if [ $array_length -eq 0 ]; then return; fi

	# TERMUX_PKG_SERVICE_SCRIPT 应该具有结构 =("daemon name" 'script to execute')
	if [ $(( $array_length & 1 )) -eq 1 ]; then
		termux_error_exit "TERMUX_PKG_SERVICE_SCRIPT has to be an array of even length"
	fi

	mkdir -p $TERMUX_PREFIX/var/service
	cd $TERMUX_PREFIX/var/service
	for ((i=0; i<${array_length}; i+=2)); do
		mkdir -p ${TERMUX_PKG_SERVICE_SCRIPT[$i]}
		# 如果 ${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run 存在，则取消链接，
		# 以允许通过 TERMUX_PKG_SERVICE_SCRIPT 覆盖它
		if [ -L "${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run" ]; then
			unlink "${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run"
		fi
		echo "#!$TERMUX_PREFIX/bin/sh" > ${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run
		echo -e ${TERMUX_PKG_SERVICE_SCRIPT[$((i + 1))]} >> ${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run

		# 如果服务脚本已存在于 CONFFILES 中，则不要添加它
		if [[ $TERMUX_PKG_CONFFILES != *${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run* ]]; then
			TERMUX_PKG_CONFFILES+=" var/service/${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run"
		fi

		chmod +x ${TERMUX_PKG_SERVICE_SCRIPT[$i]}/run

		# 避免创建 service/<service>/log/log/
		if [ "${TERMUX_PKG_SERVICE_SCRIPT[$i]: -4}" != "/log" ]; then
			touch ${TERMUX_PKG_SERVICE_SCRIPT[$i]}/down
			TERMUX_PKG_CONFFILES+=" var/service/${TERMUX_PKG_SERVICE_SCRIPT[$i]}/down"
			local _log_run=${TERMUX_PKG_SERVICE_SCRIPT[$i]}/log/run
			rm -rf "${_log_run}"
			mkdir -p "$(dirname "${_log_run}")"
			cat <<-EOF > "${_log_run}"
				#!$TERMUX_PREFIX/bin/sh
				svlogger="$TERMUX_PREFIX/share/termux-services/svlogger"
				exec "\${svlogger}" "\$@"
			EOF
			chmod 0700 "${_log_run}"

			TERMUX_PKG_CONFFILES+="
			var/service/${TERMUX_PKG_SERVICE_SCRIPT[$i]}/log/run
			var/service/${TERMUX_PKG_SERVICE_SCRIPT[$i]}/log/down
			"
		fi
	done
}
