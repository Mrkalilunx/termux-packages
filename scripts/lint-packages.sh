#!/usr/bin/env bash

set -e -u

start_time="$(date +%10s.%3N)"

TERMUX_SCRIPTDIR=$(realpath "$(dirname "$0")/../")
. "$TERMUX_SCRIPTDIR/scripts/properties.sh"

check_package_license() {
	local pkg_licenses license license_ok=true
	IFS=',' read -ra pkg_licenses <<< "${1//, /,}"

	for license in "${pkg_licenses[@]}"; do
		case "$license" in
			AFL-2.1|AFL-3.0|AGPL-V3|APL-1.0|APSL-2.0);;
			Apache-1.0|Apache-1.1|Apache-2.0|Artistic-License-2.0|Attribution);;
			BSD|"BSD 2-Clause"|"BSD 3-Clause"|"BSD New"|"BSD Simplified");;
			BSL-1.0|Bouncy-Castle|CA-TOSL-1.1|CC0-1.0|CDDL-1.0|CDDL-1.1|CPAL-1.0|CPL-1.0);;
			CPOL|CPOL-1.02|CUAOFFICE-1.0|CeCILL-1|CeCILL-2|CeCILL-2.1|CeCILL-B|CeCILL-C);;
			Codehaus|Copyfree|curl|Day|Day-Addendum|ECL2|EPL-1.0|EPL-2.0|EUDATAGRID);;
			EUPL-1.1|EUPL-1.2|Eiffel-2.0|Entessa-1.0|Facebook-Platform|Fair|Frameworx-1.0);;
			GPL-2.0|GPL-2.0-only|GPL-2.0-or-later);;
			GPL-3.0|GPL-3.0-only|GPL-3.0-or-later);;
			Go|hdparm|HPND|HSQLDB|Historical|IBMPL-1.0|IJG|IPAFont-1.0);;
			ISC|IU-Extreme-1.1.1|ImageMagick|JA-SIG|JSON|JTidy);;
			LGPL-2.0|LGPL-2.0-only|LGPL-2.0-or-later);;
			LGPL-2.1|LGPL-2.1-only|LGPL-2.1-or-later);;
			LGPL-3.0|LGPL-3.0-only|LGPL-3.0-or-later);;
			LPPL-1.0|Libpng|Lucent-1.02|MIT|MPL-2.0|MS-PL|MS-RL|MirOS|Motosoto-0.9.1);;
			Mozilla-1.1|Multics|NASA-1.3|NAUMEN|NCSA|NOSL-3.0|NTP|NUnit-2.6.3);;
			NUnit-Test-Adapter-2.6.3|Nethack|Nokia-1.0a|OCLC-2.0|OSL-3.0|OpenLDAP);;
			OpenSSL|OFL-1.1|Opengroup|PHP-3.0|PHP-3.01|PostgreSQL);;
			"Public Domain"|"Public Domain - SUN"|PythonPL|PythonSoftFoundation);;
			QTPL-1.0|RPL-1.5|Real-1.0|RicohPL|SUNPublic-1.0|Scala|SimPL-2.0|Sleepycat);;
			Sybase-1.0|TMate|UPL-1.0|Unicode-DFS-2015|Unlicense|UoI-NCSA|"VIM License");;
			VovidaPL-1.0|W3C|WTFPL|wxWindows|X11|Xnet|ZLIB|ZPL-2.0);;

			*)
				license_ok=false
				break
			;;
		esac
	done

	if [[ "$license_ok" == 'false' ]]; then
		echo "INVALID"
		return 1
	fi

	echo "PASS"
	return 0
}

check_package_name() {
	local pkg_name="$1"
	echo -n "包名称 '${pkg_name}'： "
	# 1 个字符的包名称在技术上被 `dpkg` 允许
	# 但我们不希望允许单字母包。
	if (( ${#pkg_name} < 2 )); then
		echo "无效（长度少于两个字符）"
		return 1
	fi

	if ! dpkg --validate-pkgname "${pkg_name}" &> /dev/null; then
		echo "无效 ($(dpkg --validate-pkgname "${pkg_name}"))"
		return 1
	fi

	echo "通过"
	return 0
}

check_indentation() {
	local pkg_script="$1"
	local line='' heredoc_terminator='' in_array=0 i=0
	local -a issues=('' '') bad_lines=('失败')
	local heredoc_regex="[^\(/%#]<{2}-?[[:space:]]*(['\"]?([[:alnum:]_]*(\\\.)?)*['\"]?)"
	# 我们不想用这个匹配版本约束 "(<< x.y.z)"，所以不要匹配 "(<<"。
	# 我们也不想匹配参数扩展 "${var/<<}", ${var%<<}, ${var#<<}

	# 解析前导空白
	while IFS=$'\n' read -r line; do
		((i++))

		# 确保它是 heredoc，而不是 herestring
		if [[ "$line" != *'<<<'* ]]; then
			# 在 heredocs 内完全跳过此检查
			[[ "$line" =~ $heredoc_regex ]] && {
				heredoc_terminator="${BASH_REMATCH[1]}"
			}

			[[ -n ${heredoc_terminator}  && "$line" == [[:space:]]*"${heredoc_terminator//[\'\"]}" ]] && {
				heredoc_terminator=''
			}
			(( ${#heredoc_terminator} )) && continue
		fi

		# 检查混合缩进。
		# 我们在 heredoc 检查之后执行此操作，因为空格缩进
		# 对于 Haskell 或 Nim 等语言很重要。
		# 那些可能不应该内联为 heredocs，
		# 但 Haskell `cabal.project.local` 覆盖目前是。
		# 所以让我们不要为此破坏构建。
		[[ "$line" =~ ^($'\t'+ +| +$'\t'+) ]] && {
			issues[0]='混合缩进'
			bad_lines[i]="${pkg_script}:${i}:$line"
		}

		[[ "$line" == *'=('* ]] && in_array=1

		# 用于缩进的空格可以用于对齐数组
		[[ "$in_array" == 0 && "$line" == " "* ]] && {
			# 但否则我们使用空格
			issues[1]='使用制表符进行缩进'
			bad_lines[i]="${pkg_script}:${i}:$line"
		}

		[[ "$line" == *')' ]] && in_array=0
	done < "$pkg_script"

	# 如果我们发现问题，打印它们并抛出错误
	(( ${#issues[0]} || ${#issues[1]} )) && {
		printf '%s\n' "${bad_lines[@]}"
		printf '%s\n' "${issues[@]}"
		return 1
	}
	return 0
}

{
	# We'll need the origin/master HEAD commit as a base commit when running the version check.
	# So try fetching it now.
	if origin_url="$(git config --get remote.origin.url)"; then
		git fetch "${origin_url}" || {
			echo "ERROR: Unable to fetch '${origin_url}'"
			echo "Falling back to HEAD~1"
		}
	else
		origin_url="unknown"
	fi

	base_commit="$(git rev-list "origin/master.." --exclude-first-parent-only --reverse | head -n1)"
	# On the master branch or failure `git rev-list "origin/master.."`
	# won't return a commit, so set "HEAD" as a default value.
	: "${base_commit:="HEAD"}"
} 2> /dev/null

# Also figure out if we have a `%ci:no-build` trailer in the commit range,
# we may skip some checks later if yes.
no_build="$(git log --fixed-strings --grep '%ci:no-build' --pretty=format:%H "$base_commit..")"

check_version() {
	# !!! vvv 临时 - 修复此函数时删除 vvv !!!
	return
	# !!! ^^^ 临时 - 修复此函数时删除 ^^^ !!!
	local package_dir="${1%/*}"

	[[ -z "$base_commit" ]] && {
		printf '%s\n' "失败" \
			"无法确定 'origin/master' 的 HEAD 提交。" \
			"这不应该发生..."
		ls -AR "$TERMUX_SCRIPTDIR/.git/refs/remotes/origin"
		return 1
	} >&2

	# 如果 TERMUX_PKG_VERSION 是数组，则更改格式。
	local version i=0 error=0 is_array="${TERMUX_PKG_VERSION@a}"
	printf '%s' "${is_array:+$'ARRAY\n'}"

	for version in "${TERMUX_PKG_VERSION[@]}"; do
		printf '%s' "${is_array:+$'\t'}"

		# 此版本是否有效？
		dpkg --validate-version "${version}" &> /dev/null || {
			printf '无效 %s\n' "$(dpkg --validate-version "${version}" 2>&1)"
			(( error++ ))
			continue
		}

		local version_new version_old
		version_new="${version}-${TERMUX_PKG_REVISION:-0}"
		version_old=$(
			unset TERMUX_PKG_VERSION TERMUX_PKG_REVISION
			# shellcheck source=/dev/null
			. <(git -P show "${base_commit}:${package_dir}/build.sh" 2> /dev/null)
			# ${TERMUX_PKG_VERSION[0]} also works fine for non-array versions.
			# Since those resolve in 1 iteration, no higher index is ever attempted to be called.
			echo "${TERMUX_PKG_VERSION[$i]:-0}-${TERMUX_PKG_REVISION:-0}"
		)

		# Is ${version_old} valid?
		local version_old_is_bad=""
		dpkg --validate-version "${version_old}" &> /dev/null || version_old_is_bad="0~invalid"

		# The rest of the checks aren't useful past the first index when $TERMUX_PKG_VERSION is an array
		# since that is the index that determines the actual version.
		if (( i++ > 0 )); then
			echo "PASS - ${version_old%-0}${version_old_is_bad:+" (INVALID)"} -> ${version_new%-0}"
			continue
		fi

		# 包是否在此分支中修改？
		git diff --no-merges --exit-code "${base_commit}" -- "${package_dir}" &> /dev/null && {
			printf '%s\n' "通过 - ${version_new%-0}（在此分支中未修改）"
			return 0
		}

		[[ -n "$no_build" ]] && {
			echo "跳过 - ${version_new%-0}（在提交 ${no_build::7} 上检测到 '%ci:no-build' 标签）"
			return 0
		}

		# 如果 ${version_new} 不大于 "$version_old"，则是一个问题。
		# 如果 ${version_old} 无效，此检查是无操作。
		if dpkg --compare-versions "$version_new" le "${version_old_is_bad:-$version_old}"; then
			printf '%s\n' \
				"失败 ${version_old_is_bad:-$version_old} -> ${version_new}" \
				"" \
				"'$package_name' 的版本未增加。" \
				"在更改包构建时，'TERMUX_PKG_VERSION' 或 'TERMUX_PKG_REVISION'" \
				"需要在 build.sh 中修改。" \
				"您可以使用 ./scripts/bin/revbump '$package_name' 自动执行此操作。"

			# 如果版本降低了，提供如何降级包的建议
			dpkg --compare-versions "$version_new" lt "$version_old" && \
			printf '%s\n' \
				"" \
				"- 如果您正在将 '$package_name' 恢复到旧版本，请使用 '+really' 后缀" \
				"例如：TERMUX_PKG_VERSION=${version_new%-*}+really${version_old%-*}" \
				"- 如果 ${package_name} 的版本方案已完全更改，则可能需要一个 epoch。" \
				"更多信息请参阅：" \
				"https://www.debian.org/doc/debian-policy/ch-controlfields.html#epochs-should-be-used-sparingly"

			echo ""
			return 1
		fi

		local new_revision="${version_new##*-}" old_revision="${version_old##*-}"

		# 如果版本未更改，修订号必须增加 1
		# 减少或不增加将在上面被捕获。
		# 但我们要另外强制顺序增加。
		if [[ "${version_new%-*}" == "${version_old%-*}" && "$new_revision" != "$((old_revision + 1))" ]]; then
			(( error++ )) # 未顺序增加
			printf '%s\n' "失败 " \
				"TERMUX_PKG_REVISION 应该顺序增加" \
				"当在没有新上游版本的情况下重新构建包时。" \
				"" \
				"得到：     ${version_old} -> ${version_new}" \
				"预期：${version_old} -> ${version}-$((old_revision + 1))"
			continue
		# 如果该检查通过，TERMUX_PKG_VERSION 必须已更改，
		# 在这种情况下，TERMUX_PKG_REVISION 应该重置为 0。
		elif [[ "${version_new%-*}" != "${version_old%-*}" && "$new_revision" != "0" ]]; then
			(( error++ )) # 未重置
			printf '%s\n' \
				"失败 - $version_old -> $version_new" \
				"" \
				"TERMUX_PKG_VERSION 已升级，但 TERMUX_PKG_REVISION 未重置。" \
				"请删除 'TERMUX_PKG_REVISION=${new_revision}' 行。" \
				""
			continue
		fi

		echo "PASS - ${version_old%-0}${version_old_is_bad:+" (INVALID)"} -> ${version_new%-0}"
	done
	return $error
}

lint_package() {
	local package_script package_name

	package_script="$1"
	package_name="$(basename "$(dirname "$package_script")")"

	echo "================================================================"
	echo
	echo "包：$package_name"
	echo

	echo -n "布局： "
	local channel in_dir=''
	for channel in $TERMUX_PACKAGES_DIRECTORIES; do
		[[ -d "$TERMUX_SCRIPTDIR/$channel/$package_name" ]] && {
			in_dir="$TERMUX_SCRIPTDIR/$channel/$package_name"
			break
		}
	done
	(( ! ${#in_dir} )) && {
		echo "失败 - '$package_script' 不是目录"
		return 1
	}

	[[ -f "${in_dir}/build.sh" ]] || {
		echo "失败 - 包 '$package_name' 中没有 build.sh 文件"
		return 1
	}
	echo "通过"

	check_package_name "$package_name" || return 1
	local subpkg_script subpkg_name
	for subpkg_script in "$(dirname "$package_script")"/*.subpackage.sh; do
		[[ ! -f "$subpkg_script" ]] && continue
		subpkg_name="$(basename "${subpkg_script%.subpackage.sh}")"
		check_package_name "$subpkg_name" || return 1
	done

	echo -n "行尾检查： "
	local last2octet
	read -r _ last2octet _ < <(xxd -s -2 "$package_script")
	if [[ "$last2octet" == "0a0a" ]]; then
		echo -e "失败（末尾有重复的换行符）\n"
		tail -n5 "$package_script" | sed -e "s|^|  |" -e "5s|^  |>>|"
		return 1
	fi
	if [[ "$last2octet" != *"0a" ]]; then
		echo -e "失败（没有换行符终止）\n"
		xxd -s -2 "$package_script"
		return 1
	fi
	echo "通过"

	echo -n "文件权限检查： "
	local file_permission
	file_permission=$(stat -c "%A" "$package_script")
	if [[ "$file_permission" == *"x"* ]]; then
		echo -e "失败（设置了可执行位）\n"
		echo "${file_permission}"
		return 1
	fi
	echo "通过"

	echo -n "缩进检查： "
	local script
	for script in "$package_script" "$(dirname "$package_script")"/*.subpackage.sh; do
		[[ ! -f "$script" ]] && continue
		check_indentation "$script" || return 1
	done
	echo "通过"

	echo -n "语法检查： "
	local syntax_errors
	syntax_errors=$(bash -n "$package_script" 2>&1)
	if (( ${#syntax_errors} )); then
		echo "失败"
		echo
		echo "$syntax_errors"
		echo
		return 1
	fi
	echo "通过"

	echo -n "尾随空格检查： "
	local re=$'[\t ]\n'
	if [[ "$(< "$package_script")" =~ $re ]]; then
		echo -e "失败\n\n$(grep -Hn '[[:space:]]$' "$package_script")\n"
		return 1
	fi
	echo "通过"

	# Fields checking is done in subshell since we will source build.sh.
	(set +e +u
		local pkg_lint_error

		# Certain fields may be API-specific.
		# Using API 24 here.
		TERMUX_PKG_API_LEVEL=24

		# shellcheck source=/dev/null
		. "$package_script"

		pkg_lint_error=false

		echo -n "TERMUX_PKG_HOMEPAGE： "
		if (( ${#TERMUX_PKG_HOMEPAGE} )); then
			if [[ ! "$TERMUX_PKG_HOMEPAGE" == 'https://'* ]]; then
				echo "非 HTTPS（可接受）"
			else
				echo "通过"
			fi
		else
			echo "未设置"
			pkg_lint_error=true
		fi

		echo -n "TERMUX_PKG_DESCRIPTION： "
		if (( ${#TERMUX_PKG_DESCRIPTION} )); then

			if (( ${#TERMUX_PKG_DESCRIPTION} > 100 )); then
				echo "太长（允许：最多 100 个字符）"
			else
				echo "通过"
			fi

		else
			echo "未设置"
			pkg_lint_error=true
		fi

		echo -n "TERMUX_PKG_LICENSE： "
		if (( ${#TERMUX_PKG_LICENSE} )); then
			case "$TERMUX_PKG_LICENSE" in
				*custom*) echo "自定义" ;;
				'non-free') echo "非自由";;
				*) check_package_license "$TERMUX_PKG_LICENSE" || pkg_lint_error=true
				;;
			esac
		else
			echo "未设置"
			pkg_lint_error=true
		fi

		echo -n "TERMUX_PKG_MAINTAINER： "
		if (( ${#TERMUX_PKG_MAINTAINER} )); then
			echo "通过"
		else
			echo "未设置"
			pkg_lint_error=true
		fi

		if (( ${#TERMUX_PKG_API_LEVEL} )); then
		echo -n "TERMUX_PKG_API_LEVEL： "

			if [[ "$TERMUX_PKG_API_LEVEL" == [1-9][0-9] ]]; then
				if (( TERMUX_PKG_API_LEVEL < 24 )); then
					echo "无效（允许：范围 >= 24 的数字）"
					pkg_lint_error=true
				else
					echo "通过"
				fi
			else
				echo "无效（允许：范围 >= 24 的数字）"
				pkg_lint_error=true
			fi
		fi

		echo -n "TERMUX_PKG_VERSION： "
		check_version "$package_script" || pkg_lint_error=true

		if (( ${#TERMUX_PKG_REVISION} )); then
		echo -n "TERMUX_PKG_REVISION： "

			if (( TERMUX_PKG_REVISION > 1 || TERMUX_PKG_REVISION < 999999999 )); then
				echo "通过"
			else
				echo "无效（允许：范围 1 - 999999999 的数字）"
				pkg_lint_error=true
			fi
		fi

		if (( ${#TERMUX_PKG_SKIP_SRC_EXTRACT} )); then
		echo -n "TERMUX_PKG_SKIP_SRC_EXTRACT： "

			case "$TERMUX_PKG_SKIP_SRC_EXTRACT" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		echo -n "TERMUX_PKG_SRCURL： "
		if (( ${#TERMUX_PKG_SRCURL} )); then
			for (( i = 0; i < ${#TERMUX_PKG_SRCURL[@]}; i++ )); do
				url="${TERMUX_PKG_SRCURL[$i]}"
				(( ${#url} )) || {
					echo "未设置（\${TERMUX_PKG_SRCURL[$i]} 没有值）"
					pkg_lint_error=true
					break
				}
				# 示例：
				# https://github.com/openssh/openssh-portable/archive/refs/tags/V_10_2_P1.tar.gz
				# protocol="https:"
				#        _=""
				#     host="github.com"
				#     user="openssh"
				#     repo="openssh-portable"
				# ref_path="archive/refs/tags/V_10_2_P1.tar.gz"
				IFS='/' read -r protocol _ host user repo ref_path <<< "$url"
				case "${protocol}" in
					https:) protocol_type="HTTPS";;
					git+https:) protocol_type="Git/HTTPS";;
					file:)
						if [[ -d "${url#file://}" ]]; then
							protocol_type="Local source directory"
						else
							protocol_type="Local tarball"
						fi
					;;
					git+file:) protocol_type="Local Git repository";;
					git+*) protocol_type="Git/NON-HTTPS (acceptable)";;
					*) protocol_type="NON-HTTPS (acceptable)";;
				esac

				case "${host}" in
					"github.com")
						# Is this a release tarball?
						if [[ "$ref_path" == releases/download/* ]]; then
							tarball_type="Release"
						# Is it a tag tarball?
						elif [[ "$ref_path" == archive/refs/tags/* ]]; then
							tarball_type="Tag"
						# Is it a branch tarball?
						elif [[ "$ref_path" == archive/refs/heads/* ]]; then
							tarball_type="Branch"
						# Is it an untagged commit tarball?
						elif [[ "$ref_path" =~ archive/[0-9a-f]{7,64} ]]; then
							tarball_type="Commit"
						# If it's in archive/ anyway then it's probably a tag with the incorrect download path.
						elif [[ "$ref_path" == archive/* ]]; then
							tarball_type="can-fix"
							# Get the unexpanded version of the SRCURL for the suggestion
							url="$(grep -oe "$protocol//$host/$user/$repo/archive.*" "$package_script")"
							printf -v lint_msg '%s\n' \
								"PARTIAL PASS - Tag with potential ref confusion." \
								"WARNING: GitHub tarball URLs should use /archive/refs/tags/ instead of /archive/" \
								"to avoid potential ref confusion with branches sharing the name of a tag." \
								"See: https://lore.kernel.org/buildroot/87edqhwvd0.fsf@dell.be.48ers.dk/T/" \
								"  Current:   $url" \
								"  Suggested: ${url/\/archive\//\/archive\/refs\/tags\/}"
						else
							# Is this a git repo or local source? If so, it makes sense we don't have a $ref_path
							case "${protocol}" in
								file:|git+file:)
									tarball_type="local"
									printf -v lint_msg '%s\n' \
										"PASS - "
								;;
								git+*);;
								*) # If we still have no match at this point declare it an error.
									tarball_type="invalid"
									printf -v lint_msg '%s\n' \
										"FAIL (Unknown tarball path pattern for host '$host')" \
										"  Url: $url" \
										"  Tarball path: $ref_path" \
										"  This isn't a typical tarball location for $host."
								;;
							esac
						fi
					;;
					# For other hosts we don't know the typical pattern so don't try guessing the tarball_type.
					*);;
				esac

				# Print the appropriate result based on our findings from above
				case "$tarball_type" in
					"invalid") # Known host, unknown tarball url pattern.
						pkg_lint_error=true
						echo "$lint_msg"
						break
					;;
					"can-fix") # Known host, known pattern, but should be changed.
						echo "$lint_msg"
					;;
					"local") # Local source.
						echo "$lint_msg"
					;;
					*) # Known host, known pattern, or host with no checked tarball URL patterns.
						# $user and $repo corresponds to those URL components for e.g. GitHub.
						# but it may not do so for other tarball hosts, they are included for additional context.
						echo "PASS - (${tarball_type+"${tarball_type}/"}${protocol_type}) ${host}/${user}/${repo}"
					;;
				esac
			done
			unset i url protocol host user repo ref_path protocol_type tarball_type lint_msg

			echo -n "TERMUX_PKG_SHA256： "
			if (( ${#TERMUX_PKG_SHA256} )); then
				if (( ${#TERMUX_PKG_SRCURL[@]} == ${#TERMUX_PKG_SHA256[@]} )); then
					sha256_ok="通过"

					for sha256 in "${TERMUX_PKG_SHA256[@]}"; do
						if [[ "$sha256" == 'SKIP_CHECKSUM' ]]; then
							sha256_ok="通过（跳过校验和）"
						elif [[ ! "$sha256" =~ [0-9a-f]{64} ]]; then
							echo "格式错误（SHA-256 应包含 64 个十六进制数字）"
							pkg_lint_error=true
							break
						fi
					done

					echo "$sha256_ok"
					unset sha256 sha256_ok
				else
					echo "'TERMUX_PKG_SRCURL' 和 'TERMUX_PKG_SHA256' 数组的长度不相等"
					pkg_lint_error=true
				fi
			elif [[ "${TERMUX_PKG_SRCURL:0:4}" == 'git+' ]]; then
				echo "未设置（可接受，因为 TERMUX_PKG_SRCURL 是 git 仓库）"
			else
				echo "未设置"
				pkg_lint_error=true
			fi
		else
			echo -n "未设置"
			if [[ "$TERMUX_PKG_SKIP_SRC_EXTRACT" != 'true' ]] && ! declare -F termux_step_extract_package > /dev/null 2>&1; then
				echo "（如果没有下载源代码，请将 TERMUX_PKG_SKIP_SRC_EXTRACT 设置为 'true'）"
				pkg_lint_error=true
			else
				echo "（可接受，因为 TERMUX_PKG_SKIP_SRC_EXTRACT 为 true）"
			fi
		fi

		if (( ${#TERMUX_PKG_METAPACKAGE} )); then
		echo -n "TERMUX_PKG_METAPACKAGE： "

			case "$TERMUX_PKG_METAPACKAGE" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_ESSENTIAL} )); then
		echo -n "TERMUX_PKG_ESSENTIAL： "

			case "$TERMUX_PKG_ESSENTIAL" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_NO_STATICSPLIT} )); then
		echo -n "TERMUX_PKG_NO_STATICSPLIT： "

			case "$TERMUX_PKG_NO_STATICSPLIT" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_BUILD_IN_SRC} )); then
		echo -n "TERMUX_PKG_BUILD_IN_SRC： "

			case "$TERMUX_PKG_BUILD_IN_SRC" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_HAS_DEBUG} )); then
		echo -n "TERMUX_PKG_HAS_DEBUG： "

			case "$TERMUX_PKG_HAS_DEBUG" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_PLATFORM_INDEPENDENT} )); then
		echo -n "TERMUX_PKG_PLATFORM_INDEPENDENT： "

			case "$TERMUX_PKG_PLATFORM_INDEPENDENT" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_HOSTBUILD} )); then
		echo -n "TERMUX_PKG_HOSTBUILD： "

			case "$TERMUX_PKG_HOSTBUILD" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_FORCE_CMAKE} )); then
		echo -n "TERMUX_PKG_FORCE_CMAKE： "

			case "$TERMUX_PKG_FORCE_CMAKE" in
				'true'|'false')
					echo "通过";;
				*)
					echo "无效（允许：true / false）"
					pkg_lint_error=true;;
			esac
		fi

		if (( ${#TERMUX_PKG_RM_AFTER_INSTALL} )); then
		echo -n "TERMUX_PKG_RM_AFTER_INSTALL： "
			file_path_ok=true

			while read -r file_path; do
				case "$file_path" in
					/*|./*|../*)
						echo "无效（文件路径应该相对于前缀）"
						file_path_ok=false
						pkg_lint_error=true
					break
					;;
				esac
			done <<< "$TERMUX_PKG_RM_AFTER_INSTALL"
			unset file_path

			if [[ "$file_path_ok"  == 'true' ]]; then
				echo "通过"
			fi
			unset file_path_ok
		fi

		if (( ${#TERMUX_PKG_CONFFILES} )); then
		echo -n "TERMUX_PKG_CONFFILES： "
			file_path_ok=true

			while read -r file_path; do
				case "$file_path" in
					/*|./*|../*)
						echo "无效（文件路径应该相对于前缀）"
						file_path_ok=false
						pkg_lint_error=true
						break
					;;
				esac
			done <<< "$TERMUX_PKG_CONFFILES"
			unset file_path

			if [[ "$file_path_ok" == 'true' ]]; then
				echo "通过"
			fi
			unset file_path_ok
		fi

		if (( ${#TERMUX_PKG_SERVICE_SCRIPT} )); then
		echo -n "TERMUX_PKG_SERVICE_SCRIPT： "

			if (( ${#TERMUX_PKG_SERVICE_SCRIPT[@]} % 2 )); then
				echo "无效（TERMUX_PKG_SERVICE_SCRIPT 必须是偶数长度的数组）"
				pkg_lint_error=true
			else
				echo "通过"
			fi
		fi

		if [[ "$pkg_lint_error" == 'true' ]]; then
			exit 1
		fi
	exit 0
	)

	local ret=$?

	echo

	return "$ret"
}

linter_main() {
	local problems_found=false
	local package_script

	for package_script in "$@"; do
		if ! lint_package "$package_script"; then
			problems_found=true
			break
		fi

		: $(( package_counter++ ))
	done

	if [[ "$problems_found" == 'true' ]]; then
		echo "================================================================"
		echo
		echo "在 '$(realpath --relative-to="$TERMUX_SCRIPTDIR" "$package_script")' 中发现问题。"
		echo "在检测到第一个错误之前检查了 $package_counter 个包。"
		echo
		echo "================================================================"
		unset package_counter
		exit 1
	fi

	echo "================================================================"
	echo
	echo "检查了 $package_counter 个包。"
	echo "一切似乎都正常。"
	echo
	echo "================================================================"
	return
}

time_elapsed() {
	local start="$1" end="$(date +%10s.%3N)"
	local elapsed="$(( ${end/.} - ${start/.} ))"
	echo "[信息]：完成构建脚本检查 ($(date -d "@$end" --utc '+%Y-%m-%dT%H:%M:%SZ' 2>&1))"
	printf '[信息]：经过时间：%s\n' \
		"$(sed 's/0m //;s/0s //' <<< "$(( elapsed % 3600000 / 60000 ))m$(( elapsed % 60000 / 1000 ))s$(( elapsed % 1000 ))ms")"
}

echo "[信息]：启动构建脚本检查器 ($(date -d "@$start_time" --utc '+%Y-%m-%dT%H:%M:%SZ' 2>&1))"
git -P log "$base_commit" -n1 --pretty=format:"[信息]：基础提交    - %h%n[信息]：提交消息 - %s%n"
echo "[信息]：源 URL：${origin_url}"
trap 'time_elapsed "$start_time"' EXIT

package_counter=0
if (( $# )); then
	linter_main "$@"
	unset package_counter
else
	for repo_dir in $(jq --raw-output 'del(.pkg_format) | keys | .[]' "$TERMUX_SCRIPTDIR/repo.json"); do
		linter_main "$repo_dir"/*/build.sh
	done
	unset package_counter
fi
