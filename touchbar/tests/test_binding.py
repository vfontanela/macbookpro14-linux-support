"""Read/discovery regression tests using a disposable sysfs tree; no root needed."""
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (Path(__file__).resolve().parents[1]/'scripts/bind-touchbar.sh').read_text()

class BindingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.script = SCRIPT.replace('/sys/', str(self.root)+'/')
        self.prefix = self.script.split('modprobe apple-ibridge')[0]
        (self.root/'bus/hid/devices').mkdir(parents=True)
        (self.root/'bus/usb/devices').mkdir(parents=True)

    def run_shell(self, text):
        return subprocess.run(['bash', '-c', self.prefix+'\nBUSID=2-7\nlog() { :; }; sleep() { :; };\n'+text], capture_output=True, text=True)

    def hid(self, busid, interface, devid, controls=False):
        physical = self.root/f'devices/{busid}/{busid}:1.{interface}/{devid}'
        physical.mkdir(parents=True)
        (self.root/'bus/hid/devices'/devid).symlink_to(physical)
        driver = self.root/'bus/hid/drivers/apple-ib-touchbar'
        driver.mkdir(parents=True, exist_ok=True)
        (physical/'driver').symlink_to(driver)
        if controls:
            for attr in ['idle_timeout', 'dim_timeout', 'fnmode']:
                (physical/attr).touch()
        return physical

    def test_dynamic_ids_and_device_scope(self):
        self.hid('1-1', 3, '0003:05AC:8600.0001')
        self.hid('2-7', 2, '0003:05AC:8600.0002')
        self.hid('2-7', 3, '0003:05AC:8600.ABC9')
        self.hid('1-1', 3, '0003:1D6B:0301.0001')
        self.hid('2-7', 3, '0003:1D6B:0301.BCDA')
        result = self.run_shell('find_display_physical_hid; find_display_virtual_hid')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['0003:05AC:8600.ABC9', '0003:1D6B:0301.BCDA'])

    def test_recovery_and_usb_discovery(self):
        for name, pid in [('3-4', '1281'), ('2-7', '8600')]:
            path = self.root/'bus/usb/devices'/name
            path.mkdir()
            (path/'idVendor').write_text('05ac\n')
            (path/'idProduct').write_text(pid+'\n')
        result = self.run_shell('find_busid 1281; find_busid 8600')
        self.assertEqual(result.stdout.splitlines(), ['3-4', '2-7'])

    def success_check(self):
        return self.run_shell(self.script[self.script.index('# The driver creates controls'):])

    def test_foreign_controls_cannot_report_success(self):
        self.hid('1-1', 2, '0003:1D6B:0301.0001', True)
        self.assertEqual(self.success_check().returncode, 1)

    def test_mode_hid_controls_report_success(self):
        self.hid('2-7', 2, '0003:1D6B:0301.FFFF', True)
        self.assertEqual(self.success_check().returncode, 0)

    def test_incomplete_controls_fail(self):
        path = self.hid('2-7', 2, '0003:1D6B:0301.FFFF', True)
        (path/'fnmode').unlink()
        self.assertEqual(self.success_check().returncode, 1)

    def test_already_bound_and_missing_device(self):
        self.hid('2-7', 3, '0003:1D6B:0301.FFFF')
        self.assertEqual(self.run_shell('rebind_hid 0003:1D6B:0301.FFFF apple-ib-touchbar').returncode, 0)
        self.assertEqual(self.run_shell('rebind_hid 0003:1D6B:0301.0000 apple-ib-touchbar').returncode, 1)

    def test_full_script_rebinds_both_layers(self):
        for devid in ['0003:05AC:8600.ABC9', '0003:1D6B:0301.BCDA']:
            path = self.hid('2-7', 3, devid)
            (path/'driver').unlink()
            driver = self.root/'bus/hid/drivers/hid-sensor-hub'
            driver.mkdir(parents=True, exist_ok=True)
            (driver/'unbind').touch()
            (path/'driver').symlink_to(driver)
        self.hid('2-7', 2, '0003:1D6B:0301.ABCD', True)
        for driver in ['apple-ibridge-hid', 'apple-ib-touchbar']:
            path = self.root/'bus/hid/drivers'/driver
            path.mkdir(parents=True, exist_ok=True)
            (path/'bind').touch()
        usb = self.root/'bus/usb/devices/2-7'
        usb.mkdir()
        (usb/'idVendor').write_text('05ac')
        (usb/'idProduct').write_text('8600')
        (self.root/'bus/usb/drivers_probe').touch()
        # Emulate the synchronous sysfs driver assignment after bind writes.
        mocks = """
modprobe() { :; }
logger() { :; }
sleep() { :; }
printf() {
    builtin printf "$@"
    if [[ -n "${wanted:-}" ]]; then
        ln -sfn "$(dirname "$(readlink -f "$path/driver")")/$wanted" "$path/driver"
    fi
}
"""
        main = self.script[len(self.prefix):]
        result = subprocess.run(['bash', '-c', self.prefix+mocks+main], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for devid, wanted in [('0003:05AC:8600.ABC9', 'apple-ibridge-hid'), ('0003:1D6B:0301.BCDA', 'apple-ib-touchbar')]:
            self.assertEqual((self.root/'bus/hid/devices'/devid/'driver').resolve().name, wanted)

if __name__ == '__main__':
    unittest.main()
