# shellcheck shell=bash disable=SC2155
termux_setup_xmake() {
	local XMAKE_VERSION=2.9.5
	local XMAKE_TGZ_URL=https://github.com/xmake-io/xmake/releases/download/v${XMAKE_VERSION}/xmake-v${XMAKE_VERSION}.tar.gz
	local XMAKE_TGZ_SHA256=03feb5787e22fab8dd40419ec3d84abd35abcd9f8a1b24c488c7eb571d6724c8
	local XMAKE_TGZ_FILE=${TERMUX_PKG_TMPDIR}/xmake-${XMAKE_VERSION}.tar.gz
	local XMAKE_FOLDER=${TERMUX_COMMON_CACHEDIR}/xmake-${XMAKE_VERSION}
	if [[ "${TERMUX_PACKAGES_OFFLINE-false}" == "true" ]]; then
		XMAKE_FOLDER=${TERMUX_SCRIPTDIR}/build-tools/xmake-${XMAKE_VERSION}
	fi
	local XMAKE_PKG_VERSION=$(. "${TERMUX_SCRIPTDIR}/packages/xmake/build.sh"; echo ${TERMUX_PKG_VERSION})

	if [[ "${TERMUX_ON_DEVICE_BUILD}" == "true" ]]; then
		if [[ "$(cat "${TERMUX_BUILT_PACKAGES_DIRECTORY}/xmake" 2>/dev/null)" != "${XMAKE_PKG_VERSION}" && -z "$(command -v xmake)" ]]; then
			cat <<- EOL >&2
			未安装 'xmake' 软件包。
			您可以通过以下方式安装：

			pkg install xmake

			或从源代码构建：

			./build-package.sh xmake
			EOL
			exit 1
		fi
		return
	fi

	# 始终假设主机构建，因为 xmake 不提供预构建的二进制文件
	# 不要使用 xmake-*.run，因为它使用单核构建并且
	# 自动安装到 ~/.local/{bin,share}

	if [[ ! -x "${XMAKE_FOLDER}/bin/xmake" ]]; then
		mkdir -p "${XMAKE_FOLDER}"
		termux_download "${XMAKE_TGZ_URL}" "${XMAKE_TGZ_FILE}" "${XMAKE_TGZ_SHA256}"
		tar -xf "${XMAKE_TGZ_FILE}" -C "${XMAKE_FOLDER}" --strip-components=1

		# xmake injects -m64 and -m32 when it shouldnt
		local files=$(grep -E "march = \"-m(32|64)" -nHR "${XMAKE_FOLDER}" | grep -E "gcc" | cut -d":" -f1 | sort)
		for f in ${files}; do
			echo "termux_setup_xmake: 正在修补 ${f}"
			sed -e "/.*march = \"-m.*/d" -i "${f}"
		done

		(
			# avoid pick up Termux pkg-config, stop link with Termux ncursesw
			unset AR AS CC CFLAGS CPP CPPFLAGS CXX CXXFLAGS LD LDFLAGS PREFIX TERMUX_ARCH
			export PATH="/usr/bin:$(echo -n $(tr ':' '\n' <<< "$PATH" | grep -v "^$TERMUX_PREFIX/bin$") | tr ' ' ':')"
			pushd "${XMAKE_FOLDER}"
			./configure --prefix="${XMAKE_FOLDER}"
			make -j"$(nproc)" install
			popd
		)
	fi

	export PATH="${XMAKE_FOLDER}/bin:${PATH}"
	if [[ -z "$(command -v xmake)" ]]; then
		termux_error_exit "termux_setup_xmake: No xmake executable found!"
	fi
}
