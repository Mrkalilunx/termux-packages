termux_step_create_python_debscripts() {
	if [[ -n "${SUB_PKG_NAME-}" ]]; then
		local _package_name="$SUB_PKG_NAME"
		local _package_python_home="$SUB_PKG_DIR/massage$TERMUX_PREFIX/lib/python$TERMUX_PYTHON_VERSION"
		local _package_python_deps="${TERMUX_SUBPKG_PYTHON_RUNTIME_DEPS//, / }"
	else
		local _package_name="$TERMUX_PKG_NAME"
		local _package_python_home="$TERMUX_PKG_MASSAGEDIR$TERMUX_PREFIX/lib/python$TERMUX_PYTHON_VERSION"
		local _package_python_deps="${TERMUX_PKG_PYTHON_RUNTIME_DEPS//, / }"
	fi

	local py_file_in_lib_python="" pip_metadata_file=""

	# 如果包在 $TERMUX_PREFIX/lib/python$TERMUX_PYTHON_VERSION 中不包含任何 .py 文件，
	# 那么对于此包，debpython（py3compile 和 py3clean）是不必要的或当前不支持
	if [[ -d "$_package_python_home" ]]; then
		py_file_in_lib_python="$(find "$_package_python_home" -name "*.py" -print -quit)"
	fi

	# 至少某些包拥有的元数据文件，其中包含包的 'pip' 面向名称及其任何 PyPi 依赖项。
	if [[ -d "$_package_python_home/site-packages" ]]; then
		pip_metadata_file="$(find "$_package_python_home/site-packages" -name "METADATA" -print -quit)"
	fi

	# 如果包的内部 'pip' 面向名称存在于 'METADATA' 文件中，并且 'METADATA' 文件也将包标记为依赖于
	# 任何其他 'pip' 面向包，则将其添加到 'pip install' 依赖项，这将安装软件标记为从 PyPi 依赖的
	# 所有 'pip' 面向依赖项，而这些依赖项尚未从其他 Termux 包安装。
	# 如果检测到多个 'METADATA' 文件，则此条件将评估为 false，因此不会发生任何事情。
	if [[ -f "$pip_metadata_file" ]] && grep -q '^Requires-Dist' "$pip_metadata_file"; then
		local package_pip_name="$(grep 'Name:' "$pip_metadata_file" | cut -d' ' -f2)"
		_package_python_deps+=" $package_pip_name"
	fi

	# 如果 $TERMUX_PREFIX/lib/python$TERMUX_PYTHON_VERSION/ 中没有 .py 文件，
	# 并且包具有空的 $_package_python_deps，则此函数不需要执行任何操作
	if [[ -z "$py_file_in_lib_python" ]] && [[ -z "${_package_python_deps}" ]]; then
		return
	fi

	# 如果 postinst 脚本不存在，则创建一个新的
	# 但如果 postinst 脚本已存在并且最后一行是 'exit 0'，
	# 则删除该行，以防止执行其他命令
	if [[ ! -f postinst ]]; then
		echo "#!${TERMUX_PREFIX_CLASSICAL}/bin/sh" >postinst
		chmod 0755 postinst
	elif tail -n1 postinst | grep -q 'exit 0'; then
		sed -i '$d' postinst
	fi

	# 如果包格式是 .deb，则仅在配置包（而非失败）时运行脚本
	if [[ "$TERMUX_PACKAGE_FORMAT" == "debian" ]]; then
		cat <<-POSTINST_EOF >>postinst
			if [ "\$1" != "configure" ]; then
				exit 0
			fi
		POSTINST_EOF
	fi

	# 如果包具有需要 pip 的运行时依赖项，
	# 则使此脚本安装它们
	if [[ -n "${_package_python_deps}" ]]; then
		local pip_package_name="python-pip" upgrade_flag="--upgrade"

		if [[ "$TERMUX_PACKAGE_LIBRARY" == "glibc" ]]; then
			pip_package_name+="-glibc"
		fi

		# 如果要从 PyPi 安装的依赖项列表包含当前包的名称（其中任何 'python-' 前缀都被剥离），
		# 则不要对 pip 使用 '--upgrade' 参数，以避免用同名但不同的软件或
		# 来自 PyPi 的错误版本的同名软件覆盖非 PyPi 本地包文件。
		# 这对于 'nala' 包尤为重要。
		if [[ " $(tr ' ' '\n' <<<"${_package_python_deps}" | sed "s/'//g; s/</ /g; s/>/ /g; s/=/ /g" | awk '{printf $1 " "}')" =~ " ${_package_name//python-/} " ]]; then
			upgrade_flag=""
		fi

		cat <<-POSTINST_EOF >>postinst
			echo "Installing dependencies for ${_package_name} through pip..."
			LD_PRELOAD='' LDFLAGS="-lpython$TERMUX_PYTHON_VERSION" MATHLIB="m" "${TERMUX_PREFIX}/bin/pip3" install ${upgrade_flag} ${_package_python_deps}
		POSTINST_EOF

		# 确保将 pip 添加为所有在安装期间运行 'pip' 命令的包的依赖项。
		if ([[ "$TERMUX_PACKAGE_FORMAT" == "debian" ]] && ! grep -q -E "Depends.*$pip_package_name(,|$)" control) || ([[ "$TERMUX_PACKAGE_FORMAT" == "pacman" ]] && ! grep -q "depend = $pip_package_name" .PKGINFO); then
			termux_error_exit "'$_package_name' must depend on '$pip_package_name' because it needs to run 'pip' during installation!"
		fi
	fi

	# 如果包在 $TERMUX_PREFIX/lib/python$TERMUX_PYTHON_VERSION 中不包含任何 .py 文件，
	# 则此函数不需要执行其他任何操作
	if [[ -z "$py_file_in_lib_python" ]]; then
		return
	fi

	# 生成 *.pyc 文件的 post-inst 脚本
	cat <<-POSTINST_EOF >>postinst
		if [ -f "${TERMUX_PREFIX}/bin/py3compile" ]; then
			LD_PRELOAD='' "${TERMUX_PREFIX}/bin/py3compile" -p "$_package_name" "${TERMUX_PREFIX}/lib/python${TERMUX_PYTHON_VERSION}/"
		fi
	POSTINST_EOF

	# 使 postinst 脚本的最后一条命令为 'exit 0'
	# 因为如果上一个最后一条命令是条件，并且条件失败，
	# 则 postinst 脚本可能会失败，而这实际上不是期望的结果
	cat <<-POSTINST_EOF >>postinst
		exit 0
	POSTINST_EOF

	# 如果 prerm 脚本不存在，则创建一个新的
	# 但如果 prerm 脚本已存在并且最后一行是 'exit 0'，
	# 则删除该行，以防止执行其他命令
	if [[ ! -f prerm ]]; then
		echo "#!${TERMUX_PREFIX_CLASSICAL}/bin/sh" >prerm
		chmod 0755 prerm
	elif tail -n1 prerm | grep -q 'exit 0'; then
		sed -i '$d' prerm
	fi

	# 如果包格式是 .deb，则仅在删除包（而非失败）时运行脚本
	if [[ "$TERMUX_PACKAGE_FORMAT" == "debian" ]]; then
		cat <<-PRERM_EOF >>prerm
			if [ "\$1" != "remove" ]; then
				exit 0
			fi
		PRERM_EOF
	fi

	# 清理运行时生成的文件的 pre-rm 脚本。
	cat <<-PRERM_EOF >>prerm
		if [ -f "${TERMUX_PREFIX}/bin/py3clean" ]; then
			LD_PRELOAD='' "${TERMUX_PREFIX}/bin/py3clean" -p "$_package_name"
		fi
	PRERM_EOF

	# 使 prerm 脚本的最后一条命令为 'exit 0'
	# 因为如果上一个最后一条命令是条件，并且条件失败，
	# 则 prerm 脚本可能会失败，而这实际上不是期望的结果
	cat <<-PRERM_EOF >>prerm
		exit 0
	PRERM_EOF

	# 在包更新期间为 pacman 包运行 py3compile
	if [[ "$TERMUX_PACKAGE_FORMAT" == "pacman" ]] && ! grep -qs 'post_install' postupg; then
		echo "post_install" >>postupg
	fi
}
