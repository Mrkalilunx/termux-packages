#!/bin/sh

# 此脚本清理大约 36G 的空间。

# 测试：
# echo "之后列出 100 个最大的包"
# dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -n 100
# exit 0

if [ "${CI-false}" != "true" ]; then
	echo "错误：不在 CI 上运行，不删除系统文件以释放空间！"
	exit 1
else
	# shellcheck disable=SC2046
	sudo apt purge -yq --allow-remove-essential $(
		dpkg -l |
			grep '^ii' |
			awk '{ print $2 }' |
			grep -P '(mecab|linux-azure-tools-|aspnetcore|liblldb-|netstandard-|llvm|clang|gcc-12|gcc-13|cpp-|g\+\+-|temurin-|gfortran-|mysql-|google-cloud-cli|postgresql-|cabal-|dotnet-|ghc-|mongodb-|libmono|mesa-|ant|liblua|python3|grub2-|grub-|shim-signed)'
	)

	sudo apt purge -yq \
		snapd \
		kubectl \
		podman \
		ruby3.2-doc \
		mercurial-common \
		git-lfs \
		skopeo \
		buildah \
		vim \
		python3-botocore \
		azure-cli \
		powershell \
		shellcheck \
		firefox
		# google-chrome-stable
		# microsoft-edge-stable already removed by the deps in the above apt purge

	# 目录
	sudo rm -rf /opt/ghc /opt/az /opt/hostedtoolcache /opt/actionarchivecache /opt/runner-cache
	sudo rm -rf /opt/pipx /usr/share/dotnet /usr/share/swift /usr/share/miniconda /usr/share/az_* /usr/share/gradle-* /usr/share/java /home/runner/.rustup
	sudo rm -rf /etc/skel /home/packer /home/linuxbrew
	sudo rm -rf /usr/local /usr/src/

	# https://github.com/actions/runner-images/issues/709#issuecomment-612569242
	sudo rm -rf "$AGENT_TOOLSDIRECTORY"

	# 清理压缩的 docker 镜像
	# Docker 已经在 CI 中调用 free-space.sh 之前解压了它们，所以
	# 压缩部分只是在磁盘上收集垃圾
	sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/

	sudo apt autoremove -yq
	sudo apt clean
fi
