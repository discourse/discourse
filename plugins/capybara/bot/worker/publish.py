#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request

SHA = re.compile(r"[0-9a-f]{40}")


def validate_target(target):
    if (target.get("repository") != "discourse/capybara-bot"
            or target.get("repository_id") != 1426162178
            or target.get("branch") != "capybara"
            or target.get("base_repository") != "discourse/discourse"
            or target.get("base_branch") != "main"
            or type(target.get("pull_request")) is not int or target["pull_request"] <= 0):
        raise ValueError("Publisher target is not the dedicated Capybara fork and PR")
    return target


def validate_pr(target, pr):
    validate_target(target)
    head, base = pr.get("head", {}), pr.get("base", {})
    repo = head.get("repo") or {}
    if (pr.get("number") != target["pull_request"] or pr.get("state") != "open"
            or pr.get("merged") is not False or pr.get("merged_at") is not None
            or repo.get("id") != target["repository_id"]
            or repo.get("full_name", "").lower() != target["repository"].lower()
            or head.get("ref") != target["branch"]
            or (base.get("repo") or {}).get("full_name") != target["base_repository"]
            or base.get("ref") != target["base_branch"]):
        raise ValueError("Pull request is closed, merged, or no longer targets the configured fork branch")
    return head["sha"]


def github(path, token_path):
    token = Path(token_path).read_text().strip()
    request = urllib.request.Request("https://api.github.com/" + path, headers={
        "Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "capybara-fork-publisher"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except Exception:
        raise RuntimeError("GitHub metadata verification failed") from None


def git(args, cwd, env):
    result = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "-c", "credential.helper=", "-c", "pack.threads=1", *args],
                            cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise RuntimeError("Restricted Git operation failed")
    return result.stdout.strip()


def push_ref(remote, branch, commit, expected, cwd, env):
    if not SHA.fullmatch(commit) or (expected and not SHA.fullmatch(expected)):
        raise ValueError("Invalid publication commit")
    ref = "refs/heads/" + branch
    actual = git(["ls-remote", "--refs", remote, ref], cwd, env)
    actual = actual.split()[0] if actual else ""
    if actual == commit:
        return
    if actual != expected:
        raise RuntimeError("Fork branch changed outside this publisher; refusing to overwrite it")
    git(["push", "--porcelain", "--no-verify", "--force-with-lease=" + ref + ":" + expected,
         remote, commit + ":" + ref], cwd, env)
    actual = git(["ls-remote", "--refs", remote, ref], cwd, env)
    if not actual or actual.split()[0] != commit:
        raise RuntimeError("GitHub did not retain the requested publication commit")


def publish(target, commit, expected, token_path, seed="/seed", destination="/publish", bootstrap=False):
    if bootstrap:
        if (target.get("repository") != "discourse/capybara-bot"
                or target.get("repository_id") != 1426162178 or target.get("branch") != "capybara"
                or expected):
            raise ValueError("Bootstrap only creates the dedicated missing fork branch")
        repo = github("repos/" + target["repository"], token_path)
        if (repo.get("id") != target["repository_id"] or repo.get("fork") is not True
                or (repo.get("parent") or {}).get("full_name") != "discourse/discourse"):
            raise ValueError("Bootstrap repository is not the dedicated Discourse fork")
    else:
        validate_pr(target, github(f"repos/{target['base_repository']}/pulls/{target['pull_request']}", token_path))
    Path(destination).mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as home:
        askpass = Path(home) / "askpass.py"
        askpass.write_text("#!/usr/bin/env python3\nfrom pathlib import Path\nimport sys\nprint('x-access-token' if 'Username' in sys.argv[1] else Path('/run/github-token').read_text().strip())\n")
        askpass.chmod(0o700)
        env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": home,
               "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": str(Path(home) / ".gitconfig"),
               "GIT_TERMINAL_PROMPT": "0", "GIT_ASKPASS": str(askpass), "GIT_ALLOW_PROTOCOL": "file:https"}
        git(["config", "--global", "--add", "safe.directory", seed], destination, env)
        git(["config", "--global", "--add", "safe.directory", seed.rstrip("/") + "/.git"], destination, env)
        git(["init", "--bare", destination], destination, env)
        git(["fetch", "--no-tags", seed, commit], destination, env)
        push_ref("https://github.com/" + target["repository"] + ".git", target["branch"], commit, expected, destination, env)
    if not bootstrap:
        actual = validate_pr(target, github(f"repos/{target['base_repository']}/pulls/{target['pull_request']}", token_path))
        if actual != commit:
            raise RuntimeError("Pull request does not yet reflect the published commit")
    return {"commit": commit, "pull_request_url": "" if bootstrap else
            f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default="/run/publisher-target.json")
    parser.add_argument("--commit", required=True)
    parser.add_argument("--expected", default="")
    parser.add_argument("--bootstrap", action="store_true")
    args = parser.parse_args()
    try:
        result = publish(json.loads(Path(args.target).read_text()), args.commit, args.expected,
                         "/run/github-token", bootstrap=args.bootstrap)
        Path("/publish/result.json").write_text(json.dumps(result))
        print(json.dumps(result))
    finally:
        Path("/run/github-token").unlink(missing_ok=True)


if __name__ == "__main__":
    main()
