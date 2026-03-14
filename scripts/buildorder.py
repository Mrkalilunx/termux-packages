#!/usr/bin/env python3
"用于生成构建顺序的脚本，该顺序遵循包依赖关系。"

import json, os, re, sys

from itertools import filterfalse

termux_arch = os.getenv('TERMUX_ARCH') or 'aarch64'
termux_global_library = os.getenv('TERMUX_GLOBAL_LIBRARY') or 'false'
termux_pkg_library = os.getenv('TERMUX_PACKAGE_LIBRARY') or 'bionic'

def unique_everseen(iterable, key=None):
    """列出唯一元素，保持顺序。记住所有曾经见过的元素。
    参见 https://docs.python.org/3/library/itertools.html#itertools-recipes
    示例：
    unique_everseen('AAAABBBCCDAABBB') --> A B C D
    unique_everseen('ABBCcAD', str.lower) --> A B C D"""
    seen = set()
    seen_add = seen.add
    if key is None:
        for element in filterfalse(seen.__contains__, iterable):
            seen_add(element)
            yield element
    else:
        for element in iterable:
            k = key(element)
            if k not in seen:
                seen_add(k)
                yield element

def die(msg):
    "通过错误消息退出进程。"
    sys.exit('ERROR: ' + msg)

def remove_nl_and_quotes(var):
    for char in "\"'\n":
        var = var.replace(char, '')
    return var

def parse_build_file_dependencies_with_vars(path, vars):
    "提取 build.sh 或 *.subpackage.sh 文件中给定变量指定的依赖项。"
    dependencies = []

    with open(path, encoding="utf-8") as build_script:
        for line in build_script:
            if line.startswith(vars):
                dependencies_string = remove_nl_and_quotes(line.split('DEPENDS=')[1])

                # 同时在 '|' 上分割具有 '|' 的依赖项，如 'nodejs | nodejs-current'：
                for dependency_value in re.split(',|\\|', dependencies_string):
                    # Replace parenthesis to ignore version qualifiers as in "gcc (>= 5.0)":
                    dependency_value = re.sub(r'\(.*?\)', '', dependency_value).strip()
                    arch = os.getenv('TERMUX_ARCH')
                    if arch is None:
                        arch = 'aarch64'
                    if arch == "x86_64":
                        arch = "x86-64"
                    dependency_value = re.sub(r'\${TERMUX_ARCH/_/-}', arch, dependency_value)

                    dependencies.append(dependency_value)

    return set(dependencies)

def parse_build_file_dependencies(path):
    "提取 build.sh 或 *.subpackage.sh 文件的依赖项。"
    return parse_build_file_dependencies_with_vars(path, ('TERMUX_PKG_DEPENDS', 'TERMUX_PKG_BUILD_DEPENDS', 'TERMUX_SUBPKG_DEPENDS', 'TERMUX_PKG_DEVPACKAGE_DEPENDS'))

def parse_build_file_antidependencies(path):
    "提取 build.sh 文件的反依赖项。"
    return parse_build_file_dependencies_with_vars(path, 'TERMUX_PKG_ANTI_BUILD_DEPENDS')

def parse_build_file_excluded_arches(path):
    "提取 build.sh 或 *.subpackage.sh 文件中指定的排除架构。"
    arches = []

    with open(path, encoding="utf-8") as build_script:
        for line in build_script:
            if line.startswith(('TERMUX_PKG_EXCLUDED_ARCHES', 'TERMUX_SUBPKG_EXCLUDED_ARCHES')):
                arches_string = remove_nl_and_quotes(line.split('ARCHES=')[1])
                for arches_value in re.split(',', arches_string):
                    arches.append(arches_value.strip())

    return set(arches)

def parse_build_file_variable(path, var):
    value = None

    with open(path, encoding="utf-8") as build_script:
        for line in build_script:
            if line.startswith(var):
                value = remove_nl_and_quotes(line.split('=')[-1])
                break

    return value

def parse_build_file_variable_bool(path, var):
    return parse_build_file_variable(path, var) == 'true'

def add_prefix_glibc_to_pkgname(name):
    return name.replace("-static", "-glibc-static") if "static" == name.split("-")[-1] else name+"-glibc"

def has_prefix_glibc(pkgname):
    pkgname = pkgname.split("-")
    return "glibc" in pkgname or "glibc32" in pkgname

class TermuxPackage(object):
    "主包定义，由包含 build.sh 文件的目录表示。"
    def __init__(self, dir_path, fast_build_mode):
        self.dir = dir_path
        self.fast_build_mode = fast_build_mode
        self.name = os.path.basename(self.dir)
        self.pkgs_cache = []
        if "gpkg" == self.dir.split("/")[-2] and not has_prefix_glibc(self.name):
            self.name = add_prefix_glibc_to_pkgname(self.name)

        # 搜索包的 build.sh
        build_sh_path = os.path.join(self.dir, 'build.sh')
        if not os.path.isfile(build_sh_path):
            raise Exception("未找到包 '" + self.name + "' 的 build.sh")

        self.deps = parse_build_file_dependencies(build_sh_path)
        self.antideps = parse_build_file_antidependencies(build_sh_path)
        self.excluded_arches = parse_build_file_excluded_arches(build_sh_path)
        self.only_installing = parse_build_file_variable_bool(build_sh_path, 'TERMUX_PKG_ONLY_INSTALLING')
        self.separate_subdeps = parse_build_file_variable_bool(build_sh_path, 'TERMUX_PKG_SEPARATE_SUB_DEPENDS')
        self.accept_dep_scr = parse_build_file_variable_bool(build_sh_path, 'TERMUX_PKG_ACCEPT_PKG_IN_DEP')

        if os.getenv('TERMUX_ON_DEVICE_BUILD') == "true" and termux_pkg_library == "bionic":
            always_deps = ['libc++']
            for dependency_name in always_deps:
                if dependency_name not in self.deps and self.name not in always_deps:
                    self.deps.add(dependency_name)

        # 搜索子包
        self.subpkgs = []

        for filename in os.listdir(self.dir):
            if not filename.endswith('.subpackage.sh'):
                continue
            subpkg = TermuxSubPackage(self.dir + '/' + filename, self)
            if termux_arch in subpkg.excluded_arches:
                continue

            self.subpkgs.append(subpkg)

        subpkg = TermuxSubPackage(self.dir + '/' + self.name + '-static' + '.subpackage.sh', self, virtual=True)
        self.subpkgs.append(subpkg)

        self.needed_by = set()  # 在构造函数外填充，deps 的反向。

    def __repr__(self):
        return "<{} '{}'>".format(self.__class__.__name__, self.name)

    def recursive_dependencies(self, pkgs_map, dir_root=None):
        "包的所有依赖项，包括直接和间接的。"
        result = []
        is_root = dir_root == None
        if is_root:
            dir_root = self.dir
        if is_root or not self.fast_build_mode or not self.separate_subdeps:
            for subpkg in self.subpkgs:
                if f"{self.name}-static" != subpkg.name:
                    self.deps.add(subpkg.name)
                    self.deps |= subpkg.deps
            self.deps -= self.antideps
            self.deps.discard(self.name)
            if not self.fast_build_mode or self.dir == dir_root:
                self.deps.difference_update([subpkg.name for subpkg in self.subpkgs])
        for dependency_name in sorted(self.deps):
            if termux_global_library == "true" and termux_pkg_library == "glibc" and not has_prefix_glibc(dependency_name):
                mod_dependency_name = add_prefix_glibc_to_pkgname(dependency_name)
                dependency_name = mod_dependency_name if mod_dependency_name in pkgs_map else dependency_name
            if dependency_name not in self.pkgs_cache:
                self.pkgs_cache.append(dependency_name)
                dependency_package = pkgs_map[dependency_name]
                if dependency_package.dir != dir_root and dependency_package.only_installing and not self.fast_build_mode:
                    continue
                result += dependency_package.recursive_dependencies(pkgs_map, dir_root)
                if dependency_package.accept_dep_scr or dependency_package.dir != dir_root:
                    result += [dependency_package]
        return unique_everseen(result)

class TermuxSubPackage:
    "由 ${PACKAGE_NAME}.subpackage.sh 文件表示的子包。"
    def __init__(self, subpackage_file_path, parent, virtual=False):
        if parent is None:
            raise Exception("子包应该有一个父包")

        self.name = os.path.basename(subpackage_file_path).split('.subpackage.sh')[0]
        if "gpkg" == subpackage_file_path.split("/")[-3] and not has_prefix_glibc(self.name):
            self.name = add_prefix_glibc_to_pkgname(self.name)
        self.parent = parent
        self.deps = set([parent.name])
        self.only_installing = parent.only_installing
        self.accept_dep_scr = parent.accept_dep_scr
        self.excluded_arches = set()
        if not virtual:
            self.deps |= parse_build_file_dependencies(subpackage_file_path)
            self.excluded_arches |= parse_build_file_excluded_arches(subpackage_file_path)
        self.dir = parent.dir

        self.needed_by = set()  # 在构造函数外填充，deps 的反向。

    def __repr__(self):
        return "<{} '{}' parent='{}'>".format(self.__class__.__name__, self.name, self.parent)

    def recursive_dependencies(self, pkgs_map, dir_root=None):
        """子包的所有依赖项，包括直接和间接的。
        仅在快速构建模式下相关"""
        result = []
        if not dir_root:
            dir_root = self.dir
        for dependency_name in sorted(self.deps):
            if dependency_name == self.parent.name:
                self.parent.deps.discard(self.name)
            dependency_package = pkgs_map[dependency_name]
            if dependency_package not in self.parent.subpkgs:
                result += dependency_package.recursive_dependencies(pkgs_map, dir_root=dir_root)
            if dependency_package.accept_dep_scr or dependency_package.dir != dir_root:
                result += [dependency_package]
        return unique_everseen(result)

def read_packages_from_directories(directories, fast_build_mode, full_buildmode):
    """构建从包名到 TermuxPackage 的映射。
    如果 fast_build_mode 为 false，则子包映射到父包。"""
    pkgs_map = {}
    all_packages = []

    if full_buildmode:
        # 忽略目录并从 repo.json 文件获取所有文件夹
        with open ('repo.json') as f:
            data = json.load(f)
        directories = []
        for d in data.keys():
            if d != "pkg_format":
                directories.append(d)

    for package_dir in directories:
        for pkgdir_name in sorted(os.listdir(package_dir)):
            dir_path = package_dir + '/' + pkgdir_name
            if os.path.isfile(dir_path + '/build.sh'):
                new_package = TermuxPackage(package_dir + '/' + pkgdir_name, fast_build_mode)

                if termux_arch in new_package.excluded_arches:
                    continue

                if new_package.name in pkgs_map:
                    die('Duplicated package: ' + new_package.name)
                else:
                    pkgs_map[new_package.name] = new_package
                all_packages.append(new_package)

                for subpkg in new_package.subpkgs:
                    if termux_arch in subpkg.excluded_arches:
                        continue
                    if subpkg.name in pkgs_map:
                        die('Duplicated package: ' + subpkg.name)
                    elif fast_build_mode:
                        pkgs_map[subpkg.name] = subpkg
                    else:
                        pkgs_map[subpkg.name] = new_package
                    all_packages.append(subpkg)

    for pkg in all_packages:
        for dependency_name in pkg.deps:
            if dependency_name not in pkgs_map:
                die('Package %s depends on non-existing package "%s"' % (pkg.name, dependency_name))
            dep_pkg = pkgs_map[dependency_name]
            if fast_build_mode or not isinstance(pkg, TermuxSubPackage):
                dep_pkg.needed_by.add(pkg)
    return pkgs_map

def generate_full_buildorder(pkgs_map):
    "生成构建所有包的构建顺序。"
    build_order = []

    # 所有没有依赖项的 TermuxPackages 列表
    leaf_pkgs = [pkg for pkg in pkgs_map.values() if not pkg.deps]

    if not leaf_pkgs:
        die('没有没有依赖项的包 - 从哪里开始？')

    # 按字母顺序排序：
    pkg_queue = sorted(leaf_pkgs, key=lambda p: p.name)

    # 拓扑排序
    visited = set()

    # 跟踪每个包的未访问的依赖项
    remaining_deps = {}
    for name, pkg in pkgs_map.items():
        remaining_deps[name] = set(pkg.deps)
        for subpkg in pkg.subpkgs:
            remaining_deps[subpkg.name] = set(subpkg.deps)

    while pkg_queue:
        pkg = pkg_queue.pop(0)
        if pkg.name in visited:
            continue

        # print("正在处理 {}:".format(pkg.name), pkg.needed_by)
        visited.add(pkg.name)
        build_order.append(pkg)

        for other_pkg in sorted(pkg.needed_by, key=lambda p: p.name):
            # 从 deps 中移除此包
            remaining_deps[other_pkg.name].discard(pkg.name)
            # ... 以及其所有子包
            remaining_deps[other_pkg.name].difference_update(
                [subpkg.name for subpkg in pkg.subpkgs]
            )

            if not remaining_deps[other_pkg.name]:  # 所有依赖项都已添加？
                pkg_queue.append(other_pkg)  # 应该被处理

    if set(pkgs_map.values()) != set(build_order):
        print("错误：存在循环。剩余：", file=sys.stderr)
        for name, pkg in pkgs_map.items():
            if pkg not in build_order:
                print(name, remaining_deps[name], file=sys.stderr)

        # 打印循环，以便我们有一些关于从哪里开始修复的想法。
        def find_cycles(deps, pkg, path):
            """生成每个包含循环的依赖路径。"""
            if pkg in path:
                yield path + [pkg]
            else:
                for dep in deps[pkg]:
                    yield from find_cycles(deps, dep, path + [pkg])

        cycles = set()
        for pkg in remaining_deps:
            for path_with_cycle in find_cycles(remaining_deps, pkg, []):
                # Cut the path down to just the cycle.
                cycle_start = path_with_cycle.index(path_with_cycle[-1])
                cycles.add(tuple(path_with_cycle[cycle_start:]))
        for cycle in sorted(cycles):
            print(f"cycle: {' -> '.join(cycle)}", file=sys.stderr)

        sys.exit(1)

    return build_order

def generate_target_buildorder(target_path, pkgs_map, fast_build_mode):
    "生成构建指定包的依赖项的构建顺序。"
    if target_path.endswith('/'):
        target_path = target_path[:-1]

    package_name = os.path.basename(target_path)
    if "gpkg" == target_path.split("/")[-2] and not has_prefix_glibc(package_name):
        package_name = add_prefix_glibc_to_pkgname(package_name)
    package = pkgs_map[package_name]
    # 不依赖于任何子包
    if fast_build_mode:
        package.deps.difference_update([subpkg.name for subpkg in package.subpkgs])
    return package.recursive_dependencies(pkgs_map)

def main():
    "生成构建顺序，可以是所有包或特定包。"
    import argparse

    parser = argparse.ArgumentParser(description='生成构建包的依赖项的顺序。生成')
    parser.add_argument('-i', default=False, action='store_true',
                        help='为快速构建模式生成依赖列表。这包括输出中的子包，因为这些可以下载。')
    parser.add_argument('package', nargs='?',
                        help='要为其生成依赖列表的包。')
    parser.add_argument('package_dirs', nargs='*',
                        help='包含包的目录。例如可以指向 "../community-packages/packages"。注意，如果不存在，包后缀不再自动添加。')
    args = parser.parse_args()
    fast_build_mode = args.i
    package = args.package
    packages_directories = args.package_dirs

    if not package:
        full_buildorder = True
    else:
        full_buildorder = False

    if fast_build_mode and full_buildorder:
        die('-i mode does not work when building all packages')

    if not full_buildorder:
        for path in packages_directories:
            if not os.path.isdir(path):
                die('Not a directory: ' + path)

    if package:
        if package[-1] == "/":
            package = package[:-1]
        if not os.path.isdir(package):
            die('Not a directory: ' + package)
        if not os.path.relpath(os.path.dirname(package), '.') in packages_directories:
            packages_directories.insert(0, os.path.dirname(package))
    pkgs_map = read_packages_from_directories(packages_directories, fast_build_mode, full_buildorder)

    if full_buildorder:
        build_order = generate_full_buildorder(pkgs_map)
    else:
        build_order = generate_target_buildorder(package, pkgs_map, fast_build_mode)

    for pkg in build_order:
        pkg_name = pkg.name
        if termux_global_library == "true" and termux_pkg_library == "glibc" and not has_prefix_glibc(pkg_name):
            pkg_name = add_prefix_glibc_to_pkgname(pkg_name)
        print("%-30s %s" % (pkg_name, pkg.dir))

if __name__ == '__main__':
    main()
