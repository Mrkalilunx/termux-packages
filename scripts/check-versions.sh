#!/usr/bin/env bash
# check-versions.sh - 用于在浏览器中打开包以检查其版本的脚本

OPEN=xdg-open
if [ $(uname) = Darwin ]; then OPEN=open; fi

check_package() { # 路径
	local path=$1
	local pkg=$(basename $path)
	. $path/build.sh
	echo -n "$pkg - $TERMUX_PKG_VERSION"
	read
	$OPEN $TERMUX_PKG_HOMEPAGE
}

# 在单独的进程中运行每个包，因为我们包含它们的环境变量：
for path in packages/*; do
(
	check_package $path
)
done
