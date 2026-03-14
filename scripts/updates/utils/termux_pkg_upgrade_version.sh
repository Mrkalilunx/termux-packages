# shellcheck shell=bash
_termux_should_cleanup() {
	local space_available big_package="$1"
	[[ "${big_package}" == "true" ]] && return 0 # true

	if [[ -d "/var/lib/docker" ]]; then
		# 获取可用空间（以字节为单位）
		space_available="$(df "/var/lib/docker" | awk 'NR==2 { print $4 * 1024 }')"

		if (( space_available <= TERMUX_CLEANUP_BUILT_PACKAGES_THRESHOLD )); then
			return 0 # true
		fi
	fi

	return 1 # false
}

termux_pkg_upgrade_version() {
	if (( $# < 1 )); then
		termux_error_exit <<-EndUsage
			用法：${FUNCNAME[0]} LATEST_VERSION [--skip-version-check]
			还在文件描述符 3 上报告完全解析的 LATEST_VERSION
		EndUsage
	fi

	local LATEST_VERSION SKIP_VERSION_CHECK EPOCH
	LATEST_VERSION="$(sort -rV <<< "$1")" # 确保其按降序排列。
	SKIP_VERSION_CHECK="${2:-}"
	EPOCH="${TERMUX_PKG_VERSION%%:*}" # 如果没有 epoch，这将是完整版本。
	# 检查它是否不是完整版本并添加 ':'。
	if [[ "${EPOCH}" != "${TERMUX_PKG_VERSION}" ]]; then
		EPOCH="${EPOCH}:"
	else
		EPOCH=""
	fi

	# 如果需要，使用 grep 正则表达式过滤版本号。
	if [[ -n "${TERMUX_PKG_UPDATE_VERSION_REGEXP:-}" ]]; then
		# 提取版本号。
		local ORIGINAL_LATEST_VERSION="${LATEST_VERSION}"
		LATEST_VERSION="$(grep --max-count=1 -oP "${TERMUX_PKG_UPDATE_VERSION_REGEXP}" <<< "${LATEST_VERSION}" || :)"
		if [[ -z "${LATEST_VERSION:-}" ]]; then
			termux_error_exit <<-EndOfError
				错误：无法为 '${TERMUX_PKG_NAME}' 过滤版本号。
				确保 '${TERMUX_PKG_UPDATE_VERSION_REGEXP}' 正确匹配 '${ORIGINAL_LATEST_VERSION}'。
			EndOfError
		fi
		unset ORIGINAL_LATEST_VERSION
	fi

	# 如果需要，使用 sed 正则表达式过滤版本号。
	if [[ -n "${TERMUX_PKG_UPDATE_VERSION_SED_REGEXP:-}" ]]; then
		# 提取版本号。
		local ORIGINAL_LATEST_VERSION="${LATEST_VERSION}"
		LATEST_VERSION="$(sed -E "${TERMUX_PKG_UPDATE_VERSION_SED_REGEXP}" <<< "${LATEST_VERSION}" || :)"
		if [[ -z "${LATEST_VERSION:-}" ]]; then
			termux_error_exit <<-EndOfError
				错误：无法为 '${TERMUX_PKG_NAME}' 过滤版本号。
				确保 '${TERMUX_PKG_UPDATE_VERSION_SED_REGEXP}' 正确匹配 '${ORIGINAL_LATEST_VERSION}'。
			EndOfError
		fi
		unset ORIGINAL_LATEST_VERSION
	fi

	# 删除任何前导非数字，因为那不会是有效的版本。
	# shellcheck disable=SC2001 # 这是参数扩展无法很好处理的事情，所以我们使用 sed。
	LATEST_VERSION="$(sed -e "s/^[^0-9]*//" <<< "$LATEST_VERSION")"

	# 将 "_" 转换为 "."：某些包使用下划线分隔
	# 版本号，但我们要求它们用点分隔。
	LATEST_VERSION="${LATEST_VERSION//_/.}"

	# 将 "-suffix" 转换为 "~suffix"："X.Y.Z-suffix" 被认为比
	# X.Y.Z 晚，要让它被认为更早，使用 "X.Y.Z~suffix"。
	for suffix in "rc" "alpha" "beta"; do
		LATEST_VERSION="$(sed -E "s/[-.]?(${suffix}[0-9]*)/~\1/ig" <<< "$LATEST_VERSION")"
	done

	# 如果 FD 3 打开，使用它来报告完全解析的 $LATEST_VERSION
	# 如果未打开，使用 brace 组以便能够
	# 静默丢弃 `3: Bad file descriptor` 错误。
	{ echo "$LATEST_VERSION" >&3; } 2> /dev/null

	if [[ "${SKIP_VERSION_CHECK}" != "--skip-version-check" ]]; then
		if ! termux_pkg_is_update_needed \
			"${TERMUX_PKG_VERSION#*:}" "${LATEST_VERSION}"; then
			echo "信息：无需更新。已经是版本 '${LATEST_VERSION}'。"
			return 0
		fi
	fi

	if [[ -n "${TERMUX_PKG_UPGRADE_VERSION_DRY_RUN:-}" ]]; then
		return 1
	fi

	if [[ "${BUILD_PACKAGES}" == "false" ]]; then
		echo "信息：包需要更新到 ${LATEST_VERSION}。"
		return
	fi

	echo "信息：包正在更新到 ${LATEST_VERSION}。"

	sed \
		-e "s/^\(TERMUX_PKG_VERSION=\)\(.*\)\$/\1\"${EPOCH}${LATEST_VERSION}\"/g" \
		-e "/TERMUX_PKG_REVISION=/d" \
		-i "${TERMUX_PKG_BUILDER_DIR}/build.sh"

	# 更新校验和
	if [[ "${TERMUX_PKG_SHA256[*]}" != "SKIP_CHECKSUM" && "${TERMUX_PKG_SRCURL:0:4}" != "git+" ]]; then
		echo n | "${TERMUX_SCRIPTDIR}/scripts/bin/update-checksum" "${TERMUX_PKG_NAME}" || {
			git checkout -- "${TERMUX_SCRIPTDIR}"
			git pull --rebase --autostash
			termux_error_exit "无法更新校验和。"
		}
	fi

	echo "信息：正在尝试构建包。"

	for repo_path in $(jq --raw-output 'del(.pkg_format) | keys | .[]' "${TERMUX_SCRIPTDIR}/repo.json"); do
		_buildsh_path="${TERMUX_SCRIPTDIR}/${repo_path}/${TERMUX_PKG_NAME}/build.sh"
		repo="$(jq --raw-output ".\"${repo_path}\".name" "${TERMUX_SCRIPTDIR}/repo.json")"
		repo="${repo#"termux-"}"

		if [[ -f "${_buildsh_path}" ]]; then
			echo "信息：包 ${TERMUX_PKG_NAME} 存在于 ${repo} 仓库中。"
			unset _buildsh_path repo_path
			break
		fi
	done

	# 检查清理条件
	local big_package=false
	while IFS= read -r p; do
		if [[ "${p}" == "${TERMUX_PKG_NAME}" ]]; then
			big_package=true
			break
		fi
	done < "${TERMUX_SCRIPTDIR}/scripts/big-pkgs.list"

	_termux_should_cleanup "${big_package}" && "${TERMUX_SCRIPTDIR}/scripts/run-docker.sh" ./clean.sh

	if ! "${TERMUX_SCRIPTDIR}/scripts/run-docker.sh" -d ./build-package.sh -C -a "${TERMUX_ARCH}" -i "${TERMUX_PKG_NAME}"; then
		_termux_should_cleanup "${big_package}" && "${TERMUX_SCRIPTDIR}/scripts/run-docker.sh" ./clean.sh
		git checkout -- "${TERMUX_SCRIPTDIR}"
		termux_error_exit "构建失败。"
	fi

	_termux_should_cleanup "${big_package}" && "${TERMUX_SCRIPTDIR}/scripts/run-docker.sh" ./clean.sh

	if [[ "${GIT_COMMIT_PACKAGES}" == "true" ]]; then
		echo "信息：正在提交包。"
		stderr="$(
			git add \
				"${TERMUX_PKG_BUILDER_DIR}" \
				"${TERMUX_SCRIPTDIR}/scripts/build/setup/" \
				2>&1 >/dev/null
			git commit \
				-m "bump(${repo}/${TERMUX_PKG_NAME}): ${LATEST_VERSION}" \
				-m "此提交已由 Github Actions 自动提交。" \
				2>&1 >/dev/null
		)" || {
			git reset HEAD --hard
			termux_error_exit <<-EndOfError
			错误：git 提交失败。详细信息见下文。
			${stderr}
			EndOfError
		}
	fi

	if [[ "${GIT_PUSH_PACKAGES}" == "true" ]]; then
		echo "信息：正在推送包。"
		stderr="$(
			# 在尝试推送之前获取并拉取，以避免这种情况
			# 即长时间运行自动更新失败，因为稍后更快的
			# 自动更新先被提交，现在 git 历史已过时。
			git fetch 2>&1 >/dev/null
			git pull --rebase --autostash 2>&1 >/dev/null
			git push 2>&1 >/dev/null
		)" || {
			termux_error_exit <<-EndOfError
			错误：git 推送失败。详细信息见下文。
			${stderr}
			EndOfError
		}
	fi
}
