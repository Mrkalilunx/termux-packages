#!/usr/bin/bash

termux_download() {
	if [[ $# != 2 ]] && [[ $# != 3 ]]; then
		echo "termux_download()：无效参数 - 期望 <URL> <DESTINATION> [<CHECKSUM>]" 1>&2
		return 1
	fi
	local URL="$1"
	local DESTINATION="$2"
	local CHECKSUM="${3:-SKIP_CHECKSUM}"

	if [[ "$URL" =~ ^file://(/[^/]+)+$ ]]; then
		local source="${URL:7}" # 移除 `file://` 前缀

		if [ -d "$source" ]; then
			# 从本地目录创建 tar 文件
			echo "正在从 '$source' 下载本地源代码目录"
			rm -f "$DESTINATION"
			(cd "$(dirname "$source")" && tar -cf "$DESTINATION" --exclude=".git" "$(basename "$source")")
			return 0
		elif [ ! -f "$source" ]; then
			echo "在 URL '$URL' 的路径中未找到本地源文件"
			return 1
		else
			ln -sf "$source" "$DESTINATION"
			return 0
		fi
	fi

	if [ -f "$DESTINATION" ] && [ "$CHECKSUM" != "SKIP_CHECKSUM" ]; then
		# 如果校验和匹配，则保留现有文件。
		local EXISTING_CHECKSUM
		EXISTING_CHECKSUM=$(sha256sum "$DESTINATION" | cut -d' ' -f1)
		[[ "$EXISTING_CHECKSUM" == "$CHECKSUM" ]] && return
	fi

	local TMPFILE
	local -a CURL_OPTIONS=(
		--fail               # 将 4xx 和 5xx 响应视为失败
		--retry 5            # 在瞬态故障时最多重试 5 次
		--retry-connrefused  # 在连接被拒绝时也重试
		--retry-delay 5      # 重试之间等待 5 秒
		--connect-timeout 30 # 最多等待 30 秒建立连接
		--retry-max-time 120 # 如果 120 秒后仍然失败，则停止重试
		--speed-limit 1000   # 期望至少每秒 1000 字节
		--speed-time 60      # 如果在至少 60 秒内未达到最低速度，则失败
		--location           # 跟随重定向
	)
	TMPFILE=$(mktemp "$TERMUX_PKG_TMPDIR/download.${TERMUX_PKG_NAME-unnamed}.XXXXXXXXX")
	if [[ "${TERMUX_QUIET_BUILD-}" == "true" ]]; then
		CURL_OPTIONS+=(--no-progress-meter) # 不打印传输统计信息
	fi

	echo "正在下载 ${URL}"
	if ! curl "${CURL_OPTIONS[@]}" --output "$TMPFILE" "$URL"; then
		local error=1
		local retry=2
		local delay=60
		local try
		for (( try=1; try <= retry; try++ )); do
			echo "重试 #${try} 下载 ${URL} 在 ${delay} 秒后"
			sleep "${delay}"
			if curl "${CURL_OPTIONS[@]}" --output "$TMPFILE" "$URL"; then
				error=0
				break
			fi
		done
		if [[ "${error}" != 0 ]]; then
			echo "下载 $URL 失败" 1>&2
			return 1
		fi
	fi

	local ACTUAL_CHECKSUM
	ACTUAL_CHECKSUM=$(sha256sum "$TMPFILE" | cut -d' ' -f1)
	if [[ -z "$CHECKSUM" ]]; then
		printf "警告：没有 %s 的校验和检查：\n实际： %s\n" \
			"$URL" "$ACTUAL_CHECKSUM"
	elif [[ "$CHECKSUM" == "SKIP_CHECKSUM" ]]; then
		:
	elif [[ "$CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
		printf "%s 的校验和错误\n期望： %s\n实际：   %s\n" \
			"$URL" "$CHECKSUM" "$ACTUAL_CHECKSUM" 1>&2
		return 1
	fi
	mv "$TMPFILE" "$DESTINATION"
	return 0
}

# 使脚本既可以独立执行也可以 source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	termux_download "$@"
fi
