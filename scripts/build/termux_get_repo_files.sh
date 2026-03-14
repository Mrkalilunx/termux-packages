termux_get_repo_files() {
	local PACKAGES_HASH RELEASE_FILE repo_base dl_prefix RELEASE_FILE_URL RELEASE_FILE_SIG_URL
	local -a pids=()
	# 对于设备上构建或构建依赖项时不需要。
	if [[ "$TERMUX_ON_DEVICE_BUILD" = "true" || "$TERMUX_INSTALL_DEPS" = "false" ]]; then
		return
	fi

	[[ "${CI-false}" == "true" ]] && echo "::group::INFO: Fetching repo metadata" || :

	for idx in "${!TERMUX_REPO_URL[@]}"; do
		local TERMUX_REPO_NAME="${TERMUX_REPO_URL[$idx]#https://}"
		TERMUX_REPO_NAME="${TERMUX_REPO_NAME#http://}"
		TERMUX_REPO_NAME="${TERMUX_REPO_NAME//\//-}"
		case "$TERMUX_REPO_PKG_FORMAT" in
		"debian")
			RELEASE_FILE="${TERMUX_COMMON_CACHEDIR}/${TERMUX_REPO_NAME}-${TERMUX_REPO_DISTRIBUTION[$idx]}-Release"
			repo_base="${TERMUX_REPO_URL[$idx]}/dists/${TERMUX_REPO_DISTRIBUTION[$idx]}"
			dl_prefix="${TERMUX_REPO_NAME}-${TERMUX_REPO_DISTRIBUTION[$idx]}-${TERMUX_REPO_COMPONENT[$idx]}"
			RELEASE_FILE_URL="${repo_base}/Release"
			RELEASE_FILE_SIG_URL="${RELEASE_FILE_URL}.gpg"
			;;
		"pacman")
			RELEASE_FILE="${TERMUX_COMMON_CACHEDIR}-${TERMUX_ARCH}/${TERMUX_REPO_NAME}-json"
			repo_base="${TERMUX_REPO_URL[$idx]}/${TERMUX_ARCH}"
			RELEASE_FILE_URL="${repo_base}/${TERMUX_REPO_DISTRIBUTION[$idx]}.json"
			RELEASE_FILE_SIG_URL="${RELEASE_FILE_URL}.sig"
			;;
		*) termux_error_exit "Invalid package format: $TERMUX_REPO_PKG_FORMAT"
			;;
		esac

		(
			local attempt delay=5
			if [[ "${CI-false}" == "true" ]]; then
				delay=30
			fi
			for attempt in {1..6}; do
				if termux_download "${RELEASE_FILE_URL}" "${RELEASE_FILE}" SKIP_CHECKSUM \
						&& termux_download "${RELEASE_FILE_SIG_URL}" "${RELEASE_FILE}.gpg" SKIP_CHECKSUM; then
					if ! gpg --verify "${RELEASE_FILE}.gpg" "${RELEASE_FILE}"; then
						echo "GPG verification failed, probably we downloaded corrupted metadata. Retrying in $delay seconds."
						sleep "$delay"
						continue
					fi

					if [[ "$TERMUX_REPO_PKG_FORMAT" == "debian" ]]; then
						for arch in all "${TERMUX_ARCH}"; do
							PACKAGES_HASH="$(./scripts/get_hash_from_file.py "${RELEASE_FILE}" "${arch}" "${TERMUX_REPO_COMPONENT[$idx]}")"

							# 如果 packages_hash = ""，则仓库可能不包含 $arch 的 deb
							[[ -n "$PACKAGES_HASH" ]] && \
								termux_download "${repo_base}/${TERMUX_REPO_COMPONENT[$idx]}/binary-$arch/Packages" \
										"${TERMUX_COMMON_CACHEDIR}-$arch/${dl_prefix}-Packages" "$PACKAGES_HASH" && \
								exit 0
						done
					fi
					exit 0
				fi
			done
			termux_error_exit "Failed to download package repository metadata. Try to build without -i/-I option."
		) 2>&1 | (
			set +e
			# curl 进度表使用回车而不是换行符，修复它
			sed -u 's/\r/\n/g' | while :; do
				local buffer=()
				# 半秒缓冲区以防止混合行并使输出一致。
				sleep 0.5;
				while :; do
					# 带有 0 超时的 read 不会读取任何数据，因此给出最小超时
					IFS='' read -t 0.001 -r line; rc=$?
					# 在开头追加作业名称以跟踪多个作业
					[[ $rc == 0 ]] && buffer+=( "[$TERMUX_REPO_NAME]: $line" )
					# 可能是 EOF 或超时
					[[ $rc == 1 || $rc -ge 128 ]] && break
				done

				# 通过使用 stdout 作为锁文件来防止输出混乱
				[[ "${#buffer[@]}" -ge 1 ]] && flock --no-fork . printf "%s\n" "${buffer[@]}"
				[[ $rc == 1 ]] && break # 在 EOF 时退出
			done
		) &
		pids+=( $! )
	done

	for _ in "${pids[@]}"; do
		if ! wait -n; then
			# 其中一个作业以非零状态退出，我们也应该返回错误。
			kill "${pids[@]}" 2>/dev/null
			exit 1
		fi
	done
	[[ "${CI-false}" == "true" ]] && echo "::endgroup::" || :
}
