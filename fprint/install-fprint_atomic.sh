#!/bin/bash
set -Eeuo pipefail

APP_LANG="${APP_LANG:-en}"

# 默认复用当前用户的 ~/libfprint；可用 --source 指定已有源码目录。
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$HOME/libfprint"
mode=install
target_user="${SUDO_USER:-$(id -un)}"
install_only=false

# First pass: check for language options
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
    trap 'echo "操作失败（第 ${LINENO} 行），已停止。请先解决上面的错误再重试。" >&2' ERR
else
    trap 'echo "Operation failed (line ${LINENO}), stopped. Please resolve the error above and try again." >&2' ERR
fi

while (($#)); do
    case "$1" in
        --chinese|---chinese)
            shift ;;
        --source)
            if (($# < 2)) || [[ -z "$2" ]]; then
                if is_zh; then
                    echo "--source 需要指定源码目录" >&2
                else
                    echo "--source requires a source directory" >&2
                fi
                exit 2
            fi
            source_dir="$2"
            shift 2
            ;;
        --diagnose|--repair-duplicates)
            [[ "$mode" == install ]] || {
                if is_zh; then echo "诊断与清理选项不能同时使用" >&2; else echo "Diagnosis and repair options cannot be used together" >&2; fi
                exit 2
            }
            mode="$1"; shift ;;
        --user)
            (($# >= 2)) && [[ -n "$2" ]] || {
                if is_zh; then echo "--user 需要用户名" >&2; else echo "--user requires a username" >&2; fi
                exit 2
            }
            target_user="$2"; shift 2 ;;
        --install-only) install_only=true; shift ;;
        -h|--help)
            if is_zh; then
                echo "用法：bash $0 [--source 源码目录] [--install-only] [--chinese]"
                echo "独立诊断：--diagnose；确认后清理：--repair-duplicates [--user 用户名]（不安装驱动）"
                echo "默认增量编译并安装；--install-only 仅安装此前成功编译的产物。"
            else
                echo "Usage: bash $0 [--source source_dir] [--install-only] [--chinese]"
                echo "Diagnosis: --diagnose; Cleanup after confirmation: --repair-duplicates [--user username] (does not install driver)"
                echo "Default is incremental build and install; --install-only installs previously compiled artifacts only."
            fi
            exit 0
            ;;
        *)
            if is_zh; then echo "未知参数：$1" >&2; else echo "Unknown parameter: $1" >&2; fi
            exit 2 ;;
    esac
done

as_root() {
    if ((EUID == 0)); then
        "$@"
    else
        sudo "$@"
    fi
}

if [[ "$mode" != install ]]; then
    "$install_only" && {
        if is_zh; then echo "诊断/清理不能与 --install-only 混用" >&2; else echo "Diagnosis/repair cannot be mixed with --install-only" >&2; fi
        exit 2
    }
    storage_args=(--user "$target_user")
    [[ "$mode" != --repair-duplicates ]] || storage_args+=(--repair)
    if is_zh; then
        storage_args+=(--chinese)
    fi
    as_root env GI_TYPELIB_PATH=/usr/local/lib64/girepository-1.0 LD_LIBRARY_PATH=/usr/local/lib64 python3 "$script_dir/fingerprint-storage.py" "${storage_args[@]}"
    exit 0
fi

if ! command -v rpm-ostree >/dev/null || [[ ! -e /run/ostree-booted ]]; then
    if is_zh; then
        echo "此脚本仅用于 Fedora Atomic；普通 Fedora/Nobara 请用 install-fprint_fedora.sh。" >&2
    else
        echo "This script is only for Fedora Atomic; for standard Fedora/Nobara use install-fprint_fedora.sh." >&2
    fi
    exit 1
fi

if ! "$install_only"; then
    dependencies=(git meson gcc gcc-c++ glib2-devel libgusb-devel openssl-devel libgudev-devel gobject-introspection-devel cairo-devel gtk-doc ninja-build python3-gobject fprintd fprintd-pam)
    missing=()
    for package in "${dependencies[@]}"; do
        rpm -q "$package" >/dev/null 2>&1 || missing+=("$package")
    done
    if ((${#missing[@]})); then
        as_root rpm-ostree install --apply-live --allow-inactive "${missing[@]}"
    fi
    if [[ ! -e "$source_dir" ]]; then
        git clone https://gitlab.freedesktop.org/libfprint/libfprint.git "$source_dir"
    fi
fi

if [[ ! -f "$source_dir/meson.build" ]]; then
    if is_zh; then
        echo "找不到 libfprint 源码：$source_dir；请检查 --source 参数。" >&2
    else
        echo "libfprint source not found: $source_dir; please check --source parameter." >&2
    fi
    exit 1
fi
cd "$source_dir"

if "$install_only"; then
    if [[ ! -f builddir-atomic/build.ninja || ! -f builddir-atomic/meson-private/install.dat ]]; then
        if is_zh; then
            echo "没有可用的安装配置，请先不带 --install-only 成功编译一次。" >&2
        else
            echo "No available build configuration, please compile successfully without --install-only first." >&2
        fi
        exit 1
    fi
else
    driver=libfprint/drivers/goodixmoc/goodix.c
    # 已有设备 ID 时不改文件，避免重复插入和无意义的重新编译。
    if ! grep -Eq '\.pid[[:space:]]*=[[:space:]]*0x6f94' "$driver"; then
        if ! grep -q '0x6984,' "$driver"; then
            if is_zh; then
                echo "驱动中找不到设备插入位置，请检查源码版本。" >&2
            else
                echo "Cannot find insertion point in driver, please check source code version." >&2
            fi
            exit 1
        fi
        sed -i '/0x6984,/a\  { .vid = 0x27c6,  .pid = 0x6f94,  },' "$driver"
    fi

    if [[ ! -f builddir-atomic/build.ninja ]]; then
        meson setup builddir-atomic --prefix=/usr/local --libdir=lib64 -Dudev_rules_dir=/etc/udev/rules.d --buildtype=release -Dintrospection=true
    else
        meson setup --reconfigure builddir-atomic --prefix=/usr/local --libdir=lib64 -Dudev_rules_dir=/etc/udev/rules.d --buildtype=release -Dintrospection=true
    fi
    # Ninja 会复用已有产物，只编译发生变化的部分。
    ninja -C builddir-atomic
fi

# 防止 --install-only 复用另一种系统的安装路径。
python3 - <<CHECK_CONFIG
import json
from pathlib import Path
options = {item['name']: item['value'] for item in json.loads(Path('builddir-atomic/meson-info/intro-buildoptions.json').read_text())}
if options.get('prefix') != '/usr/local' or options.get('libdir') != 'lib64':
    msg = '构建目录的安装路径不符，请去掉 --install-only 重新配置编译。' if "$APP_LANG" == "zh" else 'Build directory install paths do not match, please reconfigure without --install-only.'
    raise SystemExit(msg)
CHECK_CONFIG

# 安装阶段不再触发编译；缺失产物会报错并停止。
as_root meson install -C builddir-atomic --no-rebuild
# /usr/local 在 Atomic 上可写；明确让 fprintd 使用同一套自编译库。
printf '%s\n' /usr/local/lib64 | as_root tee /etc/ld.so.conf.d/00-magicbook-fprint.conf >/dev/null
as_root mkdir -p /etc/systemd/system/fprintd.service.d
printf '%s\n' '[Service]' 'Environment="LD_LIBRARY_PATH=/usr/local/lib64"' | as_root tee /etc/systemd/system/fprintd.service.d/90-magicbook-libfprint.conf >/dev/null
as_root systemctl daemon-reload
as_root ldconfig
as_root udevadm control --reload-rules
as_root systemctl restart fprintd

if is_zh; then
    echo "安装完成！运行 fprintd-enroll 录入指纹。"
    echo "安装不会删除任何指纹模板。若遇到 enroll-duplicate，先运行："
    printf '  bash %q --diagnose\n' "$script_dir/install-fprint_atomic.sh"
    printf '  bash %q --repair-duplicates --user %q\n' "$script_dir/install-fprint_atomic.sh" "$target_user"
    echo "清理会列出模板并要求逐项选择及确认；本地库非空时拒绝删除。"
else
    echo "Installation complete! Run fprintd-enroll to enroll fingerprints."
    echo "Installation does not delete fingerprint templates. If enroll-duplicate occurs, run:"
    printf '  bash %q --diagnose\n' "$script_dir/install-fprint_atomic.sh"
    printf '  bash %q --repair-duplicates --user %q\n' "$script_dir/install-fprint_atomic.sh" "$target_user"
    echo "Cleanup lists templates and requires item selection and confirmation; deletion is refused if local DB is non-empty."
fi
