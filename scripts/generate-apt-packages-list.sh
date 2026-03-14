#!/usr/bin/env bash
set -euo pipefail

# 此脚本生成包列表及其版本和其他详细信息，以便 check-repository-consistency.js 更容易解析
# 为每个架构输出 scripts/apt-packages-list-<arch>.txt
#
# 每行的格式：
# <package_name> <repo-name> <version> <may_have_staticsplit>
#
# 用法：
# ./scripts/generate-apt-packages-list.sh "/path/to/output_dir"
#
# 脚本将为 aarch64、arm、i686 和 x86_64
# 生成 "/path/to/output_dir/apt-packages-list-<arch>.txt"

if [[ "$#" != 1 ]]; then
	echo '用法：'
	echo './scripts/generate-apt-packages-list.sh "/path/to/output_dir"'
	exit 1
fi


TERMUX_PACKAGES_DIR="$(realpath "$(dirname "$(realpath "$0")")/..")"
OUTPUT_DIR="$1"

readarray -t repo_paths <<< "$(jq --raw-output 'del(.pkg_format) | keys | .[]' "$TERMUX_PACKAGES_DIR/repo.json")"

for arch in "aarch64" "arm" "i686" "x86_64"; do
	# 注意，此生成包列表的循环正在为每个架构并行化
	for repo_path in "${repo_paths[@]}"; do
		repo_name="$(jq --raw-output ".\"$repo_path\".name" "$TERMUX_PACKAGES_DIR/repo.json")"
		for pkg_path in "$TERMUX_PACKAGES_DIR/$repo_path"/*; do
			(
				APT_VERSION=
				export TERMUX_PKG_REVISION=0
				export TERMUX_PKG_NO_STATICSPLIT=false
				set +euo pipefail
				. "$pkg_path/build.sh" &> /dev/null || :
				set -euo pipefail
				# 我们在构建脚本中生成 apt 包时，错误地为版本包含短横线的包添加了修订版。
				# 所以在这里重现相同的错误
				# 来源：scripts/build/termux_extract_dep_info.sh
				#	if [[ "$TERMUX_PKG_REVISION" != "0" || "$TERMUX_PKG_VERSION" != "${TERMUX_PKG_VERSION/-/}" ]]; then
				#		VER_DEBIAN+="-$TERMUX_PKG_REVISION"
				# fi
				if [[ "$TERMUX_PKG_REVISION" != 0 || "$TERMUX_PKG_VERSION" != "${TERMUX_PKG_VERSION/-/}" ]]; then
					APT_VERSION="$TERMUX_PKG_VERSION-$TERMUX_PKG_REVISION"
				else
					APT_VERSION="$TERMUX_PKG_VERSION"
				fi

				IFS="," read -r -a EXCLUDED_ARCHES <<< "${TERMUX_PKG_EXCLUDED_ARCHES:-}"
				excluded=false
				for excluded_arch in "${EXCLUDED_ARCHES[@]}"; do
					if [[ "$excluded_arch" == *"$arch"* ]]; then
						excluded=true
					fi
				done
				if [[ "$excluded" != true ]]; then
					if [[ -d "$pkg_path" ]]; then
						echo -n "$(basename "$pkg_path") $repo_name $APT_VERSION"
					fi
					if [[ "$TERMUX_PKG_NO_STATICSPLIT" == true ]]; then
						echo " false"
					else
						echo " true"
					fi
				fi
				for subpkg in "$pkg_path"/*.subpackage.sh; do
					if [[ -f "$subpkg" ]]; then
						(
							set +euo pipefail
							export TERMUX_SUBPKG_PLATFORM_INDEPENDENT=false
							. "$subpkg" &> /dev/null || :
							set -euo pipefail
							IFS="," read -r -a SUBPKG_EXCLUDED_ARCHES <<< "${TERMUX_SUBPKG_EXCLUDED_ARCHES:-}"
							subpkg_excluded=false
							if [[ "${TERMUX_SUBPKG_PLATFORM_INDEPENDENT}" == "false" ]]; then
								subpkg_excluded="$excluded"
							fi
							for excluded_subpkg_arch in "${SUBPKG_EXCLUDED_ARCHES[@]}"; do
								if [[ "$excluded_subpkg_arch" == *"$arch"* ]]; then
									subpkg_excluded=true
								fi
							done
							if [[ "$subpkg_excluded" != true ]]; then
								echo "$(basename "$subpkg" .subpackage.sh) $repo_name $APT_VERSION false"
							fi
						)
					fi
				done
			)
		done
	done > "$OUTPUT_DIR/apt-packages-list-$arch.txt" & # 并行化每个架构
done

wait
