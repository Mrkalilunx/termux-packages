termux_setup_nodejs() {
	export NODE_OPTIONS=""
	# 当我们将 nodejs 版本更新到 v26 时，这应该不再需要
	# 这是 v25.2.0 之后的默认值，第一个包含它的 LTS 版本将是 v26
	# 参考：https://github.com/nodejs/node/commit/506b79e888
	NODE_OPTIONS+=" --network-family-autoselection-attempt-timeout=500"
	# 目前使用 LTS 版本
	local NODEJS_VERSION=22.22.1
	local NODEJS_FOLDER

	if [ "${TERMUX_PACKAGES_OFFLINE-false}" = "true" ]; then
		NODEJS_FOLDER=${TERMUX_SCRIPTDIR}/build-tools/nodejs-${NODEJS_VERSION}
	else
		NODEJS_FOLDER=${TERMUX_COMMON_CACHEDIR}/nodejs-$NODEJS_VERSION
	fi

	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		if [ ! -x "$NODEJS_FOLDER/bin/node" ]; then
			mkdir -p "$NODEJS_FOLDER"
			local NODEJS_TAR_FILE=$TERMUX_PKG_TMPDIR/nodejs-$NODEJS_VERSION.tar.xz
			termux_download https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz \
				"$NODEJS_TAR_FILE" \
				9a6bc82f9b491279147219f6a18add1e18424dce90d41d2a5fcd69d4924ba3aa
			tar -xf "$NODEJS_TAR_FILE" -C "$NODEJS_FOLDER" --strip-components=1
		fi
		export PATH=$NODEJS_FOLDER/bin:$PATH
	else
		local NODEJS_PKG_VERSION=$(bash -c ". $TERMUX_SCRIPTDIR/packages/nodejs/build.sh; echo \$TERMUX_PKG_VERSION")
		if ([ ! -e "$TERMUX_BUILT_PACKAGES_DIRECTORY/nodejs" ] ||
		    [ "$(cat "$TERMUX_BUILT_PACKAGES_DIRECTORY/nodejs")" != "$NODEJS_PKG_VERSION" ]) &&
		   ([[ "$TERMUX_APP_PACKAGE_MANAGER" = "apt" && "$(dpkg-query -W -f '${db:Status-Status}\n' nodejs 2>/dev/null)" != "installed" ]] ||
		    [[ "$TERMUX_APP_PACKAGE_MANAGER" = "pacman" && ! "$(pacman -Q nodejs 2>/dev/null)" ]]); then
			echo "未安装 'nodejs' 软件包。"
			echo "您可以通过以下方式安装："
			echo
			echo "  pkg install nodejs"
			echo
			echo "  pacman -S nodejs"
			echo
			echo "或从源代码构建："
			echo
			echo "  ./build-package.sh nodejs"
			echo
			exit 1
		fi
	fi
}
