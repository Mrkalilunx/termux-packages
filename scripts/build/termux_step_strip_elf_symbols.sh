termux_step_strip_elf_symbols() {
	termux_step_strip_elf_symbols__from_paths . \( -path "./bin/*" -o -path "./lib/*" -o -path "./lib32/*" -o -path "./libexec/*" \)
}

termux_step_strip_elf_symbols__from_paths() {
	# 剥离二进制文件。file(1) 对于某些不寻常的文件可能会失败，因此禁用 pipefail。
	(
		set +e +o pipefail && \
		find "$@" -type f -print0 | xargs -r -0 \
			file | grep -E "ELF .+ (executable|shared object)" | cut -f 1 -d : |
			xargs -r "$STRIP" --strip-unneeded --preserve-dates
	)
}
