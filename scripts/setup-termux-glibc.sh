#!/bin/bash

. $(dirname "$(realpath "$0")")/properties.sh
source "$TERMUX_PREFIX/bin/termux-setup-package-manager" || true

if [ "$TERMUX_APP_PACKAGE_MANAGER" = "apt" ]; then
	echo "错误：apt 没有 glibc 包"
	exit 1
elif [ "$TERMUX_APP_PACKAGE_MANAGER" = "pacman" ]; then
	if $(pacman-conf -r gpkg-dev &> /dev/null); then
		pacman -Syu gpkg-dev --needed --noconfirm
	else
		echo "错误：未找到 glibc 包仓库（目前只有 gpkg-dev）"
		exit 1
	fi
else
	echo "错误：未定义包管理器"
	exit 1
fi
