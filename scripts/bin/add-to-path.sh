# Source 此脚本以使 bin 目录的内容在 $PATH 中可用。仅在 Bash 下使用！

if [ -z "${BASH}" ]; then
	echo "无法 source，因为您的 shell 不是 Bash！"
else
	TERMUX_BINPATH=$(realpath "$(dirname "${BASH_SOURCE}")")
	PATH="${TERMUX_BINPATH}:${PATH}"
	export PATH
	echo "'$TERMUX_BINPATH' 中的脚本现在在您的 \$PATH 中可用。"
	unset TERMUX_BINPATH
fi
