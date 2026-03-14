#!/bin/sh
set -e -u

CONTAINER=termux-package-builder
IMAGE=ghcr.io/termux/package-builder

docker pull $IMAGE

LATEST=$(docker inspect --format "{{.Id}}" $IMAGE)
RUNNING=$(docker inspect --format "{{.Image}}" $CONTAINER)

if [ $LATEST = $RUNNING ]; then
	echo "容器 '$CONTAINER' 中使用的镜像 '$IMAGE' 已经是最新的"
else
	echo "容器 '$CONTAINER' 中使用的镜像 '$IMAGE' 已更新 - 正在删除过时的容器"
	docker stop $CONTAINER
	docker rm -f $CONTAINER
fi

