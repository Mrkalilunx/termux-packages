# shellcheck shell=bash disable=SC1091 disable=SC2086 disable=SC2155 disable=SC2164
termux_setup_dotnet() {
	# Microsoft 分发的 dotnet 启用遥测
	# 这对 Termux dotnet 没有影响（遥测已被禁用）
	export DOTNET_CLI_TELEMETRY_OPTOUT=1

	export DOTNET_TARGET_NAME="linux-bionic"
	case "${TERMUX_ARCH}" in
	aarch64) DOTNET_TARGET_NAME+="-arm64" ;;
	arm) DOTNET_TARGET_NAME+="-arm" ;;
	i686) DOTNET_TARGET_NAME+="-x86" ;;
	x86_64) DOTNET_TARGET_NAME+="-x64" ;;
	esac

	if [[ -z "${TERMUX_DOTNET_VERSION-}" ]]; then
		# LTS version
		TERMUX_DOTNET_VERSION=8.0
	fi

	if [[ "${TERMUX_ON_DEVICE_BUILD}" == "true" ]]; then
		if [[ -z "$(command -v dotnet)" ]]; then
			cat <<- EOL >&2
			未安装 'dotnet8.0' 软件包。
			您可以通过以下方式安装：

			pkg install dotnet8.0

			pacman -S dotnet8.0
			EOL
			exit 1
		fi
		local DOTNET_VERSION=$(dotnet --version | awk '{ print $2 }')
		if [[ -n "${TERMUX_DOTNET_VERSION-}" ]] && [[ "${TERMUX_DOTNET_VERSION-}" != "${DOTNET_VERSION//.*}"* ]]; then
			cat <<- EOL >&2
			警告：dotnet 版本不匹配！
			TERMUX_DOTNET_VERSION = ${TERMUX_DOTNET_VERSION}
			DOTNET_VERSION        = ${DOTNET_VERSION}
			EOL
		fi
		return
	fi

	# https://github.com/dotnet/core/issues/9671
	curl https://raw.githubusercontent.com/dotnet/install-scripts/refs/heads/main/src/dotnet-install.sh -sSfo "${TERMUX_PKG_TMPDIR}"/dotnet-install.sh
	bash "${TERMUX_PKG_TMPDIR}"/dotnet-install.sh --channel "${TERMUX_DOTNET_VERSION}"

	export PATH="${HOME}/.dotnet:${HOME}/.dotnet/tools:${PATH}"

	# 安装在 nuget.org 中找不到的目标包
	local _DOTNET_ROOT="${TERMUX_PREFIX}/lib/dotnet"
	if [[ ! -d "${_DOTNET_ROOT}" ]]; then
		echo "警告：${_DOTNET_ROOT} 不是目录！构建可能会失败！跳过安装符号链接。" >&2
		return
	fi
	if [[ ! -d "${HOME}/.dotnet/packs" ]]; then
		echo "错误：${HOME}/.dotnet/packs 不是目录！" >&2
		return 1
	fi

	pushd "${HOME}/.dotnet/packs"

	# 指向使用我们自己的 SDK
	local targeting_pack version
	for targeting_pack in "${_DOTNET_ROOT}"/packs/*; do
		if [[ -d "$(basename "${targeting_pack}")" ]]; then
			pushd "$(basename "${targeting_pack}")"
			for version in "${targeting_pack}"/*; do
				if [[ ! -e "$(basename "${version}")" ]]; then
					ln -fsv "${version}" .
				fi
			done
			popd
		else
			ln -fsv "${targeting_pack}" .
		fi
	done

	# 我们的（较旧的）SDK 有时与 Microsoft（较新的）SDK 不同步
	# 通常会导致在非官方支持的 RID 上构建失败，例如：linux-bionic-x86
	# 所以我们需要将最新版本指向我们拥有的旧版本
	local dotnet_runtime_versions=$(dotnet --list-runtimes | awk '{ print $2 }' | sort -Vu)
	local latest_dotnet8_version=$(echo "${dotnet_runtime_versions}" | grep "^8.0." | tail -n1)
	local latest_dotnet9_version=$(echo "${dotnet_runtime_versions}" | grep "^9.0." | tail -n1)
	for targeting_pack in "${HOME}"/.dotnet/packs/*; do
		if [[ -d "$(basename "${targeting_pack}")" ]]; then
			pushd "$(basename "${targeting_pack}")"
			for version in "${targeting_pack}"/*; do
				if [[ "$(basename "${version}")" == "8.0."* ]]; then
					if [[ -n "${latest_dotnet8_version}" && "$(basename "${version}")" != "${latest_dotnet8_version}" ]]; then
						rm -fr "${latest_dotnet8_version}"
						ln -fsvT "$(basename "${version}")" "${latest_dotnet8_version}"
					fi
				fi
				if [[ "$(basename "${version}")" == "9.0."* ]]; then
					if [[ -n "${latest_dotnet9_version}" && "$(basename "${version}")" != "${latest_dotnet9_version}" ]]; then
						rm -fr "${latest_dotnet9_version}"
						ln -fsvT "$(basename "${version}")" "${latest_dotnet9_version}"
					fi
				fi
			done
			popd
		fi
	done

	popd

	pushd "${HOME}/.dotnet"
	echo "信息：已安装的符号链接："
	find ./packs -mindepth 1 -maxdepth 3 -type l | sort
	popd
}

termux_dotnet_kill() {
	# 当 "dotnet build-server shutdown" 不够时
	local dotnet_process
	dotnet_process="$(pgrep -a dotnet)" || return 0
	echo "警告：发现悬挂进程，正在强制终止"
	echo "${dotnet_process}"
	pkill -9 dotnet || :
}
