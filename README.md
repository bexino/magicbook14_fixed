[![简体中文](https://img.shields.io/badge/简体中文-zh__cn-red)](#简体中文)
[![QuickStart](https://img.shields.io/badge/Quick-Start-orange)](#quick-start)
[![Commit Activity](https://img.shields.io/github/commit-activity/t/bexino/magicbook14_fixed?color=green)](https://github.com/bexino/magicbook14_fixed/commits/main/)
[![License](https://img.shields.io/github/license/bexino/magicbook14_fixed?color=blue)](https://github.com/bexino/magicbook14_fixed/blob/main/LICENSE)
[![MadeWith♥](https://img.shields.io/badge/@bexino-Made_With_♥-purple)](https://github.com/bexino)

# magicbook14_fixed

Fixes touchpad, keyboard, and fingerprint recognition issues on the HONOR MagicBook 14 2026 (BCC-N, M1070) under Linux.

## Applicable to


| System        | e.g.                           | Notes                                                        |
| ------------- | ------------------------------ | ------------------------------------------------------------ |
| RPM-based     | Fedora Workstation, RHEL, etc. |                                                              |
| Fedora Atomic | e.g. SilverBlue, etc.          |                                                              |
| Debian-based  | e.g. Ubuntu, Mint, etc.        | Fingerprint fix is not yet supported;  <br />PRs are welcome. |

## Quick Start

Run directly in the terminal:

```bash
(set -e; sudo -v; if [ -e /run/ostree-booted ] && command -v rpm-ostree >/dev/null; then sudo rpm-ostree install --apply-live --allow-inactive git cpio; elif command -v dnf >/dev/null; then sudo dnf install -y git cpio; elif command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y git cpio; else echo "Unsupported distribution: Fedora/Fedora Atomic/Debian/Ubuntu/Mint required" >&2; exit 1; fi; tmp="$(mktemp -d -t magicbook14_fixed.XXXXXX)"; trap 'rm -rf -- "$tmp"' EXIT; trap 'exit 130' INT TERM HUP; git clone --depth 1 https://github.com/bexino/magicbook14_fixed.git "$tmp/repo"; cd "$tmp/repo"; sudo bash run.sh)
```

> [!NOTE]
>
> If you restart using the script menu, the temporary files may not be automatically deleted in time.  
> Please go to the system temporary directory `/tmp` and remove them manually.

---

## FAQ

Q: After running the script, the touchpad still does not work, but touchpad settings are present in GNOME?  
A: Press Fn+F3 to enable the touchpad, then try again.

---

## Acknowledgements

https://gitee.com/syhun/magicbook14_2026_358h_fedora_linux_touchpad_fixed

## License

Apache-2.0 license



---


# 简体中文

修复 HONOR MagicBook 14 2026 (BCC-N, M1070) 在 Linux 系统上的：触摸板、键盘、指纹识别问题。

## 适用于


| 系统          | e.g.                           | 备注                        |
| ------------- | ------------------------------ | --------------------------- |
| RPM 系        | Fedora Workstation, RHEL, etc. |                             |
| Fedora Atomic | e.g. SliverBlue, etc.          |                             |
| Debian 系     | e.g. Ubuntu, Mint, etc.        | 暂未支持指纹修复，  <br />欢迎PR。 |

## 快速开始

直接在终端中运行：

```bash
(set -e; sudo -v; if [ -e /run/ostree-booted ] && command -v rpm-ostree >/dev/null; then sudo rpm-ostree install --apply-live --allow-inactive git cpio; elif command -v dnf >/dev/null; then sudo dnf install -y git cpio; elif command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y git cpio; else echo "不支持的发行版：需要 Fedora/Fedora Atomic/Debian/Ubuntu/Mint" >&2; exit 1; fi; tmp="$(mktemp -d -t magicbook14_fixed.XXXXXX)"; trap 'rm -rf -- "$tmp"' EXIT; trap 'exit 130' INT TERM HUP; git clone --depth 1 https://github.com/bexino/magicbook14_fixed.git "$tmp/repo"; cd "$tmp/repo"; sudo bash run.sh)
```

> [!NOTE]
>
> 若使用脚本菜单重启，可能无法及时自动删除临时文件。  
> 请前往系统临时目录 `/tmp` 手动清除。

---

## FAQ

Q：脚本运行后，触控板仍然无法使用，但GNOME中存在触控板设置？  
A：按下 Fn+F3 启用触控板后再试。

---

## 鸣谢

https://gitee.com/syhun/magicbook14_2026_358h_fedora_linux_touchpad_fixed

## 许可证

Apache-2.0 license
