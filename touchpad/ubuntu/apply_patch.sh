#!/bin/bash
# apply_patch.sh - Install HONOR MagicBook 14 2026 touchpad patch
# Applicable to Debian / Linux Mint / Ubuntu systems

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
REPO_DIR="$SCRIPT_DIR"
BACKUP_DIR="/root/acpi_backup_$(date +%Y%m%d_%H%M%S)"

echo "=========================================="
echo "HONOR MagicBook 14 2026 Touchpad Fix"
echo "=========================================="
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

# 检查补丁文件
if [[ ! -f "$REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml" ]]; then
    if is_zh; then
        echo "错误: 补丁文件不存在: $REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml"
    else
        echo "Error: Patch file does not exist: $REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml"
    fi
    exit 1
fi

# 创建备份目录
if is_zh; then
    echo "[1/6] 创建备份..."
else
    echo "[1/6] Creating backup..."
fi
mkdir -p "$BACKUP_DIR"

# 备份原始文件
if [[ -f /boot/acpi_override.cpio ]]; then
    cp /boot/acpi_override.cpio "$BACKUP_DIR/"
    if is_zh; then
        echo "  备份: /boot/acpi_override.cpio"
    else
        echo "  Backup: /boot/acpi_override.cpio"
    fi
fi

if [[ -d /boot/acpi_override ]]; then
    cp -r /boot/acpi_override "$BACKUP_DIR/"
    if is_zh; then
        echo "  备份: /boot/acpi_override/"
    else
        echo "  Backup: /boot/acpi_override/"
    fi
fi

if is_zh; then
    echo "  备份保存到: $BACKUP_DIR"
else
    echo "  Backup saved to: $BACKUP_DIR"
fi
echo

# 备份 grub 配置
if is_zh; then
    echo "[2/6] 备份引导配置..."
else
    echo "[2/6] Backing up boot loader configuration..."
fi

if [[ -f /etc/default/grub ]]; then
    cp /etc/default/grub "$BACKUP_DIR/grub"
    if is_zh; then
        echo "  备份: /etc/default/grub -> $BACKUP_DIR/grub"
    else
        echo "  Backup: /etc/default/grub -> $BACKUP_DIR/grub"
    fi
else
    if is_zh; then
        echo "  警告: /etc/default/grub 不存在"
    else
        echo "  Warning: /etc/default/grub does not exist"
    fi
fi
echo

# 安装补丁文件
if is_zh; then
    echo "[3/6] 安装补丁文件..."
else
    echo "[3/6] Installing patch files..."
fi

# 创建 /boot/acpi_override 目录
mkdir -p /boot/acpi_override
cp "$REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml" /boot/acpi_override/SSDT29.aml
if is_zh; then
    echo "  安装: /boot/acpi_override/SSDT29.aml"
else
    echo "  Installed: /boot/acpi_override/SSDT29.aml"
fi

# 复制到其他位置
cp "$REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml" /boot/SSDT-HONOR-I2C_DEVT.aml
if is_zh; then
    echo "  安装: /boot/SSDT-HONOR-I2C_DEVT.aml"
else
    echo "  Installed: /boot/SSDT-HONOR-I2C_DEVT.aml"
fi
echo

# 创建 early CPIO
if is_zh; then
    echo "[4/6] 创建 Early CPIO..."
else
    echo "[4/6] Creating Early CPIO..."
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
ACPI_CPIO_DIR="$TEMP_DIR/kernel/firmware/acpi"
mkdir -p "$ACPI_CPIO_DIR"

# 复制补丁文件
cp "$REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml" "$ACPI_CPIO_DIR/SSDT29.aml"

# 创建 CPIO
cd "$TEMP_DIR"
find . | cpio -o -H newc > /boot/acpi_override.cpio
cd /

# 清理临时目录
rm -rf "$TEMP_DIR"

# 设置权限
chmod 644 /boot/acpi_override.cpio

if is_zh; then
    echo "  创建: /boot/acpi_override.cpio"
else
    echo "  Created: /boot/acpi_override.cpio"
fi
echo

# 配置 GRUB
if is_zh; then
    echo "[5/6] 配置引导加载器..."
else
    echo "[5/6] Configuring boot loader..."
fi

if [[ -f /etc/default/grub ]]; then
    if grep -q "GRUB_EARLY_INITRD_LINUX_CUSTOM=" /etc/default/grub; then
        sed -i 's/^GRUB_EARLY_INITRD_LINUX_CUSTOM=.*/GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi_override.cpio"/' /etc/default/grub
        if is_zh; then
            echo "  已更新 GRUB_EARLY_INITRD_LINUX_CUSTOM"
        else
            echo "  Updated GRUB_EARLY_INITRD_LINUX_CUSTOM"
        fi
    else
        echo 'GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi_override.cpio"' >> /etc/default/grub
        if is_zh; then
            echo "  已添加 GRUB_EARLY_INITRD_LINUX_CUSTOM 到 /etc/default/grub"
        else
            echo "  Added GRUB_EARLY_INITRD_LINUX_CUSTOM to /etc/default/grub"
        fi
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
    fi
else
    if is_zh; then
        echo "  警告: 找不到 /etc/default/grub，请手动更新引导加载器配置。"
    else
        echo "  Warning: /etc/default/grub not found. Please update bootloader configuration manually."
    fi
fi
echo

# 完成
if is_zh; then
    echo "[6/6] 完成！"
    echo
    echo "=========================================="
    echo "安装完成！"
    echo
    echo "请重启系统:"
    echo "  sudo reboot"
    echo
    echo "重启后验证:"
    echo "  sudo dmesg | grep -iE 'Table Upgrade|SSDT.*I2C_DEVT'"
    echo "  xinput list"
    echo
    echo "备份已保存到: $BACKUP_DIR"
    echo "=========================================="
else
    echo "[6/6] Done!"
    echo
    echo "=========================================="
    echo "Installation complete!"
    echo
    echo "Please reboot system:"
    echo "  sudo reboot"
    echo
    echo "Verify after reboot:"
    echo "  sudo dmesg | grep -iE 'Table Upgrade|SSDT.*I2C_DEVT'"
    echo "  xinput list"
    echo
    echo "Backup saved to: $BACKUP_DIR"
    echo "=========================================="
fi
