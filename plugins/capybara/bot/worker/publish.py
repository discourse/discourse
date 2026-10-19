#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request
import urllib.error
from datetime import datetime, timezone

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
    expected = {"number": target["pull_request"], "state": "open", "merged": False,
                "merged_at": None, "head_repository_id": target["repository_id"],
                "head_repository": target["repository"].lower(), "head_ref": target["branch"],
                "base_repository": target["base_repository"], "base_ref": target["base_branch"]}
    observed = {"number": pr.get("number"), "state": pr.get("state"), "merged": pr.get("merged"),
                "merged_at": pr.get("merged_at"), "head_repository_id": repo.get("id"),
                "head_repository": repo.get("full_name", "").lower(), "head_ref": head.get("ref"),
                "base_repository": (base.get("repo") or {}).get("full_name"), "base_ref": base.get("ref")}
    mismatches = {key: {"expected": value, "observed": observed[key]}
                  for key, value in expected.items() if observed[key] != value}
    if mismatches:
        raise PublicationError("validate_pr", reason="invalid_pr_target", mismatches=json.dumps(mismatches))
    return head["sha"]


def sanitize(value):
    text = str(value)
    text = re.sub(r"(?:github_pat_|gh[pousr]_)[A-Za-z0-9_]+", "[REDACTED]", text)
    text = re.sub(r"(?i)(?:Bearer|Basic)\s+[^\s\"']+", "[REDACTED AUTH]", text)
    text = re.sub(r"(https?://)[^/@\s]+@", r"\1[REDACTED]@", text)
    try:
        secret = Path("/run/github-token").read_text().strip()
        if secret:
            text = text.replace(secret, "[REDACTED]")
    except OSError:
        pass
    return text[:2000]


def diagnostic(operation, **details):
    return {"timestamp": datetime.now(timezone.utc).isoformat(), "operation": operation,
            **{key: sanitize(value) for key, value in details.items() if value is not None}}


class PublicationError(RuntimeError, ValueError):
    def __init__(self, operation, **details):
        self.details = diagnostic(operation, **details)
        super().__init__(json.dumps(self.details, sort_keys=True))


def github(path, token_path):
    token = Path(token_path).read_text().strip()
    request = urllib.request.Request("https://api.github.com/" + path, headers={
        "Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "capybara-fork-publisher"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        try:
            message = json.loads(error.read(8192)).get("message", error.reason)
        except (ValueError, AttributeError):
            message = error.reason
        raise PublicationError("github_metadata", endpoint=path, status=error.code,
                               message=str(message).replace(token, "[REDACTED]"),
                               request_id=error.headers.get("X-GitHub-Request-Id"),
                               retry_after=error.headers.get("Retry-After"),
                               rate_limit_reset=error.headers.get("X-RateLimit-Reset"),
                               rate_limit_remaining=error.headers.get("X-RateLimit-Remaining")) from None
    except Exception as error:
        raise PublicationError("github_metadata", endpoint=path, exception=type(error).__name__,
                               message=str(error).replace(token, "[REDACTED]")) from None


def git(args, cwd, env):
    result = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "-c", "credential.helper=", "-c", "pack.threads=1", *args],
                            cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise PublicationError("git_" + args[0], message="Restricted Git operation failed", exit_code=result.returncode, stderr=result.stderr)
    return result.stdout.strip()


def push_ref(remote, branch, commit, expected, cwd, env, accepted=lambda: None):
    if not SHA.fullmatch(commit) or (expected and not SHA.fullmatch(expected)):
        raise ValueError("Invalid publication commit")
    ref = "refs/heads/" + branch
    actual = git(["ls-remote", "--refs", remote, ref], cwd, env)
    actual = actual.split()[0] if actual else ""
    if actual == commit:
        accepted()
        return
    if actual != expected:
        raise RuntimeError("Fork branch changed outside this publisher; refusing to overwrite it")
    git(["push", "--porcelain", "--no-verify", "--force-with-lease=" + ref + ":" + expected,
         remote, commit + ":" + ref], cwd, env)
    accepted()


def publish(target, commit, expected, token_path, seed="/seed", destination="/publish", bootstrap=False, confirm_only=False):
    Path(destination).mkdir(parents=True, exist_ok=True)
    receipt = Path(destination) / "accepted.json"
    result = {"commit": commit, "pull_request_url": "" if bootstrap else
              f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}"}

    def accepted():
        temporary = receipt.with_suffix(".tmp")
        with temporary.open("w") as output:
            output.write(json.dumps(dict(result, status="confirming")))
            output.flush()
            os.fsync(output.fileno())
        temporary.replace(receipt)

    def confirm():
        try:
            actual = github(f"repos/{target['repository']}/git/ref/heads/{target['branch']}", token_path)["object"]["sha"]
            if actual != commit:
                raise PublicationError("confirm_ref", reason="branch_changed", expected_sha=commit, observed_sha=actual)
            actual = validate_pr(target, github(f"repos/{target['base_repository']}/pulls/{target['pull_request']}", token_path))
            if actual != commit:
                raise PublicationError("confirm_pr", reason="metadata_lag", expected_sha=commit, observed_sha=actual)
        except Exception as error:
            detail = error.details if isinstance(error, PublicationError) else diagnostic("confirm_pr", reason="verification_failed", exception=type(error).__name__, message=error)
            return dict(result, status="confirming", diagnostic=detail)
        return dict(result, status="confirmed")

    if not SHA.fullmatch(commit):
        raise ValueError("Invalid publication commit")
    if confirm_only:
        validate_target(target)
        return confirm()
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
        validate_target(target)
        current = github(f"repos/{target['repository']}/git/ref/heads/{target['branch']}", token_path)["object"]["sha"]
        if current == commit:
            accepted()
            return confirm()
        validate_pr(target, github(f"repos/{target['base_repository']}/pulls/{target['pull_request']}", token_path))
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
        try:
            push_ref("https://github.com/" + target["repository"] + ".git", target["branch"], commit, expected, destination, env, accepted)
        except Exception as push_error:
            if not bootstrap:
                try:
                    actual = github(f"repos/{target['repository']}/git/ref/heads/{target['branch']}", token_path)["object"]["sha"]
                except Exception as reconcile_error:
                    raise PublicationError("push_outcome_unknown", push_error=push_error,
                                           reconciliation_error=reconcile_error) from None
                if actual == commit:
                    accepted()
                else:
                    raise
            else:
                raise
    return dict(result, status="confirmed") if bootstrap else confirm()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default="/run/publisher-target.json")
    parser.add_argument("--commit", required=True)
    parser.add_argument("--expected", default="")
    parser.add_argument("--bootstrap", action="store_true")
    parser.add_argument("--confirm-only", action="store_true")
    args = parser.parse_args()
    try:
        result = publish(json.loads(Path(args.target).read_text()), args.commit, args.expected,
                         "/run/github-token", bootstrap=args.bootstrap, confirm_only=args.confirm_only)
        Path("/publish/result.json").write_text(json.dumps(result))
        print(json.dumps(result))
    except Exception as error:
        Path("/publish").mkdir(exist_ok=True)
        detail = error.details if isinstance(error, PublicationError) else diagnostic("publication", exception=type(error).__name__, message=error)
        result = {"status": "failed", "diagnostic": detail}
        Path("/publish/result.json").write_text(json.dumps(result))
        print(json.dumps(result))
        raise SystemExit(1) from None
    finally:
        Path("/run/github-token").unlink(missing_ok=True)


if __name__ == "__main__":
    main()
