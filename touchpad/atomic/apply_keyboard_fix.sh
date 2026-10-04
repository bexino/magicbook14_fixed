#!/bin/bash
# apply_keyboard_fix.sh (Atomic Version) - Fix HONOR MagicBook 14 2026 keyboard issue
# For Fedora Atomic (Silverblue / Kinoite / Sericea / bootc) and other rpm-ostree systems
#
# Applicable issues:
#   - Key repeat
#   - Key response delay
#   - Unresponsive keys
#
# Solution: Add kernel parameter i8042.dumbkbd=1 via rpm-ostree kargs

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

if is_zh; then
    echo "=========================================="
    echo "HONOR MagicBook 14 2026 键盘修复 (Fedora Atomic)"
    echo "=========================================="
else
    echo "=========================================="
    echo "HONOR MagicBook 14 2026 Keyboard Fix (Fedora Atomic)"
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

# 检查是否存在 rpm-ostree
if ! command -v rpm-ostree >/dev/null 2>&1; then
    if is_zh; then
        echo "错误: 未检测到 rpm-ostree 命令。此脚本仅适用于 Fedora Atomic / Silverblue 等系统。"
        echo "如果是传统 Fedora 系统，请使用 touchpad/apply_keyboard_fix.sh"
    else
        echo "Error: rpm-ostree command not found. This script is intended only for Fedora Atomic / Silverblue systems."
        echo "For traditional Fedora systems, please use touchpad/apply_keyboard_fix.sh"
    fi
    exit 1
fi

# 检查当前配置
if is_zh; then
    echo "[1/2] 检查当前内核参数..."
else
    echo "[1/2] Checking current kernel parameters..."
fi
CURRENT_KARGS=$(rpm-ostree kargs 2>/dev/null || echo "")

if echo "$CURRENT_KARGS" | grep -q "i8042.dumbkbd=1"; then
    if is_zh; then
        echo "  当前系统已配置键盘修复参数 (i8042.dumbkbd=1)"
        echo
        read -p "是否要移除键盘修复? (y/N): " -n 1 -r
    else
        echo "  Current system already configured with keyboard fix parameter (i8042.dumbkbd=1)"
        echo
        read -p "Do you want to remove the keyboard fix? (y/N): " -n 1 -r
    fi
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if is_zh; then
            echo "[2/2] 正在通过 rpm-ostree 移除参数..."
        else
            echo "[2/2] Removing parameter via rpm-ostree..."
        fi
        rpm-ostree kargs --delete=i8042.dumbkbd=1
        echo
        if is_zh; then
            echo "=========================================="
            echo "键盘修复参数已移除！"
            echo "请重启系统生效: sudo reboot"
            echo "=========================================="
        else
            echo "=========================================="
            echo "Keyboard fix parameter removed!"
            echo "Please reboot system to take effect: sudo reboot"
            echo "=========================================="
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
        echo "  当前系统未配置键盘修复参数"
        echo
        read -p "是否要添加键盘修复参数 (i8042.dumbkbd=1)? (y/N): " -n 1 -r
    else
        echo "  Current system does not have keyboard fix parameter configured"
        echo
        read -p "Do you want to add keyboard fix parameter (i8042.dumbkbd=1)? (y/N): " -n 1 -r
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
        echo "[2/2] 正在通过 rpm-ostree 添加参数..."
    else
        echo "[2/2] Adding parameter via rpm-ostree..."
    fi
    rpm-ostree kargs --append=i8042.dumbkbd=1
    echo
    if is_zh; then
        echo "=========================================="
        echo "键盘修复参数添加成功！"
        echo
        echo "请重启系统生效:"
        echo "  sudo reboot"
        echo
        echo "重启后可运行以下命令验证:"
        echo "  cat /proc/cmdline | grep i8042"
        echo "=========================================="
    else
        echo "=========================================="
        echo "Keyboard fix parameter added successfully!"
        echo
        echo "Please reboot system to take effect:"
        echo "  sudo reboot"
        echo
        echo "After reboot, verify with:"
        echo "  cat /proc/cmdline | grep i8042"
        echo "=========================================="
    fi
fi
