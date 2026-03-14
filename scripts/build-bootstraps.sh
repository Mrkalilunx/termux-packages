#!/usr/bin/env bash
# shellcheck disable=SC2039,SC2059

# 标题：         build-bootstrap.sh
# 描述：   一个用于为 termux-app 构建 bootstrap 归档文件的脚本
#                从本地包源构建，而不是像 generate-bootstrap.sh 那样从
#                apt 仓库中发布的 deb 包构建。它允许为（分支的）termux
#                应用轻松构建 bootstrap 归档文件，而无需先发布 apt 仓库。
# 用法：         运行 "build-bootstrap.sh --help"
version=0.1.0

set -e

export TERMUX_SCRIPTDIR=$(realpath "$(dirname "$(realpath "$0")")/../")
: "${TERMUX_TOPDIR:="$HOME/.termux-build"}"
. "${TERMUX_SCRIPTDIR}"/scripts/properties.sh
. "${TERMUX_SCRIPTDIR}"/scripts/build/termux_step_handle_buildarch.sh

BOOTSTRAP_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-tmp.XXXXXXXX")

# 默认情况下，bootstrap 归档文件兼容 Android >=7.0
# 和 <10。
BOOTSTRAP_ANDROID10_COMPATIBLE=false

# 默认情况下，将为 Termux 应用支持的所有架构
# 构建 bootstrap 归档文件。
# 可使用选项 '--architectures' 覆盖。
TERMUX_DEFAULT_ARCHITECTURES=("aarch64" "arm" "i686" "x86_64")
TERMUX_ARCHITECTURES=("${TERMUX_DEFAULT_ARCHITECTURES[@]}")

TERMUX_PACKAGES_DIRECTORY="/home/builder/termux-packages"
TERMUX_BUILT_DEBS_DIRECTORY="$TERMUX_PACKAGES_DIRECTORY/output"
TERMUX_BUILT_PACKAGES_DIRECTORY="/data/data/.built-packages"

IGNORE_BUILD_SCRIPT_NOT_FOUND_ERROR=1
FORCE_BUILD_PACKAGES=0

# 要构建的包列表
declare -a PACKAGES=()

# 要构建的非必要包列表。
# 默认为空，但可以使用选项 '--add' 填充。
declare -a ADDITIONAL_PACKAGES=()

# 已提取的包列表
declare -a EXTRACTED_PACKAGES=()

# 要传递给 build-package.sh 的选项列表
declare -a BUILD_PACKAGE_OPTIONS=()

# 检查某些可能因某种原因不可用的重要工具。
for cmd in ar awk curl grep gzip find sed tar xargs xz zip; do
	if [ -z "$(command -v $cmd)" ]; then
		echo "[!] 工具 '$cmd' 在 PATH 中不可用。"
		exit 1
	fi
done

# 为指定架构从源代码构建包及其依赖的 deb 文件
build_package() {

	local return_value

	local TERMUX_ARCH="$1"
	local package_name="$2"

	local build_output

	# 从源代码构建包
	# stderr 将重定向到 stdout，两者都将被捕获到变量中并在屏幕上打印
	cd "$TERMUX_PACKAGES_DIRECTORY"
	echo $'\n\n\n'"[*] 正在构建 '$package_name'..."
	exec 99>&1
	build_output="$("$TERMUX_PACKAGES_DIRECTORY"/build-package.sh "${BUILD_PACKAGE_OPTIONS[@]}" -a "$TERMUX_ARCH" "$package_name" 2>&1 | tee >(cat - >&99); exit ${PIPESTATUS[0]})";
	return_value=$?
	echo "[*] 构建 '$package_name' 退出，退出代码 $return_value"
	exec 99>&-
	if [ $return_value -ne 0 ]; then
		echo "为架构 '$TERMUX_ARCH' 构建包 '$package_name' 失败" 1>&2

		# 依赖包可能没有 build.sh，因此我们忽略该错误。
		# 应该实现更好的方法来验证它是否真的是依赖项
		# 而不是必需的包本身，通过从 PACKAGES 数组中删除依赖项。
		if [[ $IGNORE_BUILD_SCRIPT_NOT_FOUND_ERROR == "1" ]] && [[ "$build_output" == *"No build.sh script at package dir"* ]]; then
			echo "忽略错误 'No build.sh script at package dir'" 1>&2
			return 0
		fi
	fi

	return $return_value

}

# 将 *.deb 文件提取到 bootstrap 根目录。
extract_debs() {

	local package_arch="$1"
	local current_package_name
	local data_archive
	local control_archive
	local package_tmpdir
	local deb
	local file

	cd "$TERMUX_BUILT_DEBS_DIRECTORY"

	if [ -z "$(ls -A)" ]; then
		echo $'\n\n\n'"未找到 deb 文件"
		return 1
	else
		echo $'\n\n\n'"Deb 文件："
		echo "\""
		ls
		echo "\""
	fi

	for deb in *.deb; do

		current_package_name="$(echo "$deb" | sed -E 's/^([^_]+).*/\1/' )"
		current_package_arch="$(echo "$deb" | sed -E 's/.*_(aarch64|all|arm|i686|x86_64).deb$/\1/' )"
		echo "current_package_name: '$current_package_name'"
		echo "current_package_arch: '$current_package_arch'"

		if [[ "$current_package_arch" != "$package_arch" ]] && [[ "$current_package_arch" != "all" ]]; then
			echo "[*] 跳过与目标 '$package_arch' 不兼容的包 '$deb'..."
			continue
		fi

		if [[ "$current_package_name" == *"-static" ]]; then
			echo "[*] 跳过静态包 '$deb'..."
			continue
		fi

		if [[ " ${EXTRACTED_PACKAGES[*]} " == *" $current_package_name "* ]]; then
			echo "[*] 跳过已提取的包 '$current_package_name'..."
			continue
		fi

		EXTRACTED_PACKAGES+=("$current_package_name")

		package_tmpdir="${BOOTSTRAP_PKGDIR}/${current_package_name}"
		mkdir -p "$package_tmpdir"
		rm -rf "$package_tmpdir"/*

		echo "[*] 正在提取 '$deb'..."
		(cd "$package_tmpdir"
			ar x "$TERMUX_BUILT_DEBS_DIRECTORY/$deb"

			# data.tar 可能具有不同于 .xz 的扩展名
			if [ -f "./data.tar.xz" ]; then
				data_archive="data.tar.xz"
			elif [ -f "./data.tar.gz" ]; then
				data_archive="data.tar.gz"
			else
				echo "在 '$deb' 中未找到 data.tar.*。"
				return 1
			fi

			# 对 control.tar 执行相同操作。
			if [ -f "./control.tar.xz" ]; then
				control_archive="control.tar.xz"
			elif [ -f "./control.tar.gz" ]; then
				control_archive="control.tar.gz"
			else
				echo "在 '$deb' 中未找到 control.tar.*。"
				return 1
			fi

			# 提取文件。
			tar xf "$data_archive" -C "$BOOTSTRAP_ROOTFS"

			if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
				# 注册提取的文件。
				tar tf "$data_archive" | sed -E -e 's@^\./@/@' -e 's@^/$@/.@' -e 's@^([^./])@/\1@' > "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info/${current_package_name}.list"

				# 生成校验和（md5）。
				tar xf "$data_archive"
				find data -type f -print0 | xargs -0 -r md5sum | sed 's@^\.$@@g' > "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info/${current_package_name}.md5sums"

				# 提取元数据。
				tar xf "$control_archive"
				{
					cat control
					echo "Status: install ok installed"
					echo
				} >> "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/status"

				# 附加数据：conffiles 和脚本
				for file in conffiles postinst postrm preinst prerm; do
					if [ -f "${PWD}/${file}" ]; then
						cp "$file" "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info/${current_package_name}.${file}"
					fi
				done
			fi
		)
	done

}

# 添加 termux bootstrap 第二阶段文件
add_termux_bootstrap_second_stage_files() {

	local package_arch="$1"

	echo $'\n\n\n'"[*] 正在添加 termux bootstrap 第二阶段文件..."

	mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR}"
	sed -e "s|@TERMUX_PREFIX@|${TERMUX_PREFIX}|g" \
		-e "s|@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@|${TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR}|g" \
		-e "s|@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@|${TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE}|g" \
		-e "s|@TERMUX_PACKAGE_MANAGER@|${TERMUX_PACKAGE_MANAGER}|g" \
		-e "s|@TERMUX_PACKAGE_ARCH@|${package_arch}|g" \
		-e "s|@TERMUX_APP__NAME@|${TERMUX_APP__NAME}|g" \
		-e "s|@TERMUX_ENV__S_TERMUX@|${TERMUX_ENV__S_TERMUX}|g" \
		"$TERMUX_SCRIPTDIR/scripts/bootstrap/$TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE" \
		> "${BOOTSTRAP_ROOTFS}/${TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR}/$TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE"
	chmod 700 "${BOOTSTRAP_ROOTFS}/${TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR}/$TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE"

	# TODO: 当 Termux 应用支持 `pacman` bootstraps 安装时删除它。
	sed -e "s|@TERMUX_PREFIX@|${TERMUX_PREFIX}|g" \
		-e "s|@TERMUX__PREFIX__PROFILE_D_DIR@|${TERMUX__PREFIX__PROFILE_D_DIR}|g" \
		-e "s|@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@|${TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR}|g" \
		-e "s|@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@|${TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE}|g" \
		"$TERMUX_SCRIPTDIR/scripts/bootstrap/01-termux-bootstrap-second-stage-fallback.sh" \
		> "${BOOTSTRAP_ROOTFS}/${TERMUX__PREFIX__PROFILE_D_DIR}/01-termux-bootstrap-second-stage-fallback.sh"
	chmod 600 "${BOOTSTRAP_ROOTFS}/${TERMUX__PREFIX__PROFILE_D_DIR}/01-termux-bootstrap-second-stage-fallback.sh"

}

# 最后阶段：生成 bootstrap 归档文件并将其放置到当前
# 工作目录。
# 符号链接的信息存储在 SYMLINKS.txt 文件中。
create_bootstrap_archive() {

	echo $'\n\n\n'"[*] 正在创建 'bootstrap-${1}.zip'..."
	(cd "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}"
		# 不要在 bootstrap 归档文件中存储符号链接。
		# 相反，将所有信息放入 SYMLINKS.txt
		while read -r -d '' link; do
			echo "$(readlink "$link")←${link}" >> SYMLINKS.txt
			rm -f "$link"
		done < <(find . -type l -print0)

		zip -r9 "${BOOTSTRAP_TMPDIR}/bootstrap-${1}.zip" ./*
	)

	mv -f "${BOOTSTRAP_TMPDIR}/bootstrap-${1}.zip" "$TERMUX_PACKAGES_DIRECTORY/"

	echo "[*] 成功完成（${1}）。"

}

set_build_bootstrap_traps() {

	# 为 build_bootstrap_trap 本身设置陷阱
	trap 'build_bootstrap_trap' EXIT
	trap 'build_bootstrap_trap TERM' TERM
	trap 'build_bootstrap_trap INT' INT
	trap 'build_bootstrap_trap HUP' HUP
	trap 'build_bootstrap_trap QUIT' QUIT

	return 0

}

build_bootstrap_trap() {

	local build_bootstrap_trap_exit_code=$?
	trap - EXIT

	[ -h "$TERMUX_BUILT_PACKAGES_DIRECTORY" ] && rm -f "$TERMUX_BUILT_PACKAGES_DIRECTORY"
	[ -d "$BOOTSTRAP_TMPDIR" ] && rm -rf "$BOOTSTRAP_TMPDIR"

	[ -n "$1" ] && trap - "$1"; exit $build_bootstrap_trap_exit_code

}

show_usage() {

    cat <<'HELP_EOF'

build-bootstraps.sh 是一个用于为 termux-app 构建 bootstrap 归档文件的脚本
从本地包源构建，而不是像 generate-bootstrap.sh 那样从
apt 仓库中发布的 deb 包构建。它允许为（分支的）termux 应用轻松构建
bootstrap 归档文件，而无需先发布 apt 仓库。


用法：
  build-bootstraps.sh [command_options]


可用的 command_options：
  [ -h  | --help ]             显示此帮助屏幕
  [ -f ]             即使包已构建也强制构建。
  [ --android10 ]
                     为 Android 10+ 生成 bootstrap 归档文件，用于
                     apk 打包系统。
  [ -a | --add <packages> ]
                     要包含在 bootstrap 归档文件中的附加包。
                     多个包应以逗号分隔的列表形式传递。
  [ --architectures <architectures> ]
                     覆盖要为其创建 bootstrap 归档文件的默认架构列表。
                     多个架构应以逗号分隔的列表形式传递。


bootstrap 所针对的包名称/前缀由 'scrips/properties.sh' 中的
TERMUX_APP_PACKAGE 定义。默认为 'com.termux'。
如果更改了包名称，请确保运行
`./scripts/run-docker.sh ./clean.sh` 或传递 '-f' 以强制重新构建包。

### 示例

为所有支持的架构构建默认 bootstrap 归档文件：
./scripts/run-docker.sh ./scripts/build-bootstraps.sh &> build.log

仅为 aarch64 架构构建默认 bootstrap 归档文件：
./scripts/run-docker.sh ./scripts/build-bootstraps.sh --architectures aarch64 &> build.log

仅为 aarch64 架构构建带有附加 openssh 包的 bootstrap 归档文件：
./scripts/run-docker.sh ./scripts/build-bootstraps.sh --architectures aarch64 --add openssh &> build.log
HELP_EOF

echo $'\n'"TERMUX_APP_PACKAGE: \"$TERMUX_APP_PACKAGE\""
echo "TERMUX_PREFIX: \"${TERMUX_PREFIX[*]}\""
echo "TERMUX_ARCHITECTURES: \"${TERMUX_ARCHITECTURES[*]}\""

}

main() {

	local return_value

	while (($# > 0)); do
		case "$1" in
			-h|--help)
				show_usage
				return 0
				;;
			--android10)
				BOOTSTRAP_ANDROID10_COMPATIBLE=true
				;;
			-a|--add)
				if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
					for pkg in $(echo "$2" | tr ',' ' '); do
						ADDITIONAL_PACKAGES+=("$pkg")
					done
					unset pkg
					shift 1
				else
					echo "[!] 选项 '--add' 需要一个参数。" 1>&2
					show_usage
					return 1
				fi
				;;
			--architectures)
				if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
					TERMUX_ARCHITECTURES=()
					for arch in $(echo "$2" | tr ',' ' '); do
						TERMUX_ARCHITECTURES+=("$arch")
					done
					unset arch
					shift 1
				else
					echo "[!] 选项 '--architectures' 需要一个参数。" 1>&2
					show_usage
					return 1
				fi
				;;
			-f)
				BUILD_PACKAGE_OPTIONS+=("-f")
				FORCE_BUILD_PACKAGES=1
				;;
			*)
				echo "[!] 收到未知选项 '$1'" 1>&2
				show_usage
				return 1
				;;
		esac
		shift 1
	done

	set_build_bootstrap_traps

	for TERMUX_ARCH in "${TERMUX_ARCHITECTURES[@]}"; do
		if [[ " ${TERMUX_DEFAULT_ARCHITECTURES[*]} " != *" $TERMUX_ARCH "* ]]; then
			echo "架构列表中不支持的架构 '$TERMUX_ARCH'：'${TERMUX_ARCHITECTURES[*]}'" 1>&2
			echo "支持的架构：'${TERMUX_DEFAULT_ARCHITECTURES[*]}'" 1>&2
			return 1
		fi
	done

	for TERMUX_ARCH in "${TERMUX_ARCHITECTURES[@]}"; do
		termux_step_handle_buildarch

		if [[ $FORCE_BUILD_PACKAGES == "1" ]]; then
			rm -f "$TERMUX_BUILT_PACKAGES_DIRECTORY_FOR_ARCH"/*
			rm -f "$TERMUX_BUILT_DEBS_DIRECTORY"/*
		fi

		BOOTSTRAP_ROOTFS="$BOOTSTRAP_TMPDIR/rootfs-${TERMUX_ARCH}"
		BOOTSTRAP_PKGDIR="$BOOTSTRAP_TMPDIR/packages-${TERMUX_ARCH}"

		# 为 $TERMUX_PREFIX 创建初始目录
		if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/etc/apt/apt.conf.d"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/etc/apt/preferences.d"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/triggers"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/updates"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/log/apt"
			touch "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/available"
			touch "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/status"
		fi
		mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/tmp"



		PACKAGES=()
		EXTRACTED_PACKAGES=()

		# 包管理器。
		if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
			PACKAGES+=("apt")
		fi

		# 核心工具。
		PACKAGES+=("bash") # 由 `termux-bootstrap-second-stage.sh` 使用
		PACKAGES+=("bzip2")
		if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
			PACKAGES+=("command-not-found")
		else
			PACKAGES+=("proot")
		fi
		PACKAGES+=("coreutils")
		PACKAGES+=("dash")
		PACKAGES+=("diffutils")
		PACKAGES+=("findutils")
		PACKAGES+=("gawk")
		PACKAGES+=("grep")
		PACKAGES+=("gzip")
		PACKAGES+=("less")
		PACKAGES+=("procps")
		PACKAGES+=("psmisc")
		PACKAGES+=("sed")
		PACKAGES+=("tar")
		PACKAGES+=("termux-core")
		PACKAGES+=("termux-exec")
		PACKAGES+=("termux-keyring")
		PACKAGES+=("termux-tools")
		PACKAGES+=("util-linux")

		# 附加包。
		PACKAGES+=("ed")
		PACKAGES+=("debianutils")
		PACKAGES+=("dos2unix")
		PACKAGES+=("inetutils")
		PACKAGES+=("lsof")
		PACKAGES+=("nano")
		PACKAGES+=("net-tools")
		PACKAGES+=("patch")
		PACKAGES+=("unzip")

		# 处理附加包。
		for add_pkg in "${ADDITIONAL_PACKAGES[@]}"; do
			if [[ " ${PACKAGES[*]} " != *" $add_pkg "* ]]; then
				PACKAGES+=("$add_pkg")
			fi
		done
		unset add_pkg

		# 构建包。
		for package_name in "${PACKAGES[@]}"; do
			set +e
			build_package "$TERMUX_ARCH" "$package_name" || return $?
			set -e
		done

		# 提取所有 deb 文件。
		extract_debs "$TERMUX_ARCH" || return $?

		# 添加 termux bootstrap 第二阶段文件
		add_termux_bootstrap_second_stage_files "$package_arch"

		# 创建 bootstrap 归档文件。
		create_bootstrap_archive "$TERMUX_ARCH" || return $?

	done

}

main "$@"
