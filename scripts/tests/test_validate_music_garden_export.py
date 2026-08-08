from __future__ import annotations

import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "validate-music-garden-export.py"
SPEC = importlib.util.spec_from_file_location("validator", SCRIPT)
validator = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(validator)


class ContractValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "v1"
        shutil.copytree(Path(__file__).parents[2] / "data" / "music_garden" / "v1", self.root)

    def tearDown(self):
        self.temp.cleanup()

    def manifest(self):
        return json.loads((self.root / "manifest.json").read_text())

    def save_manifest(self, value):
        (self.root / "manifest.json").write_text(json.dumps(value))

    def test_valid_fixture(self):
        validator.validate(self.root)

    def test_rejects_unsupported_major(self):
        manifest = self.manifest()
        manifest["contract_version"] = "2.0.0"
        self.save_manifest(manifest)
        with self.assertRaisesRegex(ValueError, "unsupported contract major"):
            validator.validate(self.root)

    def test_rejects_checksum_change(self):
        (self.root / "artists.json").write_text("{}\n")
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            validator.validate(self.root)

    def test_rejects_missing_required_file(self):
        manifest = self.manifest()
        manifest["files"] = [entry for entry in manifest["files"] if entry["path"] != "genres.json"]
        self.save_manifest(manifest)
        with self.assertRaisesRegex(ValueError, "missing required files"):
            validator.validate(self.root)


if __name__ == "__main__":
    unittest.main()
