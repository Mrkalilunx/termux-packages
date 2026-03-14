#!/bin/bash

PACKAGES=""
# 第 1 层：scripts/build/ 中核心构建脚本的要求。
PACKAGES+=" clang"				# termux-elf-cleaner 和 C/C++ 包需要。
PACKAGES+=" file"				# 在 termux_step_massage() 中使用。
PACKAGES+=" gnupg"				# 在 termux_get_repo_files() 和 build-package.sh 中使用。
PACKAGES+=" lzip"				# 由 tar 用于提取 *.tar.lz 源代码归档。
PACKAGES+=" patch"				# 用于在源代码上应用补丁。
PACKAGES+=" python"				# 使用 buildorder.py 核心脚本。
PACKAGES+=" python-pip" # 必要安装 'itstool' 用于设备上构建（因为 Ubuntu 从 'apt' 获取它）
PACKAGES+=" unzip"				# 用于提取 *.zip 源代码归档。
PACKAGES+=" jq"					# 用于解析 repo.json。

# 第 2 层：构建许多其他包的要求。
PACKAGES+=" asciidoc"
PACKAGES+=" asciidoctor"
PACKAGES+=" autoconf"
PACKAGES+=" automake"
PACKAGES+=" bc"
PACKAGES+=" bison"
PACKAGES+=" bsdtar"                     # 创建 pacman 包需要
PACKAGES+=" cmake"
PACKAGES+=" ed"
PACKAGES+=" flex"
PACKAGES+=" gettext"
PACKAGES+=" git"
PACKAGES+=" glslang"                    # mesa 需要
PACKAGES+=" golang"
PACKAGES+=" gperf"
PACKAGES+=" help2man"
PACKAGES+=" intltool"                   # qalc 需要
PACKAGES+=" libtool"
PACKAGES+=" llvm-tools"		# 构建 rust 需要
PACKAGES+=" m4"
PACKAGES+=" make"			# 用于所有基于 Makefile 的项目。
PACKAGES+=" ndk-multilib"		# 构建 rust 需要
PACKAGES+=" ninja"			# 默认用于构建所有 CMake 项目。
PACKAGES+=" perl"
PACKAGES+=" pkg-config"
PACKAGES+=" protobuf"
PACKAGES+=" python2"
PACKAGES+=" re2c"                       # kphp-timelib 需要
PACKAGES+=" rust"
PACKAGES+=" scdoc"
PACKAGES+=" texinfo"
PACKAGES+=" spirv-tools"                # mesa 需要
PACKAGES+=" uuid-utils"
PACKAGES+=" valac"
PACKAGES+=" xmlto"                      # git 的 manpage 生成需要
PACKAGES+=" zip"

PYTHON_PACKAGES=""
PYTHON_PACKAGES+=" itstool"      # 构建 orca 和其他一些包所必需的
PYTHON_PACKAGES+=" pygments"     # 构建 mesa 所必需的（mako 的依赖，_必须_保持 `--upgrade`）
PYTHON_PACKAGES+=" mako"         # 构建 mesa 所必需的
PYTHON_PACKAGES+=" pyyaml"       # 构建 mesa 所必需的
PYTHON_PACKAGES+=" setuptools"   # 构建 mesa 所必需的（明确是 'system' 范围，不像 termux_setup_python_pip 中的 setuptools）
# 如果致力于使 setup-termux.sh 用于设备上构建的行为更接近 setup-ubuntu.sh 用于交叉编译的目标
# 则应在此添加更多 'system-wide' python 包。如果在此添加包，请为每个包添加注释，
# 命名至少一个其反向构建依赖项，通过 pip 安装依赖项至少可以解决设备上构建期间的一个错误。
#PYTHON_PACKAGES+=" "

# 包管理器的定义
export TERMUX_SCRIPTDIR=$(dirname "$(realpath "$0")")/../
. $(dirname "$(realpath "$0")")/properties.sh
source "$TERMUX_PREFIX/bin/termux-setup-package-manager" || true

if [ "$TERMUX_APP_PACKAGE_MANAGER" = "apt" ]; then
	apt update
	yes | apt dist-upgrade
	yes | apt install $PACKAGES
elif [ "$TERMUX_APP_PACKAGE_MANAGER" = "pacman" ]; then
	pacman -Syu $PACKAGES --needed --noconfirm
else
	echo "错误：未定义包管理器"
	exit 1
fi

# 不应在 venv 内安装，因为在 Ubuntu 交叉构建器镜像上，这些特定的 python 包是系统范围的，
# 因此应在 Termux 范围内安装，以便设备上构建与 Ubuntu 交叉构建器镜像的行为相当准确。
pip install --upgrade $PYTHON_PACKAGES
