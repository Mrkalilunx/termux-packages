termux_git_clone_src() {
	local TMP_CHECKOUT=$TERMUX_PKG_CACHEDIR/tmp-checkout
	local TMP_CHECKOUT_VERSION=$TERMUX_PKG_CACHEDIR/tmp-checkout-version
	local termux_pkg_srcurl="${TERMUX_PKG_SRCURL:4}"
	local termux_pkg_local_srcpath=""
	local termux_pkg_branch_flags=""

	if [[ "$termux_pkg_srcurl" =~ ^file://(/[^/]+)+$ ]]; then
		termux_pkg_local_srcpath="${termux_pkg_srcurl:7}" # 移除 `file://` 前缀

		if [ ! -d "$termux_pkg_local_srcpath" ]; then
			echo "在包 '$TERMUX_PKG_NAME' 的 TERMUX_PKG_SRCURL 路径 '$TERMUX_PKG_SRCURL' 处未找到源码目录"
			return 1
		elif [ ! -d "$termux_pkg_local_srcpath/.git" ]; then
			echo "包 '$TERMUX_PKG_NAME' 的 TERMUX_PKG_SRCURL 路径 '$TERMUX_PKG_SRCURL' 处的源码目录不包含 '.git' 子目录"
			return 1
		fi
	fi

	if [ ! -f $TMP_CHECKOUT_VERSION ] || [ "$(cat $TMP_CHECKOUT_VERSION)" != "$TERMUX_PKG_VERSION" ]; then
		if [[ -n "$termux_pkg_local_srcpath" ]]; then
			if [ "$TERMUX_PKG_GIT_BRANCH" != "" ]; then
				# 需要克隆的本地 git 仓库可能
				# 没有创建跟踪其远程分支的分支，
				# 因此如果不存在则创建它，而不
				# 进行检出，否则当我们下面克隆时，
				# git 将无法在其自己的 origin 中找到该分支
				# 即本地 git 仓库，因为它不会
				# 递归地查看本地 git 仓库的 origin。
				(cd "$termux_pkg_local_srcpath" && git fetch origin $TERMUX_PKG_GIT_BRANCH:$TERMUX_PKG_GIT_BRANCH)
				termux_pkg_branch_flags="--branch $TERMUX_PKG_GIT_BRANCH"
			fi
		else
			if [ "$TERMUX_PKG_GIT_BRANCH" == "" ]; then
				termux_pkg_branch_flags="--branch v${TERMUX_PKG_VERSION#*:}"
			else
				termux_pkg_branch_flags="--branch $TERMUX_PKG_GIT_BRANCH"
			fi
		fi

		echo "正在从 '$termux_pkg_srcurl' 下载 git 源码 $([[ "$termux_pkg_branch_flags" != "" ]] && echo "（分支 '${termux_pkg_branch_flags:9}'）")"

		rm -rf "$TMP_CHECKOUT"
		git clone \
			--depth 1 \
			$termux_pkg_branch_flags \
			"$termux_pkg_srcurl" \
			"$TMP_CHECKOUT"

		pushd "$TMP_CHECKOUT"

		# 解决某些服务器的不良行为
		# 错误：服务器不允许请求未公开的对象 commit_no
		# 致命错误：在子模块 'submodule_path' 中获取，但它不包含 commit_no。直接获取该提交失败。
		if ! git submodule update --init --recursive --depth=1; then
			local depth=10
			local maxdepth=100
			sleep 1
			while :; do
				echo "警告：正在以最大深度 $depth 重试"
				if git submodule update --init --recursive --depth=$depth; then
					break
				fi
				if [[ "$depth" -gt "$maxdepth" ]]; then
					termux_error_exit "克隆子模块失败"
				fi
				depth=$((depth+10))
				sleep 1
			done
		fi

		popd

		echo "$TERMUX_PKG_VERSION" > "$TMP_CHECKOUT_VERSION"
	else
		echo "已跳过从 '$termux_pkg_srcurl' 下载 git 源码"
	fi

	rm -rf "$TERMUX_PKG_SRCDIR"
	cp -Rf "$TMP_CHECKOUT" "$TERMUX_PKG_SRCDIR"
}
