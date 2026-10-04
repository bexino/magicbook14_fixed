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

# 查找所有 BLS entries
BLS_ENTRIES=$(ls /boot/loader/entries/*.conf 2>/dev/null || echo "")

if [[ -z "$BLS_ENTRIES" ]]; then
    if is_zh; then
        echo "  错误: 未找到 BLS 条目"
    else
        echo "  Error: No BLS entries found"
    fi
    exit 1
fi

# 备份所有 BLS 条目
for BLS_ENTRY in $BLS_ENTRIES; do
    if [[ -f "$BLS_ENTRY" ]]; then
        cp "$BLS_ENTRY" "$BACKUP_DIR/"
        if is_zh; then
            echo "  备份: $(basename "$BLS_ENTRY")"
        else
            echo "  Backup: $(basename "$BLS_ENTRY")"
        fi
    fi
done
echo

# 检查是否已经应用
if is_zh; then
    echo "[2/5] 检查当前配置..."
else
    echo "[2/5] Checking current configuration..."
fi
INSTALLED_COUNT=0
TOTAL_COUNT=0

for BLS_ENTRY in $BLS_ENTRIES; do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if grep -q "i8042.dumbkbd=1" "$BLS_ENTRY" 2>/dev/null; then
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    fi
done

if [[ $INSTALLED_COUNT -eq $TOTAL_COUNT ]] && [[ $TOTAL_COUNT -gt 0 ]]; then
    if is_zh; then
        echo "  键盘修复已经应用到所有条目！"
        echo
        read -p "是否要移除键盘修复? (y/N): " -n 1 -r
    else
        echo "  Keyboard fix is already applied to all entries!"
        echo
        read -p "Do you want to remove the keyboard fix? (y/N): " -n 1 -r
    fi
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if is_zh; then
            echo "[3/5] 移除键盘修复..."
        else
            echo "[3/5] Removing keyboard fix..."
        fi
        for BLS_ENTRY in $BLS_ENTRIES; do
            sed -i 's/i8042.dumbkbd=1 //g' "$BLS_ENTRY"
            sed -i 's/ i8042.dumbkbd=1//g' "$BLS_ENTRY"
            sed -i 's/i8042.dumbkbd=1$//g' "$BLS_ENTRY"
            sed -i 's/  */ /g' "$BLS_ENTRY"
            sed -i 's/ $//' "$BLS_ENTRY"
            if is_zh; then
                echo "  已修改: $(basename "$BLS_ENTRY")"
            else
                echo "  Modified: $(basename "$BLS_ENTRY")"
            fi
        done
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
        echo "  键盘修复尚未应用到所有条目"
        echo
        read -p "是否要添加键盘修复? (y/N): " -n 1 -r
    else
        echo "  Keyboard fix is not applied to all entries"
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
        echo "[3/5] 添加键盘修复参数..."
    else
        echo "[3/5] Adding keyboard fix parameter..."
    fi
    
    # 添加参数到所有 BLS 条目
    for BLS_ENTRY in $BLS_ENTRIES; do
        # 检查是否有 options 行
        if grep -q "^options" "$BLS_ENTRY"; then
            # 在现有选项后添加空格和参数
            sed -i 's/\(options.*\)/\1 i8042.dumbkbd=1/' "$BLS_ENTRY"
            if is_zh; then
                echo "  已添加: $(basename "$BLS_ENTRY")"
            else
                echo "  Added: $(basename "$BLS_ENTRY")"
            fi
        fi
    done
fi
echo

# 同时添加到 /etc/default/grub（这样新内核会自动包含）
if is_zh; then
    echo "[4/5] 更新 /etc/default/grub..."
else
    echo "[4/5] Updating /etc/default/grub..."
fi
if grep -q "i8042.dumbkbd=1" /etc/default/grub; then
    if is_zh; then
        echo "  /etc/default/grub 已包含参数"
    else
        echo "  /etc/default/grub already contains parameter"
    fi
else
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="i8042.dumbkbd=1 /' /etc/default/grub
    if is_zh; then
        echo "  已添加 i8042.dumbkbd=1 到 /etc/default/grub"
    else
        echo "  Added i8042.dumbkbd=1 to /etc/default/grub"
    fi
fi
echo

# 更新 GRUB
if is_zh; then
    echo "[5/5] 更新 GRUB 配置..."
else
    echo "[5/5] Updating GRUB configuration..."
fi
if command -v grub2-mkconfig >/dev/null 2>&1; then
    grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
    if is_zh; then
        echo "  已更新: /boot/grub2/grub.cfg"
    else
        echo "  Updated: /boot/grub2/grub.cfg"
    fi
elif command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    if is_zh; then
        echo "  已更新: /boot/grub/grub.cfg"
    else
        echo "  Updated: /boot/grub/grub.cfg"
    fi
else
    if is_zh; then
        echo "  跳过: 未找到 grub2-mkconfig 或 grub-mkconfig"
    else
        echo "  Skipped: grub2-mkconfig or grub-mkconfig not found"
    fi
fi
echo

# 显示结果
if is_zh; then
    echo "[完成] 当前引导配置:"
else
    echo "[Done] Current boot configuration:"
fi
for BLS_ENTRY in $BLS_ENTRIES; do
    echo "  $(basename "$BLS_ENTRY"):"
    grep "^options" "$BLS_ENTRY" 2>/dev/null | head -1 | sed 's/^/    /'
done
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
