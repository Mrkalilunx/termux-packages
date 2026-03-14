#!/usr/bin/env python3

import urllib.request
from subprocess import Popen, PIPE

# 版本映射字典
version_map = {}
any_error = False

# 执行 list-versions.sh 脚本获取包版本
pipe = Popen('./scripts/list-versions.sh', stdout=PIPE)
for line in pipe.stdout:
    (name, version) = line.decode().strip().split('=')
    version_map[name] = version

def check_manifest(arch, manifest):
    """检查清单中的包版本是否与最新版本匹配。"""
    current_package = {}
    for line in manifest:
        if line.isspace():
            package_name = current_package['Package']
            package_version = current_package['Version']
            if not package_name in version_map:
                # 跳过子包
                continue
            latest_version = version_map[package_name]
            if package_version != latest_version:
                print(f'{package_name}@{arch}: 期望 {latest_version}，但实际是 {package_version}')
            current_package.clear()
        elif not line.decode().startswith(' '):
            parts = line.decode().split(':', 1)
            current_package[parts[0].strip()] = parts[1].strip()

# 检查所有架构的包版本
for arch in ['all', 'aarch64', 'arm', 'i686', 'x86_64']:
    manifest_url = f'https://termux.dev/packages/dists/stable/main/binary-{arch}/Packages'
    with urllib.request.urlopen(manifest_url) as manifest:
        check_manifest(arch, manifest)
