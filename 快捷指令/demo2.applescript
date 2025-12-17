-- 第一个坐标（列表区域）：$X=63, Y=111$第二个坐标（连接 1）：$X=80, Y=138$第三个坐标（连接 2）：$X=80, Y=158$

-- 应用程序名称和密码设置
-- set app_name to "Navicat Premium"
set app_name to "Chrome"
set target_connection_name to "aldi-aim-dev-1118" -- 仅作窗口命名使用
set db_password to "Your_Actual_Password_Here" -- ⚠️ 替换为您的真实密码

-- 坐标设置：强制选中目标连接
-- 我们直接点击目标连接所在的坐标 (假设这是第一个连接)
set target_x_coordinate to 80
set target_y_coordinate to 138

-- UI 元素名称 (根据您的中文界面可能需要修改)
set edit_menu_item to "编辑连接..." -- 请确保精确匹配右键菜单的中文名称
set ok_button_name to "确定" -- 请确保精确匹配按钮的中文名称

-- cliclick 路径
set cliclick_path to "/opt/homebrew/bin/cliclick" -- ⚠️ 替换为您在终端找到的实际路径！


-- 1. 激活 Navicat
tell application app_name
	activate
end tell

tell application "System Events"
	tell process app_name

		-- 等待 Navicat 窗口完全加载
		delay 2

		click at {target_x_coordinate, target_y_coordinate}
		delay 5

		-- 如果上面的点击成功，则执行下面的
		display dialog "成功点击了屏幕坐标:" & target_x_coordinate & "," & target_y_coordinate

		set cliclick_path to "/opt/homebrew/bin/cliclick"
		set target_x_coordinate to 80
		-- set target_y_coordinate to 138
		set target_y_coordinate to 12
		set cmd_test to cliclick_path & " -d 200 -w 50 c:" & target_x_coordinate & "," & target_y_coordinate & " > /dev/null 2>&1"
		display dialog cmd_test
		-- do shell script cmd_test

		set simple_shell_command to "date"
		try
			set date_result to do shell script simple_shell_command
			display dialog "Shell 命令执行成功！" & return & "当前日期是：" & date_result with title "Shell 命令测试"
		on error errMsg number errNum
			display dialog "Shell 命令执行失败！" & return & "错误代码: " & errNum & return & "详细信息: " & errMsg with title "Shell 命令测试失败"
		end try

		set simple_cliclick_command to cliclick_path & " p:TEST_OK"
		try
			set result_text to do shell script simple_cliclick_command
			display dialog "cliclick 程序成功启动并执行！" & return & "输出结果是：" & result_text with title "cliclick 核心测试"
		on error errMsg number errNum
			display dialog "cliclick 启动失败！" & return & "错误代码: " & errNum & return & "详细信息: " & errMsg with title "cliclick 启动失败"
		end try

		set cliclick_path to "/opt/homebrew/bin/cliclick"
		set target_x_coordinate to 80
		-- set target_y_coordinate to 138
		set target_y_coordinate to 12

		-- 构建命令
		set raw_cmd to cliclick_path & " -d 200 -w 50 c:" & target_x_coordinate & "," & target_y_coordinate

		-- 防止 AppleScript 错误解析命令，必须 quoted form
		set full_cmd to "/bin/bash -c " & quoted form of raw_cmd
		display dialog full_cmd

		try
			set result_text to do shell script full_cmd
			display dialog "运行成功: " & result_text
		on error errMsg number errNum
			display dialog "运行失败 #" & errNum & return & errMsg
		end try

		-- 2. 选中目标连接 (使用模拟鼠标点击两次，确保选中)
		-- 注意：如果点击一次就能选中，两次点击是为了保险。
		-- click at {target_x_coordinate, target_y_coordinate}
		set cmd_left_click to cliclick_path & " -d 200 -w 50 c:" & target_x_coordinate & "," & target_y_coordinate & " > /dev/null 2>&1"
		-- set cmd_left_click to cliclick_path & " -d 200 -w 50 c:" & target_x_coordinate & "," & target_y_coordinate
		try
			do shell script cmd_left_click -- 替换为您的变量
		on error errMsg number errNum
			-- display dialog "cliclick 错误 #" & errNum & return & errMsg with title "Shell 命令失败"
			display dialog "cliclick 错误 #" & errNum & return & "详细信息: " & errMsg with title "左键点击失败 (第二次)"
		end try
		delay 0.5
		-- click at {target_x_coordinate, target_y_coordinate}
		do shell script cmd_left_click
		delay 1

		-- 3. 模拟右键点击 (上下文菜单)
		-- 在选中的连接上，模拟 Control + 空格键，弹出右键菜单
		-- keystroke space using {control down}
		-- do shell script "cliclick c:ctrl,left," & target_x_coordinate & "," & target_y_coordinate & " -d 200 -w 50"
		set cmd_ctrl_click to cliclick_path & " -d 200 -w 50 c:ctrl,left," & target_x_coordinate & "," & target_y_coordinate
		do shell script cmd_ctrl_click
		delay 1

		delay 10

		-- 4. 选择并点击菜单项 "编辑连接"
		click menu item edit_menu_item -- of menu 1 of entire menu bar
		delay 1

		-- 5. 等待“编辑连接”配置窗口弹出
		delay 2

		-- 6. 密码输入和点击 OK
		set config_window_name to "Edit Connection: " & target_connection_name

		if window config_window_name exists then

			set config_window to window config_window_name

			--            set password_field to secure text field 1 of config_window

			set value of password_field to db_password

			click button ok_button_name of config_window
		else
			log "Configuration window did not appear or name is incorrect."
		end if

	end tell
end tell