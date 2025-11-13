#!/bin/zsh
# install_intellij.sh - IntelliJ IDEA 多版本安装自动化脚本（终极修正版）
# 特点：
#  ✅ 自动卸载残留卷
#  ✅ 支持中文/空格路径
#  ✅ 重新签名 / 清理 xattr / 刷新 LaunchServices
#  ✅ 修复 zsh 挂载点丢失问题
#  ✅ 输出优化，终端更清晰

export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
set -e
set -o pipefail

# -------------------------------
# 配置区
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
# 工具函数
# -------------------------------
log()  { printf "%b\n" "$*"; }
info() { log "🔧 $*"; }
ok()   { log "✅ $*"; }
warn() { log "⚠️  $*"; }
err()  { log "❌ $*"; }

# 临时挂载卷清理
TEMP_MOUNTS=()
cleanup() {
  for m in "${TEMP_MOUNTS[@]}"; do
    if [[ -d "$m" ]]; then
      warn "退出时卸载挂载卷：$m"
      sudo hdiutil detach "$m" -force >/dev/null 2>&1 || true
    fi
  done
}
trap cleanup EXIT

# -------------------------------
# 挂载与卸载逻辑
# -------------------------------
unmount_old_intellij_volumes() {
  info "🔍 检查并尝试卸载残留 IntelliJ 挂载卷..."
  for vol in /Volumes/IntelliJ*; do
    [[ -d "$vol" ]] || continue
    base=$(basename "$vol")
    if [[ "$base" = IntelliJ* ]]; then
      info "  ➜ 卸载残留卷: $vol"
      if sudo hdiutil detach "$vol" -force >/dev/null 2>&1; then
        ok "已卸载：$vol"
      else
        warn "卸载失败或被占用：$vol"
      fi
    fi
  done
}

mount_dmg() {
  local dmg="$1"
  info "📀 尝试挂载 DMG：$dmg"
  local out mp
  out=$(hdiutil attach -nobrowse -readonly -plist "$dmg" 2>/dev/null || true)
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
  fi
  err "DMG 挂载失败：$dmg"
  return 1
}

# -------------------------------
# 核心安装逻辑
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
  [[ -d "$dest_app" ]] && sudo rm -rf "$dest_app"
  sudo cp -R "$src_app" "$dest_app"
  ok "复制完成"
}

modify_info_plist() {
  local app="$1" keys="$2" vals="$3"
  local plist="$app/Contents/Info.plist"
  [[ -f "$plist" ]] || { warn "未找到 Info.plist：$plist"; return; }

  local -a karr varr
  eval "karr=(\"\${${keys}[@]}\")"
  eval "varr=(\"\${${vals}[@]}\")"

  for ((i=1;i<=${#karr[@]};i++)); do
    local k=${karr[$i]} v=${varr[$i]}
    sudo /usr/libexec/PlistBuddy -c "Set :$k $v" "$plist" 2>/dev/null ||
    sudo /usr/libexec/PlistBuddy -c "Add :$k string $v" "$plist" 2>/dev/null || true
  done
  ok "已修改 Info.plist"
}

post_install_fixup() {
  local app="$1"
  info "🧹 清理属性与刷新缓存：$app"
  sudo xattr -cr "$app" >/dev/null 2>&1 || true
  sudo chmod -R 755 "$app" >/dev/null 2>&1 || true
  sudo codesign --force --deep --sign - "$app" >/dev/null 2>&1 || true
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" >/dev/null 2>&1 || true
  ok "签名与缓存修复完成"
}

deploy_from_dmg() {
  local dmg="$1" dest="$2" keys="$3" vals="$4"
  info "------------------------------"
  info "开始安装：$dest"
  info "DMG 路径：$dmg"

  local mp
  mp="$(mount_dmg "$dmg" | tail -n1 | tr -d '\r\n')"
  if [[ -z "$mp" || ! -d "$mp" ]]; then
    err "挂载失败，跳过 $dest"
    return 1
  fi

  info "📂 挂载点确认：$mp"
  install_from_mount "$mp" "$dest" || { sudo hdiutil detach "$mp" -force >/dev/null 2>&1 || true; return 1; }
  sudo hdiutil detach "$mp" -force >/dev/null 2>&1 || true
  modify_info_plist "$dest" "$keys" "$vals"
  post_install_fixup "$dest"
  ok "$dest 安装完成"
}

# -------------------------------
# 主执行区
# -------------------------------
info "🧹 清理旧版本（仅 /Applications 指定目标）..."
sudo rm -rf "$IDEA_2023_APP" "$IDEA_2025_APP" >/dev/null 2>&1 || true

unmount_old_intellij_volumes

deploy_from_dmg "$IDEA_2023_DMG" "$IDEA_2023_APP" "INFO_2023_KEYS" "INFO_2023_VALUES" || warn "2023.2 安装失败"
deploy_from_dmg "$IDEA_2025_DMG" "$IDEA_2025_APP" "INFO_2025_KEYS" "INFO_2025_VALUES" || warn "2025.2 安装失败"

ok "✅ 安装脚本执行完毕。请使用以下命令启动验证："
log "启动 2023.2:"
log "  open -n \"$IDEA_2023_APP\" --args -Didea.paths.selector=IntelliJIdea2023.2"
log "启动 2025.2:"
log "  open -n \"$IDEA_2025_APP\" --args -Didea.paths.selector=IntelliJIdea2025.2"
