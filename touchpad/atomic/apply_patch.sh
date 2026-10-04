#!/bin/bash
# apply_patch.sh (Atomic Version) - Install HONOR MagicBook 14 2026 touchpad patch
# For Fedora Atomic (Silverblue / Kinoite / Sericea / bootc) and other rpm-ostree systems

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
PATCH_FILE="$SCRIPT_DIR/../patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml"

if is_zh; then
    echo "=========================================="
    echo "HONOR MagicBook 14 2026 Touchpad Fix (Fedora Atomic)"
    echo "=========================================="
else
    echo "=========================================="
    echo "HONOR MagicBook 14 2026 Touchpad Fix (Fedora Atomic)"
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
        echo "如果是传统 Fedora 系统，请使用 touchpad/apply_patch.sh"
    else
        echo "Error: rpm-ostree command not found. This script is intended only for Fedora Atomic / Silverblue systems."
        echo "For traditional Fedora systems, please use touchpad/apply_patch.sh"
    fi
    exit 1
fi

# 检查补丁文件是否存在
if [[ ! -f "$PATCH_FILE" ]]; then
    if is_zh; then
        echo "错误: 未找到补丁文件: $PATCH_FILE"
    else
        echo "Error: Patch file not found: $PATCH_FILE"
    fi
    exit 1
fi

# 检查是否已安装
INSTALLED=0
if [[ -f /etc/acpi/local/SSDT29.aml ]] && [[ -f /etc/dracut.conf.d/acpi_override.conf ]]; then
    INSTALLED=1
fi

if [[ $INSTALLED -eq 1 ]]; then
    if is_zh; then
        echo "[状态] 检测到触摸板 ACPI 补丁已配置在系统中。"
        echo
        read -p "是否要移除触摸板补丁配置? (y/N): " -n 1 -r
    else
        echo "[Status] Touchpad ACPI patch is configured in system."
        echo
        read -p "Do you want to remove touchpad patch configuration? (y/N): " -n 1 -r
    fi
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if is_zh; then
            echo "[1/2] 清理配置与补丁文件..."
        else
            echo "[1/2] Cleaning configuration and patch files..."
        fi
        rm -f /etc/acpi/local/SSDT29.aml
        rm -f /etc/dracut.conf.d/acpi_override.conf
        
        if is_zh; then
            echo "[2/2] 禁用 rpm-ostree 本地 initramfs 重构..."
        else
            echo "[2/2] Disabling rpm-ostree local initramfs regeneration..."
        fi
        rpm-ostree initramfs --disable || true

        echo
        if is_zh; then
            echo "=========================================="
            echo "触摸板补丁配置已清理！"
            echo "请重启系统生效: sudo reboot"
            echo "=========================================="
        else
            echo "=========================================="
            echo "Touchpad patch configuration cleaned!"
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
        echo "[1/3] 部署 ACPI 补丁到 /etc/acpi/local/..."
    else
        echo "[1/3] Deploying ACPI patch to /etc/acpi/local/..."
    fi
    mkdir -p /etc/acpi/local
    cp "$PATCH_FILE" /etc/acpi/local/SSDT29.aml
    chmod 644 /etc/acpi/local/SSDT29.aml
    if is_zh; then
        echo "  已复制: /etc/acpi/local/SSDT29.aml"
    else
        echo "  Copied: /etc/acpi/local/SSDT29.aml"
    fi

    if is_zh; then
        echo "[2/3] 配置 Dracut ACPI Override ( /etc/dracut.conf.d/acpi_override.conf )..."
    else
        echo "[2/3] Configuring Dracut ACPI Override ( /etc/dracut.conf.d/acpi_override.conf )..."
    fi
    mkdir -p /etc/dracut.conf.d
    cat <<'EOF' > /etc/dracut.conf.d/acpi_override.conf
# HONOR MagicBook 14 2026 Touchpad ACPI Patch
acpi_override="yes"
acpi_table_dir="/etc/acpi/local"
EOF
    if is_zh; then
        echo "  已创建 Dracut 配置文件"
    else
        echo "  Created Dracut configuration file"
    fi

    if is_zh; then
        echo "[3/3] 开启 rpm-ostree 本地 initramfs 重构..."
        echo "  正在调用 rpm-ostree initramfs --enable ..."
    else
        echo "[3/3] Enabling rpm-ostree local initramfs regeneration..."
        echo "  Calling rpm-ostree initramfs --enable ..."
    fi
    rpm-ostree initramfs --enable

    echo
    if is_zh; then
        echo "=========================================="
        echo "安装完成！"
        echo
        echo "请重启系统:"
        echo "  sudo reboot"
        echo
        echo "重启后运行以下命令验证 ACPI 表是否成功挂载:"
        echo "  sudo dmesg | grep -iE 'Table Upgrade|SSDT.*I2C_DEVT'"
        echo "=========================================="
    else
        echo "=========================================="
        echo "Installation complete!"
        echo
        echo "Please reboot system:"
        echo "  sudo reboot"
        echo
        echo "After reboot, verify if ACPI table is mounted successfully:"
        echo "  sudo dmesg | grep -iE 'Table Upgrade|SSDT.*I2C_DEVT'"
        echo "=========================================="
    fi
fi
