#!/bin/bash
# apply_keyboard_fix.sh - Fix HONOR MagicBook 14 2026 keyboard issue
#
# Applicable issues:
#   - Key repeat
#   - Key response delay
#   - Unresponsive keys
#
# Solution: Add kernel parameter i8042.dumbkbd=1
#
# Reference: https://wiki.archlinux.org/title/AT_Keyboard

set -euo pipefail

APP_LANG="${APP_LANG:-en}"
for arg in "$@"; do
    case "$arg" in
        --chinese|---chinese)
            APP_LANG="zh"
            ;;
    esac
done

is_zh() {
    [[ "$APP_LANG" =~ ^zh ]]
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/root/keyboard_fix_backup_$(date +%Y%m%d_%H%M%S)"

if is_zh; then
    echo "=========================================="
    echo "HONOR MagicBook 14 2026 键盘修复"
    echo "=========================================="
else
    echo "=========================================="
    echo "HONOR MagicBook 14 2026 Keyboard Fix"
    echo "=========================================="
fi
echo

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
   if is_zh; then
       echo "错误: 请使用 sudo 运行此脚本"
   else
       echo "Error: Please run this script with sudo"
   fi
   exit 1
fi

# 创建备份目录
if is_zh; then
    echo "[1/5] 创建备份..."
else
    echo "[1/5] Creating backup..."
fi
mkdir -p "$BACKUP_DIR"

# 获取内核版本
KERNEL_VERSION=$(uname -r)
if is_zh; then
    echo "  内核版本: $KERNEL_VERSION"
else
    echo "  Kernel version: $KERNEL_VERSION"
fi

# 备份 grub 配置
if [[ -f /etc/default/grub ]]; then
    cp /etc/default/grub "$BACKUP_DIR/grub"
    if is_zh; then
        echo "  备份: /etc/default/grub"
    else
        echo "  Backup: /etc/default/grub"
    fi
else
    if is_zh; then
        echo "  错误: /etc/default/grub 不存在"
    else
        echo "  Error: /etc/default/grub does not exist"
    fi
    exit 1
fi
echo

# 检查是否已经应用
if is_zh; then
    echo "[2/4] 检查当前配置..."
else
    echo "[2/4] Checking current configuration..."
fi

if grep -q "i8042.dumbkbd=1" /etc/default/grub; then
    if is_zh; then
        echo "  键盘修复已经应用！"
        echo
        read -p "是否要移除键盘修复? (y/N): " -n 1 -r
    else
        echo "  Keyboard fix is already applied!"
        echo
        read -p "Do you want to remove the keyboard fix? (y/N): " -n 1 -r
    fi
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if is_zh; then
            echo "[3/4] 移除键盘修复..."
        else
            echo "[3/4] Removing keyboard fix..."
        fi
        sed -i 's/i8042.dumbkbd=1 //g' /etc/default/grub
        sed -i 's/ i8042.dumbkbd=1//g' /etc/default/grub
        sed -i 's/i8042.dumbkbd=1$//g' /etc/default/grub
        if is_zh; then
            echo "  已移除 i8042.dumbkbd=1"
        else
            echo "  Removed i8042.dumbkbd=1"
        fi
    else
        if is_zh; then
            echo "取消操作"
        else
            echo "Operation cancelled"
        fi
        exit 0
    fi
else
    if is_zh; then
        echo "  键盘修复尚未应用"
        echo
        read -p "是否要添加键盘修复? (y/N): " -n 1 -r
    else
        echo "  Keyboard fix is not applied"
        echo
        read -p "Do you want to add the keyboard fix? (y/N): " -n 1 -r
    fi
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        if is_zh; then
            echo "取消操作"
        else
            echo "Operation cancelled"
        fi
        exit 0
    fi
    
    if is_zh; then
        echo "[3/4] 添加键盘修复参数..."
    else
        echo "[3/4] Adding keyboard fix parameter..."
    fi

    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub; then
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="i8042.dumbkbd=1 /' /etc/default/grub
    else
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="i8042.dumbkbd=1"' >> /etc/default/grub
    fi
    if is_zh; then
        echo "  已添加 i8042.dumbkbd=1 到 /etc/default/grub"
    else
        echo "  Added i8042.dumbkbd=1 to /etc/default/grub"
    fi
fi
echo

# 更新 GRUB
if is_zh; then
    echo "[4/4] 更新 GRUB 配置..."
else
    echo "[4/4] Updating GRUB configuration..."
fi

if command -v update-grub >/dev/null 2>&1; then
    update-grub >/dev/null 2>&1
    if is_zh; then
        echo "  已执行: update-grub"
    else
        echo "  Executed: update-grub"
    fi
elif command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    if is_zh; then
        echo "  已执行: grub-mkconfig"
    else
        echo "  Executed: grub-mkconfig"
    fi
else
    if is_zh; then
        echo "  跳过: 未找到 update-grub 或 grub-mkconfig"
    else
        echo "  Skipped: update-grub or grub-mkconfig not found"
    fi
fi
echo

# 显示结果
if is_zh; then
    echo "[完成] 当前引导配置:"
else
    echo "[Done] Current boot configuration:"
fi
grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub || true
echo

if is_zh; then
    echo "=========================================="
    echo "完成！"
    echo
    echo "请重启系统:"
    echo "  sudo reboot"
    echo
    echo "验证键盘参数:"
    echo "  cat /proc/cmdline | grep i8042"
    echo
    echo "备份已保存到: $BACKUP_DIR"
    echo "=========================================="
else
    echo "=========================================="
    echo "Complete!"
    echo
    echo "Please reboot system:"
    echo "  sudo reboot"
    echo
    echo "Verify keyboard parameters:"
    echo "  cat /proc/cmdline | grep i8042"
    echo
    echo "Backup saved to: $BACKUP_DIR"
    echo "=========================================="
fi
