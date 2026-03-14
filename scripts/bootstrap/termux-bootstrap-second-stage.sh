#!@TERMUX_PREFIX@/bin/bash
# shellcheck shell=bash

export TERMUX_PREFIX="@TERMUX_PREFIX@"
export TERMUX_PACKAGE_MANAGER="@TERMUX_PACKAGE_MANAGER@"
export TERMUX_PACKAGE_ARCH="@TERMUX_PACKAGE_ARCH@"

TERMUX__USER_ID___N="@TERMUX_ENV__S_TERMUX@USER_ID"
TERMUX__USER_ID="${!TERMUX__USER_ID___N:-}"

function log() { echo "[*]" "$@"; }
function log_error() { echo "[*]" "$@" 1>&2; }

show_help() {

	cat <<'HELP_EOF'
@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@ 运行 Termux bootstrap 安装的
第二阶段。


用法：
  @TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@


可用的 command_options：
  [ -h | --help ]    显示此帮助屏幕。



Termux 应用通过手动将 bootstrap 包提取到私有应用数据目录
`/data/data/<package_name>` 下的 Termux rootfs 目录来运行
bootstrap 安装第一阶段，而不使用包管理器（如 `apt`/`dpkg` 或 `pacman`）来安装
包，因为它们也是 bootstrap 的一部分。
由于手动提取，包配置可能无法正确完成，
比如运行维护者脚本，如 `preinst` 和
`postinst`。因此，`@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@` 在
提取后运行以完成包配置。第二阶段的输出
将由应用记录到 Android `logcat`。

目前，只运行 `postinst` 脚本。
在没有实际 rootfs 的情况下运行 `preinst` 脚本是不可能的，
并且需要编写对提取后运行特殊脚本的支持来处理需要它的包。

如果所有包的维护者脚本都成功执行，
`@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@` 将以退出代码 `0` 退出，
否则以最后失败的脚本返回的退出代码或任何其他失败的退出代码退出。

第二阶段只能在 rootfs 的整个生命周期中运行一次，
再次运行可能会使 rootfs 处于不一致的状态，
因此默认情况下不允许这样做。这是通过创建
`@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@.lock` 文件作为符号链接来完成的
在与 `@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@` 文件相同的目录中，
因为这是一个原子操作，只有
`@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@` 创建它的第一个实例才能够运行
第二阶段，其他实例将失败。在正常操作下，锁文件永远不会被删除。
如果 rootfs 目录被擦除，则锁文件将随之删除，因为它位于其下，
并且当再次设置 bootstrap 时，第二阶段将能够再次运行。
`$TMPDIR` 不用于锁文件，因为它通常在 rootfs 的生命周期中被删除。
如果出于某种原因，必须强制再次运行第二阶段（不推荐），
例如之前失败的情况，并且必须为了测试再次运行它，那么手动
删除锁文件并再次运行 `@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@`。

**另请参阅：**
- https://github.com/termux/termux-packages/wiki/For-maintainers#bootstraps
HELP_EOF

}

main() {

	local return_value

	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		show_help || return $?
		return 0
	else
		run_bootstrap_second_stage "$@"
		return_value=$?
		if [ $return_value -eq 64 ]; then # EX__USAGE
			echo ""
			show_help
		fi
		return $return_value
	fi

}

run_bootstrap_second_stage() {

	local return_value

	local output


	ensure_running_with_termux_uid || return $?


	output="$(ln -s "@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@" \
		"@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@/@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@.lock" 2>&1)"
	return_value=$?
	if [ $return_value -ne 0 ]; then
		if [ $return_value -eq 1 ] && [[ "$output" == *"File exists"* ]]; then
			log "Termux bootstrap 第二阶段之前已经运行过，无法再次运行。"
			log "如果您仍然想强制再次运行它（不推荐），例如在之前失败的情况下，并且必须为了测试再次运行它，那么手动删除 '@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@/@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@.lock' 文件并再次运行 '@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@'。"
			return 0
		else
			log_error "$output"
			log_error "无法在 '@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@/@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@.lock' 为 termux bootstrap 第二阶段创建锁文件"
			warn_if_process_killed "$return_value" "ln"
			return $return_value
		fi
	fi


	log "正在运行 termux bootstrap 第二阶段"
	run_bootstrap_second_stage_inner
	return_value=$?
	if [ $return_value -ne 0 ]; then
		log_error "运行 termux bootstrap 第二阶段失败"
		return $return_value
	fi

	log "Termux bootstrap 第二阶段已成功完成"


	return 0

}

run_bootstrap_second_stage_inner() {

	local return_value

	log "正在运行 postinst 维护者脚本"
	run_package_postinst_maintainer_scripts
	return_value=$?
	if [ $return_value -ne 0 ]; then
		log_error "运行 postinst 维护者脚本失败"
		return $return_value
	fi

	return 0

}

run_package_postinst_maintainer_scripts() {

	local return_value

	local package_name
	local package_version
	local package_dir
	local package_dir_basename
	local script_path
	local script_basename

	if [ "${TERMUX_PACKAGE_MANAGER}" = "apt" ]; then
		# - https://www.debian.org/doc/debian-policy/ch-maintainerscripts
		# - https://manpages.debian.org/testing/dpkg-dev/deb-postinst.5.en.html

		# - https://github.com/guillemj/dpkg/blob/1.22.6/src/main/script.c#L178-L206
		# - https://github.com/guillemj/dpkg/blob/1.22.6/src/main/script.c#L107
		if [ -d "${TERMUX_PREFIX}/var/lib/dpkg/info" ]; then
			local dpkg_version

			dpkg_version=$(dpkg --version | head -n 1 | sed -E 's/.*version ([^ ]+) .*/\1/')
			if [[ ! "$dpkg_version" =~ ^[0-9].*$ ]]; then
				log_error "无法找到 'dpkg' 版本"
				log_error "$dpkg_version"
				return 1
			fi

			# 检查 `dpkg --force-help` 获取当前默认值。
			# 如果它们更改，这将需要更新。
			# 目前，我们不解析命令输出。
			# - https://manpages.debian.org/testing/dpkg/dpkg.1.en.html#force~2
			local dpkg_force_things="security-mac,downgrade"

			# - https://manpages.debian.org/testing/dpkg/dpkg.1.en.html#D
			# - https://manpages.debian.org/unstable/dpkg/dpkg.1.en.html#DPKG_DEBUG
			# - https://manpages.debian.org/testing/dpkg/dpkg.1.en.html#DPKG_MAINTSCRIPT_DEBUG
			# - https://github.com/guillemj/dpkg/blob/1.22.6/src/main/script.c#L189
			# - https://github.com/guillemj/dpkg/blob/1.22.6/lib/dpkg/debug.c#L123
			# - https://github.com/guillemj/dpkg/blob/1.22.6/lib/dpkg/debug.h#L43
			local dbg_scripts=02
			local maintscript_debug=0
			if [[ "$DPKG_DEBUG" =~ ^0[0-7]{1,6}$ ]] && [[ "$(( DPKG_DEBUG & dbg_scripts ))" != "0" ]]; then
				maintscript_debug=1
			fi

			for script_path in "${TERMUX_PREFIX}/var/lib/dpkg/info/"*.postinst; do
				script_basename="${script_path##*/}"
				package_name="${script_basename::-9}"

				log "正在运行 '$package_name' 包的 postinst"

				# Bootstrap zip 中的维护者脚本没有执行权限，
				# 并且由于文件是由 termux-app 手动提取的，
				# 它们需要在这里分配权限，就像 `dpkg` 做的那样。
				chmod u+x "$script_path" || return $?

				(
					# 根据 `dpkg` `script.c`：
					# >切换到一个已知良好的目录，为维护者脚本
					# >提供一个更健全的环境。
					# 当前工作目录的处理方式如下：
					# - 默认情况下使用 rootfs `/`。
					# - 如果设置了 `$DPKG_ROOT` 为备用 rootfs 路径：
					#   - 如果未传递 `--force-script-chrootless` 标志，
					#     则 chroot 进入 `$DPKG_ROOT`，然后将当前工作
					#     目录更改为 `/`。
					#   - 如果传递了该标志，则不进行 chroot，
					#     仅将当前工作目录更改为 `$DPKG_ROOT`。
					# - https://github.com/guillemj/dpkg/blob/1.22.6/src/main/script.c#L99-L130
					# - https://github.com/guillemj/dpkg/blob/1.22.6/lib/dpkg/fsys-dir.c#L86
					# - https://github.com/guillemj/dpkg/blob/1.22.6/lib/dpkg/fsys-dir.c#L33
					# - https://github.com/guillemj/dpkg/blob/1.22.6/src/common/force.c#L146-L149
					# - https://github.com/guillemj/dpkg/blob/1.22.6/src/common/force.c#L348
					# - https://manpages.debian.org/unstable/dpkg/dpkg.1.en.html#DPKG_FORCE
					# - https://wiki.debian.org/Teams/Dpkg/Spec/InstallBootstrap#Detached_chroot_handling
					# Termux 默认不设置 `$DPKG_ROOT` 且不传递
					# `--force-script-chrootless` 标志，因此仅将
					# 当前工作目录更改为 Android rootfs `/`。
					# 此外，Android 应用无法在没有 root 访问权限
					# 的情况下运行 chroot，因此 `$DPKG_ROOT` 无法
					# 在没有 `--force-script-chrootless` 标志的情况下正常使用。
					# 注意 Termux rootfs 位于私有应用数据目录
					# `/data/data/<package_name>,`，这可能会对尝试
					# 使用 Android rootfs 路径而不是 Termux rootfs
					# 路径的包造成问题。
					cd / || exit $?

					# 导出 `dpkg` 为维护者脚本导出的内部环境变量。
					# - https://manpages.debian.org/testing/dpkg/dpkg.1.en.html#Internal_environment
					# - https://github.com/guillemj/dpkg/blob/1.22.6/src/main/main.c#L751-L759
					# - https://github.com/guillemj/dpkg/blob/1.22.6/src/main/script.c#L191-L197
					export DPKG_MAINTSCRIPT_PACKAGE="$package_name"
					export DPKG_MAINTSCRIPT_PACKAGE_REFCOUNT="1"
					export DPKG_MAINTSCRIPT_ARCH="$TERMUX_PACKAGE_ARCH"
					export DPKG_MAINTSCRIPT_NAME="postinst"
					export DPKG_MAINTSCRIPT_DEBUG="$maintscript_debug"
					export DPKG_RUNNING_VERSION="$dpkg_version"
					export DPKG_FORCE="$dpkg_force_things"
					export DPKG_ADMINDIR="${TERMUX_PREFIX}/var/lib/dpkg"
					export DPKG_ROOT=""

					# > 维护者脚本必须是正确的可执行文件；
					# > 如果它们是脚本（推荐），必须以常规的 `#!` 约定开始。
					# 直接执行它而不是使用 shell，
					# 如果失败则退出并返回错误，因为这暗示 bootstrap 设置失败。
					# 第一个参数是 `configure`。
					# 如果包正在升级，包版本是第二个参数，
					# 但对于首次安装不是，所以不传递它。
					# 检查 `deb-postinst(5)` 以获取更多信息。
					"$script_path" configure
					return_value=$?
					if [ $return_value -ne 0 ]; then
						log_error "无法运行 '$package_name' 包的 postinst"
						exit $return_value
					fi
				) || return $?

			done
		fi



	elif [ ${TERMUX_PACKAGE_MANAGER} = "pacman" ]; then
		# - https://wiki.archlinux.org/title/PKGBUILD#install
		# - https://gitlab.archlinux.org/pacman/pacman/-/blob/v6.1.0/lib/libalpm/add.c#L638-L647
		if [ -d "${TERMUX_PREFIX}/var/lib/pacman/local" ]; then
			# 包安装文件位于 `/var/lib/pacman/local/package-version/install`
			for script_path in "${TERMUX_PREFIX}/var/lib/pacman/local/"*/install; do
				package_dir="${script_path::-8}"
				package_dir_basename="${package_dir##*/}"

				# 从格式为 `package-version` 的 package_dir_basename 中
				# 提取格式为 `epoch:pkgver-pkgrel` 的包 `version`。
				# 不要使用外部程序进行解析，因为那需要将其作为
				# 第二阶段的依赖项添加。
				# - https://wiki.archlinux.org/title/PKGBUILD#Version
				# 设置为最后一个破折号 "-" 之后的所有内容
				local package_version_pkgrel="${package_dir_basename##*-}"
				# 设置为最后一个破折号 "-" 之前和包括它的所有内容
				local package_name_and_version_pkgver="${package_dir_basename%"$package_version_pkgrel"}"
				# 去除末尾的破折号 "-"
				package_name_and_version_pkgver="${package_name_and_version_pkgver%?}"
				# 设置为最后一个破折号 "-" 之后的所有内容
				local package_version_pkgver="${package_name_and_version_pkgver##*-}"
				# 设置 pkgver 和 pkgrel
				package_version="$package_version_pkgver-$package_version_pkgrel"
				if [[ ! "$package_version" =~ ^([0-9]+:)?[^-]+-[^-]+$ ]]; then
					log_error "从 package_dir_basename '$package_dir_basename' 提取的 package_version '$package_version' 无效"
					return 1
				fi

				log "正在运行 '$package_dir_basename' 包的 post_install"

				(
					# 根据 `pacman` 安装文档：
					# > 每个函数都在 pacman 安装目录内以 chroot 方式运行。请参阅此线程。
					# `RootDir` 被进入 chroot，然后当前工作目录更改为 `/`。
					# - https://bbs.archlinux.org/viewtopic.php?pid=913891
					# - https://man.archlinux.org/man/pacman.conf.5.en#OPTIONS
					# - https://gitlab.archlinux.org/pacman/pacman/-/blob/v6.1.0/src/pacman/conf.c#L855
					# - https://gitlab.archlinux.org/pacman/pacman/-/blob/v6.1.0/lib/libalpm/alpm.c#L47
					# - https://gitlab.archlinux.org/pacman/pacman/-/blob/v6.1.0/lib/libalpm/alpm.h#L1663-L1676
					# - https://gitlab.archlinux.org/pacman/pacman/-/blob/v6.1.0/lib/libalpm/util.c#L657-L668
					# - https://man7.org/linux/man-pages/man2/chroot.2.html
					# 但由于 Android 应用无法在没有 root 访问权限的情况下运行 chroot，
					# chroot 被 Termux pacman 包禁用，只有当前工作目录更改为 Android rootfs `/`。
					# 注意 Termux rootfs 位于私有应用数据目录 `/data/data/<package_name>,`
					# 这可能会对尝试使用 Android rootfs 路径而不是 Termux rootfs 路径的包造成问题。
					# - https://github.com/termux/termux-packages/blob/953b9f2aac0dc94f3b99b2df6af898e0a95d5460/packages/pacman/util.c.patch
					cd "/" || exit $?

					# Source 包的 `install` 文件并执行 `post_install` 函数（如果已定义）。

					# 如果环境中已定义函数，则取消设置
					unset -f post_install || exit $?

					# shellcheck disable=SC1090
					source "$script_path"
					return_value=$?
					if [ $return_value -ne 0 ]; then
						log_error "无法 source '$package_dir_basename' 包的 install 文件"
						exit $return_value
					fi

					if [[ "$(type -t post_install 2>/dev/null)" == "function" ]]; then
						# 再次 cd，以防 install 源文件更改了目录。
						cd "/" || exit $?

						# 执行 post_install 函数并在失败时退出
						# 因为这暗示 bootstrap 设置失败。
						# 包版本是第一个参数。
						# 检查 `PKGBUILD#install` 文档以获取更多信息。
						post_install "$package_version"
						return_value=$?
						if [ $return_value -ne 0 ]; then
							log_error "无法运行 '$package_dir_basename' 包的 post_install"
							exit $return_value
						fi
					fi
				) || return $?
			done
		fi
	fi

	return 0

}





ensure_running_with_termux_uid() {

	local return_value

	local uid

	# 查找当前有效的 uid
	uid="$(id -u 2>&1)"
	return_value=$?
	if [ $return_value -ne 0 ]; then
		log_error "$uid"
		log_error "无法获取运行 '@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@' 脚本的用户的 uid"
		warn_if_process_killed "$return_value" "uid"
		# 如果使用 `adb install -r --abi arm64-v8a termux-app_v*_universal.apk`
		# 将 Termux 安装在 `x86_64` Android AVD 上，其中 `getprop ro.product.cpu.abilist`
		# 返回 `x86_64,arm64-v8a`，但只有 `x86_64` bootstrap zip 应该已被提取
		# 到 APK 原生 lib 目录并安装到 rootfs，则会触发此操作。
		# 如果在 shell 中执行完整路径，命令可以正常工作，但如果仅使用 `basename`
		# 依赖 `$PATH` 的命令，则会失败并出现以下错误。
		if [[ "$uid" == *"Unable to get realpath of id"* ]]; then
			log_error "您可能安装了与设备不兼容的错误 ABI/架构变体"
			log_error "的 @TERMUX_APP__NAME@ 应用 APK。卸载并重新安装正确的 @TERMUX_APP__NAME@ 应用 APK 变体。"
			log_error "如果您不知道设备的正确 ABI/架构，请安装 'universal' 变体。"
		fi
		return $return_value
	fi

	if [[ ! "$uid" =~ ^[0-9]+$ ]]; then
		log_error "'id -u' 命令返回的 uid '$uid' 无效。"
		return 1
	fi

	if [[ -n "$TERMUX__UID" ]] && [[ "$uid" != "$TERMUX__UID" ]]; then
		log_error "@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@ 不能以 uid '$uid' 运行，\ 必须以 @TERMUX_APP__NAME@ 应用导出的 TERMUX__UID '$TERMUX__UID' 运行。"
		return 1
	fi

	return 0

}

warn_if_process_killed() {

	local return_value="${1:-}"
	local command="${2:-}"

	if [[ "$return_value" == "137" ]]; then
		log_error "'$command' 命令似乎被 SIGKILL（信号 9）终止。\\
这可能是由于您设备上安装的 Android 操作系统的安全策略造成的。
查看 https://github.com/termux/termux-app/issues/4219 获取更多信息。"
		return 0
	fi

	return 1

}






# 如果在 bash 中运行，则运行脚本逻辑，否则退出并显示使用错误
if [ -n "${BASH_VERSION:-}" ]; then
	# 如果脚本被 source，则返回错误，否则调用 main 函数
	# - https://stackoverflow.com/a/28776166/14686958
	# - https://stackoverflow.com/a/29835459/14686958
	if (return 0 2>/dev/null); then
		echo "${0##*/} 不能被 source，因为需要 \"\$0\"。" 1>&2
		return 64 # EX__USAGE
	else
		main "$@"
		exit $?
	fi
else
	(echo "${0##*/} 必须使用 bash shell 运行。"; exit 64) # EX__USAGE
fi
