#!/bin/bash
# uninstall_all.sh - Uninstall all fixes (Touchpad + Keyboard)

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
    echo "卸载所有修复"
    echo "=========================================="
else
    echo "=========================================="
    echo "Uninstall All Fixes"
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

if is_zh; then
    echo "[1/4] 卸载触摸板修复..."
else
    echo "[1/4] Uninstalling touchpad fix..."
fi

if [[ -x "$(dirname "$0")/uninstall_patch.sh" ]]; then
    "$(dirname "$0")/uninstall_patch.sh" "$@"
else
    if is_zh; then
        echo "  错误: uninstall_patch.sh 不存在或没有执行权限"
    else
        echo "  Error: uninstall_patch.sh does not exist or is not executable"
    fi
fi
echo

if is_zh; then
    echo "[2/4] 卸载键盘修复..."
else
    echo "[2/4] Uninstalling keyboard fix..."
fi

BLS_ENTRIES=$(ls /boot/loader/entries/*.conf 2>/dev/null || echo "")

for BLS_ENTRY in $BLS_ENTRIES; do
    if [[ -f "$BLS_ENTRY" ]] && grep -q "i8042.dumbkbd=1" "$BLS_ENTRY"; then
        sed -i 's/i8042.dumbkbd=1 //g' "$BLS_ENTRY"
        sed -i 's/ i8042.dumbkbd=1//g' "$BLS_ENTRY"
        sed -i 's/i8042.dumbkbd=1$//g' "$BLS_ENTRY"
        sed -i 's/  */ /g' "$BLS_ENTRY"
        if is_zh; then
            echo "  已移除: $(basename "$BLS_ENTRY")"
        else
            echo "  Removed: $(basename "$BLS_ENTRY")"
        fi
    fi
done
echo

if is_zh; then
    echo "[3/4] 更新 /etc/default/grub..."
else
    echo "[3/4] Updating /etc/default/grub..."
fi

if grep -q "i8042.dumbkbd=1" /etc/default/grub; then
    sed -i 's/i8042.dumbkbd=1 //g' /etc/default/grub
    if is_zh; then
        echo "  已从 /etc/default/grub 移除"
    else
        echo "  Removed from /etc/default/grub"
    fi
else
    if is_zh; then
        echo "  /etc/default/grub 中没有键盘参数"
    else
        echo "  No keyboard parameters in /etc/default/grub"
    fi
fi
echo

if is_zh; then
    echo "[4/4] 更新 GRUB..."
else
    echo "[4/4] Updating GRUB..."
fi

if command -v grub2-mkconfig >/dev/null 2>&1; then
    grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
    if is_zh; then
        echo "  已更新 GRUB"
    else
        echo "  Updated GRUB"
    fi
fi
echo

if is_zh; then
    echo "=========================================="
    echo "卸载完成！"
    echo
    echo "请重启系统:"
    echo "  sudo reboot"
    echo "=========================================="
else
    echo "=========================================="
    echo "Uninstallation complete!"
    echo
    echo "Please reboot system:"
    echo "  sudo reboot"
    echo "=========================================="
fi
