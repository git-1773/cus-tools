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

# ===============================================================
# ⭐ 关键新增：挂载 DMG，自动获取挂载卷路径（不猜、不试、无风险）
# ===============================================================
mount_dmg() {
    local dmg="$1"

    info "📀 挂载 DMG：$dmg"

    if [ ! -f "$dmg" ]; then
        err "找不到 DMG 文件：$dmg"
        return 1
    fi

    # 执行挂载（不显示 Finder）
    local output
    output=$(hdiutil attach -nobrowse -noverify "$dmg" 2>&1)
    if [ $? -ne 0 ]; then
        err "DMG 挂载失败："
        echo "$output"
        return 1
    fi

    ok "DMG 挂载成功"

    # 自动解析挂载卷路径：取最后一个 Volumes 行
    local mount_point
    mount_point=$(echo "$output" | grep "/Volumes/" | awk '{print $3}' | tail -n 1)

    if [ ! -d "$mount_point" ]; then
        err "挂载成功但未找到卷路径"
        echo "$output"
        return 1
    fi

    ok "挂载卷路径：$mount_point"

    # 将挂载路径返回给调用者
    echo "$mount_point"
    return 0
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

  # 修复 zsh 挂载点丢失问题：真实查找 .app
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

  # 重新签名 + 清理 xattr
  sudo xattr -dr com.apple.quarantine "$dest_app" 2>/dev/null || true
  sudo xattr -cr "$dest_app" 2>/dev/null || true
  sudo codesign --force --deep --sign - "$dest_app" >/dev/null 2>&1 || warn "codesign 失败"
  sudo /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$dest_app" >/dev/null 2>&1

  killall Dock >/dev/null 2>&1
  sleep 2

  ok "$dest_app 安装完成并图标注册成功"
}

# -------------------------------
# 清理旧版本
# -------------------------------
#info "🧹 清理旧版本..."
#sudo rm -rf "$IDEA_2023_APP" "$IDEA_2025_APP" >/dev/null 2>&1 || true
#unmount_old_intellij_volumes
echo "🔧 🧹 清理旧版本..."
echo "🔧 🔍 检查并尝试卸载残留 IntelliJ 挂载卷..."

# 遍历 /Volumes 下所有目录，精准匹配 IntelliJ 相关挂载点
find /Volumes -maxdepth 1 -mindepth 1 -type d | while read -r vol; do
    # 通过挂载信息判断是否属于 IntelliJ DMG
    if mount | grep -F "on $vol" | grep -qi "IntelliJ IDEA"; then
        echo "🔧   ➜ 卸载残留卷: $vol"
        if hdiutil detach "$vol" -force >/dev/null 2>&1; then
            echo "✅ 已卸载：$vol"
        else
            echo "⚠️ 未能卸载：$vol（可能被占用，将继续尝试下一步）"
        fi
    else
        echo "⚠️ 未找到残留 IntelliJ 挂载卷..."
    fi
done
echo "🔧 ------------------------------"

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
