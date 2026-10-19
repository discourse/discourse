#!/usr/bin/env python3
import argparse
import ctypes
import fcntl
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess


OFFICIAL_UPSTREAM = "https://github.com/discourse/discourse.git"
HASH = re.compile(r"[0-9a-f]{40}\Z")
IDENTITY = re.compile(r"[A-Za-z0-9-]{8,80}\Z")


def sandbox_child(writable, username):
    account = pwd.getpwnam(username)
    libc = ctypes.CDLL(None, use_errno=True)
    version = libc.syscall(444, 0, 0, 1)
    if version < 3:
        raise RuntimeError("Conflict resolution requires Landlock ABI 3 or newer")
    rights = sum(1 << bit for bit in (1, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14))

    class Ruleset(ctypes.Structure):
        _fields_ = [("handled_access_fs", ctypes.c_uint64)]

    class PathRule(ctypes.Structure):
        _pack_ = 1
        _fields_ = [("allowed_access", ctypes.c_uint64), ("parent_fd", ctypes.c_int32)]

    def prepare():
        if libc.prctl(38, 1, 0, 0, 0) != 0:
            raise OSError(ctypes.get_errno(), "no_new_privs")
        rules = Ruleset(rights)
        descriptor = libc.syscall(444, ctypes.byref(rules), ctypes.sizeof(rules), 0)
        if descriptor < 0:
            raise OSError(ctypes.get_errno(), "landlock_create_ruleset")
        try:
            for path in [*writable, "/dev/null"]:
                handle = os.open(path, os.O_PATH | os.O_CLOEXEC)
                try:
                    allowed = rights if Path(path).is_dir() else (1 << 1) | (1 << 14)
                    rule = PathRule(allowed, handle)
                    if libc.syscall(445, descriptor, 1, ctypes.byref(rule), 0) != 0:
                        raise OSError(ctypes.get_errno(), "landlock_add_rule")
                finally:
                    os.close(handle)
            if libc.syscall(446, descriptor, 0) != 0:
                raise OSError(ctypes.get_errno(), "landlock_restrict_self")
        finally:
            os.close(descriptor)
        os.setgroups([])
        os.setgid(account.pw_gid)
        os.setuid(account.pw_uid)
    return prepare


class Integrator:
    def __init__(self, source, card, work, run_id, commit, base, upstream=OFFICIAL_UPSTREAM,
                 resolver=None, validator=None):
        if not IDENTITY.fullmatch(run_id) or not HASH.fullmatch(commit) or not HASH.fullmatch(base):
            raise ValueError("Invalid integration identity or commit")
        self.source, self.card, self.work = Path(source), Path(card), Path(work)
        self.repo = self.work / "repo"
        self.run_id, self.commit, self.base = run_id, commit, base
        self.upstream = upstream
        self.resolver = resolver or self.resolve_conflicts
        self.validator = validator or self.validate
        self.result_path = self.work / "result.json"
        self.ref = f"refs/capybara-bot/runs/{run_id}"

    def git(self, path, *arguments, check=True, environment=None):
        directories = [Path(path), *(Path(value) for value in arguments
                                      if Path(value).is_absolute() and Path(value).is_dir())]
        safe = [item for directory in directories for candidate in (directory, directory / ".git")
                for item in ("-c", f"safe.directory={candidate}")]
        result = subprocess.run(["git", *safe, "-c", "core.hooksPath=/dev/null",
                                 "-C", str(path), *arguments], text=True, capture_output=True,
                                env={**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_EDITOR": "true",
                                     **({"HOME": "/home/discourse", "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null"}
                                        if Path(path) == self.repo else {}),
                                     **(environment or {})},
                                preexec_fn=self.repo_sandbox() if Path(path) == self.repo else None)
        if check and result.returncode:
            raise RuntimeError(f"git {arguments[0]} failed: {result.stderr[-4000:]}")
        return result

    def repo_sandbox(self):
        return sandbox_child([str(self.repo), "/opt/bundle", "/tmp", "/home/discourse"], "discourse")

    def import_card(self):
        directory = self.work / "import"
        directory.mkdir(exist_ok=True)
        account = pwd.getpwnam("discourse")
        os.chown(directory, account.pw_uid, account.pw_gid)
        bundle = directory / "card.bundle"
        subprocess.run(["git", "-c", f"safe.directory={self.card}", "-c", "core.hooksPath=/dev/null",
                        "-C", str(self.card), "bundle", "create", str(bundle), "HEAD"],
                       check=True, timeout=600,
                       env={**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null", "HOME": "/home/discourse"},
                       preexec_fn=sandbox_child([str(directory), "/tmp", "/home/discourse"], "discourse"))
        self.git(self.repo, "fetch", "--no-tags", str(bundle), "HEAD")
        if self.git(self.repo, "rev-parse", "FETCH_HEAD").stdout.strip() != self.commit:
            raise RuntimeError("Card workspace no longer matches its reviewed commit")

    def head(self, path):
        return self.git(path, "rev-parse", "HEAD").stdout.strip()

    def source_ready(self, expected=None):
        if self.git(self.source, "branch", "--show-current").stdout.strip() != "capybara":
            raise RuntimeError("Source checkout must remain on capybara")
        if self.git(self.source, "status", "--porcelain").stdout.strip():
            raise RuntimeError("Source checkout has uncommitted changes; preserve them before integration")
        if expected and self.head(self.source) != expected:
            raise RuntimeError("capybara changed during integration; refusing to overwrite it")

    def save_result(self, result):
        temporary = self.result_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(result))
        temporary.replace(self.result_path)
        return result

    def published(self):
        reference = self.git(self.source, "rev-parse", "--verify", self.ref, check=False)
        if reference.returncode:
            return None
        commit = reference.stdout.strip()
        if self.git(self.source, "merge-base", "--is-ancestor", commit, "capybara", check=False).returncode == 0:
            return {"commit": commit, "card_commit": self.commit, "run_id": self.run_id,
                    "published": True, "recovered": True}
        return None

    def run(self):
        self.work.mkdir(parents=True, exist_ok=True)
        git_dir = Path(self.git(self.source, "rev-parse", "--absolute-git-dir").stdout.strip())
        with (git_dir / "capybara-bot.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if self.result_path.exists():
                prepared = json.loads(self.result_path.read_text())
                if prepared.get("run_id") == self.run_id and self.head(self.source) == prepared.get("commit"):
                    self.recover_checkout(prepared)
            self.source_ready()
            previous = self.published()
            if previous:
                return self.save_result(previous)
            original = self.head(self.source)
            if self.result_path.exists():
                result = json.loads(self.result_path.read_text())
                if result.get("run_id") == self.run_id and result.get("previous_head") == original:
                    candidate = result["commit"]
                    if self.git(self.source, "cat-file", "-e", candidate, check=False).returncode == 0:
                        return self.publish(result, original)
            self.git(self.source, "fetch", "--no-tags", self.upstream,
                     "+refs/heads/main:refs/capybara-bot/upstream")
            upstream = self.git(self.source, "rev-parse", "refs/capybara-bot/upstream").stdout.strip()
            if self.repo.exists():
                shutil.rmtree(self.repo)
            self.git(self.work, "clone", "--no-hardlinks", "--no-local", str(self.source), str(self.repo))
            subprocess.run(["chown", "-R", "--no-dereference", "discourse:discourse", str(self.repo)], check=True)
            self.git(self.repo, "config", "user.name", "Codex Bot")
            self.git(self.repo, "config", "user.email", "codex-bot@localhost.invalid")
            self.git(self.repo, "switch", "-C", "integration", original)
            if self.git(self.repo, "cat-file", "-e", upstream, check=False).returncode:
                upstream_bundle = self.work / "upstream.bundle"
                self.git(self.source, "bundle", "create", str(upstream_bundle), "refs/capybara-bot/upstream", "^" + original)
                os.chmod(upstream_bundle, 0o644)
                self.git(self.repo, "fetch", "--no-tags", str(upstream_bundle), "refs/capybara-bot/upstream")
            self.import_card()
            self.git(self.repo, "cat-file", "-e", self.base + "^{commit}")
            if self.git(self.repo, "merge-base", "--is-ancestor", self.base, self.commit, check=False).returncode:
                raise RuntimeError("Card commit does not descend from its recorded capybara base")
            patch = subprocess.run(["git", "-c", f"safe.directory={self.repo}", "-C", str(self.repo),
                                    "diff", "--binary", self.base, self.commit], capture_output=True, check=True,
                                   preexec_fn=self.repo_sandbox()).stdout
            merged = subprocess.run(["git", "-c", f"safe.directory={self.repo}", "-C", str(self.repo),
                                     "apply", "--3way", "--index", "-"], input=patch, capture_output=True,
                                    preexec_fn=self.repo_sandbox())
            if merged.returncode:
                self.resolve("merge", merged.stderr.decode())
            if self.git(self.repo, "diff", "--cached", "--quiet", check=False).returncode == 0:
                raise RuntimeError("Accepted card has no changes to merge into capybara")
            self.git(self.repo, "commit", "-m",
                     f"Complete card for run {self.run_id}\n\nCapybara-Run: {self.run_id}\nCapybara-Card-Commit: {self.commit}")
            before_rebase = self.head(self.repo)
            merge_base = self.git(self.repo, "merge-base", original, upstream).stdout.strip()
            rebased = self.git(self.repo, "rebase", "--onto", upstream, merge_base, check=False)
            attempts = 0
            while rebased.returncode:
                if attempts >= 12:
                    raise RuntimeError("Rebase conflict resolution exceeded 12 attempts")
                attempts += 1
                self.resolve("rebase", rebased.stderr)
                rebased = self.git(self.repo, "rebase", "--continue", check=False)
            candidate = self.head(self.repo)
            self.validator(upstream, candidate)
            candidate = self.head(self.repo)
            if self.git(self.repo, "merge-base", "--is-ancestor", upstream, candidate, check=False).returncode:
                raise RuntimeError("Integrated commit is missing latest official upstream")
            result = {"commit": candidate, "card_commit": self.commit, "run_id": self.run_id,
                      "previous_head": original, "upstream": upstream, "published": False,
                      "before_rebase": before_rebase}
            exported = self.repo / ".git/capybara-accepted.bundle"
            self.git(self.repo, "bundle", "create", str(exported), "HEAD", "^" + original)
            bundle = self.work / "accepted.bundle"
            descriptor = os.open(exported, os.O_RDONLY | os.O_NOFOLLOW)
            with os.fdopen(descriptor, "rb") as input_file, bundle.open("wb") as output:
                shutil.copyfileobj(input_file, output)
            self.git(self.source, "fetch", "--no-tags", str(bundle), "HEAD")
            self.save_result(result)
            return self.publish(result, original)

    def recover_checkout(self, result):
        candidate, original = result["commit"], result["previous_head"]
        if self.git(self.source, "branch", "--show-current").stdout.strip() != "capybara":
            raise RuntimeError("Source checkout must remain on capybara")
        if self.git(self.source, "diff", "--quiet", check=False).returncode:
            raise RuntimeError("Source has human edits during publication recovery; preserving them")
        index = self.git(self.source, "write-tree").stdout.strip()
        old_tree = self.git(self.source, "rev-parse", original + "^{tree}").stdout.strip()
        new_tree = self.git(self.source, "rev-parse", candidate + "^{tree}").stdout.strip()
        if index == old_tree:
            if self.head(self.source) != candidate:
                raise RuntimeError("capybara changed before publication recovery")
            self.git(self.source, "read-tree", "-u", "-m", original, candidate)
        elif index != new_tree:
            raise RuntimeError("Source index changed during publication; preserving it")
        self.source_ready(candidate)
        result["published"] = True
        self.save_result(result)

    def publish(self, result, original):
        self.source_ready(original)
        candidate = result["commit"]
        self.git(self.source, "update-ref", f"refs/capybara-bot/backups/{self.run_id}", original)
        self.git(self.source, "update-ref", self.ref, candidate)
        self.git(self.source, "update-ref", "refs/heads/capybara", candidate, original)
        try:
            if self.git(self.source, "branch", "--show-current").stdout.strip() != "capybara":
                raise RuntimeError("Source branch changed during publication")
            self.git(self.source, "read-tree", "-u", "-m", original, candidate)
        except Exception:
            self.git(self.source, "update-ref", "refs/heads/capybara", original, candidate, check=False)
            raise
        self.source_ready(candidate)
        result["published"] = True
        return self.save_result(result)

    def resolve(self, operation, diagnostic):
        conflicts = self.git(self.repo, "diff", "--name-only", "--diff-filter=U").stdout.splitlines()
        if not conflicts:
            raise RuntimeError(f"{operation} failed without resolvable conflicts: {diagnostic[-3000:]}")
        self.resolver(operation, conflicts)
        remaining = self.git(self.repo, "diff", "--name-only", "--diff-filter=U").stdout.strip()
        if remaining:
            raise RuntimeError(f"Unresolved {operation} conflicts remain: {remaining}")
        self.git(self.repo, "diff", "--cached", "--check")

    def dependencies(self):
        modules = self.repo / "node_modules"
        template_modules = Path("/opt/template/node_modules")
        if not modules.exists() and template_modules.exists():
            subprocess.run(["cp", "-a", str(template_modules), str(modules)], check=True,
                           preexec_fn=self.repo_sandbox())
        for command in (["bundle", "install", "--jobs", "4"], ["pnpm", "install", "--frozen-lockfile"]):
            subprocess.run(command, cwd=self.repo, check=True, timeout=1200,
                           env={**os.environ, "RAILS_ENV": "development", "CI": "1", "HOME": "/home/discourse"},
                           preexec_fn=self.repo_sandbox())

    def resolve_conflicts(self, operation, conflicts):
        home = self.work / "codex-home"
        home.mkdir(exist_ok=True)
        refreshed = Path("/run/refreshed-auth.json")
        auth = refreshed if refreshed.exists() else Path("/run/codex-auth.json")
        if not auth.exists():
            raise RuntimeError("Codex authentication is unavailable for conflict resolution")
        shutil.copyfile(auth, home / "auth.json")
        os.chmod(home / "auth.json", 0o600)
        account = pwd.getpwnam("discourse")
        for path in [home, *home.rglob("*")]:
            if not path.is_symlink():
                os.chown(path, account.pw_uid, account.pw_gid)
        prompt = (f"Resolve the {operation} conflicts in {self.repo}. Preserve the intended behavior of both "
                  "the accepted card and official upstream. Inspect related code and tests to resolve correctly. "
                  "Do not discard either side wholesale. Stage resolved files with git add. Do not commit, "
                  "continue or abort the operation, or touch /source. Run focused checks for changed behavior. "
                  "If resolution cannot be justified, stop and leave unresolved files. Conflicted paths are "
                  + json.dumps(conflicts))
        try:
            with (self.work / "conflicts.jsonl").open("a") as log:
                subprocess.run(["/usr/local/bin/codex", "exec", "--sandbox", "danger-full-access", "--json", "-"],
                               cwd=self.repo, input=prompt, text=True, stdout=log, stderr=log, timeout=1200,
                               env={**os.environ, "HOME": "/home/discourse", "CODEX_HOME": str(home)},
                               preexec_fn=sandbox_child([str(self.repo), str(home), "/opt/bundle", "/tmp", "/home/discourse"], "discourse"),
                               check=True)
        finally:
            if (home / "auth.json").exists():
                shutil.copyfile(home / "auth.json", refreshed)
                os.chmod(refreshed, 0o600)
                (home / "auth.json").unlink()

    def validate(self, original, candidate):
        self.dependencies()
        self.git(self.repo, "diff", "--check", original, candidate)
        subprocess.run(["python3", "/opt/bot/lint.py", original], check=True,
                       timeout=1200, cwd=self.repo, preexec_fn=self.repo_sandbox(),
                       env={**os.environ, "HOME": "/home/discourse", "CI": "1", "RAILS_ENV": "development"})
        if self.git(self.repo, "status", "--porcelain").stdout.strip():
            self.git(self.repo, "add", "-A")
            self.git(self.repo, "commit", "--amend", "--no-edit")
        self.git(self.repo, "diff", "--check", original, "HEAD")
        if self.git(self.repo, "status", "--porcelain").stdout.strip():
            raise RuntimeError("Integration checks left uncommitted changes")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--base", required=True)
    options = parser.parse_args()
    result = Integrator("/source", "/card/discourse", "/integration", options.run_id,
                        options.commit, options.base).run()
    print(json.dumps(result))


if __name__ == "__main__":
    main()
