#!/bin/bash

set -e -u

: "${TERMUX_PKG_TMPDIR:="/tmp"}"

# 安装 Android SDK 的所需部分：
. $(cd "$(dirname "$0")"; pwd)/properties.sh
. $(cd "$(dirname "$0")"; pwd)/build/termux_download.sh

ANDROID_SDK_FILE=commandlinetools-linux-${TERMUX_SDK_REVISION}_latest.zip
ANDROID_SDK_SHA256=0bebf59339eaa534f4217f8aa0972d14dc49e7207be225511073c661ae01da0a
if [ "$TERMUX_NDK_VERSION" = "29" ]; then
	ANDROID_NDK_FILE=android-ndk-r${TERMUX_NDK_VERSION}-linux.zip
	ANDROID_NDK_SHA256=4abbbcdc842f3d4879206e9695d52709603e52dd68d3c1fff04b3b5e7a308ecf
elif [ "$TERMUX_NDK_VERSION" = 23c ]; then
	ANDROID_NDK_FILE=android-ndk-r${TERMUX_NDK_VERSION}-linux.zip
	ANDROID_NDK_SHA256=6ce94604b77d28113ecd588d425363624a5228d9662450c48d2e4053f8039242
else
	echo "错误：未知的 NDK 版本 $TERMUX_NDK_VERSION" >&2
	exit 1
fi

if [ ! -d "$ANDROID_HOME" ]; then
	mkdir -p "$ANDROID_HOME"
	cd "$ANDROID_HOME/.."
	rm -Rf "$(basename "$ANDROID_HOME")"

	# https://developer.android.com/studio/index.html#command-tools
	echo "正在下载 Android SDK..."
	termux_download https://dl.google.com/android/repository/${ANDROID_SDK_FILE} \
		tools-$TERMUX_SDK_REVISION.zip \
		$ANDROID_SDK_SHA256
	rm -Rf android-sdk-$TERMUX_SDK_REVISION
	unzip -q tools-$TERMUX_SDK_REVISION.zip -d android-sdk-$TERMUX_SDK_REVISION
fi

if [ ! -d "$NDK" ]; then
	mkdir -p "$NDK"
	cd "$NDK/.."
	rm -Rf "$(basename "$NDK")"

	# https://developer.android.com/ndk/downloads
	echo "正在下载 Android NDK..."
	termux_download https://dl.google.com/android/repository/${ANDROID_NDK_FILE} \
		ndk-r${TERMUX_NDK_VERSION}.zip \
		$ANDROID_NDK_SHA256
	rm -Rf android-ndk-r$TERMUX_NDK_VERSION
	unzip -q ndk-r${TERMUX_NDK_VERSION}.zip

	# 删除未使用的部分
	rm -Rf android-ndk-r$TERMUX_NDK_VERSION/sources/cxx-stl/system
fi

if [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
	SDK_MANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
elif [ -x "$ANDROID_HOME/cmdline-tools/bin/sdkmanager" ]; then
	SDK_MANAGER="$ANDROID_HOME/cmdline-tools/bin/sdkmanager"
else
	echo "错误：在 $ANDROID_HOME 中未找到可用的 sdkmanager" >&2
	echo "检查其他可能的路径：（如果未找到则为空）" >&2
	find "$ANDROID_HOME" -type f -name sdkmanager >&2
	exit 1
fi

echo "信息：使用 sdkmanager ... $SDK_MANAGER"
echo "信息：使用 NDK ... $NDK"

yes | $SDK_MANAGER --sdk_root="$ANDROID_HOME" --licenses

# android 平台用于 ecj 和 apksigner 包：
yes | $SDK_MANAGER --sdk_root="$ANDROID_HOME" \
		"platform-tools" \
		"build-tools;${TERMUX_ANDROID_BUILD_TOOLS_VERSION}" \
		"platforms;android-35" \
		"platforms;android-28" \
		"platforms;android-24"
