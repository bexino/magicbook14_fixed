#!/bin/bash
# uninstall_patch.sh - Uninstall HONOR MagicBook 14 2026 touchpad patch

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
    echo "卸载触摸板补丁"
    echo "=========================================="
else
    echo "=========================================="
    echo "Uninstall Touchpad Patch"
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

# 获取内核版本
KERNEL_VERSION=$(uname -r)

# 查找备份目录
BACKUP_DIRS=(/root/acpi_backup_*)

if [[ ${#BACKUP_DIRS[@]} -eq 0 ]] || [[ ! -d "${BACKUP_DIRS[-1]}" ]]; then
    if is_zh; then
        echo "警告: 未找到备份目录"
        echo "手动恢复请:"
        echo "  1. 删除 /boot/acpi_override.cpio"
        echo "  2. 删除 /boot/acpi_override/"
        echo "  3. 编辑 /boot/loader/entries/*.conf 删除 initrd 行中的 /acpi_override.cpio"
    else
        echo "Warning: No backup directory found"
        echo "To restore manually:"
        echo "  1. Delete /boot/acpi_override.cpio"
        echo "  2. Delete /boot/acpi_override/"
        echo "  3. Edit /boot/loader/entries/*.conf to remove /acpi_override.cpio from initrd line"
    fi
    exit 1
fi

BACKUP_DIR="${BACKUP_DIRS[-1]}"
if is_zh; then
    echo "找到备份目录: $BACKUP_DIR"
else
    echo "Found backup directory: $BACKUP_DIR"
fi
echo

# 确认操作
if is_zh; then
    read -p "确认卸载补丁? (y/N): " -n 1 -r
else
    read -p "Confirm uninstall patch? (y/N): " -n 1 -r
fi
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    if is_zh; then
        echo "取消卸载"
    else
        echo "Uninstallation cancelled"
    fi
    exit 0
fi

if is_zh; then
    echo "[1/4] 恢复 BLS 配置..."
else
    echo "[1/4] Restoring BLS configuration..."
fi

BLS_ENTRY=$(ls /boot/loader/entries/*-${KERNEL_VERSION}.conf 2>/dev/null | head -1)

if [[ -z "$BLS_ENTRY" ]]; then
    BLS_ENTRY=$(ls /boot/loader/entries/*.conf 2>/dev/null | head -1)
fi

if [[ -n "$BLS_ENTRY" ]] && [[ -f "$BACKUP_DIR/"$(basename "$BLS_ENTRY") ]]; then
    cp "$BACKUP_DIR/"$(basename "$BLS_ENTRY") "$BLS_ENTRY"
    if is_zh; then
        echo "  已恢复: $BLS_ENTRY"
    else
        echo "  Restored: $BLS_ENTRY"
    fi
elif [[ -n "$BLS_ENTRY" ]]; then
    # 移除 initrd 中的 acpi_override.cpio
    sed -i 's|initrd /acpi_override.cpio ||g' "$BLS_ENTRY"
    if is_zh; then
        echo "  已修改: $BLS_ENTRY"
    else
        echo "  Modified: $BLS_ENTRY"
    fi
fi
echo

if is_zh; then
    echo "[2/4] 删除补丁文件..."
else
    echo "[2/4] Deleting patch files..."
fi
rm -f /boot/acpi_override.cpio
rm -rf /boot/acpi_override
rm -f /boot/SSDT-HONOR-I2C_DEVT.aml
if is_zh; then
    echo "  已删除补丁文件"
else
    echo "  Deleted patch files"
fi
echo

if is_zh; then
    echo "[3/4] 清理 dracut 配置..."
else
    echo "[3/4] Cleaning dracut configuration..."
fi
rm -f /etc/dracut.conf.d/99-acpi-override.conf 2>/dev/null || true
if is_zh; then
    echo "  已清理 dracut 配置"
else
    echo "  Cleaned dracut configuration"
fi
echo

if is_zh; then
    echo "[4/4] 完成！"
    echo
    echo "=========================================="
    echo "卸载完成！"
    echo
    echo "请重启系统:"
    echo "  sudo reboot"
    echo
    echo "备份仍保存在: $BACKUP_DIR"
    echo "=========================================="
else
    echo "[4/4] Done!"
    echo
    echo "=========================================="
    echo "Uninstallation complete!"
    echo
    echo "Please reboot system:"
    echo "  sudo reboot"
    echo
    echo "Backup is preserved at: $BACKUP_DIR"
    echo "=========================================="
fi
