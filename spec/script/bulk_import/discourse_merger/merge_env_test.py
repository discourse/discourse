"""Run with python3 on the Docker host. All resources and inputs are synthetic."""
import argparse
import contextlib
import gzip
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ENTRY = Path(__file__).resolve().parents[4] / "script/bulk_import/discourse_merger/docker/merge-env"
loader = importlib.machinery.SourceFileLoader("merge_env", str(ENTRY))
spec = importlib.util.spec_from_loader(loader.name, loader)
env = importlib.util.module_from_spec(spec)
loader.exec_module(env)


class HostEnvironmentTest(unittest.TestCase):
    def setUp(self):
        self.ctx = contextlib.ExitStack()
        self.addCleanup(self.ctx.close)
        self.tmp = Path(self.ctx.enter_context(tempfile.TemporaryDirectory()))
        self.root = self.tmp / "runs"
        self.root.mkdir(mode=0o700)
        launcher = self.tmp / "launcher-tree"
        launcher.mkdir()
        (launcher / "launcher").touch()
        self.rows = []
        self.tag = None
        self.commands = []
        self.patch("containers", side_effect=lambda: self.rows.copy())
        self.patch("image_owner", side_effect=lambda tag: self.tag)
        self.patch("output", side_effect=self.output)
        self.patch("call", side_effect=self.call)
        self.ctx.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.media = self.tmp / "media"
        (self.media / "original").mkdir(parents=True)
        self.args = argparse.Namespace(launcher=launcher, revision="b"*40, source_url="https://source.test",
            review_host="review.test", plugin=[], mode="preuploaded", source_media=self.media,
            destination_media=None, space_gib=0, port=0, exclude_pms=False, exclude_tags=False)
        for n, side in enumerate(env.ROLES):
            backup = self.tmp / f"{side}-v2026010{n+1}000000.sql.gz"
            backup.write_bytes(gzip.compress(side.encode()))
            setattr(self.args, side, str(backup))
        # Model free space independently of the test runner's filesystem.
        self.ctx.enter_context(patch.object(env.shutil, "disk_usage", return_value=argparse.Namespace(free=20*2**30)))

    def patch(self, key, **kw):
        return self.ctx.enter_context(patch.object(env, key, **kw))

    def output(self, *args):
        if args[:2] == ("docker", "info"):
            return str(self.tmp)
        if args[:2] == ("docker", "ps"):
            return ""
        if args[:4] == ("docker", "inspect", "-f", "{{.Image}}"):
            return "sha256:pinned"
        raise AssertionError(args)

    def call(self, *args, **kw):
        self.commands.append(args)
        if args[:3] == ("docker", "rm", "-f"):
            self.rows[:] = [r for r in self.rows if r[0] != args[-1]]
        elif args[:3] == ("docker", "image", "rm"):
            self.tag = None
        else:
            raise AssertionError(args)

    def start(self):
        return env.new_run(self.args, self.root)

    def backup_archive(self, role, entries):
        archive = self.tmp / f"{role}-v20260101000000.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            for name, data in entries:
                item = tarfile.TarInfo(name)
                if data is None:
                    item.type = tarfile.SYMTYPE
                    item.linkname = "/tmp"
                    tar.addfile(item)
                else:
                    item.size = len(data)
                    tar.addfile(item, io.BytesIO(data))
        setattr(self.args, role, str(archive))
        setattr(self.args, role + "_media", None)
        return archive

    def test_setup_stages_source_archive_and_cleanup_protects_exports(self):
        sql = gzip.compress(b"source SQL")
        archive = self.backup_archive("source", [("./dump.sql.gz", sql), ("uploads/forum/original/1X/a", b"original"),
                                       ("uploads/forum/optimized/1X/a", b"thumbnail")])
        destination = Path(self.args.destination)
        originals = archive.read_bytes(), destination.read_bytes()
        run = self.start()
        run.data["done"].append("bootstrap")
        old_mask = os.umask(0o077)
        try:
            with patch.object(run, "create", side_effect=InterruptedError), self.assertRaises(InterruptedError):
                run.setup()
        finally:
            os.umask(old_mask)
        run = env.Run(run.path, json.loads((run.path / "state.json").read_text()))
        self.assertIn("stage-source-archive", run.data["done"])
        dump = Path(run.restore_input("source")["path"])
        self.assertEqual(dump.name, "source-v20260101000000.sql.gz")
        self.assertEqual(dump.read_bytes(), sql)
        self.assertEqual(run.restore_input("destination")["path"], str(destination))
        media, writable = run.mounts("destination")["/mnt/source-uploads"]
        self.assertFalse(writable)
        self.assertEqual((media / "optimized/1X/a").read_bytes(), b"thumbnail")
        self.assertEqual((media / "original/1X/a").read_bytes(), b"original")
        for directory in (media, media / "original", media / "original/1X"):
            self.assertEqual(directory.stat().st_mode & 0o005, 0o005)
        self.assertTrue((media / "original/1X/a").stat().st_mode & 0o004)
        restored = run.runtime / "source/backups/default"
        restored.mkdir(parents=True)
        (restored / dump.name).write_bytes(sql)
        exported = restored / "merged-v20260202000000.sql.gz"
        exported.touch()
        with self.assertRaisesRegex(ValueError, "Move exported backup"):
            run.cleanup(True)
        exported.rename(run.path / exported.name)
        run.cleanup(True)
        self.assertEqual((archive.read_bytes(), destination.read_bytes()), originals)

    def test_archive_staging_resumes_after_interruption(self):
        self.backup_archive("source", [("dump.sql.gz", gzip.compress(b"sql")), ("uploads/site/original/a", b"a")])
        run = self.start()
        def interrupt(archive, dump, media):
            dump.write_bytes(b"partial")
            raise InterruptedError
        with patch.object(env, "unpack_archive", side_effect=interrupt), self.assertRaises(InterruptedError):
            run.stage("stage-source-archive", run.stage_archive, "source")
        self.assertFalse((run.runtime / "source-input").exists())
        run = env.Run(run.path, json.loads((run.path / "state.json").read_text()))
        run.stage("stage-source-archive", run.stage_archive, "source")
        self.assertEqual(gzip.decompress(Path(run.restore_input("source")["path"]).read_bytes()), b"sql")

    def test_two_archives_resume_and_restore_each_sites_own_files(self):
        inputs = {}
        for role in env.ROLES:
            data = role.encode()
            archive = self.backup_archive(role, [("dump.sql.gz", gzip.compress(data)),
                                                 ("uploads/default/original/1X/a", data)])
            inputs[archive] = archive.read_bytes()
        run = self.start()
        run.data["done"].append("bootstrap")
        unpack = env.unpack_archive
        def interrupt_destination(archive, dump, media):
            if archive == Path(self.args.destination):
                dump.write_bytes(b"partial")
                raise InterruptedError
            unpack(archive, dump, media)
        with patch.object(env, "unpack_archive", side_effect=interrupt_destination), self.assertRaises(InterruptedError):
            run.setup()
        run = env.Run(run.path, json.loads((run.path / "state.json").read_text()))
        self.assertEqual(run.data["active"], "stage-destination-archive")
        with patch.object(env, "unpack_archive", wraps=unpack) as retry, patch.object(
            run, "create", side_effect=InterruptedError
        ), self.assertRaises(InterruptedError):
            run.setup()
        self.assertEqual([c.args[0] for c in retry.call_args_list], [Path(self.args.destination)])

        for role in env.ROLES:
            dump = Path(run.restore_input(role)["path"])
            self.assertEqual(gzip.decompress(dump.read_bytes()), role.encode())
            media, writable = run.mounts("destination")[f"/mnt/{role}-uploads"]
            self.assertFalse(writable)
            self.assertEqual((media / "original/1X/a").read_bytes(), role.encode())
            restored = run.runtime / role / "backups/default"
            restored.mkdir(parents=True)
            (restored / dump.name).write_bytes(dump.read_bytes())
        exported = run.runtime / "destination/backups/default/merged-v20260202000000.sql.gz"
        exported.touch()
        with self.assertRaisesRegex(ValueError, "Move exported backup"):
            run.cleanup(True)
        exported.rename(run.path / exported.name)
        run.cleanup(True)
        for archive, original in inputs.items():
            self.assertEqual(archive.read_bytes(), original)

    def test_destination_archive_with_sql_source_and_external_media(self):
        self.backup_archive("destination", [("dump.sql.gz", gzip.compress(b"destination")),
                                            ("uploads/forum/original/a", b"a")])
        self.args.destination_media = self.media
        with self.assertRaisesRegex(ValueError, "Omit --destination-media"):
            self.start()
        self.args.destination_media = None
        run = self.start()
        run.data["done"].append("bootstrap")
        with patch.object(run, "create", side_effect=InterruptedError), self.assertRaises(InterruptedError):
            run.setup()
        self.assertEqual(run.restore_input("source")["path"], self.args.source)
        self.assertEqual(run.mounts("destination")["/mnt/source-uploads"], (self.media, False))
        self.assertIn("stage-destination-archive", run.data["done"])
        self.assertNotIn("stage-source-archive", run.data["done"])

    def test_invalid_source_archives(self):
        dump = ("dump.sql.gz", gzip.compress(b"sql"))
        original = ("uploads/site/original/a", b"a")
        for entries, error in [
            ([original], "missing dump"), ([dump], "original/"), ([dump, dump], "one regular dump"),
            ([dump, original, ("uploads/other/original/a", b"a")], "multiple site"),
            ([dump, ("uploads/site/original/../../escape", b"a")], "Unsafe path"),
            ([dump, ("uploads/site/original/link", None)], "regular files"),
        ]:
            with self.subTest(error=error):
                self.backup_archive("source", entries)
                run = self.start()
                with self.assertRaisesRegex(ValueError, error):
                    run.stage_archive("source")
                self.assertFalse((run.runtime / "source-input").exists())
        self.args.source_media = self.media
        with self.assertRaisesRegex(ValueError, "Omit --source-media"):
            self.start()

    def test_guided_setup_records_the_reviewed_target_and_writes_private_configuration(self):
        run = self.start()
        target = dict(bucket="review", prefix="incoming", cdn="", region="eu-west-1",
                      read_prefixes=dict(destination="s3://production/retained"), access=[False, True, "acl", "public", "private"])
        private = self.tmp / "settings.yml"
        private.write_bytes(b"private settings fixture")
        run.data["settings_path"] = str(private)
        configs = []
        def capture(*args, **kwargs):
            if "stdin" in kwargs:
                self.assertEqual(kwargs["stdin"].read(), private.read_bytes())
            if kwargs.get("input"):
                configs.append(json.loads(kwargs["input"]))
        with patch.object(run, "identify", return_value=dict(title="Forum", topics=10)), patch.object(
            env, "output", return_value=json.dumps(target)
        ), patch.object(env, "call", side_effect=capture), patch("builtins.input", side_effect=[
            "https://review.example", "incoming_site", "yes", "y"
        ]):
            run.confirm(dict(source="src", destination="dst"))
            run.workbook("dst")
        self.assertEqual(configs[0]["preupload_locations"], dict(write="s3://review/incoming", read_prefixes=target["read_prefixes"]))
        self.assertEqual(configs[0]["destination_url"], "https://review.example")
        self.assertEqual(configs[0]["namespace"], "incoming_site")
        self.assertTrue(configs[0]["preserve_destination_uploads"])
        self.assertNotIn("private settings fixture", (run.path / "state.json").read_text())

    def test_recovery_uses_both_cold_copies_and_preserves_failed_storage(self):
        run = self.start()
        self.runtime(run, "destination")
        run.data["storage"] = {}
        run.data["done"].append("workbook")
        root = run.runtime / "destination"
        markers = [root / "postgres", root / "redis", root / "media", run.project / "plan.json"]
        for path in markers:
            path.write_bytes(b"reviewed")
        (run.project / "workflow.lock").touch()
        digest = env.hashlib.sha256(b"reviewed").hexdigest()
        calls = []
        def simulated(*args, **kwargs):
            if args[0] == "cp":
                return subprocess.run(args, check=True)
            calls.append(args)
        with patch.object(env, "call", side_effect=simulated):
            run.baseline(digest)
            for path in markers:
                path.write_bytes(b"failed")
            run.baseline(digest, recover=True)
        for path in markers:
            self.assertEqual(path.read_bytes(), b"reviewed")
        previous = next(run.path.glob("before-recovery-*"))
        self.assertEqual((previous / "project/plan.json").read_bytes(), b"failed")
        self.assertIn(("docker", "stop", "destination"), calls)
        self.assertIn(("docker", "start", "destination"), calls)

    def runtime(self, run, role):
        mounts = [{"Destination": dst, "Source": str(src), "RW": rw}
                  for dst, (src, rw) in run.mounts(role).items()]
        self.rows.append((role, run.name_for(role), run.owner, mounts))
        run.data["image"] = "sha256:pinned"
        run.data.setdefault("containers", {})[role] = role
        (run.runtime / role).mkdir()
        run.save()

    def test_allocation_and_collisions(self):
        a = self.start()
        b = self.start()
        self.assertNotEqual(a.name, b.name)
        self.assertNotEqual(a.data["port"], b.data["port"])
        self.args.port = a.data["port"]
        with self.assertRaisesRegex(ValueError, "reserved"):
            self.start()
        with socket.socket() as s:
            s.bind(("127.0.0.1", 0))
            self.args.port = s.getsockname()[1]
            with self.assertRaises(OSError):
                self.start()
        self.args.port = 0
        self.tag = ("sha256:foreign", "")
        with self.assertRaisesRegex(ValueError, "occupied"):
            self.start()

    def test_bootstrap_uses_private_templates_and_a_single_pinned_image(self):
        a = self.start()
        a.data["plugins"] = [("https://plugins.example.test/org/demo.git", "c" * 40)]
        launcher = self.args.launcher
        (launcher / "templates").mkdir()
        for name in env.TEMPLATES:
            (launcher / "templates" / f"{name}.template.yml").write_text("run: []")
        def bootstrap(*argv, **kwargs):
            self.assertEqual(argv[0], a.runtime / "launcher")
            self.assertEqual(argv[1:3], ("bootstrap", a.name))
            self.assertIn(f"--label {env.LABEL}={a.owner}", argv)
            self.tag = ("sha256:pinned", a.owner)
        with (a.path / ".lock").open("a") as lock, patch.object(env, "call", side_effect=bootstrap):
            a.lock_fd = lock.fileno()
            a.stage("bootstrap", a.build)
        cfg = json.loads((a.runtime / "containers" / (a.name + ".yml")).read_text())
        self.assertEqual(cfg["params"]["version"], self.args.revision)
        self.assertEqual(Path(cfg["volumes"][0]["volume"]["host"]), a.runtime / "seed")
        self.assertIn("git -C demo checkout --detach " + "c"*40, cfg["hooks"]["after_code"][0]["exec"]["cmd"])
        self.assertEqual(json.loads((a.path / "state.json").read_text())["image"], "sha256:pinned")
        self.assertFalse((launcher / "containers").exists())

    def test_deliverables_survive_retirement(self):
        a = self.start()
        backups = a.runtime / "destination/backups/default"
        backups.mkdir(parents=True)
        export = backups / "merged-v20260202000000.sql.gz"
        export.write_bytes(gzip.compress(b"merged"))
        with self.assertRaisesRegex(ValueError, "Move exported backup"):
            a.cleanup(True)
        retained = a.path / export.name
        export.rename(retained)
        workbook = a.project / "mappings.xlsx"
        workbook.write_bytes(b"reviewer's edits")
        a.data["done"].append("workbook")
        a.setup()
        a.cleanup(True)
        self.assertEqual(gzip.decompress(retained.read_bytes()), b"merged")
        self.assertEqual(workbook.read_bytes(), b"reviewer's edits")

    def test_partial_and_repeat_cleanup(self):
        a, b = self.start(), self.start()
        self.runtime(a, "source")
        self.runtime(b, "destination")
        # A stopped neighbor started from the run image can inherit its label.
        self.rows.append(("neighbor", "other", a.owner, []))
        self.tag = ("sha256:pinned", a.owner)
        workbook = a.project / "mappings.xlsx"
        workbook.write_bytes(b"reviewed")
        a.cleanup(False)
        self.assertTrue(a.runtime.exists())
        self.assertFalse(self.commands)
        a.cleanup(True)
        first = self.commands.copy()
        a.cleanup(True)
        self.assertEqual(self.commands, first)
        self.assertEqual(workbook.read_bytes(), b"reviewed")
        self.assertFalse(a.runtime.exists())
        self.assertTrue(b.runtime.exists())
        self.assertEqual([r[0] for r in self.rows], ["destination", "neighbor"])
        self.assertTrue((self.media / "original").is_dir())
        self.assertEqual(gzip.decompress(Path(self.args.source).read_bytes()), b"source")

    def test_replaced_container_or_shared_storage_blocks_cleanup(self):
        a = self.start()
        self.runtime(a, "destination")
        row = self.rows[0]
        self.rows[0] = ("replaced", *row[1:])
        with self.assertRaisesRegex(ValueError, "identity changed"):
            a.cleanup(True)
        self.rows[0] = row
        row[-1][0]["Source"] = str(self.media)
        with self.assertRaisesRegex(ValueError, "Mounts changed"):
            a.cleanup(True)
        self.rows[:] = [("foreign", "neighbor", "", [{"Source": str(a.runtime / "source")}])]
        with self.assertRaisesRegex(ValueError, "neighbor still mounts"):
            a.cleanup(True)
        self.assertTrue(a.runtime.exists())
        self.assertFalse(self.commands)

    def test_restore_retry_discards_only_interrupted_role(self):
        a = self.start()
        self.runtime(a, "source")
        a.data.update(active="restore-source", done=["bootstrap"])
        # Stop at the next create, after the owned half-restored role was retired.
        with patch.object(a, "create", side_effect=InterruptedError), self.assertRaises(InterruptedError):
            a.setup()
        self.assertEqual(self.commands, [("docker", "rm", "-f", "source")])
        self.assertFalse((a.runtime / "source").exists())
        state = json.loads((a.path / "state.json").read_text())
        self.assertEqual(state["active"], "restore-source")
        self.assertEqual(state["done"], ["bootstrap"])
        a.cleanup(True)
        self.assertTrue(a.project.is_dir())

    def test_space_and_replaced_paths(self):
        self.args.space_gib = 30
        with self.assertRaisesRegex(ValueError, "Insufficient space"):
            self.start()
        self.args.space_gib = 0
        a = self.start()
        a.runtime.rename(self.tmp / "original-runtime")
        a.runtime.symlink_to(self.media, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "replaced"):
            a.cleanup(True)
        self.assertTrue(self.media.exists())

    def test_stage_failure_and_changed_backup(self):
        a = self.start()
        Path(self.args.source).write_bytes(gzip.compress(b"changed"))
        with self.assertRaisesRegex(ValueError, "backup has changed"):
            (a.runtime / "source").mkdir()
            a.restore("source", "source")
        def migration_failure():
            raise subprocess.CalledProcessError(1, ["discourse", "restore"])
        with self.assertRaises(subprocess.CalledProcessError):
            a.stage("restore-source", migration_failure)
        self.assertEqual(a.data["done"], [])
        self.assertEqual(json.loads((a.path / "state.json").read_text())["active"], "restore-source")


if __name__ == "__main__":
    unittest.main()
