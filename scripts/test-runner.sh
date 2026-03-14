#!/data/data/com.termux/files/usr/bin/bash

if [ $# != 1 ]; then
	echo "指定要运行测试的包作为唯一参数"
	exit 1
fi

PACKAGE=$1
TEST_DIR=packages/$PACKAGE/tests

if [ ! -d $TEST_DIR ]; then
	echo "错误：包 $PACKAGE 没有测试文件夹"
	exit 1
fi

NUM_TESTS=0
NUM_FAILURES=0

for TEST_SCRIPT in $TEST_DIR/*; do
	test -t 1 && printf "\033[32m"
	echo "正在运行测试 ${TEST_SCRIPT}..."
	(( NUM_TESTS += 1 ))
	test -t 1 && printf "\033[31m"
	(
		assert_equals() {
			FIRST=$1
			SECOND=$2
			if [ "$FIRST" != "$SECOND" ]; then
				echo "断言失败 - 期望 '$FIRST'，得到 '$SECOND'"
				exit 1
			fi
		}
		set -e -u
		. $TEST_SCRIPT
	)
	if [ $? != 0 ]; then
		(( NUM_FAILURES += 1 ))
	fi
	test -t 1 && printf "\033[0m"
done

echo "运行了 $NUM_TESTS 个测试 - $NUM_FAILURES 个失败"
