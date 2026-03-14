termux_extract_src_archive() {
	# STRIP=1 将归档文件直接解压到 TERMUX_PKG_SRCDIR，而 STRIP=0 将它们放入子文件夹。zip 默认具有相同的行为
	# 如果这不是期望的行为，可以在 termux_step_post_get_source 中修复。
	local STRIP=1
	local PKG_SRCURL=(${TERMUX_PKG_SRCURL[@]})
	for i in $(seq 0 $(( ${#PKG_SRCURL[@]}-1 ))); do
		local file="$TERMUX_PKG_CACHEDIR/$(basename "${PKG_SRCURL[$i]}")"
		local folder
		set +o pipefail
		if [ "${file##*.}" = zip ]; then
			folder=$(unzip -qql "$file" | head -n1 | tr -s ' ' | cut -d' ' -f5-)
			rm -Rf "$folder"
			unzip -q "$file"
			mv "$folder" "$TERMUX_PKG_SRCDIR"
		else
			test "$i" -gt 0 && STRIP=0
			mkdir -p "$TERMUX_PKG_SRCDIR"
			tar xf "$file" -C "$TERMUX_PKG_SRCDIR" --strip-components=$STRIP
		fi
		set -o pipefail
	done
}
