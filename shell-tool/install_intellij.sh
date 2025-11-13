#!/bin/zsh
# install_intellij.sh
# 终极版：支持多版本 IntelliJ IDEA 安装，自动卸载旧卷、处理 Info.plist、签名修复与缓存刷新。
# ✅ 兼容中文路径与空格路径
# ✅ 修复 bad substitution 错误
# ✅ 自动检测 DMG 是否存在并优雅报错

export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
set -e
set -o pipefail

# -------------------------------
# 配置区（按需修改路径）
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

# -------------------------------
# 自动清理临时挂载
# -------------------------------
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

# -------------------------------
# 卸载残留 IntelliJ 挂载卷
# -------------------------------
unmount_old_intellij_volumes() {
  info "🔍 检查并尝试卸载残留 IntelliJ 挂载卷..."
  for vol in /Volumes/IntelliJ*; do
    if [[ -d "$vol" ]]; then
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

# -------------------------------
# 挂载 DMG 并返回挂载点
# -------------------------------
mount_dmg() {
  local dmg_path="$1"
  local max_retries=${2:-3}

  if [[ ! -f "$dmg_path" ]]; then
    err "DMG 文件不存在：$dmg_path"
    return 1
  fi

  info "📀 尝试挂载 DMG：$dmg_path"

  local attempt=1
  while (( attempt <= max_retries )); do
    local out
    if ! out=$(hdiutil attach -nobrowse -readonly -plist "$dmg_path" 2>/dev/null); then
      warn "hdiutil attach 返回错误（第 ${attempt} 次）"
      ((attempt++))
      sleep 1
      continue
    fi

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

# -------------------------------
# 从挂载卷复制 .app 到目标目录
# -------------------------------
install_from_mount() {
  local mount_point="$1"
  local dest_app="$2"

  local src_app
  src_app=$(find "$mount_point" -maxdepth 1 -name "*.app" -print -quit || true)
  if [[ -z "$src_app" || ! -d "$src_app" ]]; then
    err "DMG 内未找到 .app（挂载点：$mount_point）"
    return 1
  fi

  info "📦 复制应用：$src_app -> $dest_app"
  if [[ -d "$dest_app" ]]; then
    info "    删除已有目标：$dest_app"
    sudo rm -rf "$dest_app"
  fi

  sudo cp -R "$src_app" "$dest_app"
  if [[ ! -d "$dest_app" ]]; then
    err "复制失败：$dest_app 未创建"
    return 1
  fi
  return 0
}

# -------------------------------
# 修改 Info.plist（键值数组）
# -------------------------------
modify_info_plist() {
  local dest_app="$1"; shift
  local keys_name="$1"; shift
  local vals_name="$1"; shift

  local plist="$dest_app/Contents/Info.plist"
  if [[ ! -f "$plist" ]]; then
    warn "Info.plist 不存在：$plist（将继续）"
    return 0
  fi

  local -a keys vals
  eval "keys=(\"\${${keys_name}[@]}\")"
  eval "vals=(\"\${${vals_name}[@]}\")"

  local n=${#keys[@]}
  for ((i=0;i<n;i++)); do
    local k=${keys[i]}
    local v=${vals[i]}
    sudo /usr/libexec/PlistBuddy -c "Set :${k} ${v}" "$plist" 2>/dev/null || \
      sudo /usr/libexec/PlistBuddy -c "Add :${k} string ${v}" "$plist" 2>/dev/null || \
      warn "无法写 Info.plist 的 ${k}（继续）"
  done
}

# -------------------------------
# 后处理：xattr、签名、注册
# -------------------------------
post_install_fixup() {
  local dest_app="$1"
  info "🧹 清除扩展属性与修正权限：$dest_app"
  sudo xattr -cr "$dest_app" >/dev/null 2>&1 || warn "xattr 清理失败"
  sudo chmod -R 755 "$dest_app" >/dev/null 2>&1 || warn "chmod 失败"

  info "🔏 重新签名并刷新 LaunchServices：$dest_app"
  sudo codesign --force --deep --sign - "$dest_app" >/dev/null 2>&1 || warn "codesign 失败"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$dest_app" >/dev/null 2>&1 || warn "lsregister 刷新失败"
}

# -------------------------------
# 主流程：安装单个版本
# -------------------------------
deploy_from_dmg() {
  local dmg_path="$1"
  local dest_app="$2"
  local keys_array_name="$3"
  local vals_array_name="$4"

  info "------------------------------"
  info "开始安装：$dest_app"
  info "DMG 路径：$dmg_path"

  local mp
  if ! mp=$(mount_dmg "$dmg_path"); then
    err "挂载失败，跳过安装：$dmg_path"
    return 1
  fi

  if ! install_from_mount "$mp" "$dest_app"; then
    err "复制失败，尝试卸载挂载并返回"
    sudo hdiutil detach "$mp" -force >/dev/null 2>&1 || true
    return 1
  fi

  sudo hdiutil detach "$mp" -force >/dev/null 2>&1 || warn "卸载 $mp 失败（继续）"

  modify_info_plist "$dest_app" "$keys_array_name" "$vals_array_name"
  post_install_fixup "$dest_app"

  ok "$dest_app 安装完成"
  return 0
}

# -------------------------------
# 主入口
# -------------------------------
info "🧹 清理旧版本（仅 /Applications 指定目标）..."
sudo rm -rf "$IDEA_2023_APP" "$IDEA_2025_APP" >/dev/null 2>&1 || true
unmount_old_intellij_volumes

deploy_from_dmg "$IDEA_2023_DMG" "$IDEA_2023_APP" "INFO_2023_KEYS" "INFO_2023_VALUES" || warn "2023.2 安装返回非0"
deploy_from_dmg "$IDEA_2025_DMG" "$IDEA_2025_APP" "INFO_2025_KEYS" "INFO_2025_VALUES" || warn "2025.2 安装返回非0"

log ""
ok "安装脚本执行完毕。请使用以下命令启动验证："
log "启动 2023.2:"
log "  open -n \"$IDEA_2023_APP\" --args -Didea.paths.selector=IntelliJIdea2023.2"
log "启动 2025.2:"
log "  open -n \"$IDEA_2025_APP\" --args -Didea.paths.selector=IntelliJIdea2025.2"

exit 0
