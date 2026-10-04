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
    parser.add_argument('--chinese', '---chinese', action='store_true', dest='chinese')
    args = parser.parse_args()

    app_lang = os.environ.get('APP_LANG', 'en')
    if args.chinese:
        app_lang = 'zh'

    is_zh = app_lang.startswith('zh')

    if os.geteuid() != 0:
        msg = '请通过安装脚本的 --diagnose 或 --repair-duplicates 运行。' if is_zh else 'Please run via the installation script with --diagnose or --repair-duplicates.'
        parser.error(msg)
    if args.repair and not args.user:
        msg = '直接以 root 运行时必须用 --user 指定模板所属用户。' if is_zh else 'When running directly as root, --user must be specified for template owner.'
        parser.error(msg)
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
        msg = '需要且只能有一个 27c6:6f94 设备，已停止。' if is_zh else 'Requires exactly one 27c6:6f94 device, stopped.'
        raise RuntimeError(msg)

    was_active = subprocess.run(['systemctl', 'is-active', '--quiet', 'fprintd']).returncode == 0
    device = None
    opened = False
    try:
        subprocess.run(['systemctl', 'stop', 'fprintd'], check=True)
        context = FPrint.Context()
        context.enumerate()
        devices = list(context.get_devices())
        if len(devices) != 1 or devices[0].get_driver() != 'goodixmoc':
            msg = '设备数量或驱动与预期不符，已停止。' if is_zh else 'Device count or driver does not match expected, stopped.'
            raise RuntimeError(msg)
        device = devices[0]
        device.open_sync(None)
        opened = True
        if not device.get_features() & FPrint.DeviceFeature.STORAGE_LIST:
            msg = '驱动不支持读取设备模板。' if is_zh else 'Driver does not support listing device templates.'
            raise RuntimeError(msg)
        prints = device.list_prints_sync(None)
        if is_zh:
            print('设备:', device.get_name(), '驱动:', device.get_driver())
            print('设备模板数量:', len(prints))
            for index, fingerprint in enumerate(prints, 1):
                print(f'{index}: 用户={fingerprint.get_username()!r}; 手指={fingerprint.get_finger()}; 描述={fingerprint.get_description()!r}')
        else:
            print('Device:', device.get_name(), 'Driver:', device.get_driver())
            print('Device template count:', len(prints))
            for index, fingerprint in enumerate(prints, 1):
                print(f'{index}: User={fingerprint.get_username()!r}; Finger={fingerprint.get_finger()}; Description={fingerprint.get_description()!r}')

        database = Path('/var/lib/fprint')
        def require_empty_database():
            # Conservatively refuse even empty subdirectories or symlinks.
            if database.is_symlink() or (database.exists() and any(database.iterdir())):
                msg = '本地库非空或为符号链接；为保护现有登记，拒绝删除。请单独排查。' if is_zh else 'Local DB is non-empty or a symlink; refusing deletion to protect existing enrollments. Please investigate separately.'
                raise RuntimeError(msg)

        if not args.repair:
            if is_zh:
                print('仅诊断，未删除模板。')
            else:
                print('Diagnosis only, no templates deleted.')
            return
        require_empty_database()
        if not device.get_features() & FPrint.DeviceFeature.STORAGE_DELETE:
            msg = '驱动不支持逐条删除，已停止。' if is_zh else 'Driver does not support individual deletion, stopped.'
            raise RuntimeError(msg)
        eligible = {i: p for i, p in enumerate(prints, 1) if p.get_username() == args.user}
        if not eligible:
            if is_zh:
                print('没有该用户可清理的设备模板。')
            else:
                print('No device templates available to clean for this user.')
            return
        if not sys.stdin.isatty():
            msg = '删除必须在交互终端中确认。' if is_zh else 'Deletion must be confirmed in an interactive terminal.'
            raise RuntimeError(msg)

        if is_zh:
            prompt_str = f'只允许选择用户 {args.user!r} 的模板。输入要删除的编号（空格分隔，回车取消）：'
        else:
            prompt_str = f'Only templates for user {args.user!r} allowed. Enter numbers to delete (space-separated, Enter to cancel): '

        choice = input(prompt_str).strip()
        if not choice:
            if is_zh:
                print('已取消。')
            else:
                print('Cancelled.')
            return
        indices = list(dict.fromkeys(int(value) for value in choice.split()))
        if any(index not in eligible for index in indices):
            msg = '编号不存在或属于其他用户，未删除任何模板。' if is_zh else 'Index does not exist or belongs to another user, no templates deleted.'
            raise RuntimeError(msg)
        selected = [eligible[index] for index in indices]

        if is_zh:
            print('将永久删除以下设备端模板，之后需要重新录入；其他系统若使用它们也会受影响：')
        else:
            print('The following device templates will be permanently deleted and need re-enrollment; other systems using them may be affected:')
        for fingerprint in selected:
            print(repr(fingerprint.get_description()))

        confirm_prompt = '输入 DELETE 确认，其他输入取消：' if is_zh else 'Type DELETE to confirm, any other input to cancel: '
        if input(confirm_prompt) != 'DELETE':
            if is_zh:
                print('已取消。')
            else:
                print('Cancelled.')
            return
        require_empty_database()
        for fingerprint in selected:
            device.delete_print_sync(fingerprint, None)
            deleted_msg = f'已删除: {fingerprint.get_description()!r}' if is_zh else f'Deleted: {fingerprint.get_description()!r}'
            print(deleted_msg, flush=True)
        remaining = device.list_prints_sync(None)
        if any(old.equal(current) for old in selected for current in remaining):
            msg = '目标模板仍存在，请停止并进一步检查。' if is_zh else 'Target template still exists, please stop and inspect further.'
            raise RuntimeError(msg)

        if is_zh:
            print('清理完成，剩余设备模板数量:', len(remaining))
            print('请以普通用户运行 fprintd-enroll；录入完成后运行 fprintd-verify。')
        else:
            print('Cleanup complete, remaining device template count:', len(remaining))
            print('Please run fprintd-enroll as normal user; then run fprintd-verify when completed.')
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
        is_zh = os.environ.get('APP_LANG', 'en').startswith('zh') or '--chinese' in sys.argv or '---chinese' in sys.argv
        prefix = '已停止：' if is_zh else 'Stopped: '
        print(f'{prefix}{error}', file=sys.stderr)
        sys.exit(1)
