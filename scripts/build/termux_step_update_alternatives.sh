# shellcheck shell=bash

# Debian `.alternatives` 格式是一个简单的临时纯文本格式，
# 用于声明性地定义 `update-alternatives` 的组。
# 此函数解析这种格式的文件并以关联数组形式返回其内容：
# ${LINK[@]} ${[ALTERNATIVE@]} ${DEPENDENTS[@]} ${PRIORITY[@]}
termux_parse_alternatives() {
	local line key value
	local dependents=0
	while IFS=$'\n' read -r line; do

		key="${line%%:*}" # Part before the first ':'
		value="${line#*:[[:blank:]]*}" # Part after the first `:`, leading whitespace stripped

		case "$key" in
			'Name') NAME+=("$value") dependents=0 ;;
			'Link')               LINK[${NAME[-1]}]="$value" dependents=0 ;;
			'Alternative') ALTERNATIVE[${NAME[-1]}]="$value" dependents=0 ;;
			'Priority')       PRIORITY[${NAME[-1]}]="$value" dependents=0 ;;
			'Dependents') dependents=1; continue;;
		esac

		if (( dependents )); then
			read -r dep_link dep_name dep_alternative <<< "$line"
			DEPENDENTS[${NAME[-1]}]+="      --slave \"${TERMUX_PREFIX}/${dep_link}\" \"${dep_name}\" \"${TERMUX_PREFIX}/${dep_alternative}\""$' \\\n'
		fi

	done < <(sed -e 's|\s*#.*$||g' "$1") # Strip out any comments
}

termux_step_update_alternatives() {
	printf '%s\n' "INFO: Processing 'update-alternatives' entries:" 1>&2
	for alternatives_file in "${TERMUX_PKG_BUILDER_DIR}"/*.alternatives; do
		[[ -f "$alternatives_file" ]] || continue
		local -a NAME=()
		local -A DEPENDENTS=() LINK=() ALTERNATIVE=() PRIORITY=()
		termux_parse_alternatives "$alternatives_file"

		# 处理 postinst 脚本
		[[ -f postinst ]] && mv postinst{,.orig}

		local name
		for name in "${NAME[@]}"; do
			# 并非每个条目在其组中都有依赖项，
			# 但无论如何我们需要初始化键
			: "${DEPENDENTS[$name]:=}"
		done

		{ # Splice in the alternatives
		# Use the original shebang if there's a 'postinst.orig'
		[[ -f postinst.orig ]] && head -n1 postinst.orig || echo "#!${TERMUX_PREFIX}/bin/sh"
		# Boilerplate header comment and checks
		echo "# Automatically added by termux_step_update_alternatives"
		echo "if [ \"\$1\" = 'configure' ] || [ \"\$1\" = 'abort-upgrade' ] || [ \"\$1\" = 'abort-deconfigure' ] || [ \"\$1\" = 'abort-remove' ] || [ \"${TERMUX_PACKAGE_FORMAT}\" = 'pacman' ]; then"
		echo "  if [ -x \"${TERMUX_PREFIX}/bin/update-alternatives\" ]; then"
		# 'update-alternatives' command for each group
		for name in "${NAME[@]}"; do
			# Main alternative group
			printf '%b' \
				"    # ${name}\n" \
				"    update-alternatives" $' \\\n' \
				"      --install \"${TERMUX_PREFIX}/${LINK[$name]}\" \"${name}\" \"${TERMUX_PREFIX}/${ALTERNATIVE[$name]}\" ${PRIORITY[$name]}"
			# If we have dependents, add those as well
			if [[ -n "${DEPENDENTS[$name]}" ]]; then
				# We need to add a ' \<lf>' to the --install line,
				# and remove the last ' \<lf>' from the dependents.
				printf ' \\\n%s' "${DEPENDENTS[$name]%$' \\\n'}"
			fi
			echo ""
		done
		# 关闭样板并添加结束注释
		echo "  fi"
		echo "fi"
		echo "# End automatically added section"
		} > postinst
		if [[ -f postinst.orig ]]; then
			tail -n+2 postinst.orig >> postinst
			rm postinst.orig
		fi

		# 处理 prerm 脚本
		[[ -f prerm  ]] && mv prerm{,.orig}

		{ # 插入替代方案
		# 如果有 'prerm.orig'，则使用原始的 shebang
		[[ -f prerm.orig ]] && head -n1 prerm.orig || echo "#!${TERMUX_PREFIX}/bin/sh"
		# 样板页眉注释和检查
		echo "# Automatically added by termux_step_update_alternatives"
		echo "if [ \"\$1\" = 'remove' ] || [ \"\$1\" != 'upgrade' ] || [ \"${TERMUX_PACKAGE_FORMAT}\" = 'pacman' ]; then"
		echo "  if [ -x \"${TERMUX_PREFIX}/bin/update-alternatives\" ]; then"
		# 删除每个组
		for name in "${NAME[@]}"; do
			# 此替代组的日志消息
			printf 'INFO: %s\n' "${name} -> ${ALTERNATIVE[$name]} (${PRIORITY[$name]})" 1>&2
			# 删除行
			printf '%s\n' "    update-alternatives --remove \"${name}\" \"${TERMUX_PREFIX}/${ALTERNATIVE[$name]}\""
		done
		# 关闭样板并添加结束注释
		echo "  fi"
		echo "fi"
		echo "# End automatically added section"
		} > prerm
		if [[ -f prerm.orig ]]; then
			tail -n+2 prerm.orig >> prerm
			rm prerm.orig
		fi
	done
}
