#!/usr/bin/env bash
set -euo pipefail

# manage_service.sh: 安装/管理 systemd 服务（适用于 mockim 项目）
# 用法：
#   ./scripts/manage_service.sh install [BIN_PATH] [SERVICE_NAME] [SERVICE_USER]
#   ./scripts/manage_service.sh uninstall [SERVICE_NAME]
#   ./scripts/manage_service.sh start|stop|restart|status [SERVICE_NAME]

CMD=${1:-}
BIN_PATH=${2:-./mockim}
SERVICE_NAME=${3:-mockim}
SERVICE_USER=${4:-$(whoami)}

usage(){
  echo "Usage: $0 {install|uninstall|start|stop|restart|status} [BIN_PATH] [SERVICE_NAME] [SERVICE_USER]"
  exit 2
}

if [ -z "$CMD" ]; then
  # 默认行为：若 systemd 单元已存在，则重启（若运行中）或启用并启动；否则执行安装。
  if systemctl list-unit-files "$SERVICE_NAME.service" >/dev/null 2>&1; then
    ensure_root
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      echo "Service $SERVICE_NAME is running — restarting"
      sudo systemctl restart "$SERVICE_NAME"
      exit $?
    else
      echo "Service $SERVICE_NAME exists but is not active — enabling and starting"
      sudo systemctl enable --now "$SERVICE_NAME"
      exit $?
    fi
  else
    # 没有单元文件，执行安装流程
    install_service
    exit $?
  fi
fi

ensure_root(){
  if [ "$EUID" -ne 0 ]; then
    echo "This operation requires sudo/root. Re-running with sudo..."
    sudo "$0" "$@"
    exit $?
  fi
}

install_service(){
  if [ ! -f "$BIN_PATH" ]; then
    echo "Binary not found: $BIN_PATH"
    exit 1
  fi

  ensure_root install "$BIN_PATH" "$SERVICE_NAME" "$SERVICE_USER"

  echo "Installing binary to /usr/local/bin/$SERVICE_NAME"
  sudo cp "$BIN_PATH" "/usr/local/bin/$SERVICE_NAME"
  sudo chmod 755 "/usr/local/bin/$SERVICE_NAME"

  echo "Writing systemd unit to /etc/systemd/system/$SERVICE_NAME.service"
  cat > "/tmp/$SERVICE_NAME.service" <<EOF
[Unit]
Description=$SERVICE_NAME service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
ExecStart=/usr/local/bin/$SERVICE_NAME
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  sudo mv "/tmp/$SERVICE_NAME.service" "/etc/systemd/system/$SERVICE_NAME.service"
  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl start "$SERVICE_NAME"

  echo "$SERVICE_NAME installed and started."
}

uninstall_service(){
  ensure_root uninstall "$SERVICE_NAME"

  echo "Stopping and disabling $SERVICE_NAME"
  sudo systemctl stop "$SERVICE_NAME" || true
  sudo systemctl disable "$SERVICE_NAME" || true
  sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
  sudo systemctl daemon-reload
  sudo systemctl reset-failed

  echo "Removing binary /usr/local/bin/$SERVICE_NAME"
  sudo rm -f "/usr/local/bin/$SERVICE_NAME"

  echo "$SERVICE_NAME uninstalled."
}

manage(){
  ensure_root $CMD "$SERVICE_NAME"
  sudo systemctl "$CMD" "$SERVICE_NAME"
}

case "$CMD" in
  install)
    install_service
    ;;
  uninstall)
    uninstall_service
    ;;
  start|stop|restart|status)
    manage
    ;;
  *)
    usage
    ;;
esac

exit 0
