
#!/bin/zsh

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
# 函数区
# -------------------------------

# 安全挂载 DMG，返回挂载点
function mount_dmg() {
  local dmg_path="$1"
  local mp=$(hdiutil attach -nobrowse -readonly "$dmg_path" | grep "/Volumes/" | tail -1 | awk '{$1=$2=""; print $0}' | sed 's/^ *//')
  if [[ -z "$mp" ]]; then
    echo ""
  else
    echo "$mp"
  fi
}

# 安装 IDEA
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

  echo "安装 $dest_app ..."

  # 挂载 DMG
  local mount_point=$(mount_dmg "$dmg")
  if [[ -z "$mount_point" || ! -d "$mount_point" ]]; then
    echo "错误：DMG 挂载失败或未找到卷"
    return 1
  fi

  # 查找 DMG 内的 .app 文件
  local src_app=$(find "$mount_point" -maxdepth 1 -name "*.app" | head -1)
  if [[ ! -d "$src_app" ]]; then
    echo "错误：DMG 内未找到 .app 文件"
    hdiutil detach "$mount_point" 2>/dev/null
    return 1
  fi

  # 删除旧版本
  if [[ -d "$dest_app" ]]; then
    echo "删除旧版本 $dest_app ..."
    sudo rm -rf "$dest_app"
  fi

  # 复制应用
  echo "复制应用到 $dest_app ..."
  sudo cp -R "$src_app" "$dest_app"

  # 卸载 DMG
  hdiutil detach "$mount_point" 2>/dev/null

  # 修改 Info.plist
  local plist_path="$dest_app/Contents/Info.plist"
  for i in {0..3}; do
    sudo /usr/libexec/PlistBuddy -c "Set :${keys[$i]} '${values[$i]}'" "$plist_path" 2>/dev/null || \
    sudo /usr/libexec/PlistBuddy -c "Add :${keys[$i]} string '${values[$i]}'" "$plist_path"
  done

  # 重新签名
  sudo codesign --force --deep --sign - "$dest_app" >/dev/null 2>&1

  echo "$dest_app 安装完成！"
}

# -------------------------------
# 清理旧版本
# -------------------------------
echo "清理旧版本..."
sudo rm -rf "$IDEA_2023_APP" "$IDEA_2025_APP"

# -------------------------------
# 安装
# -------------------------------
install_idea "$IDEA_2023_DMG" "$IDEA_2023_APP"
install_idea "$IDEA_2025_DMG" "$IDEA_2025_APP"

# -------------------------------
# 启动指令
# -------------------------------
echo "启动 2023.2:"
echo "open -n \"$IDEA_2023_APP\" --args -Didea.paths.selector=IntelliJIdea2023.2"
echo "启动 2025.2:"
echo "open -n \"$IDEA_2025_APP\" --args -Didea.paths.selector=IntelliJIdea2025.2"
