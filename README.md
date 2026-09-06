# HONOR MagicBook 14 2026 (BCC-N, M1070) — Fix

修复 HONOR MagicBook 14 2026 (BCC-N, M1070) 在 Linux 系统上的：触摸板、键盘、指纹识别问题。

---

## 适用于

- RPM 系，  
  
  > (e.g. Fedora Workstation, RHEL, etc.)  
  
- Fedora Atomic，  

  > (e.g. SliverBlue, etc.)
  
- Debian 系。
  
  > (e.g. Ubuntu, Mint, etc.)
  >   
  > **注意**：Debian 系暂未支持指纹修复。  

---

## 快速开始

直接在终端中运行：

```bash
(set -e; sudo -v; if [ -e /run/ostree-booted ] && command -v rpm-ostree >/dev/null; then sudo rpm-ostree install --apply-live --allow-inactive git cpio; elif command -v dnf >/dev/null; then sudo dnf install -y git cpio; elif command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y git cpio; else echo "不支持的发行版：需要 Fedora/Fedora Atomic/Debian/Ubuntu/Mint" >&2; exit 1; fi; tmp="$(mktemp -d -t magicbook14_fixed.XXXXXX)"; trap 'rm -rf -- "$tmp"' EXIT; trap 'exit 130' INT TERM HUP; git clone --depth 1 https://github.com/bexino/magicbook14_fixed.git "$tmp/repo"; cd "$tmp/repo"; sudo bash run.sh)
```

---

## 鸣谢

https://gitee.com/syhun/magicbook14_2026_358h_fedora_linux_touchpad_fixed
