# 指纹安装与设备模板排查

普通 Fedora / Nobara 使用 `install-fprint_fedora.sh`；Fedora Atomic 使用
`install-fprint_atomic.sh`。请以普通用户运行脚本，需要权限时会调用 sudo。

两份脚本复用 `~/libfprint`，也可通过 `--source /源码路径` 指定已有源码。
不会自动拉取更新或删除源码。`--install-only` 仅安装已编译产物，并检查安装路径。
Fedora 使用 `builddir`；Atomic 使用独立的 `builddir-atomic`，首次切换需要编译。
如果旧源码位于 root 家目录，请明确指定路径并使用有访问权限的用户运行。

## 正常安装

```bash
bash install-fprint_fedora.sh
# Atomic 改用：bash install-fprint_atomic.sh
```

Atomic 将驱动安装到 `/usr/local/lib64`，规则写入 `/etc/udev/rules.d`，
并写入 `/etc/ld.so.conf.d/00-magicbook-fprint.conf` 和
`/etc/systemd/system/fprintd.service.d/90-magicbook-libfprint.conf`，
让 fprintd 使用自编译驱动。依赖通过 rpm-ostree 的 apply-live 安装；
如果系统拒绝实时应用，脚本立即停止，请处理部署状态并按系统提示重启后重试。
当前修订未在 Atomic 实机上验证。

安装后以普通用户运行 `fprintd-enroll`，得到 `enroll-completed` 后运行
`fprintd-verify`，确认 `verify-match`。系统软件包更新可能覆盖 Fedora 上的自编译库；
Atomic 的本地驱动也需要随系统升级维护兼容性。

## 新手指反复 enroll-duplicate

这可能是设备端模板与本地记录不同步，也可能是驱动问题，不能直接清空数据库。
以下选项独立运行，不编译或安装驱动；需要已安装 Python GObject 和 FPrint typelib。

```bash
bash install-fprint_fedora.sh --diagnose
bash install-fprint_fedora.sh --repair-duplicates --user 你的用户名
```

Atomic 使用同名选项，只需把脚本名换成 `install-fprint_atomic.sh`。
两份脚本都需要同目录的 `fingerprint-storage.py`。

诊断会暂时停止 fprintd，读取设备模板清单后恢复原先运行的服务。
清理仅适用于 USB `27c6:6f94`、`goodixmoc` 驱动且本地 `/var/lib/fprint` 为空的情况。
本地已有记录时拒绝删除，以保护正常登记的指纹。
清理会列出模板，要求选择指定用户的记录，再输入 `DELETE` 明确确认；
不会整机清空，也不会删除其他用户的模板。删除不可撤销，需要重新录入，
其他系统若使用所删模板也可能受影响。中途出错会停止，已成功删除的记录不会回滚。

本次 Nobara 实机故障通过逐条删除设备内的旧模板后重新录入解决，
已得到 `enroll-completed` 和 `verify-match`。这不代表所有重复提示都应通过删除处理。
目前指纹正常时，不需要运行清理或重新安装。

参考：[libfprint 设备操作 API](https://fprint.freedesktop.org/libfprint-dev/FpDevice.html)、
[rpm-ostree apply-live](https://coreos.github.io/rpm-ostree/apply-live/)。
