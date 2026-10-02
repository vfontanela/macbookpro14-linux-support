"""Exercise hardware gates and video-node scope without root or hardware changes."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class CameraTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'sys/bus/pci/devices').mkdir(parents=True)
        self.library = (ROOT/'scripts/hardware.sh').read_text().replace('/sys/', str(self.root)+'/sys/').replace('/dev/', str(self.root)+'/dev/')
        self.libfile = self.root/'hardware.sh'
        self.libfile.write_text(self.library)

    def pci(self, name, vendor, device):
        path = self.root/'sys/bus/pci/devices'/name
        path.mkdir()
        (path/'vendor').write_text(vendor+'\n')
        (path/'device').write_text(device+'\n')
        return path

    def shell(self, text):
        return subprocess.run(['bash','-c','set -euo pipefail\n'+self.library+'\n'+text], capture_output=True, text=True)

    def test_absent_camera_rejected(self):
        result = self.shell('facetimehd_require_hardware')
        self.assertEqual(result.returncode, 1)
        self.assertIn('14e4:1570', result.stderr)

    def test_wifi_and_other_vendor_are_not_camera(self):
        self.pci('0000:02:00.0','0x14e4','0x43a3')
        self.pci('0000:03:00.0','0x8086','0x1570')
        self.assertEqual(self.shell('facetimehd_require_hardware').returncode, 1)

    def test_bdf_is_dynamic(self):
        self.pci('0000:0a:00.0','0x14e4','0x1570')
        result=self.shell('facetimehd_require_hardware; facetimehd_devices')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.strip(),'0000:0a:00.0')

    def test_video_nodes_exclude_unrelated_camera(self):
        self.pci('0000:0a:00.0','0x14e4','0x1570')
        videos=self.root/'sys/class/video4linux'
        videos.mkdir(parents=True)
        (self.root/'dev').mkdir()
        for node,bdf in [('video9','0000:0a:00.0'),('video0','0000:11:00.0')]:
            path=videos/node
            path.mkdir()
            physical=self.root/'devices'/bdf
            physical.mkdir(parents=True)
            (path/'device').symlink_to(physical)
            (self.root/'dev'/node).symlink_to('/dev/null')
        result=self.shell('facetimehd_video_nodes')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.strip(),str(self.root/'dev/video9'))

    def test_package_preinstall_blocks_before_side_effect(self):
        spec=importlib.util.spec_from_file_location('camera_build',ROOT/'build.py')
        build=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(build)
        pre=build.preinstall().replace('/sys/',str(self.root)+'/sys/')
        marker=self.root/'configured'
        result=subprocess.run(['bash','-c',pre+f'touch "{marker}"'],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(marker.exists())

    def test_postinstall_skips_dkms_without_hardware(self):
        script=(ROOT/'scripts/install-dkms.sh').read_text().replace('/usr/libexec/macbook-facetimehd/hardware.sh',str(self.libfile))
        # Neither headers nor DKMS should be consulted after the absent-hardware gate.
        script=script.replace('name=facetimehd','exit 99\nname=facetimehd')
        result=subprocess.run(['bash','-c',script],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def test_firmware_and_activation_do_nothing_without_hardware(self):
        script=(ROOT/'scripts/macbook-facetimehd').read_text().replace('/usr/libexec/macbook-facetimehd/hardware.sh',str(self.libfile))
        for action in ['setup','firmware','activate','test-stream']:
            result=subprocess.run(['bash','-c',script,'test-helper',action],capture_output=True,text=True)
            self.assertEqual(result.returncode,1,result.stderr)
            self.assertIn('Nothing configured',result.stderr)

if __name__=='__main__':
    unittest.main()
