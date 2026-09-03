#!/usr/bin/python3
"""Inspect Goodix MOC storage; delete selected orphan records only after confirmation."""
import argparse
import os
from pathlib import Path
import pwd
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repair', action='store_true')
    parser.add_argument('--user', default=os.environ.get('SUDO_USER'))
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error('请通过安装脚本的 --diagnose 或 --repair-duplicates 运行。')
    if args.repair and not args.user:
        parser.error('直接以 root 运行时必须用 --user 指定模板所属用户。')
    if args.user:
        pwd.getpwnam(args.user)

    import gi
    gi.require_version('FPrint', '2.0')
    from gi.repository import FPrint

    matches = []
    for path in Path('/sys/bus/usb/devices').iterdir():
        try:
            if (path / 'idVendor').read_text().strip() == '27c6' and (path / 'idProduct').read_text().strip() == '6f94':
                matches.append(path)
        except FileNotFoundError:
            pass
    if len(matches) != 1:
        raise RuntimeError('需要且只能有一个 27c6:6f94 设备，已停止。')

    was_active = subprocess.run(['systemctl', 'is-active', '--quiet', 'fprintd']).returncode == 0
    device = None
    opened = False
    try:
        subprocess.run(['systemctl', 'stop', 'fprintd'], check=True)
        context = FPrint.Context()
        context.enumerate()
        devices = list(context.get_devices())
        if len(devices) != 1 or devices[0].get_driver() != 'goodixmoc':
            raise RuntimeError('设备数量或驱动与预期不符，已停止。')
        device = devices[0]
        device.open_sync(None)
        opened = True
        if not device.get_features() & FPrint.DeviceFeature.STORAGE_LIST:
            raise RuntimeError('驱动不支持读取设备模板。')
        prints = device.list_prints_sync(None)
        print('设备:', device.get_name(), '驱动:', device.get_driver())
        print('设备模板数量:', len(prints))
        for index, fingerprint in enumerate(prints, 1):
            print(f'{index}: 用户={fingerprint.get_username()!r}; 手指={fingerprint.get_finger()}; 描述={fingerprint.get_description()!r}')

        database = Path('/var/lib/fprint')
        def require_empty_database():
            # Conservatively refuse even empty subdirectories or symlinks.
            if database.is_symlink() or (database.exists() and any(database.iterdir())):
                raise RuntimeError('本地库非空或为符号链接；为保护现有登记，拒绝删除。请单独排查。')

        if not args.repair:
            print('仅诊断，未删除模板。')
            return
        require_empty_database()
        if not device.get_features() & FPrint.DeviceFeature.STORAGE_DELETE:
            raise RuntimeError('驱动不支持逐条删除，已停止。')
        eligible = {i: p for i, p in enumerate(prints, 1) if p.get_username() == args.user}
        if not eligible:
            print('没有该用户可清理的设备模板。')
            return
        if not sys.stdin.isatty():
            raise RuntimeError('删除必须在交互终端中确认。')
        choice = input(f'只允许选择用户 {args.user!r} 的模板。输入要删除的编号（空格分隔，回车取消）：').strip()
        if not choice:
            print('已取消。')
            return
        indices = list(dict.fromkeys(int(value) for value in choice.split()))
        if any(index not in eligible for index in indices):
            raise RuntimeError('编号不存在或属于其他用户，未删除任何模板。')
        selected = [eligible[index] for index in indices]
        print('将永久删除以下设备端模板，之后需要重新录入；其他系统若使用它们也会受影响：')
        for fingerprint in selected:
            print(repr(fingerprint.get_description()))
        if input('输入 DELETE 确认，其他输入取消：') != 'DELETE':
            print('已取消。')
            return
        require_empty_database()
        for fingerprint in selected:
            device.delete_print_sync(fingerprint, None)
            print('已删除:', repr(fingerprint.get_description()), flush=True)
        remaining = device.list_prints_sync(None)
        if any(old.equal(current) for old in selected for current in remaining):
            raise RuntimeError('目标模板仍存在，请停止并进一步检查。')
        print('清理完成，剩余设备模板数量:', len(remaining))
        print('请以普通用户运行 fprintd-enroll；录入完成后运行 fprintd-verify。')
    finally:
        try:
            if opened:
                device.close_sync(None)
        finally:
            if was_active:
                subprocess.run(['systemctl', 'start', 'fprintd'], check=True)


if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print(f'已停止：{error}', file=sys.stderr)
        sys.exit(1)
