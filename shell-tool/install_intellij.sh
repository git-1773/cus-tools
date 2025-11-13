#!/bin/zsh
# install_intellij.sh
# zsh: 为多版本 IntelliJ 安装做全面处理（支持中文/空格路径、卸载残留挂载、签名、清除 quarantine、刷新 LaunchServices）

export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
set -e
set -o pipefail

# -------------------------------
# 配置区（请按需修改路径）
# -------------------------------
IDEA_2023_DMG="/Users/ypj/Desktop/移动硬盘/aldi待整理文件夹/待安装软件列表/ideaIU-2023.2.dmg"
IDEA_2025_DMG="/Users/ypj/Downloads/download_googlechrome/ideaIU-2025.2.4-aarch64.dmg"

IDEA_2023_APP="/Applications/IntelliJ IDEA 2023.2.app"
IDEA_2025_APP="/Applications/IntelliJ IDEA 2025.2.app"

INFO_2023_KEYS=("CFBundleIdentifier" "CFBundleName" "CFBundleDisplayName" "LSMinimumSystemVersion")
INFO_2023_VALUES=("com.jetbrains.intellij.2023.2" "IntelliJ IDEA 2023.2" "IntelliJ IDEA 2023.2" "10.15")

INFO_2025_KEYS=("CFBundleIdentifier" "CFBundleName" "CFBundleDisplayName" "LSMinimumSystemVersion")
INFO_2025_VALUES=("com.jetbrains.intellij.2025.2" "IntelliJ IDEA 2025.2" "IntelliJ IDEA 2025.2" "10.13")

# -------------------------------
# 公共工具函数
# -------------------------------
log()    { printf "%b\n" "$*"; }
info()   { log "🔧 $*"; }
ok()     { log "✅ $*"; }
warn()   { log "⚠️  $*"; }
err()    { log "❌ $*"; }

# 保证退出时尝试卸载我们挂载的临时卷
TEMP_MOUNTS=()
cleanup() {
  if [[ ${#TEMP_MOUNTS[@]} -gt 0 ]]; then
    for m in "${TEMP_MOUNTS[@]}"; do
      if [[ -d "$m" ]]; then
        warn "退出时尝试卸载临时挂载：$m"
        sudo hdiutil detach "$m" -force >/dev/null 2>&1 || warn "卸载 $m 失败"
      fi
    done
  fi
}
trap cleanup EXIT

# 卸载残留 IntelliJ 相关挂载（保守匹配 /Volumes/IntelliJ*）
unmount_old_intellij_volumes() {
  info "🔍 检查并尝试卸载残留 IntelliJ 挂载卷..."
  for vol in /Volumes/IntelliJ*; do
    if [[ -d "$vol" ]]; then
      # 仅卸载路径名以 IntelliJ 开头的卷，避免误操作其他卷
      base=$(basename "$vol")
      if [[ "$base" = IntelliJ* ]]; then
        info "  ➜ 卸载残留卷: $vol"
        if sudo hdiutil detach "$vol" -force >/dev/null 2>&1; then
          ok "已卸载：$vol"
        else
          warn "卸载失败或被占用：$vol"
        fi
      fi
    fi
  done
}

# 将 DMG 挂载并返回挂载点（兼容 BSD awk、中文路径、-plist 输出）
# 返回值：打印挂载点（stdout），失败返回非0
mount_dmg() {
  local dmg_path="$1"
  local max_retries=${2:-3}
  info "📀 尝试挂载 DMG：$dmg_path"

  local attempt=1
  while (( attempt <= max_retries )); do
    # 使用 plist 输出便于解析（在 zsh 上用 awk 提取 <string>)
    local out
    if ! out=$(hdiutil attach -nobrowse -readonly -plist "$dmg_path" 2>/dev/null); then
      warn "hdiutil attach 返回错误（第 ${attempt} 次）"
      ((attempt++))
      sleep 1
      continue
    fi

    # BSD awk 解析：找到 <key>mount-point</key> 后的 <string> 内容
    local mp
    mp=$(echo "$out" | awk '
      /<key>mount-point<\/key>/ {found=1; next}
      found && /<string>/ {
        sub(/.*<string>/, "", $0)
        sub(/<\/string>.*/, "", $0)
        print $0
        exit
      }')

    if [[ -n "$mp" && -d "$mp" ]]; then
      ok "挂载成功：$mp"
      # 记录到临时挂载列表，脚本退出时会尝试卸载
      TEMP_MOUNTS+=("$mp")
      echo "$mp"
      return 0
    else
      warn "未解析到有效挂载点（第 ${attempt} 次）"
      ((attempt++))
      sleep 1
    fi
  done

  err "DMG 挂载失败或未找到有效卷：$dmg_path"
  return 1
}

# 复制 .app 并修复签名、xattr、LaunchServices
install_from_mount() {
  local mount_point="$1"
  local dest_app="$2"
  local -a keys=("${(@P)3}")   # placeholder - not used; we'll pass keys/values explicit
  # 寻找 DMG 内的 .app（顶层）
  local src_app
  src_app=$(find "$mount_point" -maxdepth 1 -name "*.app" -print -quit || true)
  if [[ -z "$src_app" || ! -d "$src_app" ]]; then
    err "DMG 内未找到 .app（挂载点：$mount_point）"
    return 1
  fi

  info "📦 复制应用：$src_app -> $dest_app"
  # 删除目标（保守操作，先备份可以改为移动到废纸篓）
  if [[ -d "$dest_app" ]]; then
    info "    删除已有目标：$dest_app"
    sudo rm -rf "$dest_app"
  fi

  sudo cp -R "$src_app" "$dest_app"
  if [[ ! -d "$dest_app" ]]; then
    err "复制失败：$dest_app 未创建"
    return 1
  fi

  # 修 Info.plist 的步骤由调用方传入键值对
  return 0
}

# 修改 Info.plist 的通用函数：传入 dest_app, keys_array_name, values_array_name
modify_info_plist() {
  local dest_app="$1"; shift
  local keys_name="$1"; shift
  local vals_name="$1"; shift

  local plist="$dest_app/Contents/Info.plist"
  if [[ ! -f "$plist" ]]; then
    warn "Info.plist 不存在：$plist（将继续）"
    return 0
  fi

  # 读取键值数组
  local -a keys
  local -a vals
  eval "keys=(\"\${${keys_name}[@]}\")"
  eval "vals=(\"\${${vals_name}[@]}\")"

  local n=${#keys[@]}
  for ((i=0;i<n;i++)); do
    local k=${keys[i]}
    local v=${vals[i]}
    # 用 PlistBuddy 设置或新增
    sudo /usr/libexec/PlistBuddy -c "Set :${k} ${v}" "$plist" 2>/dev/null || \
      sudo /usr/libexec/PlistBuddy -c "Add :${k} string ${v}" "$plist" 2>/dev/null || \
      warn "无法写 Info.plist 的 ${k}（继续）"
  done
}

# 清理安全属性、签名、刷新 LaunchServices
post_install_fixup() {
  local dest_app="$1"
  info "🧹 清除扩展属性（xattr）与修正权限：$dest_app"
  sudo xattr -cr "$dest_app" >/dev/null 2>&1 || warn "xattr 清理失败（可忽略）"
  sudo chmod -R 755 "$dest_app" >/dev/null 2>&1 || warn "chmod 失败（可忽略）"

  info "🔏 重新签名（占位签名）并刷新 LaunchServices：$dest_app"
  sudo codesign --force --deep --sign - "$dest_app" >/dev/null 2>&1 || warn "codesign 失败（可忽略）"

  # 强制注册到 LaunchServices，确保 Launchpad / Spotlight 能看到新版路径
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$dest_app" >/dev/null 2>&1 || warn "lsregister 刷新失败（可忽略）"
}

# 主安装流程：给出 dmg_path, dest_app, keys_array_name, values_array_name
deploy_from_dmg() {
  local dmg_path="$1"
  local dest_app="$2"
  local keys_array_name="$3"
  local vals_array_name="$4"

  info "------------------------------"
  info "开始安装：$dest_app"
  info "DMG 路径：$dmg_path"

  # 尝试挂载
  local mp
  if ! mp=$(mount_dmg "$dmg_path"); then
    err "挂载失败，跳过安装：$dmg_path"
    return 1
  fi

  # 复制 .app
  if ! install_from_mount "$mp" "$dest_app"; then
    err "复制失败，尝试卸载挂载并返回"
    sudo hdiutil detach "$mp" -force >/dev/null 2>&1 || true
    return 1
  fi

  # 卸载挂载点（我们已复制出 app）
  if sudo hdiutil detach "$mp" -force >/dev/null 2>&1; then
    ok "已卸载挂载点：$mp"
    # 从临时列表移除（避免 cleanup 再次尝试）
    for i in "${(@)TEMP_MOUNTS}"; do
      if [[ "$i" == "$mp" ]]; then
        # 删除匹配项
        local newarr=()
        for j in "${TEMP_MOUNTS[@]}"; do
          [[ "$j" == "$mp" ]] || newarr+=("$j")
        done
        TEMP_MOUNTS=("${newarr[@]}")
        break
      fi
    done
  else
    warn "卸载 $mp 失败（但是继续）"
  fi

  # 修改 Info.plist
  modify_info_plist "$dest_app" "$keys_array_name" "$vals_array_name"

  # 修复签名/权限/缓存
  post_install_fixup "$dest_app"

  ok "$dest_app 安装完成"
  return 0
}

# -------------------------------
# 主流程
# -------------------------------
info "🧹 清理旧版本（仅 /Applications 指定目标）..."
sudo rm -rf "$IDEA_2023_APP" "$IDEA_2025_APP" >/dev/null 2>&1 || true

unmount_old_intellij_volumes

# 依次安装两个版本（可按需改顺序）
deploy_from_dmg "$IDEA_2023_DMG" "$IDEA_2023_APP" "INFO_2023_KEYS" "INFO_2023_VALUES" || warn "2023.2 安装过程返回非0"
deploy_from_dmg "$IDEA_2025_DMG" "$IDEA_2025_APP" "INFO_2025_KEYS" "INFO_2025_VALUES" || warn "2025.2 安装过程返回非0"

# 最终提示启动指令（使用 -n 保证新实例）
log ""
ok "安装脚本执行完毕。请分别用下列命令启动并验证："
log "启动 2023.2:"
log "  open -n \"$IDEA_2023_APP\" --args -Didea.paths.selector=IntelliJIdea2023.2"
log "启动 2025.2:"
log "  open -n \"$IDEA_2025_APP\" --args -Didea.paths.selector=IntelliJIdea2025.2"

# 结束（trap 会处理未卸载的临时挂载）
exit 0
