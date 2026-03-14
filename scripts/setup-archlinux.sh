#!/usr/bin/env bash
set -e -u

PACKAGES=""
PACKAGES+=" asciidoc"
PACKAGES+=" asciidoctor" # 由 weechat 用于 man 页面。
PACKAGES+=" automake"
PACKAGES+=" bison"
PACKAGES+=" clang" # 由 golang 使用，使用相同的编译器构建很有用。
PACKAGES+=" curl" # 用于获取源代码。
PACKAGES+=" ed" # 由 bc 使用。
PACKAGES+=" expat" # ghostscript 需要。
PACKAGES+=" flex"
PACKAGES+=" gawk" # apr-util 需要。
PACKAGES+=" gcc" # 主机 C/C++ 编译器。
PACKAGES+=" gettext" # 提供 'msgfmt'。
PACKAGES+=" git" # 由 neovim 构建使用。
PACKAGES+=" glib2" # 提供 'glib-genmarshal'，glib 构建使用它。
PACKAGES+=" gnupg" # 需要验证下载的 deb。
PACKAGES+=" gperf" # 由 fontconfig 构建使用。
PACKAGES+=" help2man"
PACKAGES+=" intltool" # 由 qalc 构建使用。
PACKAGES+=" jre8-openjdk-headless"
PACKAGES+=" jq" # 需要解析 repo.json
PACKAGES+=" re2c" # kphp-timelib 需要
PACKAGES+=" libjpeg-turbo" # ghostscript 需要。
PACKAGES+=" libtool"
PACKAGES+=" lua" # 需要构建 luarocks 包。
PACKAGES+=" lzip"
PACKAGES+=" m4"
PACKAGES+=" openssl"  # 需要构建 rust。
PACKAGES+=" patch"
PACKAGES+=" pkgconf"
PACKAGES+=" python"
PACKAGES+=" python-docutils" # 用于 rst2man，由 mpv 使用。
PACKAGES+=" python-recommonmark" # LLVM-8 文档需要。
PACKAGES+=" python-setuptools" # 至少 asciinema 需要。
PACKAGES+=" python-sphinx" # notmuch man 页面生成需要。
PACKAGES+=" ruby" # 需要构建 ruby。
PACKAGES+=" scdoc" # aerc 需要。
PACKAGES+=" scons"
PACKAGES+=" tar"
PACKAGES+=" texinfo"
PACKAGES+=" unzip"
PACKAGES+=" xmlto"

# 如果已经以 root 身份运行，则不需要 sudo。
if [ "$(id -u)" = "0" ]; then
	SUDO=""
else
	SUDO="sudo"
fi
$SUDO pacman -Syq --needed --noconfirm $PACKAGES

. $(dirname "$(realpath "$0")")/properties.sh

# 如果 `TERMUX__PREFIX` 在 `TERMUX_APP__DATA_DIR` 下，则必须在 `TERMUX_APP__DATA_DIR` 之前修复其所有权
# 否则 `TERMUX__ROOTFS` 将不会修复其所有权。
$SUDO mkdir -p "$TERMUX__PREFIX"
$SUDO chown -R "$(whoami)" "$TERMUX__PREFIX"
$SUDO mkdir -p "$TERMUX_APP__DATA_DIR"
$SUDO chown -R "$(whoami)" "${TERMUX_APP__DATA_DIR%"${TERMUX_APP__DATA_DIR#/*/}"}" # 从 `/path/to/app__data_dir` 获取 `/path/`。

echo "继续之前，请从 AUR 安装以下包"
echo
echo "- ncurses5-compat-libs"
echo "- makedepend"
echo "- python2"
echo "- lib32-c-ares"
