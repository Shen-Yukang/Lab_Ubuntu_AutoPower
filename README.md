# Ubuntu自动开关机系统使用指南

## 概述

Ubuntu自动开关机系统是一个基于`rtcwake`的自动化电源管理工具，可以让你的Ubuntu系统在指定时间自动关机，并在设定时间自动开机。
初衷，我实验室要部署一台远程可以访问的ubuntu 服务器，用来跑AI、和自动化标注等实验任务... 我可以随时访问，虽然Ubuntu系统设计就是为零超长时间稳定运行，但是奈何物理机器可能扛不住，而且实验室的一些机器可能都是一转二，二转三。所以我觉得有必要整一个自动化开启和关机的功能
一开始想的是WOL，通过远程网口开启关闭服务器，确实，这是一种很流行的方式，但是我觉得会比较复杂，而且有学习成本在，我想能不能用脚本控制呢，于是诞生了这个脚本...

The original intention was for my laboratory to deploy a remotely accessible ubuntu server to run AI and automated annotation and other experimental tasks... I can access it at any time. Although the Ubuntu system is designed to run stably for an extremely long time, physical machines may not be able to handle it, and some machines in the laboratory may be 1-to-2 and 2-to-3 converters. So I think it's necessary to develop an automatic on/off function
At first, I thought of `WOL`, which enables the server to be turned on and off through a remote network port. Indeed, this is a very popular method, but I think it would be rather complicated and have a learning cost. I wondered if it could be controlled by a script, and thus this script was born...

## 系统要求

- Ubuntu Linux系统
- 支持RTC唤醒的硬件
- `rtcwake`命令（通常包含在util-linux包中）
- sudo权限

## 安装

运行安装脚本：
```bash
sudo bash install-auto-power.sh
```

安装完成后会自动：
- 创建配置文件：`/etc/auto-power/config.conf`
- 安装管理脚本：`/usr/local/bin/auto-power-manager`
- 创建日志文件：`/var/log/auto-power.log`
- 测试RTC功能并设置默认配置

## 基本使用

### 查看系统状态
```bash
auto-power-manager status
```

### 启用/禁用自动开关机
```bash
sudo auto-power-manager enable    # 启用
sudo auto-power-manager disable   # 禁用
```

### 设置时间
```bash
# 设置关机时间（24小时制）
sudo auto-power-manager set-shutdown 01:30

# 设置开机时间（24小时制）
sudo auto-power-manager set-wakeup 09:30
```

### 测试功能
```bash
# 测试RTC唤醒功能
sudo auto-power-manager test-rtc

# 手动执行关机流程（测试用）
sudo auto-power-manager shutdown
```

## 完整命令列表

| 命令 | 说明 | 需要sudo |
|------|------|----------|
| `status` | 显示当前状态和配置 | 否 |
| `enable` | 启用自动开关机 | 是 |
| `disable` | 禁用自动开关机 | 是 |
| `set-shutdown <时间>` | 设置关机时间 | 是 |
| `set-wakeup <时间>` | 设置开机时间 | 是 |
| `shutdown` | 执行关机流程 | 是 |
| `update-cron` | 更新cron任务 | 是 |
| `test-rtc` | 测试rtcwake功能 | 是 |
| `install` | 重新安装/初始化 | 是 |
| `help` | 显示帮助信息 | 否 |

## 配置文件

配置文件位置：`/etc/auto-power/config.conf`

```bash
# 是否启用自动开关机
ENABLED=true

# 关机时间（24小时制）
SHUTDOWN_TIME=01:30

# 开机时间（24小时制）
WAKEUP_TIME=09:30

# 日志文件路径
LOG_FILE=/var/log/auto-power.log

# 是否在关机前发送通知
SEND_NOTIFICATION=true

# 关机前等待时间(分钟)
SHUTDOWN_DELAY=5
```

## 工作原理

1. **定时任务**：系统使用cron在指定时间触发关机流程
2. **RTC设置**：关机前使用`rtcwake`设置硬件时钟唤醒时间
3. **自动关机**：系统执行关机并进入休眠状态
4. **自动开机**：硬件RTC在设定时间唤醒系统

## 故障排除

### 检查RTC功能
```bash
sudo auto-power-manager test-rtc
```

### 查看日志
```bash
tail -f /var/log/auto-power.log
```

### 检查cron任务
```bash
sudo crontab -l | grep auto-power
```

### 常见问题

**1. cron任务未设置**
```bash
sudo auto-power-manager update-cron
```

**2. RTC时间错误**
```bash
sudo hwclock --systohc  # 同步系统时间到RTC
```

**3. 权限问题**
确保使用sudo权限运行需要权限的命令

## 安全测试

在正式使用前，建议进行短时间测试：

```bash
# 设置2分钟后关机，5分钟后开机
sudo auto-power-manager set-shutdown $(date -d "+2 minutes" +%H:%M)
sudo auto-power-manager set-wakeup $(date -d "+5 minutes" +%H:%M)

# 查看状态确认
auto-power-manager status

# 测试完成后恢复正常时间
sudo auto-power-manager set-shutdown 01:30
sudo auto-power-manager set-wakeup 09:30
```

## 注意事项

1. **保存工作**：确保在关机前保存所有重要工作
2. **BIOS设置**：某些系统可能需要在BIOS中启用"RTC唤醒"或"Wake on RTC"
3. **时间同步**：确保系统时间和RTC时间同步
4. **权限要求**：大部分管理命令需要sudo权限
5. **硬件支持**：并非所有硬件都支持RTC唤醒功能

## 默认配置

安装后的默认设置：
- 关机时间：01:30（凌晨1点30分）
- 开机时间：09:30（早上9点30分）
- 关机前通知：启用
- 关机前等待：5分钟
- 自动开关机：启用

## 文件位置

- **安装脚本**：`install-auto-power.sh`
- **管理脚本**：`/usr/local/bin/auto-power-manager`
- **配置文件**：`/etc/auto-power/config.conf`
- **日志文件**：`/var/log/auto-power.log`
- **Cron任务**：root用户的crontab

## 卸载

如需卸载系统：
```bash
# 禁用功能
sudo auto-power-manager disable

# 删除文件
sudo rm -rf /etc/auto-power
sudo rm /usr/local/bin/auto-power-manager
sudo rm /var/log/auto-power.log

# 清理cron任务
sudo crontab -l | grep -v auto-power | sudo crontab -
```


