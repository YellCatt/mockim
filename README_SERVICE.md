# 服务安装与管理（systemd）

本说明演示如何使用仓库中的 `scripts/manage_service.sh` 脚本在 Linux 上安装、启用并管理 `mockim` 的 systemd 服务。

文件
- 脚本：[scripts/manage_service.sh](scripts/manage_service.sh#L1)
- 单元模板：[scripts/mockim.service.template](scripts/mockim.service.template#L1)

快速示例

1. 构建二进制（示例使用 nimble）：

```bash
nimble build -d:release --verbose
# 生成的二进制通常是 ./mockim 或 bin/mockim（视 .nimble 而定）
```

2. 使用脚本安装并开机自启（默认：二进制 `./mockim`，服务名 `mockim`，用户为当前用户）。

	- 直接执行（更简单的方式）：

	```bash
	./scripts/manage_service.sh
	# 行为：若服务尚未安装则安装并启用；若服务已存在且正在运行则重启；否则启用并启动
	```

	- 如果你需要显式安装或指定参数，也可以：

	```bash
	./scripts/manage_service.sh install ./mockim mockim $(whoami)
	```

3. 其他管理命令：

```bash
# 停止服务
./scripts/manage_service.sh stop mockim

# 启动服务
./scripts/manage_service.sh start mockim

# 重启服务
./scripts/manage_service.sh restart mockim

# 查看服务状态
./scripts/manage_service.sh status mockim

# 卸载服务（会停止、禁用并删除单元与二进制）
./scripts/manage_service.sh uninstall mockim
```

脚本行为说明
- 安装时会将指定二进制复制到 `/usr/local/bin/<SERVICE_NAME>`，并在 `/etc/systemd/system/` 下写入 `<SERVICE_NAME>.service`，随后 `systemctl enable` 并 `start` 服务。
- 卸载时会 stop/disable 单元、删除单元文件并移除 `/usr/local/bin/<SERVICE_NAME>`。
- 脚本内部会在需要时尝试用 `sudo` 重新运行以获得 root 权限。

系统级别命令（等效）

```bash
# 直接使用 systemctl（若已安装单元）
sudo systemctl daemon-reload
sudo systemctl enable mockim
sudo systemctl start mockim
sudo systemctl status mockim
```

故障排查
- 若服务未启动，查看 journal 日志：`sudo journalctl -u mockim -f`
- 确保二进制有执行权限：`sudo chmod +x /usr/local/bin/mockim`

问题或定制
- 需要自定义 `ExecStart` 参数时，可先编辑 [scripts/mockim.service.template](scripts/mockim.service.template#L1) 或手动修改 `/etc/systemd/system/mockim.service` 后运行 `sudo systemctl daemon-reload`。
