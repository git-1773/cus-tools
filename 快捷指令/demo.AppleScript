set app_name to "Navicat Premium"
set cliclick_path to "/opt/homebrew/bin/cliclick"
set targetX to 1813
set targetY to 138

set targetX to 3068
set targetY to 730

set clickCmd to quoted form of (cliclick_path & " c:" & targetX & "," & targetY)

tell application app_name
	activate
end tell

tell application "System Events"
	tell process app_name
		
		try

			set targetX to 2748
			set targetY to 417
			set clickCmd to quoted form of (cliclick_path & " c:" & targetX & "," & targetY)
			do shell script clickCmd
			
			set targetX to 2743
			set targetY to 447
			set clickCmd to quoted form of (cliclick_path & " c:" & targetX & "," & targetY)
			do shell script clickCmd
			
			set targetX to 3068
			set targetY to 730
			set clickCmd to quoted form of (cliclick_path & " c:" & targetX & "," & targetY)
			do shell script clickCmd
			display dialog "左键单击成功！" with title "Navicat 自动化"
			
			set targetX to 1813
			set targetY to 138
			set clickCmd1 to quoted form of (cliclick_path & " c:" & targetX & "," & targetY)
			do shell script clickCmd1
			
		on error errMsg number errNum
			display dialog "左键单击失败：" & errMsg & " (错误代码：" & errNum & ")" with title "错误"
		end try
		
	end tell
end tell

