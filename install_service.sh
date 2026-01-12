#!/bin/bash
# 115-strm TG Bot systemd 服务安装脚本
# 使用方法: sudo bash install_service.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="/etc/systemd/system/115-strm-bot.service"

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 获取当前用户（调用 sudo 的用户）
CURRENT_USER="${SUDO_USER:-$USER}"
CURRENT_GROUP=$(id -gn "$CURRENT_USER")

echo "正在创建 systemd 服务..."

# 创建服务文件
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=115-strm Telegram Bot
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$SCRIPT_DIR
ExecStart=/bin/bash $SCRIPT_DIR/tg_bot.sh
Restart=always
RestartSec=10

# 环境变量
Environment=HOME=/home/$CURRENT_USER
Environment=LANG=en_US.UTF-8

# 日志
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd
systemctl daemon-reload

# 启用开机自启
systemctl enable 115-strm-bot

echo ""
echo "✅ 服务安装完成！"
echo ""
echo "常用命令："
echo "  启动服务:   sudo systemctl start 115-strm-bot"
echo "  停止服务:   sudo systemctl stop 115-strm-bot"
echo "  重启服务:   sudo systemctl restart 115-strm-bot"
echo "  查看状态:   sudo systemctl status 115-strm-bot"
echo "  查看日志:   sudo journalctl -u 115-strm-bot -f"
echo "  禁用自启:   sudo systemctl disable 115-strm-bot"
echo ""
echo "是否立即启动服务？[y/N]"
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    systemctl start 115-strm-bot
    echo "✅ 服务已启动"
    systemctl status 115-strm-bot --no-pager
fi
