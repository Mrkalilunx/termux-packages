#!@TERMUX_PREFIX@/bin/sh
# shellcheck shell=sh

(
	# 如果 termux bootstrap 第二阶段从未运行过，例如在情况下
	# bootstrap 是从 shell 提取到 rootfs，而不是由
	# Termux 应用，后者通常运行第二阶段，那么运行它。
	# 这目前是 pacman bootstrap 的问题，它不被
	# Termux 应用支持，提取和第二阶段
	# 都是从 shell 运行的。一旦添加了支持，此脚本
	# 将被删除。
	# 如果第二阶段失败，Termux 应用会擦除前缀目录，
	# 否则当应用重新启动时，损坏的前缀目录
	# 将被使用并登录。我们不在这里这样做，因为那
	# 可能会擦除对前缀所做的其他更改，如果需要，用户应该手动
	# 擦除。我们不会在失败时删除锁文件，因为这样当启动新的 shell 时
	# 第二阶段将再次运行，这可能会影响已配置的包。
	# 如果下面运行的第二阶段失败，shell 仍应加载。
	if [ ! -L "@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@/@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@.lock" ]; then
		echo "开始 termux bootstrap 第二阶段的后备运行"
		chmod +x "@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@/@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@" || exit $?
		"@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_DIR@/@TERMUX_BOOTSTRAP__BOOTSTRAP_SECOND_STAGE_ENTRY_POINT_SUBFILE@" || exit $?
	fi

	# 删除脚本本身，使其永远不会再次运行
	rm -f "@TERMUX__PREFIX__PROFILE_D_DIR@/01-termux-bootstrap-second-stage-fallback.sh" || exit $?

) || return $?
