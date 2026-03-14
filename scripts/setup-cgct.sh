#!/usr/bin/env bash
# 设置 CGCT - Cross Gnu Compilers for Termux
# 为 Termux 编译基于 glibc 的二进制文件

. $(dirname "$(realpath "$0")")/properties.sh
. $(dirname "$(realpath "$0")")/build/termux_download.sh

set -e -u

ARCH="x86_64"
REPO_URL="https://service.termux-pacman.dev/cgct/${ARCH}"

if [ "$ARCH" != "$(uname -m)" ]; then
	echo "错误：您的架构不支持请求的 CGCT"
	exit 1
fi

declare -A CGCT=(
	["cbt"]="2.45.1-0" # Termux 的交叉 Binutils
	["cgt"]="15.2.0-0" # Termux 的交叉 GCC
	["glibc-cgct"]="2.42-0" # CGCT 的 Glibc
 	["cgct-headers"]="6.18.6-0" # CGCT 的头文件
)

: "${TERMUX_PKG_TMPDIR:="/tmp"}"
TMPDIR_CGCT="${TERMUX_PKG_TMPDIR}/cgct"

# 在 tmp 中为 CGCT 创建目录
if [ ! -d "$TMPDIR_CGCT" ]; then
	mkdir -p "$TMPDIR_CGCT"
fi

# 删除旧的 CGCT
if [ -d "$CGCT_DIR" ]; then
	echo "正在删除旧的 CGCT..."
	rm -fr "$CGCT_DIR"
fi

# 安装 CGCT
echo "正在安装 CGCT..."
curl "${REPO_URL}/cgct.json" -o "${TMPDIR_CGCT}/cgct.json"
for pkgname in ${!CGCT[@]}; do
	SHA256SUM=$(jq -r '."'$pkgname'"."SHA256SUM"' "${TMPDIR_CGCT}/cgct.json")
	if [ "$SHA256SUM" = "null" ]; then
		echo "错误：未找到包 '${pkgname}'"
		exit 1
	fi
	version="${CGCT[$pkgname]}"
	version_of_json=$(jq -r '."'$pkgname'"."VERSION"' "${TMPDIR_CGCT}/cgct.json")
	if [ "${version}" != "${version_of_json}" ]; then
		echo "错误：版本不匹配：请求的 - '${version}'；实际的 - '${version_of_json}'"
		exit 1
	fi
	filename=$(jq -r '."'$pkgname'"."FILENAME"' "${TMPDIR_CGCT}/cgct.json")
	if [ ! -f "${TMPDIR_CGCT}/${filename}" ]; then
		termux_download "${REPO_URL}/${filename}" \
			"${TMPDIR_CGCT}/${filename}" \
			"${SHA256SUM}"
	fi
	tar xJf "${TMPDIR_CGCT}/${filename}" -C / data
done

# 为 CGCT 安装 gcc-libs
if [ ! -f "${CGCT_DIR}/lib/libgcc_s.so" ]; then
	pkgname="gcc-libs"
	echo "正在为 CGCT 安装 ${pkgname}..."
	#curl -L "https://archlinux.org/packages/core/${ARCH}/${pkgname}/download/" -o "${TMPDIR_CGCT}/${pkgname}.pkg.zstd"
	termux_download "https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-15.1.1+r7+gf36ec88aa85a-1-x86_64.pkg.tar.zst" \
		"${TMPDIR_CGCT}/${pkgname}.pkg.zstd" \
		"6eedd2e4afc53e377b5f1772b5d413de3647197e36ce5dc4a409f993668aa5ed"
	tar --use-compress-program=unzstd -xf "${TMPDIR_CGCT}/${pkgname}.pkg.zstd" -C "${TMPDIR_CGCT}" usr/lib
	cp -r "${TMPDIR_CGCT}/usr/lib/"* "${CGCT_DIR}/lib"
fi

# 设置 CGCT
if [ ! -f "${CGCT_DIR}"/bin/setup-cgct ]; then
	echo "错误：在 CGCT 目录中未找到 setup-cgct 命令"
	exit 1
fi
"${CGCT_DIR}"/bin/setup-cgct "/usr/lib/x86_64-linux-gnu"
