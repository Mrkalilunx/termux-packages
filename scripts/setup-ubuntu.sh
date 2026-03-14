#!/usr/bin/env bash
set -e -u

PACKAGES=""

# 用于 en_US.UTF-8 语言环境。
PACKAGES+=" locales"

# 提供将 /usr/bin/python 作为符号链接到 /usr/bin/python3
PACKAGES+=" python-is-python3"

# 由 build-package.sh 和 CI/CD 脚本使用。
PACKAGES+=" curl"
PACKAGES+=" gnupg"

# 用于从 Git 仓库获取包源代码。
PACKAGES+=" git"

# 用于提取包源代码。
PACKAGES+=" lzip"
PACKAGES+=" tar"
PACKAGES+=" unzip"
PACKAGES+=" lrzip"
PACKAGES+=" lzop"
PACKAGES+=" lz4"
PACKAGES+=" zstd"

# 用于无根容器的用户空间 overlayfs 实现
# 用于设置 NDK 工具链，而无需复制整个工具链以节省一些磁盘空间
PACKAGES+=" fuse-overlayfs"

# 由常用构建系统使用。
PACKAGES+=" autoconf"
PACKAGES+=" autogen"
PACKAGES+=" automake"
PACKAGES+=" autopoint"
PACKAGES+=" bison"
PACKAGES+=" flex"
PACKAGES+=" g++"
PACKAGES+=" g++-multilib"
PACKAGES+=" gawk"
PACKAGES+=" gettext"
PACKAGES+=" gperf"
PACKAGES+=" intltool"
PACKAGES+=" libglib2.0-dev"
PACKAGES+=" libltdl-dev"
PACKAGES+=" libtool-bin"
PACKAGES+=" m4"
PACKAGES+=" pkg-config"
PACKAGES+=" scons"

# 用于生成包文档。
PACKAGES+=" asciidoc"
PACKAGES+=" asciidoctor"
PACKAGES+=" go-md2man"
PACKAGES+=" groff"
PACKAGES+=" help2man"
PACKAGES+=" pandoc"
PACKAGES+=" python3-docutils"
PACKAGES+=" python3-recommonmark"
PACKAGES+=" python3-myst-parser"
PACKAGES+=" python3-sphinx"
PACKAGES+=" python3-sphinx-rtd-theme"
PACKAGES+=" python3-sphinxcontrib.qthelp"
PACKAGES+=" scdoc"
PACKAGES+=" texinfo"
PACKAGES+=" txt2man"
PACKAGES+=" xmlto"
PACKAGES+=" xmltoman"

# python 模块（例如 asciinema）和某些构建系统需要。
PACKAGES+=" python3-pip"
PACKAGES+=" python3-setuptools"
PACKAGES+=" python-wheel-common"
PACKAGES+=" python3.12-venv"

# 包 bc 需要。
PACKAGES+=" ed"

# gnunet 需要。
PACKAGES+=" recutils"

# 提供包 bitcoin 需要的实用程序 hexdump。
PACKAGES+=" bsdmainutils"

# 包 seafile-client 需要。
PACKAGES+=" valac"

# 包 libgcrypt 需要。
PACKAGES+=" fig2dev"

# 包 gimp 需要。
PACKAGES+=" gegl"

# 包 libidn2 需要。
PACKAGES+=" gengetopt"

# 包 dbus-glib 需要。
PACKAGES+=" libdbus-1-dev"

# 下面的包需要。
PACKAGES+=" libelf-dev"

# 包 ghostscript 需要。
PACKAGES+=" libexpat1-dev"
PACKAGES+=" libjpeg-dev"

# 包 gimp3 需要。
PACKAGES+=" librsvg2-dev"

# 包 news-flash-gtk 需要。
PACKAGES+=" libsqlite3-dev"

# 包 luarocks 需要。
PACKAGES+=" lua5.4"

# 包 fennel 需要。
PACKAGES+=" lua5.3"

# 包 vlc 需要。
PACKAGES+=" lua5.2"

# 由包 mariadb 的主机构建使用。
PACKAGES+=" libncurses5-dev"

# 构建 neovim >= 8.0.0 需要
PACKAGES+=" lua-lpeg"
PACKAGES+=" lua-mpack"

# 包 ruby 的主机构建需要。
PACKAGES+=" libyaml-dev"

# 包 mkvtoolnix 需要。
PACKAGES+=" ruby"

# 包 nodejs 的主机构建需要。
PACKAGES+=" libc-ares-dev"
PACKAGES+=" libc-ares-dev:i386"
PACKAGES+=" libicu-dev"
PACKAGES+=" libsqlite3-dev:i386"

# php 需要。
PACKAGES+=" re2c"

# composer 需要。
PACKAGES+=" php"
PACKAGES+=" php-xml"
PACKAGES+=" composer"

# 包 rust 需要。
PACKAGES+=" libssl-dev"

# librusty-v8 需要
PACKAGES+=" libclang-rt-17-dev"
PACKAGES+=" libclang-rt-17-dev:i386"

# 包 smalltalk 需要。
PACKAGES+=" libsigsegv-dev"
PACKAGES+=" zip"

# 包 sqlcipher 需要。
PACKAGES+=" tcl"

# 包 swi-prolog 需要。
PACKAGES+=" openssl"
PACKAGES+=" zlib1g-dev"
PACKAGES+=" libssl-dev:i386"
PACKAGES+=" zlib1g-dev:i386"

# 用于 swift。
PACKAGES+=" lld"

# wrk 需要。
PACKAGES+=" luajit"

# libduktape 需要
PACKAGES+=" bc"

# ovmf 需要
PACKAGES+=" libarchive-tools"

# cavif-rs 需要
PACKAGES+=" nasm"

# debianutils 需要
PACKAGES+=" po4a"

# dgsh 需要
PACKAGES+=" rsync"

# megacmd 需要
PACKAGES+=" wget"

# codeblocks 需要
PACKAGES+=" libwxgtk3.2-dev"
PACKAGES+=" libgtk-3-dev"

# unstable 仓库中的包需要。
PACKAGES+=" comerr-dev"
PACKAGES+=" docbook-to-man"
PACKAGES+=" docbook-utils"
PACKAGES+=" erlang-nox"
PACKAGES+=" heimdal-multidev"
PACKAGES+=" libconfig-dev"
PACKAGES+=" libevent-dev"
PACKAGES+=" libgc-dev"
PACKAGES+=" libgmp-dev"
PACKAGES+=" libjansson-dev"
PACKAGES+=" libparse-yapp-perl"
PACKAGES+=" libreadline-dev"
PACKAGES+=" libunistring-dev"

# X11 仓库中的包需要。
PACKAGES+=" alex"
PACKAGES+=" docbook-xsl-ns"
PACKAGES+=" gnome-common"
PACKAGES+=" gobject-introspection"
PACKAGES+=" gtk-3-examples"
PACKAGES+=" gtk-doc-tools"
PACKAGES+=" happy"
PACKAGES+=" itstool"
PACKAGES+=" libdbus-glib-1-dev-bin"
PACKAGES+=" libgdk-pixbuf2.0-dev"
PACKAGES+=" python3-html5lib"
PACKAGES+=" python3-xcbgen"
PACKAGES+=" sassc"
PACKAGES+=" texlive-extra-utils"
PACKAGES+=" unifdef"
PACKAGES+=" xfce4-dev-tools"
PACKAGES+=" xfonts-utils"
PACKAGES+=" xutils-dev"
PACKAGES+=" desktop-file-utils"

# science 仓库中的包需要
PACKAGES+=" protobuf-c-compiler"
PACKAGES+=" sqlite3"

# game 仓库中的包需要
PACKAGES+=" cvs"
PACKAGES+=" python3-yaml"

# gobject-introspection (termux_setup_gir) 需要。
PACKAGES+=" bash-static"

# apt 需要。
PACKAGES+=" triehash"

# aspell 字典需要。
PACKAGES+=" aspell"

# 包 gdb 需要。
PACKAGES+=" guile-3.0-dev"

# 包 kphp 需要。
PACKAGES+=" python3-jsonschema"

# 包 lilypond 需要。
PACKAGES+=" fontforge-nox"
PACKAGES+=" guile-3.0"
PACKAGES+=" python3-fontforge"
PACKAGES+=" texlive-metapost"

# 包 motif 需要。
PACKAGES+=" libfl-dev"
PACKAGES+=" libxft-dev"
PACKAGES+=" libxt-dev"
PACKAGES+=" xbitmaps"

# cava 需要
PACKAGES+=" xxd"

# samba 需要
PACKAGES+=" libjson-perl"

# 解析 repo.json 需要
PACKAGES+=" jq"

# txikijs 的主机构建步骤需要
PACKAGES+=" libcurl4-openssl-dev"

# openjdk-17 需要
PACKAGES+=" openjdk-17-jre openjdk-17-jdk"

# openjdk-21 需要
PACKAGES+=" openjdk-21-jre openjdk-21-jdk"

# qt5-qtwebengine 需要
PACKAGES+=" libnss3 libnss3:i386 libnss3-dev"
PACKAGES+=" libwebp7 libwebp7:i386 libwebp-dev"
PACKAGES+=" libwebpdemux2 libwebpdemux2:i386"
PACKAGES+=" libwebpmux3 libwebpmux3:i386"

# 基于 chromium 的包需要
PACKAGES+=" libfontconfig1"
PACKAGES+=" libfontconfig1:i386"
PACKAGES+=" libcups2-dev"
PACKAGES+=" libglib2.0-0t64:i386"
PACKAGES+=" libexpat1:i386"

# code-oss 需要
PACKAGES+=" libxkbfile-dev"
PACKAGES+=" libsecret-1-dev"
PACKAGES+=" libkrb5-dev"

# wine-stable 需要
PACKAGES+=" libfreetype-dev:i386"

# CGCT 需要
PACKAGES+=" libdebuginfod-dev"

# 设置 CGCT 以及设置其他包需要
PACKAGES+=" patchelf"

# lldb 用于 python 集成需要
PACKAGES+=" swig"

# binutils-cross 需要
PACKAGES+=" libzstd-dev"

# wlroots 需要
PACKAGES+=" glslang-tools"

# 如果已经以 root 身份运行，则不需要 sudo。
SUDO="sudo"
if [ "$(id -u)" = "0" ]; then
	SUDO=""
fi

# 允许 32 位包。
$SUDO dpkg --add-architecture i386

# 首先安装 jq，然后 source properties.sh
$SUDO env DEBIAN_FRONTEND=noninteractive \
	apt-get install -yq --no-install-recommends jq

. $(dirname "$(realpath "$0")")/properties.sh

# 添加 apt.llvm.org 仓库以获取比 Ubuntu 提供的更新的 LLVM
$SUDO cp $(dirname "$(realpath "$0")")/llvm-snapshot.gpg.key /etc/apt/trusted.gpg.d/apt.llvm.org.asc
$SUDO chmod a+r /etc/apt/trusted.gpg.d/apt.llvm.org.asc
{
	echo "deb [arch=amd64] http://apt.llvm.org/noble/ llvm-toolchain-noble-${TERMUX_HOST_LLVM_MAJOR_VERSION} main"
} | $SUDO tee /etc/apt/sources.list.d/apt-llvm-org.list > /dev/null

LLVM_PACKAGES=""

# rust 和其他包需要。
LLVM_PACKAGES+=" llvm-${TERMUX_HOST_LLVM_MAJOR_VERSION}-dev"
LLVM_PACKAGES+=" llvm-${TERMUX_HOST_LLVM_MAJOR_VERSION}-tools"
LLVM_PACKAGES+=" clang-${TERMUX_HOST_LLVM_MAJOR_VERSION}"
LLVM_PACKAGES+=" lld-${TERMUX_HOST_LLVM_MAJOR_VERSION}"

$SUDO apt-get -yq update

$SUDO env DEBIAN_FRONTEND=noninteractive \
	apt-get install -yq --no-install-recommends $PACKAGES $LLVM_PACKAGES

$SUDO locale-gen --purge en_US.UTF-8
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' | $SUDO tee -a /etc/default/locale

# 如果 `TERMUX__PREFIX` 在 `TERMUX_APP__DATA_DIR` 下，则必须在 `TERMUX_APP__DATA_DIR` 之前修复其所有权
# 否则 `TERMUX__ROOTFS` 将不会修复其所有权。
$SUDO mkdir -p "$TERMUX__PREFIX"
$SUDO chown -R "$(whoami)" "$TERMUX__PREFIX"
$SUDO mkdir -p "$TERMUX_APP__DATA_DIR"
$SUDO chown -R "$(whoami)" "${TERMUX_APP__DATA_DIR%"${TERMUX_APP__DATA_DIR#/*/}"}" # 从 `/path/to/app__data_dir` 获取 `/path/`。

# 包的符号链接链中的初始符号链接
# 这些包具有 'aosp-libs' 的构建依赖；请参阅 scripts/build/termux_step_override_config_scripts.sh
# 和 scripts/build/setup/termux_setup_proot.sh 以获取更多信息
$SUDO ln -sf "$TERMUX_APP__DATA_DIR/aosp" /system

# 安装比 Ubuntu 提供的更新的 pkg-config，因为库存
# ubuntu 版本在至少 protobuf 方面存在性能问题：
PKGCONF_VERSION=2.3.0
PKGCONF_SHA256=3a9080ac51d03615e7c1910a0a2a8df08424892b5f13b0628a204d3fcce0ea8b
HOST_TRIPLET=$(gcc -dumpmachine)
PKG_CONFIG_DIRS=$(grep DefaultSearchPaths: /usr/share/pkgconfig/personality.d/${HOST_TRIPLET}.personality | cut -d ' ' -f 2)
SYSTEM_LIBDIRS=$(grep SystemLibraryPaths: /usr/share/pkgconfig/personality.d/${HOST_TRIPLET}.personality | cut -d ' ' -f 2)
mkdir -p /tmp/pkgconf-build
cd /tmp/pkgconf-build
curl -O https://distfiles.ariadne.space/pkgconf/pkgconf-${PKGCONF_VERSION}.tar.xz
tar xf pkgconf-${PKGCONF_VERSION}.tar.xz
echo "${PKGCONF_SHA256}  pkgconf-${PKGCONF_VERSION}.tar.xz" | sha256sum -c -
cd pkgconf-${PKGCONF_VERSION}
echo "SYSTEM_LIBDIRS: $SYSTEM_LIBDIRS"
echo "PKG_CONFIG_DIRS: $PKG_CONFIG_DIRS"
./configure --prefix=/usr \
	--with-system-libdir=${SYSTEM_LIBDIRS} \
	--with-pkg-config-dir=${PKG_CONFIG_DIRS}
make
$SUDO make install
cd -
rm -Rf /tmp/pkgconf-build
# 防止包被升级并覆盖我们的手动安装：
$SUDO apt-mark hold pkgconf
