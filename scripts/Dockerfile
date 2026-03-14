# 使用以下命令构建：
#	docker build -t ghcr.io/termux/package-builder .
# 使用以下命令推送到 GitHub 注册表：
#	docker push ghcr.io/termux/package-builder
# 在更改此文件或任何
# scripts/setup-{ubuntu,android-sdk,cgct}.sh 安装脚本之后完成此操作。
FROM ubuntu:24.04

# 修复区域设置以避免警告：
ENV LANG=en_US.UTF-8

# 安装所需：
RUN rm -rf /tmp/termux-packages
RUN mkdir -p /tmp/termux-packages
RUN mkdir -p /tmp/termux-packages/scripts
COPY ./llvm-snapshot.gpg.key ./properties.sh ./setup-android-sdk.sh ./setup-cgct.sh ./setup-ubuntu.sh /tmp/termux-packages/scripts/
RUN mkdir -p /tmp/termux-packages/scripts/build
COPY ./build/termux_download.sh /tmp/termux-packages/scripts/build/

# 安装所需的包以及 Android SDK 和 NDK 以及 CGCT：
RUN apt-get update && \
	apt-get -yq upgrade && \
	apt-get install -yq sudo lsb-release software-properties-common && \
	userdel ubuntu && \
	useradd -u 1001 -U -m -s /bin/bash builder && \
	echo "builder ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/builder && \
	chmod 0440 /etc/sudoers.d/builder && \
	chmod a+rx /tmp/termux-packages/scripts/*.sh /tmp/termux-packages/scripts/build/termux_download.sh && \
	su - builder -c "TERMUX_PKGS__BUILD__IS_DOCKER_BUILD='true' /tmp/termux-packages/scripts/setup-ubuntu.sh" && \
	su - builder -c "TERMUX_PKGS__BUILD__IS_DOCKER_BUILD='true' /tmp/termux-packages/scripts/setup-android-sdk.sh" && \
	# 删除未使用的部分以创建更小的 Docker 镜像：
	apt-get remove -yq --autoremove lsb-release software-properties-common && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	su - builder -c "rm ~/lib/*.zip" && \
	su - builder -c "rm -r ~/.android/cache/"

# 切换用户
USER builder:builder

# 我们期望使用 '-v $PWD:/home/builder/termux-packages' 挂载此目录：
WORKDIR /home/builder/termux-packages
