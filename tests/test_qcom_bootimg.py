import json
from pathlib import Path
import shlex
import struct
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]


def bootimg_args(config):
    script = (ROOT / "devices/qcom/bootloader.sh").read_text()
    function = script.split("bootimg_offsets() {", 1)[1].split("\n}\n", 1)[0]
    result = subprocess.run(
        ["sh", "-c", "bootimg_offsets() {" + function
         + '\n}\nbootimg_offsets "$1"', "test", json.dumps(config)],
        check=True, capture_output=True, text=True,
    )
    return shlex.split(result.stdout)


class BootImageTests(unittest.TestCase):
    def setUp(self):
        self.config = tomllib.loads(
            (ROOT / "devices/qcom/configs/r8q.toml").read_text()
        )

    def build_header(self, args):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            for name in ("kernel", "ramdisk", "dtb"):
                (directory / name).write_bytes(b"test-" + name.encode())
            output = directory / "boot.img"
            subprocess.run(
                ["mkbootimg", *args, "--kernel", str(directory / "kernel"),
                 "--ramdisk", str(directory / "ramdisk"),
                 "--dtb", str(directory / "dtb"), "-o", str(output)],
                check=True,
            )
            return output.read_bytes()

    def test_stock_r8q_header(self):
        header = self.build_header(bootimg_args(self.config["bootimg"]))
        self.assertEqual(header[:8], b"ANDROID!")
        self.assertEqual(struct.unpack_from("<I", header, 12)[0], 0x8000)
        self.assertEqual(struct.unpack_from("<I", header, 20)[0], 0x2000000)
        self.assertEqual(struct.unpack_from("<I", header, 28)[0], 0)
        self.assertEqual(struct.unpack_from("<I", header, 32)[0], 0x1E00000)
        self.assertEqual(struct.unpack_from("<I", header, 36)[0], 4096)
        self.assertEqual(struct.unpack_from("<I", header, 40)[0], 2)
        os_version = (11 << 14) << 11
        patch_level = (2022 - 2000) << 4 | 4
        self.assertEqual(
            struct.unpack_from("<I", header, 44)[0], os_version | patch_level
        )
        self.assertEqual(header[48:64].rstrip(b"\0"), b"SRPTG02C004")
        self.assertEqual(struct.unpack_from("<I", header, 1644)[0], 1660)
        self.assertEqual(struct.unpack_from("<I", header, 1648)[0], 8)
        self.assertEqual(struct.unpack_from("<Q", header, 1652)[0], 0x1F00000)
        self.assertFalse(self.config["device"][0]["append_dtb_to_kernel"])

    def test_nonzero_base_is_added_only_once(self):
        config = dict(self.config["bootimg"], base=0x80000000)
        header = self.build_header(bootimg_args(config))
        for offset, field in (
            (12, "kernel"), (20, "ramdisk"), (32, "tags")
        ):
            self.assertEqual(
                struct.unpack_from("<I", header, offset)[0],
                config["base"] + config[field],
            )
        self.assertEqual(struct.unpack_from("<I", header, 28)[0], 0)
        self.assertEqual(
            struct.unpack_from("<Q", header, 1652)[0],
            config["base"] + config["dtb"],
        )


if __name__ == "__main__":
    unittest.main()
