# 此脚本将其自己的 python 构建添加到 $PATH 中，这会覆盖 Ubuntu
# 打包的版本。在 Ubuntu 上使用 apt 安装的软件包将无法工作。
# 此 python 构建仅应用于 pip 软件包的交叉编译。
#
# 在任何地方手动使用此脚本之前，强烈建议阅读
# https://crossenv.readthedocs.io/en/latest/quickstart.html
# 对于 python 软件包和 python 的交叉编译，需要相同版本的
# python 主机构建。对于 pip 软件包交叉编译，
# crossenv 建议理想情况下使用相同版本的 python。
termux_setup_build_python() {
	if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
		if [[ "$TERMUX_APP_PACKAGE_MANAGER" = "apt" && "$(dpkg-query -W -f '${db:Status-Status}\n' python 2>/dev/null)" != "installed" ]] ||
		[[ "$TERMUX_APP_PACKAGE_MANAGER" = "pacman" && ! "$(pacman -Q python 2>/dev/null)" ]]; then
			echo "未安装 'python 软件包。"
			echo "您可以通过以下方式安装："
			echo
			echo "  pkg install python"
			echo
			echo "  pacman -S python"
			echo
			echo "注意：'python' 软件包在设备上构建时已知存在问题。"
			exit 1
		fi
	else
		local _PYTHON_VERSION
		local _PYTHON_SRCURL
		local _PYTHON_SHA256
		local _PYTHON_FOLDER
		_PYTHON_VERSION="$(. "$TERMUX_SCRIPTDIR/packages/python/build.sh"; echo "$TERMUX_PKG_VERSION")"
		_PYTHON_SRCURL="$(. "$TERMUX_SCRIPTDIR/packages/python/build.sh"; echo "$TERMUX_PKG_SRCURL")"
		_PYTHON_SHA256="$(. "$TERMUX_SCRIPTDIR/packages/python/build.sh"; echo "$TERMUX_PKG_SHA256")"
		if [[ "${TERMUX_PACKAGES_OFFLINE-false}" = "true" ]]; then
			_PYTHON_FOLDER=${TERMUX_SCRIPTDIR}/build-tools/python-${_PYTHON_VERSION}
		else
			_PYTHON_FOLDER=${TERMUX_COMMON_CACHEDIR}/python-${_PYTHON_VERSION}
		fi
		export TERMUX_BUILD_PYTHON_DIR=$_PYTHON_FOLDER

		if [[ ! -d "$_PYTHON_FOLDER" ]]; then
			local LAST_PWD="$(pwd)"
			termux_download \
				"$_PYTHON_SRCURL" "python-$_PYTHON_VERSION.tar.xz" "$_PYTHON_SHA256"
			mkdir "$_PYTHON_FOLDER"
			tar \
				--extract \
				--strip-components=1 \
				-C "$_PYTHON_FOLDER" \
				-f "python-$_PYTHON_VERSION.tar.xz"
			cd "$_PYTHON_FOLDER"

			for f in "$TERMUX_SCRIPTDIR"/packages/python/0009-fix-ctypes-util-find_library.patch; do
				echo "[${FUNCNAME[0]}]: 正在应用 $(basename "$f")"
				cat "$f" | sed -e "s|@@TERMUX_PKG_API_LEVEL@@|${TERMUX_PKG_API_LEVEL}|g" | patch --silent -p1
			done

			# Perform a hostbuild of python. We are kind of doing a minimal build, which
			# may break some stuff that rely on an extended python release
			mkdir host-build/
			cd host-build/
			# 我们使用 env -i 因为有很多环境变量需要取消设置，
			# 所以最好从头开始
			# 另外，不管是谁编写了 python 的构建脚本，都没有想到
			# 正确支持标准的 LD 环境变量甚至 LDFLAGS。
			# 所以我们必须将链接器参数传递给 CC 和 CXX 而不是使用 LDFLAGS，
			# 并希望 Clang C 和 C++ 驱动程序继续忽略链接标志。这是
			# 不可能的，在不修补的情况下指定单独的链接器，因为它
			# 被硬编码为 "$(CC) -shared" 和 "$(CXX) -shared"
			# 那个人需要停止编写构建脚本，而应该
			# 质疑他对世界的存在的影响
			env -i \
				CC="clang-${TERMUX_HOST_LLVM_MAJOR_VERSION} -fuse-ld=lld" \
				CXX="clang++-${TERMUX_HOST_LLVM_MAJOR_VERSION} -fuse-ld=lld" \
				LDFLAGS="-Wl,-rpath=$_PYTHON_FOLDER/host-build-prefix/lib" \
				PATH="/usr/bin" \
				../configure \
					--with-ensurepip=install \
					--enable-shared \
					--prefix="$_PYTHON_FOLDER/host-build-prefix"
			env -i \
				make -j "$(nproc)" install
			cd "$LAST_PWD"
		fi
		# 将我们自己构建的 python 添加到路径
		export PATH="$_PYTHON_FOLDER/host-build-prefix/bin:$PATH"
	fi
}
