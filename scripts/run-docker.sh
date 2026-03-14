#!/bin/bash
set -euo pipefail

TERMUX_SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; cd ..; pwd)
: ${TERMUX_BUILDER_IMAGE_NAME:=ghcr.io/termux/package-builder}
: ${CONTAINER_NAME:=termux-package-builder}
: ${TERMUX_DOCKER_RUN_EXTRA_ARGS:=}
: ${TERMUX_DOCKER_EXEC_EXTRA_ARGS:=}
BUILDSCRIPT_NAME=build-package.sh
CONTAINER_HOME_DIR=/home/builder

_show_usage() {
	echo "用法：$0 [选项] [命令]"
	echo ""
	echo "在 Termux 包构建器容器中运行命令。如果未提供命令，将启动交互式 shell。"
	echo ""
	echo "选项："
	echo "  -h, --help                 显示此帮助消息并退出"
	echo "  -d, --dry-run              在构建任何包之前运行 'build-package-dry-run-simulation.sh'"
	echo "                             这对于 CI 很有用，可以跳过不必要的 docker 运行。"
	echo "  -m, --mount-termux-dirs    将 /data 和 ~/.termux-build 挂载到容器中。"
	echo "                             这对于使用主机 IDE 和编辑器进行本地开发构建很有用。"
	echo "支持的环境变量："
	echo "  TERMUX_BUILDER_IMAGE_NAME     要使用的 Docker 镜像名称"
	echo "  CONTAINER_NAME                要创建/使用的 Docker 容器名称"
	echo "  TERMUX_DOCKER_RUN_EXTRA_ARGS  创建容器时要传递给 'docker run' 的"
	echo "                                额外参数"
	echo "  TERMUX_DOCKER_EXEC_EXTRA_ARGS 在容器中运行命令时要传递给 'docker exec' 的"
	echo "                                额外参数"
	echo "  TERMUX_DOCKER_USE_SUDO        如果设置为任何非空值，将使用 'sudo'"
	echo "                                来运行 'docker' 命令"
	echo ""
	echo ""
	echo "请注意："
	echo "- TERMUX_DOCKER_RUN_EXTRA_ARGS 仅在创建容器时考虑，"
	echo "  并且如果容器已存在，在容器中运行命令时将不会应用。"
	echo "- 要应用新的 TERMUX_DOCKER_RUN_EXTRA_ARGS，需要先删除现有容器。"
	echo "- 上述规则也适用于 -m/--mount-termux-dirs 选项，因为它将挂载参数"
	echo "  添加到 TERMUX_DOCKER_RUN_EXTRA_ARGS。"
	echo "- dry-run 选项仅在传递给此运行 docker 的脚本的第一个参数"
	echo "  包含 '$BUILDSCRIPT_NAME' 时才有效，它将运行"
	echo "  'build-package-dry-run-simulation.sh' 并使用传递给此脚本的参数。"
	exit 0
}

dry_run="false"

while (( $# != 0 )); do
	case "$1" in
		-h|--help) shift 1; _show_usage;;
		-d|--dry-run)
			dry_run="true"
			shift 1;;
		-m|--mount-termux-dirs)
			TERMUX_DOCKER_RUN_EXTRA_ARGS="--volume /data:/data --volume $HOME/.termux-build:$CONTAINER_HOME_DIR/.termux-build $TERMUX_DOCKER_RUN_EXTRA_ARGS"
			shift 1;;
		--) shift 1; break;;
		-*) echo "错误：未知选项 '$1'" 1>&2; shift 1; exit 1;;
		*) break;;
	esac
done

# 如果 'build-package-dry-run-simulation.sh' 不返回 85 (EX_C__NOOP)，或者如果
# $1（传递给此运行 docker 的脚本的第一个参数）不包含
# $BUILDSCRIPT_NAME，此条件将评估为 false，此运行 docker 的脚本
# 将继续。
if [ "${dry_run}" = "true" ]; then
	case "${1:-}" in
		*"/$BUILDSCRIPT_NAME")
			RETURN_VALUE=0
			OUTPUT="$("$TERMUX_SCRIPTDIR/scripts/bin/build-package-dry-run-simulation.sh" "$@" 2>&1)" || RETURN_VALUE=$?
			if [ $RETURN_VALUE -ne 0 ]; then
				echo "$OUTPUT" 1>&2
				if [ $RETURN_VALUE -eq 85 ]; then # EX_C__NOOP
					echo "$0: 退出，因为 '$BUILDSCRIPT_NAME' 不会构建任何包"
					exit 0
				fi
				exit $RETURN_VALUE
			fi
			;;
	esac
fi

UNAME=$(uname)
if [ "$UNAME" = Darwin ]; then
	# mac readlink 不支持 -f 的变通方法。
	REPOROOT=$PWD
	SEC_OPT=""
else
	REPOROOT="$(dirname $(readlink -f $0))/../"
	SEC_OPT=" --security-opt seccomp=$REPOROOT/scripts/profile.json --security-opt apparmor=_custom-termux-package-builder-$CONTAINER_NAME --cap-add CAP_SYS_ADMIN --device /dev/fuse"
fi

if [ "${CI:-}" = "true" ]; then
	CI_OPT="--env CI=true"
else
	CI_OPT=""
fi

# 对于带有 SELinux 和 btrfs 的 Linux，避免权限问题所必需，例如：Fedora
# 要重置，使用 "restorecon -Fr ."
# 要检查，使用 "ls -Z ."
if [ -n "$(command -v getenforce)" ] && [ "$(getenforce)" = Enforcing ]; then
	VOLUME=$REPOROOT:$CONTAINER_HOME_DIR/termux-packages:z
else
	VOLUME=$REPOROOT:$CONTAINER_HOME_DIR/termux-packages
fi

USER=builder

if [ -n "${TERMUX_DOCKER_USE_SUDO-}" ]; then
	SUDO="sudo"
else
	SUDO=""
fi

echo "正在从镜像 '$TERMUX_BUILDER_IMAGE_NAME' 运行容器 '$CONTAINER_NAME'..."

# 检查是否附加到 tty 并相应调整 docker 标志。
if [ -t 1 ]; then
	DOCKER_TTY=" --tty"
else
	DOCKER_TTY=""
fi

APPARMOR_PARSER=""
if command -v apparmor_parser > /dev/null; then
	APPARMOR_PARSER="apparmor_parser"
fi

if [ -z "$APPARMOR_PARSER" ] || ! $SUDO aa-status --enabled; then
	echo "警告：未找到 apparmor_parser，AppArmor 配置文件将不会被加载！"
	echo "         不推荐这样做，因为它可能会导致安全问题和意外行为"
	echo "         避免在容器中执行不受信任的代码"
	APPARMOR_PARSER=""
fi

load_apparmor_profile() {
	local profile_path="$1"
	local msg="${2:-}"
	if [ -n "$APPARMOR_PARSER" ]; then
		if [ -n "$msg" ]; then
			echo "$msg..."
		fi
		cat "$profile_path" | sed -e "s/{{CONTAINER_NAME}}/$CONTAINER_NAME/g" | sudo "$APPARMOR_PARSER" -rK
	fi
}

# 首先加载宽松的 AppArmor 配置文件，因为我们可能需要更改权限
load_apparmor_profile ./scripts/profile-relaxed.apparmor

__change_builder_uid_gid() {
	if [ "$UNAME" != Darwin ]; then
		if [ $(id -u) -ne 1001 -a $(id -u) -ne 0 ]; then
			echo "正在更改构建器 uid/gid...（这可能需要一段时间）"
			$SUDO docker exec $DOCKER_TTY $TERMUX_DOCKER_EXEC_EXTRA_ARGS $CONTAINER_NAME sudo chown -R $(id -u):$(id -g) $CONTAINER_HOME_DIR
			$SUDO docker exec $DOCKER_TTY $TERMUX_DOCKER_EXEC_EXTRA_ARGS $CONTAINER_NAME sudo chown -R $(id -u):$(id -g) /data
			$SUDO docker exec $DOCKER_TTY $TERMUX_DOCKER_EXEC_EXTRA_ARGS $CONTAINER_NAME sudo usermod -u $(id -u) builder
			$SUDO docker exec $DOCKER_TTY $TERMUX_DOCKER_EXEC_EXTRA_ARGS $CONTAINER_NAME sudo groupmod -g $(id -g) builder
		fi
	fi
}

__change_container_pid_max() {
	if [ "$UNAME" != Darwin ]; then
		echo "正在将 /proc/sys/kernel/pid_max 更改为 65535，以便为需要使用 proot 运行本机可执行文件的包（对于 32 位架构）"
		if [[ "$($SUDO docker exec $CONTAINER_NAME cat /proc/sys/kernel/pid_max)" -le 65535 ]]; then
			echo "无需更改 /proc/sys/kernel/pid_max，当前值为 $($SUDO docker exec $DOCKER_TTY $CONTAINER_NAME cat /proc/sys/kernel/pid_max)"
		else
			# 在内核版本 >= 6.14 上，pid_max 值是 pid 命名空间的，因此我们需要在容器命名空间中设置它，而不是在主机上。
			# 但某些发行版可能会将 pid 命名空间反向移植到旧内核，因此我们通过在容器中设置它之后检查值来验证它是否有效。
			$SUDO docker run --privileged --pid="container:$CONTAINER_NAME" --rm "$TERMUX_BUILDER_IMAGE_NAME" sh -c "echo 65535 | sudo tee /proc/sys/kernel/pid_max > /dev/null" || :
			if [[ "$($SUDO docker exec $CONTAINER_NAME cat /proc/sys/kernel/pid_max)" -eq 65535 ]]; then
				echo "成功为容器命名空间更改了 /proc/sys/kernel/pid_max"
			else
				echo "无法为容器更改 /proc/sys/kernel/pid_max，回退到在主机上设置它..."
				if ( echo 65535 | sudo tee /proc/sys/kernel/pid_max >/dev/null ); then
					echo "成功在主机上更改了 /proc/sys/kernel/pid_max，但这可能会影响主机系统上的其他进程"
				else
					echo "也无法在主机上更改 /proc/sys/kernel/pid_max，某些需要使用 proot 运行本机可执行文件的包（对于 32 位架构）可能无法正常工作"
				fi
			fi
		fi
	fi
}


if ! $SUDO docker container inspect $CONTAINER_NAME > /dev/null 2>&1; then
	echo "正在创建新容器..."
	$SUDO docker run \
		--detach \
		--init \
		--name $CONTAINER_NAME \
		--volume $VOLUME \
		$SEC_OPT \
		--tty \
		$TERMUX_DOCKER_RUN_EXTRA_ARGS \
		$TERMUX_BUILDER_IMAGE_NAME
	__change_builder_uid_gid
	__change_container_pid_max
fi

if [[ "$($SUDO docker container inspect -f '{{ .State.Running }}' $CONTAINER_NAME)" == "false" ]]; then
	$SUDO docker start $CONTAINER_NAME >/dev/null 2>&1
	__change_container_pid_max
fi

load_apparmor_profile ./scripts/profile-restricted.apparmor "正在加载受限的 AppArmor 配置文件"

# 设置陷阱以确保使用 docker exec 启动的进程及其所有子进程都被终止。
. "$TERMUX_SCRIPTDIR/scripts/utils/docker/docker.sh"; docker__setup_docker_exec_traps

if [ "$#" -eq "0" ]; then
	set -- bash
fi

$SUDO docker exec $CI_OPT --env "DOCKER_EXEC_PID_FILE_PATH=$DOCKER_EXEC_PID_FILE_PATH" --interactive $DOCKER_TTY $TERMUX_DOCKER_EXEC_EXTRA_ARGS $CONTAINER_NAME "$@"
