#!/usr/bin/env bash
# check-pie.sh - 检测非 PIE 二进制文件的脚本（在 Android 上不起作用）

. $(dirname "$(realpath "$0")")/properties.sh

cd ${TERMUX_PREFIX}/bin

for file in *; do
	if readelf -h $file 2>/dev/null | grep -q 'Type:[[:space:]]*EXEC'; then
		echo $file
	fi
done
