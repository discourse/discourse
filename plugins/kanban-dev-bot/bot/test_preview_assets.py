import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import time
import unittest
from unittest.mock import Mock, patch


WORKER = Path(__file__).parent / "worker"
readiness = runpy.run_path(str(WORKER / "wait-preview.py"))
check_static_build = readiness["check_static_build"]
wait_for_live_build = readiness["wait_for_live_build"]


class PreviewAssetTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.dist = self.root / "frontend/discourse/dist"
        (self.dist / "manifest").mkdir(parents=True)
        (self.dist / "assets").mkdir()
        self.manifest = {
            "entrypoints": {"discourse": "assets/app.js"},
            "dynamicEntrypoints": {"admin": "assets/admin.js"},
            "chunks": {"assets/app.js": {"file": "assets/app.js", "imports": ["assets/vendor.js"]}},
            "importMap": {"vendor": "assets/vendor.js"},
        }
        for name in ("app", "admin", "vendor"):
            (self.dist / f"assets/{name}.js").write_text("fixture")
        self.write_manifest()

    def write_manifest(self):
        (self.dist / "manifest/manifest.json").write_text(json.dumps(self.manifest))

    def test_static_build_succeeds_without_live_builder(self):
        check_static_build(self.dist)

    def test_static_build_rejects_missing_malformed_or_incomplete_manifest(self):
        path = self.dist / "manifest/manifest.json"
        for content in (None, "{", "[]", '{}', '{"entrypoints": {}}'):
            with self.subTest(content=content):
                if content is None:
                    path.unlink(missing_ok=True)
                else:
                    path.write_text(content)
                with self.assertRaisesRegex(RuntimeError, "manifest"):
                    check_static_build(self.dist)

    def test_static_build_requires_main_entrypoint(self):
        self.manifest["entrypoints"] = {}
        self.write_manifest()
        with self.assertRaisesRegex(RuntimeError, "discourse entrypoint"):
            check_static_build(self.dist)

    def test_static_build_checks_every_referenced_file(self):
        for name in ("app", "admin", "vendor"):
            with self.subTest(name=name):
                output = self.dist / f"assets/{name}.js"
                output.unlink()
                with self.assertRaisesRegex(RuntimeError, "output is missing"):
                    check_static_build(self.dist)
                output.write_text("fixture")

    def test_static_build_rejects_output_outside_dist(self):
        (self.root / "outside.js").write_text("fixture")
        self.manifest["entrypoints"]["discourse"] = str(self.root / "outside.js")
        self.write_manifest()
        with self.assertRaisesRegex(RuntimeError, "invalid"):
            check_static_build(self.dist)

    def test_static_build_rejects_stale_status_even_with_valid_assets(self):
        (self.dist / "manifest/build.json").write_text('{"status":"ok","pid":99999999}')
        with self.assertRaisesRegex(RuntimeError, "watcher status"):
            check_static_build(self.dist)

    def test_default_live_mode_requires_a_live_builder(self):
        status = self.root / "build.json"
        status.write_text(json.dumps({"status": "ok", "pid": 123}))
        with patch.dict(wait_for_live_build.__globals__, os=Mock()) as globals_:
            wait_for_live_build(status)
            globals_["os"].kill.assert_called_once_with(123, 0)

    def test_default_live_mode_rejects_a_dead_builder(self):
        status = self.root / "build.json"
        status.write_text(json.dumps({"status": "ok", "pid": 123}))
        fake_os = Mock()
        fake_os.kill.side_effect = ProcessLookupError()
        fake_time = Mock()
        fake_time.monotonic.side_effect = [0, 1, 301]
        with patch.dict(wait_for_live_build.__globals__, os=fake_os, time=fake_time):
            with self.assertRaisesRegex(TimeoutError, "live builder"):
                wait_for_live_build(status)

    def test_default_live_mode_reports_build_failure(self):
        status = self.root / "build.json"
        status.write_text(json.dumps({"status": "error", "pid": os.getpid(), "error": "broken"}))
        with self.assertRaisesRegex(RuntimeError, "broken"):
            wait_for_live_build(status)

    def test_pitchfork_watchers_are_opt_out_and_ready_log_matches(self):
        fixture = r'''require "json"
require "logger"
require "ostruct"
$started = []
module Rails
  def self.env = OpenStruct.new(development?: true)
end
module GlobalSetting
  def self.enable_vips_image_processing = false
end
module DiscoursePluginRegistry
  def self.demon_processes = []
end
module Demon
  module PluginJsWatcher
    def self.start(**) = $started << "plugin"
  end
end
module EmberAssets
  def self.watch! = $started << "ember"
end
class Config
  attr_reader :ready
  def require(*) = nil
  def method_missing(name, *, &block)
    @ready = block if name == :before_service_worker_ready
  end
end
config = Config.new
config.instance_eval(File.read(ARGV[0]), ARGV[0])
def Thread.new(*) = nil
config.ready.call(OpenStruct.new(worker_processes: 3, logger: Logger.new($stdout)), nil)
puts JSON.generate($started)
'''
        config = WORKER.parents[3] / "config/pitchfork.conf.rb"
        for flag, ci, expected in ((None, None, ["plugin", "ember"]), ("0", None, ["plugin", "ember"]), ("1", None, []), (None, "1", ["ember"])):
            with self.subTest(flag=flag, ci=ci):
                env = {key: value for key, value in os.environ.items() if key not in ("CI", "DISCOURSE_SKIP_JS_WATCHERS", "ENABLE_LOGSTASH_LOGGER")}
                env["RAILS_ENV"] = "production"
                if flag is not None:
                    env["DISCOURSE_SKIP_JS_WATCHERS"] = flag
                if ci is not None:
                    env["CI"] = ci
                result = subprocess.run(["ruby", "-e", fixture, str(config)], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout.splitlines()[-1]), expected)
                self.assertEqual("plugin JS watcher" in result.stdout, "plugin" in expected)

    def run_startup(self, fail=""):
        commands = self.root / "commands"
        commands.mkdir()
        log = self.root / "commands.log"
        command_script = """#!/bin/bash
set -eu
name=$(basename "$0")
if [ "$name" = sudo ]; then
  shift 3
  exec "$@"
fi
printf '%s %s js=%s css=%s\n' "$name" "$*" "$DISCOURSE_SKIP_JS_WATCHERS" "$DISCOURSE_SKIP_CSS_WATCHER" >> "$COMMAND_LOG"
if [ "$name" = "$FAIL_COMMAND" ]; then exit 7; fi
"""
        for name in ("sudo", "pnpm", "rails", "rake", "pitchfork"):
            target = commands / name
            target.write_text(command_script)
            target.chmod(0o755)
        (self.root / "bin").mkdir()
        for name in ("rails", "rake", "pitchfork"):
            (self.root / "bin" / name).symlink_to(commands / name)
        start = self.root / "start.sh"
        start.write_text((WORKER / "start-preview.sh").read_text().replace("/workspace", str(self.root)).replace("cd " + str(self.root) + "/discourse", "cd " + str(self.root)).replace("/opt/bot/wait-preview.py", str(WORKER / "wait-preview.py")))
        fake_pnpm = commands / "pnpm"
        fake_pnpm.write_text(command_script + "cp fixture-manifest.json frontend/discourse/dist/manifest/manifest.json\n")
        (self.root / "fixture-manifest.json").write_text(json.dumps(self.manifest))
        (self.dist / "manifest/build.json").write_text('{"status":"error"}')
        result = subprocess.run(["bash", str(start)], env={**os.environ, "PATH": str(commands) + os.pathsep + os.environ["PATH"], "COMMAND_LOG": str(log), "FAIL_COMMAND": fail}, capture_output=True, text=True)
        if not fail:
            deadline = time.monotonic() + 3
            while "pitchfork" not in log.read_text() and time.monotonic() < deadline:
                time.sleep(0.02)
        return result, log.read_text()

    def test_startup_builds_once_then_starts_server_without_watchers(self):
        result, log = self.run_startup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(log.index("pnpm --dir frontend/discourse build"), log.index("rake assets:precompile:build_plugins"))
        self.assertLess(log.index("rake assets:precompile:build_plugins"), log.index("pitchfork"))
        self.assertNotIn("frontend/discourse start", log)
        self.assertEqual(log.count("pnpm "), 1)
        self.assertTrue(all("js=1 css=1" in line for line in log.splitlines()))
        self.assertFalse((self.dist / "manifest/build.json").exists())

    def test_core_build_failure_prevents_server_start(self):
        result, log = self.run_startup("pnpm")
        self.assertEqual(result.returncode, 7)
        self.assertNotIn("pitchfork", log)
        self.assertNotIn("rake ", log)

    def test_plugin_build_failure_prevents_server_start(self):
        result, log = self.run_startup("rake")
        self.assertEqual(result.returncode, 7)
        self.assertNotIn("pitchfork", log)


if __name__ == "__main__":
    unittest.main()
