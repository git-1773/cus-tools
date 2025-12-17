tell application "Navicat Premium" to activate

tell application "System Events"
    tell process "Navicat Premium"
        try
            click at {1813, 138}
            delay 5

            -- 尝试点击菜单项
            click menu item "连接" of menu "文件" of menu bar 1
            display dialog "菜单点击成功！" with title "成功"
        on error errMsg number errNum
            -- 捕捉并显示详细错误
            display dialog ¬
                "菜单点击失败！" & return & return & ¬
                "错误代码: " & errNum & return & ¬
                "详细信息: " & errMsg ¬
                with title "菜单点击异常" buttons {"OK"} default button 1
        end try
    end tell
end tell
