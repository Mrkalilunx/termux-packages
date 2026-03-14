termux_step_create_debian_package() {
	if [ "$TERMUX_PKG_METAPACKAGE" = "true" ]; then
		# 元包内部没有数据。
		rm -rf data
	fi
	tar --sort=name \
		--mtime="@${SOURCE_DATE_EPOCH}" \
		--owner=0 --group=0 --numeric-owner \
		-cJf "$TERMUX_PKG_PACKAGEDIR/data.tar.xz" -H gnu .

	# 获取安装大小。这将被写入为 "Installed-Size" deb 字段，因此以 1024 字节块为单位测量：
	local TERMUX_PKG_INSTALLSIZE
	TERMUX_PKG_INSTALLSIZE=$(du -sk . | cut -f 1)

	# 从现在开始，如果包设置了 TERMUX_PKG_PLATFORM_INDEPENDENT，则 TERMUX_ARCH 被设置为 "all"
	[ "$TERMUX_PKG_PLATFORM_INDEPENDENT" = "true" ] && TERMUX_ARCH=all

	mkdir -p DEBIAN
	cat > DEBIAN/control <<-HERE
		Package: $TERMUX_PKG_NAME
		Architecture: ${TERMUX_ARCH}
		Installed-Size: ${TERMUX_PKG_INSTALLSIZE}
		Maintainer: $TERMUX_PKG_MAINTAINER
		Version: $TERMUX_PKG_FULLVERSION
		Homepage: $TERMUX_PKG_HOMEPAGE
	HERE
	if [ "$TERMUX_GLOBAL_LIBRARY" = "true" ] && [ "$TERMUX_PACKAGE_LIBRARY" = "glibc" ]; then
		test ! -z "$TERMUX_PKG_DEPENDS" && TERMUX_PKG_DEPENDS=$(termux_package__add_prefix_glibc_to_package_list "$TERMUX_PKG_DEPENDS")
		test ! -z "$TERMUX_PKG_BREAKS" && TERMUX_PKG_BREAKS=$(termux_package__add_prefix_glibc_to_package_list "$TERMUX_PKG_BREAKS")
		test ! -z "$TERMUX_PKG_CONFLICTS" && TERMUX_PKG_CONFLICTS=$(termux_package__add_prefix_glibc_to_package_list "$TERMUX_PKG_CONFLICTS")
		test ! -z "$TERMUX_PKG_RECOMMENDS" && TERMUX_PKG_RECOMMENDS=$(termux_package__add_prefix_glibc_to_package_list "$TERMUX_PKG_RECOMMENDS")
		test ! -z "$TERMUX_PKG_REPLACES" && TERMUX_PKG_REPLACES=$(termux_package__add_prefix_glibc_to_package_list "$TERMUX_PKG_REPLACES")
		test ! -z "$TERMUX_PKG_PROVIDES" && TERMUX_PKG_PROVIDES=$(termux_package__add_prefix_glibc_to_package_list "$TERMUX_PKG_PROVIDES")
		test ! -z "$TERMUX_PKG_SUGGESTS" && TERMUX_PKG_SUGGESTS=$(termux_package__add_prefix_glibc_to_package_list "$TERMUX_PKG_SUGGESTS")
	fi
	test ! -z "$TERMUX_PKG_BREAKS" && echo "Breaks: $TERMUX_PKG_BREAKS" >> DEBIAN/control
	test ! -z "$TERMUX_PKG_PRE_DEPENDS" && echo "Pre-Depends: $TERMUX_PKG_PRE_DEPENDS" >> DEBIAN/control
	test ! -z "$TERMUX_PKG_DEPENDS" && echo "Depends: $TERMUX_PKG_DEPENDS" >> DEBIAN/control
	[ "$TERMUX_PKG_ESSENTIAL" = "true" ] && echo "Essential: yes" >> DEBIAN/control
	test ! -z "$TERMUX_PKG_CONFLICTS" && echo "Conflicts: $TERMUX_PKG_CONFLICTS" >> DEBIAN/control
	test ! -z "$TERMUX_PKG_RECOMMENDS" && echo "Recommends: $TERMUX_PKG_RECOMMENDS" >> DEBIAN/control
	test ! -z "$TERMUX_PKG_REPLACES" && echo "Replaces: $TERMUX_PKG_REPLACES" >> DEBIAN/control
	test ! -z "$TERMUX_PKG_PROVIDES" && echo "Provides: $TERMUX_PKG_PROVIDES" >> DEBIAN/control
	test ! -z "$TERMUX_PKG_SUGGESTS" && echo "Suggests: $TERMUX_PKG_SUGGESTS" >> DEBIAN/control
	echo "Description: $TERMUX_PKG_DESCRIPTION" >> DEBIAN/control

	# 创建 DEBIAN/conffiles（参见 https://www.debian.org/doc/debian-policy/ap-pkg-conffiles.html）：
	for f in $TERMUX_PKG_CONFFILES; do echo "$TERMUX_PREFIX_CLASSICAL/$f" >> DEBIAN/conffiles; done

	# 允许包创建任意控制文件。
	# XXX：应该在没有函数的情况下以更好的方式完成？
	cd DEBIAN
	termux_step_create_debscripts
	# 处理来自 `.alternatives` 文件的 `update-alternatives` 条目
	# 这些需要合并到 `.postinst` 和 `.prerm` 文件中，因此在创建这些文件之后。
	termux_step_update_alternatives
	termux_step_create_python_debscripts

	# 创建 control.tar.xz
	tar --sort=name \
		--mtime="@${SOURCE_DATE_EPOCH}" \
		--owner=0 --group=0 --numeric-owner \
		-cJf "$TERMUX_PKG_PACKAGEDIR/control.tar.xz" -H gnu .

	test ! -f "$TERMUX_COMMON_CACHEDIR/debian-binary" && echo "2.0" > "$TERMUX_COMMON_CACHEDIR/debian-binary"
	TERMUX_PKG_DEBFILE=$TERMUX_OUTPUT_DIR/${TERMUX_PKG_NAME}${DEBUG}_${TERMUX_PKG_FULLVERSION}_${TERMUX_ARCH}.deb
	# 创建实际的 .deb 文件：
	${AR-ar} cr "$TERMUX_PKG_DEBFILE" \
		"$TERMUX_COMMON_CACHEDIR/debian-binary" \
		"$TERMUX_PKG_PACKAGEDIR/control.tar.xz" \
		"$TERMUX_PKG_PACKAGEDIR/data.tar.xz"
}
