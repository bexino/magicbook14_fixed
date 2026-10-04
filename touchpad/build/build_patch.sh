#!/usr/bin/env bash
# build_patch.sh - Build ACPI patch

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
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SRC="$REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.dsl"
OUT="$REPO_DIR/patch/SSDT29_MagicBook14_2026_BCC-N_358H.aml"

# 检查依赖
if is_zh; then
    command -v iasl >/dev/null || { echo "缺少 iasl (安装: sudo dnf install acpica-tools)"; exit 1; }
    command -v python3 >/dev/null || { echo "缺少 python3"; exit 1; }

    echo "=========================================="
    echo "构建 ACPI 补丁"
    echo "=========================================="
else
    command -v iasl >/dev/null || { echo "Missing iasl (Install: sudo dnf install acpica-tools)"; exit 1; }
    command -v python3 >/dev/null || { echo "Missing python3"; exit 1; }

    echo "=========================================="
    echo "Building ACPI Patch"
    echo "=========================================="
fi
echo

# 创建临时目录
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp "$SRC" "$WORK/SSDT29.dsl"

if is_zh; then
    echo "[1/3] iasl 编译..."
else
    echo "[1/3] iasl compiling..."
fi
( cd "$WORK" && iasl SSDT29.dsl ) | tail -3
echo

if is_zh; then
    echo "[2/3] 修改 OEM Revision (0x1000 -> 0x2000) 和 checksum..."
else
    echo "[2/3] Modifying OEM Revision (0x1000 -> 0x2000) and checksum..."
fi

python3 <<PY
import sys

aml_path = "$WORK/SSDT29.aml"
data = bytearray(open(aml_path, "rb").read())

old_rev = int.from_bytes(data[24:28], "little")
if "$APP_LANG" == "zh":
    print(f"  原始 OEM Revision: 0x{old_rev:04x}")
else:
    print(f"  Original OEM Revision: 0x{old_rev:04x}")

# 修改 OEM revision
data[24:28] = (0x2000).to_bytes(4, "little")

# 重新计算 checksum
data[9] = 0
new_checksum = (-sum(data)) & 0xFF
data[9] = new_checksum

verify = sum(data) & 0xFF
if "$APP_LANG" == "zh":
    print(f"  新 OEM Revision: 0x2000")
    print(f"  新 Checksum: 0x{new_checksum:02x}")
    print(f"  验证: 0x{verify:02x}")
else:
    print(f"  New OEM Revision: 0x2000")
    print(f"  New Checksum: 0x{new_checksum:02x}")
    print(f"  Verification: 0x{verify:02x}")

assert verify == 0, "Checksum calculation error!"
if "$APP_LANG" == "zh":
    print("  Checksum 验证通过！")
else:
    print("  Checksum verification passed!")

open(aml_path, "wb").write(data)
PY

echo

if is_zh; then
    echo "[3/3] 安装..."
else
    echo "[3/3] Installing..."
fi
install -m0644 "$WORK/SSDT29.aml" "$OUT"
if is_zh; then
    echo "  输出: $OUT"
else
    echo "  Output: $OUT"
fi
echo

if is_zh; then
    echo "=========================================="
    echo "构建完成！"
    echo
    echo "请运行: sudo ./apply_patch.sh"
    echo "=========================================="
else
    echo "=========================================="
    echo "Build complete!"
    echo
    echo "Please run: sudo ./apply_patch.sh"
    echo "=========================================="
fi
