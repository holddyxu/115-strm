#!/bin/bash
################# 115-strm Telegram Bot 服务脚本 #################
# 此脚本用于接收 Telegram 消息，解析命令，调用 115-strm.sh 执行功能
# 使用 Long Polling 模式持续监听用户消息

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/bot.conf"
MAIN_SCRIPT="$SCRIPT_DIR/115-strm.sh"
STATE_DIR="$SCRIPT_DIR/.bot_state"

# 加载配置
if [ -f "$CONF_FILE" ]; then
    source "$CONF_FILE"
else
    echo "❌ 未找到配置文件: $CONF_FILE"
    exit 1
fi

# 检查必要配置
if [[ -z "$TG_BOT_TOKEN" || -z "$TG_ALLOWED_USERS" ]]; then
    echo "❌ 请在 bot.conf 中配置 TG_BOT_TOKEN 和 TG_ALLOWED_USERS"
    exit 1
fi

# 创建状态目录
mkdir -p "$STATE_DIR"

# API 基础 URL
API_URL="https://api.telegram.org/bot${TG_BOT_TOKEN}"

# 记录最后处理的更新 ID
LAST_UPDATE_ID=0

################# 工具函数 #################

# 发送消息（使用 --data-urlencode 避免参数过长）
send_message() {
    local chat_id="$1"
    local text="$2"
    local reply_markup="$3"
    
    if [[ -n "$reply_markup" ]]; then
        curl -s -X POST "${API_URL}/sendMessage" \
            --data-urlencode "chat_id=${chat_id}" \
            --data-urlencode "text=${text}" \
            --data-urlencode "parse_mode=HTML" \
            --data-urlencode "reply_markup=${reply_markup}" >/dev/null
    else
        curl -s -X POST "${API_URL}/sendMessage" \
            --data-urlencode "chat_id=${chat_id}" \
            --data-urlencode "text=${text}" \
            --data-urlencode "parse_mode=HTML" >/dev/null
    fi
}

# 截断过长输出，只保留最后的有用信息
truncate_output() {
    local text="$1"
    local max_lines="${2:-50}"
    
    # 移除进度刷新行（以 \r 开头的内容），只保留最终结果
    local cleaned
    cleaned=$(echo "$text" | tr '\r' '\n' | grep -v '^$' | tail -n "$max_lines")
    echo "$cleaned"
}

# 检查用户权限
check_permission() {
    local user_id="$1"
    [[ " $TG_ALLOWED_USERS " == *" $user_id "* ]]
}

# 获取用户状态
get_user_state() {
    local user_id="$1"
    local state_file="$STATE_DIR/${user_id}.state"
    if [ -f "$state_file" ]; then
        cat "$state_file"
    else
        echo "idle"
    fi
}

# 设置用户状态
set_user_state() {
    local user_id="$1"
    local state="$2"
    echo "$state" > "$STATE_DIR/${user_id}.state"
}

# 获取用户参数
get_user_param() {
    local user_id="$1"
    local param_name="$2"
    local param_file="$STATE_DIR/${user_id}_${param_name}"
    if [ -f "$param_file" ]; then
        cat "$param_file"
    fi
}

# 设置用户参数
set_user_param() {
    local user_id="$1"
    local param_name="$2"
    local value="$3"
    echo "$value" > "$STATE_DIR/${user_id}_${param_name}"
}

# 清除用户状态和参数
clear_user_state() {
    local user_id="$1"
    rm -f "$STATE_DIR/${user_id}."* 2>/dev/null
    rm -f "$STATE_DIR/${user_id}_"* 2>/dev/null
}

# 获取当前时间
get_time() {
    date "+%Y-%m-%d %H:%M:%S"
}

################# 菜单和帮助 #################

show_main_menu() {
    local chat_id="$1"
    local menu_text="🎛 <b>115-strm 控制菜单</b>

请选择要执行的操作：

/convert - 📂 将目录树转换为目录文件
/strm - 🎬 生成 .strm 文件
/index - 📊 建立 alist 索引数据库
/auto - ⚙️ 创建自动更新脚本
/config - 🔧 高级配置
/download - ⬇️ 下载指定格式文件
/other - 📦 其他功能
/status - 📈 查看当前配置
/cancel - ❌ 取消当前操作

💡 直接点击命令即可开始"
    
    send_message "$chat_id" "$menu_text"
}

show_welcome() {
    local chat_id="$1"
    local username="$2"
    local welcome_text="👋 欢迎使用 <b>115-strm Bot</b>，${username}！

这是一个通过 Telegram 控制 115-strm 脚本的工具。

📖 功能列表：
1️⃣ 目录树转换
2️⃣ 生成 strm 文件
3️⃣ 建立 alist 索引
4️⃣ 创建自动更新脚本
5️⃣ 高级配置
6️⃣ 下载指定格式
7️⃣ 其他功能

输入 /menu 查看完整菜单
输入 /help 获取帮助"

    send_message "$chat_id" "$welcome_text"
}

################# 命令处理 - 目录树转换 #################

handle_convert_start() {
    local chat_id="$1"
    local user_id="$2"
    
    # 读取配置获取上次路径
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    local prompt="📂 <b>目录树转换</b>

请输入目录树文件的路径或下载链接：

📍 支持格式：
• 本地路径：/path/to/目录树.txt
• HTTP 链接：http://example.com/目录树.txt"

    if [[ -n "$directory_tree_file" ]]; then
        prompt="${prompt}

📋 上次配置：
\`${directory_tree_file}\`

直接发送新路径，或发送 /use_last 使用上次配置"
    fi
    
    set_user_state "$user_id" "convert_waiting_path"
    send_message "$chat_id" "$prompt"
}

handle_convert_path() {
    local chat_id="$1"
    local user_id="$2"
    local path="$3"
    
    # 使用上次配置
    if [[ "$path" == "/use_last" ]]; then
        source "$HOME/.115-strm.conf" 2>/dev/null
        path="$directory_tree_file"
    fi
    
    if [[ -z "$path" ]]; then
        send_message "$chat_id" "❌ 路径不能为空，请重新输入："
        return
    fi
    
    set_user_param "$user_id" "convert_path" "$path"
    clear_user_state "$user_id"
    
    send_message "$chat_id" "⏳ 正在处理目录树转换...

📁 路径：${path}"
    
    # 执行转换
    local result
    result=$("$MAIN_SCRIPT" --tg-mode --action convert --param-directory_tree_file "$path" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        local truncated_result
        truncated_result=$(truncate_output "$result" 20)
        send_message "$chat_id" "✅ 目录树转换完成！

${truncated_result}

输入 /menu 返回主菜单"
    else
        local truncated_result
        truncated_result=$(truncate_output "$result" 20)
        send_message "$chat_id" "❌ 转换失败：

${truncated_result}"
    fi
}

################# 命令处理 - 生成 strm #################

handle_strm_start() {
    local chat_id="$1"
    local user_id="$2"
    
    local prompt="🎬 <b>生成 strm 文件</b>

<b>步骤 1/6</b> - 选择文件格式分类

请发送数字（多个用空格分隔）：
1️⃣ 音频 (mp3, flac, wav 等)
2️⃣ 视频 (mp4, mkv, avi 等)
3️⃣ 图片 (jpg, png, gif 等)
4️⃣ 其他 (iso, srt, pdf 等)
5️⃣ 全选（默认）
0️⃣ 自定义扩展名

例如发送：\`1 2\` 表示只处理音频和视频"

    set_user_state "$user_id" "strm_step1_formats"
    send_message "$chat_id" "$prompt"
}

handle_strm_step1() {
    local chat_id="$1"
    local user_id="$2"
    local formats="$3"
    
    # 默认全选
    if [[ -z "$formats" ]]; then
        formats="5"
    fi
    
    set_user_param "$user_id" "strm_formats" "$formats"
    
    # 读取配置
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    local prompt="🎬 <b>生成 strm 文件</b>

<b>步骤 2/6</b> - strm 文件保存路径

请输入保存 .strm 文件的目录路径："

    if [[ -n "$strm_save_path" ]]; then
        prompt="${prompt}

📋 上次配置：\`${strm_save_path}\`
发送 /use_last 使用上次配置"
    fi
    
    set_user_state "$user_id" "strm_step2_path"
    send_message "$chat_id" "$prompt"
}

handle_strm_step2() {
    local chat_id="$1"
    local user_id="$2"
    local path="$3"
    
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    if [[ "$path" == "/use_last" ]]; then
        path="$strm_save_path"
    fi
    
    if [[ -z "$path" ]]; then
        send_message "$chat_id" "❌ 路径不能为空"
        return
    fi
    
    set_user_param "$user_id" "strm_save_path" "$path"
    
    local prompt="🎬 <b>生成 strm 文件</b>

<b>步骤 3/6</b> - alist 地址

请输入 alist 的地址+端口：
例如：\`http://abc.com:5244\`"

    if [[ -n "$alist_url" ]]; then
        prompt="${prompt}

📋 上次配置：\`${alist_url}\`
发送 /use_last 使用上次配置"
    fi
    
    set_user_state "$user_id" "strm_step3_url"
    send_message "$chat_id" "$prompt"
}

handle_strm_step3() {
    local chat_id="$1"
    local user_id="$2"
    local url="$3"
    
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    if [[ "$url" == "/use_last" ]]; then
        url="$alist_url"
    fi
    
    set_user_param "$user_id" "strm_alist_url" "$url"
    
    local prompt="🎬 <b>生成 strm 文件</b>

<b>步骤 4/6</b> - 挂载路径

请输入 alist 存储里对应的挂载路径信息：
例如：\`/115\` 或 \`/\`"

    if [[ -n "$mount_path" ]]; then
        local decoded_path=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('${mount_path}'))")
        prompt="${prompt}

📋 上次配置：\`${decoded_path}\`
发送 /use_last 使用上次配置"
    fi
    
    set_user_state "$user_id" "strm_step4_mount"
    send_message "$chat_id" "$prompt"
}

handle_strm_step4() {
    local chat_id="$1"
    local user_id="$2"
    local mount="$3"
    
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    if [[ "$mount" == "/use_last" ]]; then
        mount="$mount_path"
    fi
    
    set_user_param "$user_id" "strm_mount_path" "$mount"
    
    local prompt="🎬 <b>生成 strm 文件</b>

<b>步骤 5/6</b> - 剔除目录层级

请输入要剔除的目录层级数量（默认为 2）："

    if [[ -n "$exclude_option" ]]; then
        prompt="${prompt}

📋 上次配置：\`${exclude_option}\`
直接发送数字或 /use_last"
    fi
    
    set_user_state "$user_id" "strm_step5_exclude"
    send_message "$chat_id" "$prompt"
}

handle_strm_step5() {
    local chat_id="$1"
    local user_id="$2"
    local exclude="$3"
    
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    if [[ "$exclude" == "/use_last" || -z "$exclude" ]]; then
        exclude="${exclude_option:-2}"
    fi
    
    set_user_param "$user_id" "strm_exclude" "$exclude"
    
    local prompt="🎬 <b>生成 strm 文件</b>

<b>步骤 6/6</b> - 更新选项

如果 strm 文件已存在：
1️⃣ 跳过（默认）
2️⃣ 更新

请发送 1 或 2："
    
    set_user_state "$user_id" "strm_step6_update"
    send_message "$chat_id" "$prompt"
}

handle_strm_step6() {
    local chat_id="$1"
    local user_id="$2"
    local update_option="$3"
    
    if [[ -z "$update_option" ]]; then
        update_option="1"
    fi
    
    set_user_param "$user_id" "strm_update" "$update_option"
    
    # 收集所有参数
    local formats=$(get_user_param "$user_id" "strm_formats")
    local save_path=$(get_user_param "$user_id" "strm_save_path")
    local alist_url=$(get_user_param "$user_id" "strm_alist_url")
    local mount_path=$(get_user_param "$user_id" "strm_mount_path")
    local exclude=$(get_user_param "$user_id" "strm_exclude")
    
    clear_user_state "$user_id"
    
    local summary="⏳ <b>正在生成 strm 文件...</b>

📋 参数汇总：
• 格式分类：${formats}
• 保存路径：${save_path}
• alist 地址：${alist_url}
• 挂载路径：${mount_path}
• 剔除层级：${exclude}
• 更新选项：${update_option}

请稍候..."
    
    send_message "$chat_id" "$summary"
    
    # 执行 strm 生成
    local result
    result=$("$MAIN_SCRIPT" --tg-mode --action strm \
        --param-formats "$formats" \
        --param-strm_save_path "$save_path" \
        --param-alist_url "$alist_url" \
        --param-mount_path "$mount_path" \
        --param-exclude_option "$exclude" \
        --param-update_existing "$update_option" \
        --param-delete_absent "2" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        # 截断输出，只保留最后20行关键信息
        local truncated_result
        truncated_result=$(truncate_output "$result" 20)
        send_message "$chat_id" "✅ strm 文件生成完成！

${truncated_result}

输入 /menu 返回主菜单"
    else
        local truncated_result
        truncated_result=$(truncate_output "$result" 20)
        send_message "$chat_id" "❌ 生成失败：

${truncated_result}"
    fi
}

################# 命令处理 - 查看状态 #################

handle_status() {
    local chat_id="$1"
    
    # 读取配置
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    local status_text="📈 <b>当前配置状态</b>

📁 <b>路径配置</b>
• 目录树文件：${directory_tree_file:-未配置}
• strm 保存路径：${strm_save_path:-未配置}

🌐 <b>alist 配置</b>
• 地址：${alist_url:-未配置}
• 挂载路径：${mount_path:-未配置}

⚙️ <b>其他配置</b>
• 剔除层级：${exclude_option:-2}
• 更新选项：${update_existing:-1}
• 删除选项：${delete_absent:-2}
• 自定义扩展名：${custom_extensions:-无}

🕐 更新时间：$(get_time)"
    
    send_message "$chat_id" "$status_text"
}

################# 命令处理 - 数据库索引 #################

handle_index_start() {
    local chat_id="$1"
    local user_id="$2"
    
    # 读取配置
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    local prompt="📊 <b>更新 alist 索引数据库</b>

⚠️ <b>建议在操作前备份 data.db 文件</b>

<b>步骤 1/4</b> - 数据库文件路径

请输入 alist 的 data.db 文件完整路径：
例如：\`/opt/alist/data/data.db\`"

    if [[ -n "$db_file" ]]; then
        prompt="${prompt}

📋 上次配置：\`${db_file}\`
发送 /use_last 使用上次配置"
    fi
    
    set_user_state "$user_id" "index_step1_db"
    send_message "$chat_id" "$prompt"
}

handle_index_step1() {
    local chat_id="$1"
    local user_id="$2"
    local db_path="$3"
    
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    if [[ "$db_path" == "/use_last" ]]; then
        db_path="$db_file"
    fi
    
    if [[ -z "$db_path" ]]; then
        send_message "$chat_id" "❌ 路径不能为空，请重新输入"
        return
    fi
    
    set_user_param "$user_id" "index_db_file" "$db_path"
    
    local prompt="📊 <b>更新 alist 索引数据库</b>

<b>步骤 2/4</b> - 挂载路径

请输入 alist 存储里对应的挂载路径信息：
例如：\`/115\` 或 \`/\`"

    if [[ -n "$mount_path" ]]; then
        local decoded_path=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('${mount_path}'))")
        prompt="${prompt}

📋 上次配置：\`${decoded_path}\`
发送 /use_last 使用上次配置"
    fi
    
    set_user_state "$user_id" "index_step2_mount"
    send_message "$chat_id" "$prompt"
}

handle_index_step2() {
    local chat_id="$1"
    local user_id="$2"
    local mount="$3"
    
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    if [[ "$mount" == "/use_last" ]]; then
        mount="$mount_path"
    fi
    
    if [[ -z "$mount" ]]; then
        mount="/"
    fi
    
    set_user_param "$user_id" "index_mount_path" "$mount"
    
    local prompt="📊 <b>更新 alist 索引数据库</b>

<b>步骤 3/4</b> - 剔除目录层级

请输入要剔除的目录层级数量（默认为 2）："

    if [[ -n "$exclude_option" ]]; then
        prompt="${prompt}

📋 上次配置：\`${exclude_option}\`
发送 /use_last 使用上次配置"
    fi
    
    set_user_state "$user_id" "index_step3_exclude"
    send_message "$chat_id" "$prompt"
}

handle_index_step3() {
    local chat_id="$1"
    local user_id="$2"
    local exclude="$3"
    
    source "$HOME/.115-strm.conf" 2>/dev/null
    
    if [[ "$exclude" == "/use_last" || -z "$exclude" ]]; then
        exclude="${exclude_option:-2}"
    fi
    
    set_user_param "$user_id" "index_exclude" "$exclude"
    
    local prompt="📊 <b>更新 alist 索引数据库</b>

<b>步骤 4/4</b> - 操作模式

请选择如何更新索引表：
1️⃣ 新增（保留现有数据，添加新数据）
2️⃣ 替换（清空现有数据，写入新数据）

请发送 1 或 2（默认为 2）："
    
    set_user_state "$user_id" "index_step4_choice"
    send_message "$chat_id" "$prompt"
}

handle_index_step4() {
    local chat_id="$1"
    local user_id="$2"
    local choice="$3"
    
    if [[ -z "$choice" ]]; then
        choice="2"
    fi
    
    # 收集所有参数
    local db_file=$(get_user_param "$user_id" "index_db_file")
    local mount_path=$(get_user_param "$user_id" "index_mount_path")
    local exclude=$(get_user_param "$user_id" "index_exclude")
    
    clear_user_state "$user_id"
    
    local choice_text=$([ "$choice" == "1" ] && echo "新增" || echo "替换")
    local summary="⏳ <b>正在更新索引数据库...</b>

📋 参数汇总：
• 数据库：${db_file}
• 挂载路径：${mount_path}
• 剔除层级：${exclude}
• 操作模式：${choice_text}

请稍候..."
    
    send_message "$chat_id" "$summary"
    
    # 执行索引更新
    local result
    result=$("$MAIN_SCRIPT" --tg-mode --action index \
        --param-db_file "$db_file" \
        --param-mount_path "$mount_path" \
        --param-exclude_option "$exclude" \
        --param-db_choice "$choice" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        local truncated_result
        truncated_result=$(truncate_output "$result" 20)
        send_message "$chat_id" "✅ 索引数据库更新完成！

${truncated_result}

输入 /menu 返回主菜单"
    else
        local truncated_result
        truncated_result=$(truncate_output "$result" 20)
        send_message "$chat_id" "❌ 更新失败：

${truncated_result}"
    fi
}

################# 命令处理 - 取消操作 #################

handle_cancel() {
    local chat_id="$1"
    local user_id="$2"
    
    clear_user_state "$user_id"
    send_message "$chat_id" "❌ 操作已取消

输入 /menu 返回主菜单"
}

################# 主消息处理 #################

process_message() {
    local chat_id="$1"
    local user_id="$2"
    local username="$3"
    local text="$4"
    
    # 权限检查
    if ! check_permission "$user_id"; then
        send_message "$chat_id" "⛔ 抱歉，您没有权限使用此 Bot。

您的用户 ID：${user_id}
请联系管理员添加权限。"
        return
    fi
    
    # 获取当前状态
    local state=$(get_user_state "$user_id")
    
    # 预处理命令：移除群组中的 @bot_username 后缀
    local cmd="$text"
    if [[ "$cmd" == /* ]]; then
        cmd="${cmd%%@*}"  # 移除 @ 及其后面的内容
    fi
    
    # 处理命令
    case "$cmd" in
        /start)
            clear_user_state "$user_id"
            show_welcome "$chat_id" "$username"
            ;;
        /menu|/help)
            clear_user_state "$user_id"
            show_main_menu "$chat_id"
            ;;
        /cancel)
            handle_cancel "$chat_id" "$user_id"
            ;;
        /convert)
            clear_user_state "$user_id"
            handle_convert_start "$chat_id" "$user_id"
            ;;
        /strm)
            clear_user_state "$user_id"
            handle_strm_start "$chat_id" "$user_id"
            ;;
        /status)
            handle_status "$chat_id"
            ;;
        /index)
            clear_user_state "$user_id"
            handle_index_start "$chat_id" "$user_id"
            ;;
        /auto)
            send_message "$chat_id" "⚙️ 自动更新脚本功能正在开发中..."
            ;;
        /config)
            send_message "$chat_id" "🔧 高级配置功能正在开发中..."
            ;;
        /download)
            send_message "$chat_id" "⬇️ 下载功能正在开发中..."
            ;;
        /other)
            send_message "$chat_id" "📦 其他功能正在开发中..."
            ;;
        *)
            # 根据状态处理输入
            case "$state" in
                convert_waiting_path)
                    handle_convert_path "$chat_id" "$user_id" "$text"
                    ;;
                strm_step1_formats)
                    handle_strm_step1 "$chat_id" "$user_id" "$text"
                    ;;
                strm_step2_path)
                    handle_strm_step2 "$chat_id" "$user_id" "$text"
                    ;;
                strm_step3_url)
                    handle_strm_step3 "$chat_id" "$user_id" "$text"
                    ;;
                strm_step4_mount)
                    handle_strm_step4 "$chat_id" "$user_id" "$text"
                    ;;
                strm_step5_exclude)
                    handle_strm_step5 "$chat_id" "$user_id" "$text"
                    ;;
                strm_step6_update)
                    handle_strm_step6 "$chat_id" "$user_id" "$text"
                    ;;
                index_step1_db)
                    handle_index_step1 "$chat_id" "$user_id" "$text"
                    ;;
                index_step2_mount)
                    handle_index_step2 "$chat_id" "$user_id" "$text"
                    ;;
                index_step3_exclude)
                    handle_index_step3 "$chat_id" "$user_id" "$text"
                    ;;
                index_step4_choice)
                    handle_index_step4 "$chat_id" "$user_id" "$text"
                    ;;
                idle|*)
                    send_message "$chat_id" "🤔 未识别的命令或输入

输入 /menu 查看可用命令"
                    ;;
            esac
            ;;
    esac
}

################# 主循环 - Long Polling #################

echo "🤖 115-strm Bot 已启动"
echo "📡 正在监听 Telegram 消息..."
echo "按 Ctrl+C 停止"

while true; do
    # 获取更新
    response=$(curl -s "${API_URL}/getUpdates?offset=$((LAST_UPDATE_ID + 1))&timeout=${TG_POLL_TIMEOUT:-30}")
    
    # 检查响应是否为空
    if [[ -z "$response" ]]; then
        sleep "${TG_POLL_INTERVAL:-2}"
        continue
    fi
    
    # 检查是否有错误（使用 try-except 避免 JSON 解析失败）
    api_ok=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('True' if data.get('ok', False) else 'False')
except:
    print('Error')
" 2>/dev/null)
    
    if [[ "$api_ok" != "True" ]]; then
        sleep "${TG_POLL_INTERVAL:-2}"
        continue
    fi
    
    # 解析更新
    updates=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except:
    data = {}
for update in data.get('result', []):
    update_id = update.get('update_id', 0)
    message = update.get('message', {})
    chat_id = message.get('chat', {}).get('id', '')
    user_id = message.get('from', {}).get('id', '')
    username = message.get('from', {}).get('first_name', 'User')
    text = message.get('text', '')
    if chat_id and text:
        # 使用 TAB 作为分隔符
        print(f'{update_id}\t{chat_id}\t{user_id}\t{username}\t{text}')
")
    
    # 处理每条消息
    while IFS=$'\t' read -r update_id chat_id user_id username text; do
        if [[ -n "$update_id" && "$update_id" -gt "$LAST_UPDATE_ID" ]]; then
            LAST_UPDATE_ID="$update_id"
            echo "[$(get_time)] 收到消息 from ${username}(${user_id}): ${text}"
            process_message "$chat_id" "$user_id" "$username" "$text"
        fi
    done <<< "$updates"
    
    sleep "${TG_POLL_INTERVAL:-2}"
done
