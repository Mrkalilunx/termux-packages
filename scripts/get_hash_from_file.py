#!/usr/bin/env python3

import sys, os

def get_pkg_hash_from_Packages(Packages_file, package, version, hash_type="SHA256"):
    with open(Packages_file, 'r') as Packages:
        package_list = Packages.read().split('\n\n')
    for pkg in package_list:
        if pkg.split('\n')[0] == "Package: "+package:
            for line in pkg.split('\n'):
                # 假设 Filename: 出现在 Version: 之前
                if line.startswith('Filename:'):
                    print(line.split(" ")[1] + " ")
                elif line.startswith('Version:'):
                    if os.getenv('TERMUX_WITHOUT_DEPVERSION_BINDING') != 'true' and line != 'Version: '+version:
                        # 似乎仓库包含错误的版本或多个版本
                        # 我们不能使用这个版本，所以继续查找
                        break
                elif line.startswith(hash_type):
                    print(line.split(" ")[1])
                    package_list.clear()

def get_Packages_hash_from_Release(Release_file, arch, component, hash_type="SHA256"):
    string_to_find = component+'/binary-'+arch+'/Packages'
    with open(Release_file, 'r') as Release:
        hash_list = Release.readlines()
    for i in range(len(hash_list)):
        if hash_list[i].startswith(hash_type+':'):
            break
    for j in range(i, len(hash_list)):
        if string_to_find in hash_list[j].strip(' ') and string_to_find+"." not in hash_list[j].strip(' '):
            hash_entry = list(filter(lambda s: s != '', hash_list[j].strip('').split(' ')))
            if hash_entry[2].startswith(".work_"):
                continue
            print(hash_entry[0])
            break

if __name__ == '__main__':
    if len(sys.argv) < 4:
        sys.exit('参数太少，我需要一个 Packages 文件的路径、一个包名称和一个版本，或者一个 InRelease 文件、一个架构和一个组件名称。正在退出')

    if sys.argv[1].endswith('Packages'):
        get_pkg_hash_from_Packages(sys.argv[1], sys.argv[2], sys.argv[3])
    elif sys.argv[1].endswith(('InRelease', 'Release')):
        get_Packages_hash_from_Release(sys.argv[1], sys.argv[2], sys.argv[3])
    else:
        sys.exit(sys.argv[1]+' 似乎不是 Packages 或 InRelease/Release 文件的路径')
