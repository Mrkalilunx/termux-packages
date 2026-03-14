# 这些选项和函数来自
# .github/workflows/packages.yml，用于将包上传到我们的仓库

CURL_COMMON_OPTIONS=(
  --silent
  --retry 2
  --retry-delay 3
  --user-agent 'Termux-Packages/1.0\ (https://github.com/termux/termux-packages)'
  --user "${APTLY_API_AUTH}"
  --write-out "|%{http_code}"
)

CURL_ADDITIONAL_OPTIONS=()

# 如果没有提供认证，发出警告而不是退出
check_login() {
  export APTLY_API_AUTH_WARN=${APTLY_API_AUTH_WARN:=0}
  local e=0
  if [[ -z "${APTLY_API_AUTH}" ]]; then
    e=1
    if [[ "$((APTLY_API_AUTH_WARN & 1))" == 0 ]]; then
      echo "[$(date +%H:%M:%S)] 警告：未提供 APTLY_API_AUTH"
      APTLY_API_AUTH_WARN=$((APTLY_API_AUTH_WARN | 1))
    fi
  fi
  if [[ -z "${GPG_PASSPHRASE}" ]]; then
    e=1
    if [[ "$((APTLY_API_AUTH_WARN & 2))" == 0 ]]; then
      echo "[$(date +%H:%M:%S)] 警告：未提供 GPG_PASSPHRASE"
      APTLY_API_AUTH_WARN=$((APTLY_API_AUTH_WARN | 2))
    fi
  fi
  if [[ "${e}" != 0 ]]; then
    if [[ "$((APTLY_API_AUTH_WARN & 4))" == 0 ]]; then
      echo "[$(date +%H:%M:%S)] 警告：您很可能在分支仓库中。上传将被取消。如果此信息不正确，请修复。"
      APTLY_API_AUTH_WARN=$((APTLY_API_AUTH_WARN | 4))
    fi
    return 1
  fi
}

# 用于从服务器删除包含上传文件的临时目录的函数。
aptly_delete_dir() {
  ! check_login && return 0
  echo "[$(date +%H:%M:%S)] 正在删除上传的临时目录..."

  curl_response=$(
    curl \
      "${CURL_COMMON_OPTIONS[@]}" "${CURL_ADDITIONAL_OPTIONS[@]}" \
      --request DELETE \
      ${REPOSITORY_URL}/files/${REPOSITORY_NAME}-${GITHUB_SHA}
  )

  http_status_code=$(echo "$curl_response" | cut -d'|' -f2 | grep -oP '\d{3}$')

  if [ "$http_status_code" != "200" ]; then
    echo "[$(date +%H:%M:%S)] 警告：服务器在删除临时目录时返回了 $http_status_code 状态码。"
  fi
}

aptly_upload_file() {
  ! check_login && return 0
  local filename="$1"
  curl_response=$(curl \
    "${CURL_COMMON_OPTIONS[@]}" "${CURL_ADDITIONAL_OPTIONS[@]}" \
    --request POST \
    --form file=@${filename} \
    ${REPOSITORY_URL}/files/${REPOSITORY_NAME}-${GITHUB_SHA} || true
  )
  http_status_code=$(echo "$curl_response" | cut -d'|' -f2 | grep -oP '\d{3}$')

  if [ "$http_status_code" = "200" ]; then
    echo "[$(date +%H:%M:%S)] 已上传：$(echo "$curl_response" | cut -d'|' -f1 | jq -r '.[]' | cut -d'/' -f2)"
  elif [ "$http_status_code" = "000" ]; then
    echo "[$(date +%H:%M:%S)]：上传 '$filename' 失败。服务器/代理在上传过程中断开连接。"
    echo "[$(date +%H:%M:%S)]：中止对此仓库的任何进一步上传。"
    aptly_delete_dir
    return 1
  else
    # 手动清理临时目录以释放磁盘空间。
    # 不要依赖服务器端的定时脚本。
    echo "[$(date +%H:%M:%S)] 错误：上传 '$filename' 失败。服务器返回了 $http_status_code 状态码。"
    echo "[$(date +%H:%M:%S)] 中止对此仓库的任何进一步上传。"
    aptly_delete_dir
    return 1
  fi
  return 0
}

aptly_add_to_repo() {
  ! check_login && return 0
  echo "[$(date +%H:%M:%S)] 正在将包添加到仓库 '$REPOSITORY_NAME'..."
  curl_response=$(
    curl \
      "${CURL_COMMON_OPTIONS[@]}" "${CURL_ADDITIONAL_OPTIONS[@]}" \
      --max-time 300 \
      --request POST \
      ${REPOSITORY_URL}/repos/${REPOSITORY_NAME}/file/${REPOSITORY_NAME}-${GITHUB_SHA} || true
  )
  http_status_code=$(echo "$curl_response" | cut -d'|' -f2 | grep -oP '\d{3}$')

  if [ "$http_status_code" = "200" ]; then
    warnings=$(echo "$curl_response" | cut -d'|' -f1 | jq '.Report.Warnings' | jq -r '.[]')
    if [ -n "$warnings" ]; then
      echo "[$(date +%H:%M:%S)] APTLY 警告（非致命）："
      echo
      echo "$warnings"
      echo
      return 1
    fi
  elif [ "$http_status_code" == "000" ]; then
    echo "[$(date +%H:%M:%S)] 警告：服务器/代理断开连接。假设主机正在添加包，尽管连接已丢失。"
    echo "[$(date +%H:%M:%S)] 警告：等待主机添加包。休眠 180 秒。假设包在此之前将被添加。"
    sleep 180
    return 0
  else
    echo "[$(date +%H:%M:%S)] 错误：得到 http_status_code == '$http_status_code'。"
    echo "[$(date +%H:%M:%S)] 错误：发生了意外情况。请任何维护者检查 aptly 日志"
    return 1
  fi
  return 0
}

aptly_publish_repo() {
  ! check_login && return 0
  echo "[$(date +%H:%M:%S)] 正在发布仓库更改..."
  curl_response=$(
    curl \
      "${CURL_COMMON_OPTIONS[@]}" "${CURL_ADDITIONAL_OPTIONS[@]}" \
      --max-time 300 \
      --header 'Content-Type: application/json' \
      --request PUT \
      --data "{\"Signing\": {\"Passphrase\": \"${GPG_PASSPHRASE}\"}}" \
      ${REPOSITORY_URL}/publish/${REPOSITORY_NAME}/${REPOSITORY_DISTRIBUTION} || true
  )
  http_status_code=$(echo "$curl_response" | cut -d'|' -f2 | grep -oP '\d{3}$')

  if [ "$http_status_code" = "200" ]; then
    echo "[$(date +%H:%M:%S)] 仓库已成功更新。"
  elif [ "$http_status_code" = "000" ]; then
    echo "[$(date +%H:%M:%S)] 警告：服务器/代理已断开连接。"
    # 忽略 - 除非更改代理，否则无法对此做任何处理。
    # return 1
  elif [ "$http_status_code" = "504" ]; then
    echo "[$(date +%H:%M:%S)] 警告：请求处理时间过长，连接断开。"
    # 忽略 - 除非更改仓库管理工具或减小仓库大小，否则无法对此做任何处理。
    # return 1
  else
    echo "[$(date +%H:%M:%S)] 错误：得到 http_status_code == '$http_status_code'"
    return 1
  fi
  return 0
}
