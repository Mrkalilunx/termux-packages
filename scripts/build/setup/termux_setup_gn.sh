termux_setup_gn() {
	termux_setup_ninja
	local GN_COMMIT=64d35867ca0a1088f13de8f4ccaf1a5687d7f1ce
	local GN_TARFILE=$TERMUX_COMMON_CACHEDIR/gn_$GN_COMMIT.tar.gz
	local GN_SOURCE=https://gn.googlesource.com/gn/+archive/$GN_COMMIT.tar.gz

	if [ "${TERMUX_PACKAGES_OFFLINE-false}" = "true" ]; then
		GN_FOLDER=$TERMUX_SCRIPTDIR/build-tools/gn-$GN_COMMIT
	else
		GN_FOLDER=$TERMUX_COMMON_CACHEDIR/gn-$GN_COMMIT
	fi

	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		if [ ! -d "$GN_FOLDER" ]; then
			# FIXME: 我们希望在下载时启用校验和
			# tar 文件，但它们每次都会更改，因为 tar 元数据
			# 不同：https://github.com/google/gitiles/issues/84
			termux_download \
				$GN_SOURCE \
				$GN_TARFILE \
				SKIP_CHECKSUM
			mkdir -p $GN_FOLDER
			tar xf $GN_TARFILE -C $GN_FOLDER
			local LAST_PWD=$(pwd)
			cd $GN_FOLDER
			(
				unset CC CXX CFLAGS CXXFLAGS LD LDFLAGS AR AS CPP OBJCOPY OBJDUMP RANLIB READELF STRIP
				export CC="clang-${TERMUX_HOST_LLVM_MAJOR_VERSION}"
				export CXX="clang++-${TERMUX_HOST_LLVM_MAJOR_VERSION}"
				export LD="clang++-${TERMUX_HOST_LLVM_MAJOR_VERSION}"
				export PATH="/usr/bin:$(echo -n $(tr ':' '\n' <<< "$PATH" | grep -v "^$TERMUX_PREFIX/bin$") | tr ' ' ':')"
				./build/gen.py \
					--no-last-commit-position
				cat <<-EOF >./out/last_commit_position.h
					#ifndef OUT_LAST_COMMIT_POSITION_H_
					#define OUT_LAST_COMMIT_POSITION_H_
					#define LAST_COMMIT_POSITION_NUM 2311
					#define LAST_COMMIT_POSITION "2311 ${GN_COMMIT:0:12}"
					#endif  // OUT_LAST_COMMIT_POSITION_H_
				EOF
				ninja -C out/
			)
			cd $LAST_PWD
		fi
		export PATH=$GN_FOLDER/out:$PATH
	else
		if [[ "$TERMUX_APP_PACKAGE_MANAGER" = "apt" && "$(dpkg-query -W -f '${db:Status-Status}\n' gn 2>/dev/null)" != "installed" ]] ||
                   [[ "$TERMUX_APP_PACKAGE_MANAGER" = "pacman" && ! "$(pacman -Q gn 2>/dev/null)" ]]; then
			echo "未安装 'gn' 软件包。"
			echo "您可以通过以下方式安装："
			echo
			echo "  pkg install gn"
			echo
			echo "  pacman -S gn"
			echo
			exit 1
		fi
	fi
}
