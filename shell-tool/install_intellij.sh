#!/bin/zsh

set -e  # 遇错误即退出
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

echo "🔍 检查并清理残留挂载卷..."
for vol in /Volumes/IntelliJ*; do
  if [[ -d "$vol" ]]; then
    echo "  ➜ 卸载残留卷: $vol"
    sudo hdiutil detach "$vol" -force >/dev/null 2>&1
  fi
done

# -------------------------------
# 工具函数
# -------------------------------
function unmount_old_volumes() {
  local volumes=($(mount | grep "/Volumes/IntelliJ IDEA" | awk '{print $3}'))
  for v in "${volumes[@]}"; do
    echo "🔍 检测到旧卷：$v，尝试卸载..."
    hdiutil detach "$v" -force >/dev/null 2>&1 && echo "✅ 已卸载 $v" || echo "⚠️ 卸载失败：$v"
  done
}

function mount_dmg() {
  local dmg_path="$1"
  echo "👉 尝试挂载 DMG: $dmg_path"

  # 使用 -plist 输出标准 XML 结构
  local output
  output=$(hdiutil attach -nobrowse -readonly -plist "$dmg_path" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "❌ DMG 挂载失败"
    return 1
  fi

  # 用 awk 和 grep 提取 XML 中的挂载点（更兼容 zsh）
  local mount_point
  mount_point=$(echo "$output" | awk '/<key>mount-point<\/key>/{getline; if($0 ~ /<string>/){match($0, /<string>([^<]+)<\/string>/, a); print a[1]; exit}}')

  if [[ -z "$mount_point" || ! -d "$mount_point" ]]; then
    echo "❌ 未找到挂载点"
    return 1
  fi

  echo "✅ 挂载成功：$mount_point"
  echo "$mount_point"
}

# -------------------------------
# 主安装函数
# -------------------------------
function install_idea() {
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

  echo ""
  echo "=============================="
  echo "🚀 开始安装 $dest_app ..."
  echo "=============================="

  unmount_old_volumes

  local mount_point=$(mount_dmg "$dmg")
  if [[ -z "$mount_point" || ! -d "$mount_point" ]]; then
    echo "❌ 错误：DMG 挂载失败或未找到卷"
    return 1
  fi

  local src_app=$(find "$mount_point" -maxdepth 1 -name "*.app" | head -1)
  if [[ ! -d "$src_app" ]]; then
    echo "❌ 错误：DMG 内未找到 .app 文件"
    hdiutil detach "$mount_point" 2>/dev/null
    return 1
  fi

  echo "📦 复制应用到 $dest_app ..."
  sudo rm -rf "$dest_app" >/dev/null 2>&1 || true
  sudo cp -R "$src_app" "$dest_app"

  echo "⏳ 等待卸载镜像..."
  sleep 1
  hdiutil detach "$mount_point" -force >/dev/null 2>&1

  echo "🧩 修改 Info.plist ..."
  local plist_path="$dest_app/Contents/Info.plist"
  for i in {0..3}; do
    sudo /usr/libexec/PlistBuddy -c "Set :${keys[$i]} '${values[$i]}'" "$plist_path" 2>/dev/null || \
    sudo /usr/libexec/PlistBuddy -c "Add :${keys[$i]} string '${values[$i]}'" "$plist_path"
  done

  echo "🧹 清除安全属性与缓存 ..."
  sudo xattr -cr "$dest_app"
  sudo chmod -R 755 "$dest_app"

  echo "🔏 重新签名 ..."
  sudo codesign --force --deep --sign - "$dest_app" >/dev/null 2>&1

  echo "📚 刷新 Launch Services 缓存 ..."
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$dest_app" >/dev/null 2>&1

  echo "✅ $dest_app 安装完成！"
}

# -------------------------------
# 主流程
# -------------------------------
echo "🧹 清理旧版本..."
unmount_old_volumes
sudo rm -rf "$IDEA_2023_APP" "$IDEA_2025_APP"

install_idea "$IDEA_2023_DMG" "$IDEA_2023_APP"
install_idea "$IDEA_2025_DMG" "$IDEA_2025_APP"

echo ""
echo "🔧 启动 2023.2:"
echo "open -n \"$IDEA_2023_APP\" --args -Didea.paths.selector=IntelliJIdea2023.2"
echo "🔧 启动 2025.2:"
echo "open -n \"$IDEA_2025_APP\" --args -Didea.paths.selector=IntelliJIdea2025.2"
