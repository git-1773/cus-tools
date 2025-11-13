#!/bin/zsh
# install_intellij.sh
# zsh: 为多版本 IntelliJ 安装做全面处理（支持中文/空格路径、卸载残留挂载、签名、清除 quarantine、刷新 LaunchServices）
# ✅ 自动卸载残留卷
# ✅ 支持中文/空格路径
# ✅ 重新签名 / 清理 xattr / 刷新 LaunchServices
# ✅ 修复 zsh 挂载点丢失问题
# ✅ 输出优化，终端更清晰

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

# -------------------------------
# 保证退出时尝试卸载我们挂载的临时卷
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
# ✅ 自动卸载残留卷
# -------------------------------
unmount_old_intellij_volumes() {
  info "🔍 检查并尝试卸载残留 IntelliJ 挂载卷..."
  for vol in /Volumes/IntelliJ*; do
    if [[ -d "$vol" ]]; then
      info "  ➜ 卸载残留卷: $vol"
      sudo hdiutil detach "$vol" -force >/dev/null 2>&1 && ok "已卸载：$vol" || warn "卸载失败或被占用：$vol"
    fi
  done
}

# -------------------------------
# ✅ 支持中文/空格路径的安全挂载 DMG（修复挂载点丢失问题）
# -------------------------------
mount_dmg() {
  local dmg_path="$1"
  info "📀 尝试挂载 DMG：$dmg_path"
  local out mp

  # 挂载 DMG 并获取 plist 输出
  out=$(hdiutil attach -nobrowse -readonly -plist "$dmg_path" 2>/dev/null)

  # 遍历 system-entities 查找第一个有效 mount-point
  local count
  count=$(/usr/libexec/PlistBuddy -c "Print :system-entities" /dev/stdin <<< "$out" 2>/dev/null | grep -c 'Dict {')
  for i in $(seq 0 $((count-1))); do
    mp=$(/usr/libexec/PlistBuddy -c "Print :system-entities:$i:mount-point" /dev/stdin <<< "$out" 2>/dev/null)
    if [[ -n "$mp" && -d "$mp" ]]; then
      ok "挂载成功：$mp"
      TEMP_MOUNTS+=("$mp")
      echo "$mp"
      return 0
    fi
  done

  # fallback 到 awk 方法
  if [[ -z "$mp" ]]; then
    mp=$(echo "$out" | awk '
      /<key>mount-point<\/key>/ {
        getline
        if($0 ~ /<string>/) {
          gsub(/.*<string>/,"")
          gsub(/<\/string>.*/,"")
          print
          exit
        }
      }
    ')
    mp=$(echo "$mp" | sed 's/^ *//;s/ *$//')
    if [[ -n "$mp" && -d "$mp" ]]; then
      ok "挂载成功（fallback）：$mp"
      TEMP_MOUNTS+=("$mp")
      echo "$mp"
      return 0
    fi
  fi

  err "DMG 挂载失败或未找到卷：$dmg_path"
  return 1
}

# -------------------------------
# 安装 IDEA（复制、修改 Info.plist、签名、xattr）
# -------------------------------
install_idea() {
  local dmg="$1"
  local dest_app="$2"
  local -a keys
  local -a values

  if [[ "$dest_app" == "$IDEA_2023_APP" ]]; then
    keys=("${INFO_2023_KEYS[@]}")
    values=("${INFO_2023_VALUES[@]}")
  else
    keys=("${INFO_2025_KEYS[@]}")
    values=("${INFO_2025_VALUES[@]}")
  fi

  info "------------------------------"
  info "安装 $dest_app ..."

  # 挂载 DMG
  local mount_point
  mount_point=$(mount_dmg "$dmg") || return 1

  # ✅ 修复 zsh 挂载点丢失问题
  local src_app
  src_app=$(find "$mount_point" -maxdepth 1 -name "*.app" -print -quit)
  if [[ -z "$src_app" || ! -d "$src_app" ]]; then
    err "DMG 内未找到 .app（挂载点：$mount_point）"
    sudo hdiutil detach "$mount_point" -force >/dev/null 2>&1
    return 1
  fi

  # 删除旧版本
  [[ -d "$dest_app" ]] && sudo rm -rf "$dest_app"

  # 复制应用
  info "📦 复制应用：$src_app -> $dest_app"
  sudo cp -R "$src_app" "$dest_app"

  # 卸载 DMG
  sudo hdiutil detach "$mount_point" -force >/dev/null 2>&1 || warn "卸载挂载失败"

  # 修改 Info.plist
  local plist="$dest_app/Contents/Info.plist"
  for i in {0..3}; do
    sudo /usr/libexec/PlistBuddy -c "Set :${keys[$i]} '${values[$i]}'" "$plist" 2>/dev/null || \
    sudo /usr/libexec/PlistBuddy -c "Add :${keys[$i]} string '${values[$i]}'" "$plist" 2>/dev/null
  done

  # ✅ 重新签名 / 清理 xattr / 刷新 LaunchServices
  sudo xattr -dr com.apple.quarantine "$dest_app" 2>/dev/null || true
  sudo xattr -cr "$dest_app" 2>/dev/null || true
  sudo codesign --force --deep --sign - "$dest_app" >/dev/null 2>&1 || warn "codesign 失败"
  sudo /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$dest_app" >/dev/null 2>&1

  # ✅ 保证 Launchpad 图标显示，刷新 Dock
  killall Dock >/dev/null 2>&1
  sleep 2

  ok "$dest_app 安装完成并图标注册成功"
}

# -------------------------------
# 清理旧版本
# -------------------------------
info "🧹 清理旧版本..."
sudo rm -rf "$IDEA_2023_APP" "$IDEA_2025_APP" >/dev/null 2>&1 || true
unmount_old_intellij_volumes

# -------------------------------
# 安装两个版本
# -------------------------------
install_idea "$IDEA_2023_DMG" "$IDEA_2023_APP"
install_idea "$IDEA_2025_DMG" "$IDEA_2025_APP"

# -------------------------------
# 启动提示
# -------------------------------
ok "安装完成！请使用下列命令启动："
echo "启动 2023.2:"
echo "  open -n \"$IDEA_2023_APP\" --args -Didea.paths.selector=IntelliJIdea2023.2"
echo "启动 2025.2:"
echo "  open -n \"$IDEA_2025_APP\" --args -Didea.paths.selector=IntelliJIdea2025.2"
