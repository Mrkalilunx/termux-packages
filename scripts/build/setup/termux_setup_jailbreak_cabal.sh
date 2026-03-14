# shellcheck shell=bash
# 用于设置 jailbreak-cabal 脚本的实用脚本。它被 haskell 构建系统使用，
# 用于删除 cabal 文件中的版本约束。
termux_setup_jailbreak_cabal() {
	if [[ "${TERMUX_ON_DEVICE_BUILD}" == "false" ]]; then
		local TERMUX_JAILBREAK_VERSION=1.3.5
		local TERMUX_JAILBREAK_TAR="${TERMUX_COMMON_CACHEDIR}/jailbreak-cabal-${TERMUX_JAILBREAK_VERSION}.tar.gz"
		local TERMUX_JAILBREAK_RUNTIME_FOLDER

		if [[ "${TERMUX_PACKAGES_OFFLINE-false}" == "true" ]]; then
			TERMUX_JAILBREAK_RUNTIME_FOLDER="${TERMUX_SCRIPTDIR}/build-tools/jailbreak-cabal-${TERMUX_JAILBREAK_VERSION}-runtime"
		else
			TERMUX_JAILBREAK_RUNTIME_FOLDER="${TERMUX_COMMON_CACHEDIR}/jailbreak-cabal-${TERMUX_JAILBREAK_VERSION}-runtime"
		fi

		export PATH="${TERMUX_JAILBREAK_RUNTIME_FOLDER}:${PATH}"

		[[ -d "${TERMUX_JAILBREAK_RUNTIME_FOLDER}" ]] && return

		termux_download "https://github.com/MrAdityaAlok/ghc-cross-tools/releases/download/jailbreak-cabal-v${TERMUX_JAILBREAK_VERSION}/jailbreak-cabal-${TERMUX_JAILBREAK_VERSION}.tar.xz" \
			"${TERMUX_JAILBREAK_TAR}" \
			"8d1a8b8fadf48f4abf42da025d5cf843bd68e1b3c18ecacdc0cd0c9bd470c64e"

		mkdir -p "${TERMUX_JAILBREAK_RUNTIME_FOLDER}"
		tar xf "${TERMUX_JAILBREAK_TAR}" -C "${TERMUX_JAILBREAK_RUNTIME_FOLDER}"

		rm "${TERMUX_JAILBREAK_TAR}"
	else
		if [[ "${TERMUX_APP_PACKAGE_MANAGER}" == "apt" ]] && "$(dpkg-query -W -f '${db:Status-Status}\n' jailbreak-cabal 2>/dev/null)" != "installed" ||
			[[ "${TERMUX_APP_PACKAGE_MANAGER}" = "pacman" ]] && ! "$(pacman -Q jailbreak-cabal 2>/dev/null)"; then
			echo "未安装 'jailbreak-cabal' 软件包。"
			exit 1
		fi
	fi
}
