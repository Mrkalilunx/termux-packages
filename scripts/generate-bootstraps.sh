#!/usr/bin/env bash
##
##  用于生成 bootstrap 归档文件的脚本。
##

set -e

export TERMUX_SCRIPTDIR=$(realpath "$(dirname "$(realpath "$0")")/../")
. $(dirname "$(realpath "$0")")/properties.sh
BOOTSTRAP_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-tmp.XXXXXXXX")
trap 'rm -rf $BOOTSTRAP_TMPDIR' EXIT

# 默认情况下，bootstrap 归档文件兼容 Android >=7.0
# 和 <10。
BOOTSTRAP_ANDROID10_COMPATIBLE=false

# 默认情况下，将为 Termux 应用支持的所有架构
# 构建 bootstrap 归档文件。
# 可使用选项 '--architectures' 覆盖。
TERMUX_ARCHITECTURES=("aarch64" "arm" "i686" "x86_64")

# 支持的 termux 包管理器。
TERMUX_PACKAGE_MANAGERS=("apt" "pacman")

# 包管理器的仓库基础 URL 映射。
declare -A REPO_BASE_URLS=(
	["apt"]="https://packages-cf.termux.dev/apt/termux-main"
	["pacman"]="https://service.termux-pacman.dev/main"
)

# 将在 bootstrap 中安装的包管理器。
# 默认为 'apt'。可以使用 '--pm' 选项更改。
TERMUX_PACKAGE_MANAGER="apt"

# 包管理器的仓库基础 URL。
# 可以使用 '--repository' 选项更改。
REPO_BASE_URL="${REPO_BASE_URLS[${TERMUX_PACKAGE_MANAGER}]}"

# 非必要包列表。默认为空，但可以使用选项 '--add' 填充。
declare -a ADDITIONAL_PACKAGES

# 检查某些可能因某种原因不可用的重要工具。
for cmd in ar awk curl grep gzip find sed tar xargs xz zip jq; do
	if [ -z "$(command -v $cmd)" ]; then
		echo "[!] 工具 '$cmd' 在 PATH 中不可用。"
		exit 1
	fi
done

# 从远程仓库下载包列表。
# 实际上，可以下载 2 个列表：一个与架构无关，一个用于指定为 '$1' 参数的架构。这取决于仓库。
# 如果仓库是使用 "aptly" 创建的，则与架构无关的列表不可用。
read_package_list_deb() {
	local architecture
	for architecture in all "$1"; do
		if [ ! -e "${BOOTSTRAP_TMPDIR}/packages.${architecture}" ]; then
			echo "[*] 正在下载架构 '${architecture}' 的包列表..."
			if ! curl --fail --location \
				--output "${BOOTSTRAP_TMPDIR}/packages.${architecture}" \
				"${REPO_BASE_URL}/dists/stable/main/binary-${architecture}/Packages"; then
				if [ "$architecture" = "all" ]; then
					echo "[!] 由于不可用，跳过与架构无关的包列表..."
					continue
				fi
			fi
			echo >> "${BOOTSTRAP_TMPDIR}/packages.${architecture}"
		fi

		echo "[*] 正在读取 '${architecture}' 的包列表..."
		while read -r -d $'\xFF' package; do
			if [ -n "$package" ]; then
				local package_name
				package_name=$(echo "$package" | grep -i "^Package:" | awk '{ print $2 }')

				if [ -z "${PACKAGE_METADATA["$package_name"]}" ]; then
					PACKAGE_METADATA["$package_name"]="$package"
				else
					local prev_package_ver cur_package_ver
					cur_package_ver=$(echo "$package" | grep -i "^Version:" | awk '{ print $2 }')
					prev_package_ver=$(echo "${PACKAGE_METADATA["$package_name"]}" | grep -i "^Version:" | awk '{ print $2 }')

					# 如果包有多个版本，请确保我们的元数据包含最新的版本。
					if [ "$(echo -e "${prev_package_ver}\n${cur_package_ver}" | sort -rV | head -n1)" = "${cur_package_ver}" ]; then
						PACKAGE_METADATA["$package_name"]="$package"
					fi
				fi
			fi
		done < <(sed -e "s/^$/\xFF/g" "${BOOTSTRAP_TMPDIR}/packages.${architecture}")
	done
}

download_db_packages_pac() {
	if [ ! -e "${PATH_DB_PACKAGES}" ]; then
		echo "[*] 正在下载架构 '${package_arch}' 的包列表..."
		curl --fail --location \
			--output "${PATH_DB_PACKAGES}" \
			"${REPO_BASE_URL}/${package_arch}/main.json"
	fi
}

read_db_packages_pac() {
	jq -r '."'${package_name}'"."'${1}'" | if type == "array" then .[] else . end' "${PATH_DB_PACKAGES}"
}

print_desc_package_pac() {
	echo -e "%${1}%\n${2}\n"
}

# 下载指定的包及其依赖项，然后将 *.deb 或 *.pkg.tar.xz 文件提取到
# bootstrap 根目录。
pull_package() {
	local package_name=$1
	local package_tmpdir="${BOOTSTRAP_PKGDIR}/${package_name}"
	mkdir -p "$package_tmpdir"

	if [ ${TERMUX_PACKAGE_MANAGER} = "apt" ]; then
		local package_url
		package_url="$REPO_BASE_URL/$(echo "${PACKAGE_METADATA[${package_name}]}" | grep -i "^Filename:" | awk '{ print $2 }')"
		if [ "${package_url}" = "$REPO_BASE_URL" ] || [ "${package_url}" = "${REPO_BASE_URL}/" ]; then
			echo "[!] 无法确定包 '$package_name' 的 URL。"
			exit 1
		fi

		local package_dependencies
		package_dependencies=$(
			while read -r token; do
				echo "$token" | cut -d'|' -f1 | sed -E 's@\(.*\)@@'
			done < <(echo "${PACKAGE_METADATA[${package_name}]}" | grep -i "^Depends:" | sed -E 's@^[Dd]epends:@@' | tr ',' '\n')
		)

		# 递归处理依赖项。
		if [ -n "$package_dependencies" ]; then
			local dep
			for dep in $package_dependencies; do
				if [ ! -e "${BOOTSTRAP_PKGDIR}/${dep}" ]; then
					pull_package "$dep"
				fi
			done
			unset dep
		fi

		if [ ! -e "$package_tmpdir/package.deb" ]; then
			echo "[*] 正在下载 '$package_name'..."
			curl --fail --location --output "$package_tmpdir/package.deb" "$package_url"

			echo "[*] 正在提取 '$package_name'..."
			(cd "$package_tmpdir"
				ar x package.deb

				# data.tar 可能具有不同于 .xz 的扩展名
				if [ -f "./data.tar.xz" ]; then
					data_archive="data.tar.xz"
				elif [ -f "./data.tar.gz" ]; then
					data_archive="data.tar.gz"
				else
					echo "在 '$package_name' 中未找到 data.tar.*。"
					exit 1
				fi

				# 对 control.tar 执行相同操作。
				if [ -f "./control.tar.xz" ]; then
					control_archive="control.tar.xz"
				elif [ -f "./control.tar.gz" ]; then
					control_archive="control.tar.gz"
				else
					echo "在 '$package_name' 中未找到 control.tar.*。"
					exit 1
				fi

				# 提取文件。
				tar xf "$data_archive" -C "$BOOTSTRAP_ROOTFS"

				if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
					# 注册提取的文件。
					tar tf "$data_archive" | sed -E -e 's@^\./@/@' -e 's@^/$@/.@' -e 's@^([^./])@/\1@' > "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info/${package_name}.list"

					# 生成校验和（md5）。
					tar xf "$data_archive"
					find data -type f -print0 | xargs -0 -r md5sum | sed 's@^\.$@@g' > "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info/${package_name}.md5sums"

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
							cp "$file" "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info/${package_name}.${file}"
						fi
					done
				fi
			)
		fi
	else
		local package_dependencies=$(read_db_packages_pac "DEPENDS" | sed 's/<.*$//g; s/>.*$//g; s/=.*$//g')

		if [ "$package_dependencies" != "null" ]; then
			local dep
			for dep in $package_dependencies; do
				if [ ! -e "${BOOTSTRAP_PKGDIR}/${dep}" ]; then
					pull_package "$dep"
				fi
			done
			unset dep
		fi

		if [ ! -e "$package_tmpdir/package.pkg.tar.xz" ]; then
			echo "[*] 正在下载 '$package_name'..."
			local package_filename=$(read_db_packages_pac "FILENAME")
			curl --fail --location --output "$package_tmpdir/package.pkg.tar.xz" "${REPO_BASE_URL}/${package_arch}/${package_filename}"

			echo "[*] 正在提取 '$package_name'..."
			(cd "$package_tmpdir"
				local package_desc="${package_name}-$(read_db_packages_pac VERSION)"
				mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/local/${package_desc}"
				{
					echo "%FILES%"
					tar xvf package.pkg.tar.xz -C "$BOOTSTRAP_ROOTFS" .INSTALL .MTREE data 2> /dev/null | grep '^data/' || true
				} >> "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/local/${package_desc}/files"
				mv "${BOOTSTRAP_ROOTFS}/.MTREE" "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/local/${package_desc}/mtree"
				if [ -f "${BOOTSTRAP_ROOTFS}/.INSTALL" ]; then
					mv "${BOOTSTRAP_ROOTFS}/.INSTALL" "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/local/${package_desc}/install"
				fi
				{
					local keys_desc="VERSION BASE DESC URL ARCH BUILDDATE PACKAGER ISIZE GROUPS LICENSE REPLACES DEPENDS OPTDEPENDS CONFLICTS PROVIDES"
					for i in "NAME ${package_name}" \
						"INSTALLDATE $(date +%s)" \
						"VALIDATION $(test $(read_db_packages_pac PGPSIG) != 'null' && echo 'pgp' || echo 'sha256')"; do
						print_desc_package_pac ${i}
					done
					jq -r -j '."'${package_name}'" | to_entries | .[] | select(.key | contains('$(sed 's/^/"/; s/ /","/g; s/$/"/' <<< ${keys_desc})')) | "%",(if .key == "ISIZE" then "SIZE" else .key end),"%\n",.value,"\n\n" | if type == "array" then (.| join("\n")) else . end' \
						"${PATH_DB_PACKAGES}"
				} >> "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/local/${package_desc}/desc"
			)
		fi
	fi
}

# 添加 termux bootstrap 第二阶段文件
add_termux_bootstrap_second_stage_files() {

	local package_arch="$1"

	echo "[*] 正在添加 termux bootstrap 第二阶段文件..."

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
	echo "[*] 正在创建 'bootstrap-${1}.zip'..."
	(cd "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}"
		# 不要在 bootstrap 归档文件中存储符号链接。
		# 相反，将所有信息放入 SYMLINKS.txt
		while read -r -d '' link; do
			echo "$(readlink "$link")←${link}" >> SYMLINKS.txt
			rm -f "$link"
		done < <(find . -type l -print0)

		zip -r9 "${BOOTSTRAP_TMPDIR}/bootstrap-${1}.zip" ./*
	)

	mv -f "${BOOTSTRAP_TMPDIR}/bootstrap-${1}.zip" ./
	echo "[*] 成功完成（${1}）。"
}

show_usage() {
	echo
	echo "用法：generate-bootstraps.sh [选项]"
	echo
	echo "为 Termux 应用生成 bootstrap 归档文件。"
	echo
	echo "选项："
	echo
	echo " -h, --help                  显示此帮助。"
	echo
	echo " --android10                 为 Android 10 生成 bootstrap 归档文件。"
	echo
	echo " -a, --add PKG_LIST          指定一个或多个附加包"
	echo "                             包含到 bootstrap 归档文件中。"
	echo "                             多个包应以"
	echo "                             逗号分隔的列表形式传递。"
	echo
	echo " --pm MANAGER                在 bootstrap 中设置包管理器。"
	echo "                             它只能是 pacman 或 apt（默认为 apt）。"
	echo
	echo " --architectures ARCH_LIST   覆盖要为其"
	echo "                             创建 bootstrap 归档文件的"
	echo "                             默认架构列表。"
	echo "                             多个架构应以"
	echo "                             逗号分隔的列表形式传递。"
	echo
	echo " -r, --repository URL        指定 APT 仓库的 URL，"
	echo "                             将从该仓库下载包。"
	echo "                             必须在 '--pm' 选项之后传递。"
	echo
	echo "架构：${TERMUX_ARCHITECTURES[*]}"
	echo "仓库基础 URL：${REPO_BASE_URL}"
	echo "前缀：${TERMUX_PREFIX}"
        echo "包管理器：${TERMUX_PACKAGE_MANAGER}"
	echo
}

while (($# > 0)); do
	case "$1" in
		-h|--help)
			show_usage
			exit 0
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
				echo "[!] 选项 '--add' 需要一个参数。"
				show_usage
				exit 1
			fi
			;;
		--pm)
			if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
				TERMUX_PACKAGE_MANAGER="$2"
				REPO_BASE_URL="${REPO_BASE_URLS[${TERMUX_PACKAGE_MANAGER}]}"
				shift 1
			else
				echo "[!] 选项 '--pm' 需要一个参数。" 1>&2
				show_usage
				exit 1
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
				echo "[!] 选项 '--architectures' 需要一个参数。"
				show_usage
				exit 1
			fi
			;;
		-r|--repository)
			if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
				REPO_BASE_URL="$2"
				shift 1
			else
				echo "[!] 选项 '--repository' 需要一个参数。"
				show_usage
				exit 1
			fi
			;;
		*)
			echo "[!] 收到未知选项 '$1'"
			show_usage
			exit 1
			;;
	esac
	shift 1
done

if [[ "$TERMUX_PACKAGE_MANAGER" == *" "* ]] || [[ " ${TERMUX_PACKAGE_MANAGERS[*]} " != *" $TERMUX_PACKAGE_MANAGER "* ]]; then
	echo "[!] 无效的包管理器 '$TERMUX_PACKAGE_MANAGER'" 1>&2
	echo "支持的包管理器：'${TERMUX_PACKAGE_MANAGERS[*]}'" 1>&2
	exit 1
fi

if [ -z "$REPO_BASE_URL" ]; then
	echo "[!] 仓库基础 URL 未设置。" 1>&2
	exit 1
fi

for package_arch in "${TERMUX_ARCHITECTURES[@]}"; do
	PATH_DB_PACKAGES="$BOOTSTRAP_TMPDIR/main_${package_arch}.json"
	BOOTSTRAP_ROOTFS="$BOOTSTRAP_TMPDIR/rootfs-${package_arch}"
	BOOTSTRAP_PKGDIR="$BOOTSTRAP_TMPDIR/packages-${package_arch}"

	# Create initial directories for $TERMUX_PREFIX
	if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
		if [ ${TERMUX_PACKAGE_MANAGER} = "apt" ]; then
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/etc/apt/apt.conf.d"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/etc/apt/preferences.d"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/info"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/triggers"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/updates"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/log/apt"
			touch "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/available"
			touch "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/dpkg/status"
		else
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/sync"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/local"
			echo "9" >> "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/lib/pacman/local/ALPM_DB_VERSION"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/cache/pacman/pkg"
			mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/var/log"
		fi
	fi
	mkdir -p "${BOOTSTRAP_ROOTFS}/${TERMUX_PREFIX}/tmp"

	# Read package metadata.
	unset PACKAGE_METADATA
	declare -A PACKAGE_METADATA
	if [ ${TERMUX_PACKAGE_MANAGER} = "apt" ]; then
		read_package_list_deb "$package_arch"
	else
		download_db_packages_pac
	fi

	# Package manager.
	if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
		pull_package ${TERMUX_PACKAGE_MANAGER}
	fi

	# Core utilities.
	pull_package bash # Used by `termux-bootstrap-second-stage.sh`
	pull_package bzip2
	if ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then
		pull_package command-not-found
	else
		pull_package proot
	fi
	pull_package coreutils
	pull_package curl
	pull_package dash
	pull_package diffutils
	pull_package findutils
	pull_package gawk
	pull_package grep
	pull_package gzip
	pull_package less
	pull_package procps
	pull_package psmisc
	pull_package sed
	pull_package tar
	pull_package termux-core
	pull_package termux-exec
	pull_package termux-keyring
	pull_package termux-tools
	pull_package util-linux
	pull_package xz-utils

	# Additional.
	pull_package ed
	if [ ${TERMUX_PACKAGE_MANAGER} = "apt" ]; then
		pull_package debianutils
	fi
	pull_package dos2unix
	pull_package inetutils
	pull_package lsof
	pull_package nano
	pull_package net-tools
	pull_package patch
	pull_package unzip

	# Handle additional packages.
	for add_pkg in "${ADDITIONAL_PACKAGES[@]}"; do
		pull_package "$add_pkg"
	done
	unset add_pkg

	# Add termux bootstrap second stage files
	add_termux_bootstrap_second_stage_files "$package_arch"

	# Create bootstrap archive.
	create_bootstrap_archive "$package_arch"
done
