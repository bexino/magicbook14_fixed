#!/bin/bash
set -Eeuo pipefail
trap 'echo "操作失败（第 ${LINENO} 行），已停止。请先解决上面的错误再重试。" >&2' ERR

# 默认复用当前用户的 ~/libfprint；可用 --source 指定已有源码目录。
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$HOME/libfprint"
mode=install
target_user="${SUDO_USER:-$(id -un)}"
install_only=false
while (($#)); do
    case "$1" in
        --source)
            if (($# < 2)) || [[ -z "$2" ]]; then
                echo "--source 需要指定源码目录" >&2
                exit 2
            fi
            source_dir="$2"
            shift 2
            ;;
        --diagnose|--repair-duplicates)
            [[ "$mode" == install ]] || { echo "诊断与清理选项不能同时使用" >&2; exit 2; }
            mode="$1"; shift ;;
        --user)
            (($# >= 2)) && [[ -n "$2" ]] || { echo "--user 需要用户名" >&2; exit 2; }
            target_user="$2"; shift 2 ;;
        --install-only) install_only=true; shift ;;
        -h|--help)
            echo "用法：bash $0 [--source 源码目录] [--install-only]"
            echo "独立诊断：--diagnose；确认后清理：--repair-duplicates [--user 用户名]（不安装驱动）"
            echo "默认增量编译并安装；--install-only 仅安装此前成功编译的产物。"
            exit 0
            ;;
        *) echo "未知参数：$1" >&2; exit 2 ;;
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
    "$install_only" && { echo "诊断/清理不能与 --install-only 混用" >&2; exit 2; }
    storage_args=(--user "$target_user")
    [[ "$mode" != --repair-duplicates ]] || storage_args+=(--repair)
    as_root python3 "$script_dir/fingerprint-storage.py" "${storage_args[@]}"
    exit 0
fi

if ! "$install_only"; then
    # gcc 不包含 C++ 编译器，Meson 还需要 gcc-c++。
    as_root dnf install -y git meson gcc gcc-c++ glib2-devel libgusb-devel openssl-devel libgudev-devel gobject-introspection-devel cairo-devel gtk-doc ninja-build python3-gobject fprintd fprintd-pam
    if [[ ! -e "$source_dir" ]]; then
        git clone https://gitlab.freedesktop.org/libfprint/libfprint.git "$source_dir"
    fi
fi

if [[ ! -f "$source_dir/meson.build" ]]; then
    echo "找不到 libfprint 源码：$source_dir；请检查 --source 参数。" >&2
    exit 1
fi
cd "$source_dir"

if "$install_only"; then
    if [[ ! -f builddir/build.ninja || ! -f builddir/meson-private/install.dat ]]; then
        echo "没有可用的安装配置，请先不带 --install-only 成功编译一次。" >&2
        exit 1
    fi
else
    driver=libfprint/drivers/goodixmoc/goodix.c
    # 已有设备 ID 时不改文件，避免重复插入和无意义的重新编译。
    if ! grep -Eq '\.pid[[:space:]]*=[[:space:]]*0x6f94' "$driver"; then
        if ! grep -q '0x6984,' "$driver"; then
            echo "驱动中找不到设备插入位置，请检查源码版本。" >&2
            exit 1
        fi
        sed -i '/0x6984,/a\  { .vid = 0x27c6,  .pid = 0x6f94,  },' "$driver"
    fi

    if [[ ! -f builddir/build.ninja ]]; then
        meson setup builddir --prefix=/usr --libdir=lib64 --buildtype=release -Dintrospection=true
    else
        meson setup --reconfigure builddir --prefix=/usr --libdir=lib64 --buildtype=release -Dintrospection=true
    fi
    # Ninja 会复用已有产物，只编译发生变化的部分。
    ninja -C builddir
fi

# 防止 --install-only 复用另一种系统的安装路径。
python3 - <<'CHECK_CONFIG'
import json
from pathlib import Path
options = {item['name']: item['value'] for item in json.loads(Path('builddir/meson-info/intro-buildoptions.json').read_text())}
if options.get('prefix') != '/usr' or options.get('libdir') != 'lib64':
    raise SystemExit('构建目录的安装路径不符，请去掉 --install-only 重新配置编译。')
CHECK_CONFIG

# 安装阶段不再触发编译；缺失产物会报错并停止。
as_root meson install -C builddir --no-rebuild
as_root ldconfig
as_root udevadm control --reload-rules
as_root systemctl restart fprintd
echo "安装完成！运行 fprintd-enroll 录入指纹。"
echo "安装不会删除任何指纹模板。若遇到 enroll-duplicate，先运行："
printf '  bash %q --diagnose\n' "$script_dir/install-fprint_fedora.sh"
printf '  bash %q --repair-duplicates --user %q\n' "$script_dir/install-fprint_fedora.sh" "$target_user"
echo "清理会列出模板并要求逐项选择及确认；本地库非空时拒绝删除。"
