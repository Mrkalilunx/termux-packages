#!/bin/bash
# list-packages.sh - 列出所有包及其主页和描述的工具

show_package() {
	. $1/build.sh
	local pkg=$(basename $1)
	echo "$pkg($TERMUX_PKG_VERSION): $TERMUX_PKG_HOMEPAGE"
	echo "       $TERMUX_PKG_DESCRIPTION"
}

for path in packages/*; do
	( show_package $path )
done
