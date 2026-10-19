import argparse
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import Mock, patch

from deployment import DockerBoard


secret_key = runpy.run_path(str(Path(__file__).parent / "worker/board-secret.py"))["secret_key"]


class BoardSecretTests(unittest.TestCase):
    def test_adopts_existing_redis_secret_and_keeps_private_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "secret"
            token = "a" * 128
            self.assertEqual(secret_key(path, token), token)
            self.assertEqual(path.read_text().strip(), token)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(sorted(x.name for x in path.parent.iterdir()), ["secret"])

    def test_saved_secret_survives_redis_loss_and_changed_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "secret"
            token = secret_key(path, "a" * 128)
            self.assertEqual(secret_key(path), token)
            self.assertEqual(secret_key(path, "b" * 128), token)

    def test_fresh_board_generates_valid_secret_and_reuses_it(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "secret"
            token = secret_key(path)
            self.assertRegex(token, r"^[0-9a-f]{128}$")
            self.assertEqual(secret_key(path), token)

    def test_invalid_redis_value_is_not_used(self):
        with tempfile.TemporaryDirectory() as directory:
            token = secret_key(Path(directory) / "secret", "bad-secret")
            self.assertRegex(token, r"^[0-9a-f]{128}$")

    def test_invalid_saved_secret_fails_without_rotating(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "secret"
            path.write_text("bad-secret")
            with self.assertRaisesRegex(RuntimeError, "refusing to rotate") as error:
                secret_key(path, "a" * 128)
            self.assertEqual(path.read_text(), "bad-secret")
            self.assertNotIn("bad-secret", str(error.exception))

    def test_failed_atomic_replace_leaves_no_partial_secret(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "secret"
            with patch.dict(secret_key.__globals__, os=Mock(wraps=__import__("os"))) as globals_:
                globals_["os"].replace.side_effect = OSError("fixture failure")
                with self.assertRaises(OSError):
                    secret_key(path)
            self.assertFalse(path.exists())
            self.assertEqual(list(path.parent.iterdir()), [])
            self.assertRegex(secret_key(path), r"^[0-9a-f]{128}$")

    def test_board_mounts_redis_at_image_data_directory(self):
        client = Mock()
        client.volumes.get.return_value.attrs = {"Labels": {"owner": DockerBoard.owner}}
        with patch.dict("os.environ", {"BOARD_BOOTSTRAP_HOST_PATH": "/bootstrap-fixture"}, clear=True):
            board = DockerBoard(argparse.Namespace(ngrok_api="http://agent:4040", seed="/seed-fixture", worker_image="fixture"), client)
        board.create("a" * 40)
        volumes = client.containers.create.call_args.kwargs["volumes"]
        self.assertEqual(volumes["capybara-board-redis"]["bind"], "/shared/redis_data")
        self.assertEqual(volumes["capybara-board-workspace"]["bind"], "/workspace")


if __name__ == "__main__":
    unittest.main()
