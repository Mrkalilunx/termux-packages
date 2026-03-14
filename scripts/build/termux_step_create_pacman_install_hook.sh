termux_step_create_pacman_install_hook() {
	# 与 dpkg 不同，pacman 不对包安装钩子使用单独的脚本。
	# 相反，它使用带有函数的单个脚本。
	if [ -f "./preinst" ]; then
		echo "pre_install() {" >> .INSTALL
		cat preinst | grep -v '^#' >> .INSTALL
		echo "}" >> .INSTALL
		rm -f preinst
	fi
	if [ -f "./postinst" ]; then
		echo "post_install() {" >> .INSTALL
		cat postinst | grep -v '^#' >> .INSTALL
		echo "}" >> .INSTALL
		rm -f postinst
	fi
	if [ -f "./preupg" ]; then
		echo "pre_upgrade() {" >> .INSTALL
		cat preupg | grep -v '^#' >> .INSTALL
		echo "}" >> .INSTALL
		rm -f preupg
	fi
	if [ -f "./postupg" ]; then
		echo "post_upgrade() {" >> .INSTALL
		cat postupg | grep -v '^#' >> .INSTALL
		echo "}" >> .INSTALL
		rm -f postupg
	fi
	if [ -f "./prerm" ]; then
		echo "pre_remove() {" >> .INSTALL
		cat prerm | grep -v '^#' >> .INSTALL
		echo "}" >> .INSTALL
		rm -f prerm
	fi
	if [ -f "./postrm" ]; then
		echo "post_remove() {" >> .INSTALL
		cat postrm | grep -v '^#' >> .INSTALL
		echo "}" >> .INSTALL
		rm -f postrm
	fi

	# 目前不支持从 dpkg 触发器到 libalpm 钩子的转换。
	# 删除不需要的触发器文件。
	rm -f triggers
}
