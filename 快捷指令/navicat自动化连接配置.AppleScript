-- 应用程序名称和密码设置
set app_name to "Navicat Premium"
set target_connection_name to "aldi-aim-dev-1118"
set db_password to "Your_Actual_Password_Here"

-- UI 元素名称 (根据您的中文界面可能需要修改)
set password_window_name to "Connection Password"
set edit_menu_item to "编辑连接..." -- 确保您使用的就是这个精确的中文名称
set ok_button_name to "确定"       -- 确保使用中文 "确定"


-- 1. 激活 Navicat
tell application app_name
    activate
end tell

tell application "System Events"
    tell process app_name

        -- 等待 Navicat 窗口完全加载
        delay 5

        -- 2. 强制获取连接列表焦点
        repeat 3 times
            keystroke tab
            delay 0.2
        end repeat

        -- ---------------------------------------------
        -- 2. 🎯 验证点：使用 try/catch 块替代复杂的 return
        -- ---------------------------------------------

        -- 尝试获取当前焦点元素的角色
--        try
--            -- set focused_element_role to role of attribute "AXFocused" of window 1
--        on error
--            display dialog "错误：无法获取焦点属性。请检查 Navicat 的 Accessibility 权限！" with title "焦点调试"
--            error number -128 -- 模拟退出
--        end try
--
--        -- 检查角色是否是列表或表格类型
--        if focused_element_role is not in {"AXOutline", "AXTable", "AXScrollArea", "AXGroup"} then
--            display dialog "错误：当前焦点角色是 " & focused_element_role & ", 预期是列表/表格！" with title "验证失败"
--            error number -128 -- 模拟退出，以便您修改 Tab 次数
--        end if
--
--        display dialog "✅ 验证通过！焦点角色是: " & focused_element_role with title "验证成功"

        -- 3. 选中目标连接
        keystroke target_connection_name
        delay 1

        -- 4. 模拟右键点击 (上下文菜单)
        keystroke space using {control down}
        delay 1 -- 修正延迟时间为 1 秒

        -- 5. 选择并点击菜单项 "编辑连接"
        -- 假设上下文菜单是当前进程的 menu 1
        click menu item edit_menu_item of menu 1 of entire menu bar
        delay 1

        -- 6. 等待“编辑连接”配置窗口弹出
        delay 2

        -- 7. 密码输入和点击 OK

        -- 假设配置窗口标题格式是这样 (请手动确认)
        set config_window_name to "Edit Connection: " & target_connection_name

        -- 检查配置窗口是否存在
        if window config_window_name exists then

            set config_window to window config_window_name

            -- 查找密码输入框
            set password_field to secure text field 1 of config_window

            -- 输入密码
            set value of password_field to db_password

            -- 模拟点击“确定”按钮保存配置
            click button ok_button_name of config_window
        else
            -- 如果窗口名不对或未弹出，显示调试信息
            display dialog "错误：配置窗口未弹出或窗口名不匹配。请检查：[" & config_window_name & "]"
            log "Configuration window did not appear or name is incorrect."
        end if

    end tell
end tell