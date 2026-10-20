"""Bounded review deliverables from immutable Git objects."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import PurePosixPath
import re
import posixpath
from urllib.parse import unquote, urlsplit
import subprocess
import zipfile

MAX_FILES = 24
MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_TOTAL_BYTES = 8 * 1024 * 1024
MAX_JSON_BYTES = 12 * 1024 * 1024
INLINE_CHARS = 6500
EXTENSIONS = frozenset("md txt rst csv pdf docx pptx xlsx zip png jpg jpeg gif webp diff patch".split())
SECRET_PATH = re.compile(r"(^|/)(\.env(?:\..*)?|\.git|\.ssh|\.aws|credentials[^/]*|secrets?[^/]*|auth\.json|id_rsa|id_ed25519)(/|$)|\.(pem|key|p12|pfx)$", re.I)
SECRET_CONTENT = re.compile(rb"-----BEGIN (?:[A-Z ]*PRIVATE KEY|OPENSSH PRIVATE KEY)-----|(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,})|(?:api[_-]?key|access[_-]?token|password|secret)\s*[=:]\s*[\"']?[A-Za-z0-9_+/.-]{16,}", re.I)


def safe_path(path):
    return (bool(path) and len(path) <= 240 and chr(92) not in path
            and not any(ord(character) < 32 for character in path)
            and not PurePosixPath(path).is_absolute()
            and all(part not in ("", ".", "..") for part in path.split("/"))
            and not SECRET_PATH.search(path))


def git(repo, *arguments, limit=MAX_FILE_BYTES):
    process = subprocess.Popen(["git", "--literal-pathspecs", "-C", str(repo), *arguments],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        output = process.stdout.read(limit + 1)
        if len(output) > limit:
            raise ValueError("Git output exceeds review artifact limit")
        if process.wait(timeout=30):
            raise ValueError("Unable to read immutable review Git objects")
        return output
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        process.stdout.close()


def secret_content(content, extension):
    if SECRET_CONTENT.search(content):
        return True
    if extension in {"zip", "docx", "pptx", "xlsx"}:
        try:
            with zipfile.ZipFile(io.BytesIO(content)) as archive:
                entries = archive.infolist()
                if len(entries) > 1000 or sum(entry.file_size for entry in entries) > MAX_TOTAL_BYTES:
                    return True
                for entry in entries:
                    if not safe_path(entry.filename.rstrip("/")) or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                        return True
                    if SECRET_CONTENT.search(archive.read(entry)):
                        return True
        except (ValueError, OSError, zipfile.BadZipFile, RuntimeError):
            return True
    return False


def artifact(path, content, kind="file"):
    return {"path": path, "sha256": hashlib.sha256(content).hexdigest(),
            "content_base64": base64.b64encode(content).decode("ascii"), "kind": kind}


def collect_bundle(repo, base, head):
    if not all(re.fullmatch(r"[0-9a-f]{40}", commit) for commit in (base, head)):
        raise ValueError("Review requires immutable base and head commit hashes")
    for commit in (base, head):
        git(repo, "cat-file", "-e", commit + "^{commit}")
    records = git(repo, "diff", "--no-ext-diff", "--no-textconv", "--raw", "--no-abbrev", "--no-renames", "-z", base, head,
                  limit=MAX_JSON_BYTES).split(b"\0")
    changed, omitted, eligible, files = [], [], [], []
    index = 0
    total = 0
    while index < len(records) and records[index]:
        metadata = records[index].decode("ascii").split()
        path = records[index + 1].decode("utf-8", errors="replace")
        index += 2
        if len(metadata) != 5:
            raise ValueError("Unexpected Git diff record")
        old_mode, new_mode, old_oid, new_oid, status = metadata
        changed.append(path)
        if not safe_path(path) or new_mode not in {"100644", "100755", "000000"} or old_mode.lstrip(":") not in {"100644", "100755", "000000"}:
            omitted.append(path + " (unsafe path or non-regular file)")
            continue
        contents = {}
        unsafe = False
        for oid in {old_oid, new_oid} - {"0" * 40}:
            size = int(git(repo, "cat-file", "-s", oid).decode())
            if size > MAX_FILE_BYTES:
                unsafe = True
                break
            contents[oid] = git(repo, "cat-file", "blob", oid)
            if secret_content(contents[oid], PurePosixPath(path).suffix[1:].lower()):
                unsafe = True
                break
        if unsafe:
            omitted.append(path + " (secret-like content, invalid archive, or size limit)")
            continue
        eligible.append(path)
        extension = PurePosixPath(path).suffix[1:].lower()
        if status == "D":
            continue
        if extension not in EXTENSIONS:
            omitted.append(path + " (attachment type unsupported; included in diff)")
            continue
        content = contents[new_oid]
        if not content:
            omitted.append(path + " (empty file)")
        elif len(files) >= MAX_FILES - 1 or total + len(content) > MAX_TOTAL_BYTES - MAX_FILE_BYTES:
            omitted.append(path + " (bundle count or size limit)")
        else:
            files.append(artifact(path, content))
            total += len(content)
    diff = git(repo, "diff", "--no-ext-diff", "--no-textconv", "--no-renames", "--binary", base, head, "--", *eligible) if eligible else b""
    if not diff:
        diff = b"No changes in the eligible review diff.\n"
    used_paths = {item["path"] for item in files}
    diff_path = "review.diff"
    suffix = 1
    while diff_path in used_paths:
        diff_path = f"review-{suffix}.diff"
        suffix += 1
    files.insert(0, artifact(diff_path, diff, "diff"))
    return {"base": base, "head": head, "files": files, "omitted": omitted,
            "no_changes": not changed}


def validate_bundle(bundle):
    if not isinstance(bundle, dict) or not all(re.fullmatch(r"[0-9a-f]{40}", bundle.get(key, "")) for key in ("base", "head")):
        raise ValueError("Invalid review bundle commits")
    files = bundle.get("files")
    if not isinstance(files, list) or not 1 <= len(files) <= MAX_FILES:
        raise ValueError("Invalid review bundle file count")
    total = 0
    paths = set()
    for item in files:
        path = item["path"]
        if not safe_path(path) or path in paths or PurePosixPath(path).suffix[1:].lower() not in EXTENSIONS:
            raise ValueError("Invalid review artifact path")
        content = base64.b64decode(item["content_base64"], validate=True)
        if not 0 < len(content) <= MAX_FILE_BYTES or hashlib.sha256(content).hexdigest() != item["sha256"]:
            raise ValueError("Invalid review artifact content")
        total += len(content)
        paths.add(path)
    if total > MAX_TOTAL_BYTES or sum(item.get("kind") == "diff" for item in files) != 1:
        raise ValueError("Invalid review bundle limits")
    if not isinstance(bundle.get("omitted"), list) or not all(isinstance(item, str) for item in bundle["omitted"]):
        raise ValueError("Invalid review omissions")
    return bundle


def label(value):
    return "".join(chr(92) + character if character in "[]_*<>\\`" else character
                   for character in value)


def markdown_preview(path, content, by_path):
    def replace_link(match):
        target = match.group(2)
        if urlsplit(target).scheme or target.startswith(("/", "#")):
            return match.group(0)
        resolved = posixpath.normpath(posixpath.join(posixpath.dirname(path), unquote(target.split("#", 1)[0])))
        uploaded = by_path.get(resolved)
        return "[" + match.group(1) + "](" + uploaded["short_url"] + ")" if uploaded else match.group(0)
    content = re.sub(r"\[([^\]\n]+)\]\(([^)\s]+)\)", replace_link, content)
    fence = None
    for line in content.splitlines():
        match = re.match(r"^ {0,3}(\u0060{3,}|~{3,})", line)
        if match:
            marker = match.group(1)
            if fence is None:
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence):
                fence = None
    return content + ("\n\n" + fence if fence else "")


def render_review(run, uploads):
    bundle = validate_bundle(run.review_bundle)
    by_path = {item["path"]: item for item in uploads}
    summary = run.summary[:2000]
    if len(summary) < len(run.summary):
        summary += "\n\nSummary truncated."
    tests = "\n".join("- " + test for test in run.tests) if run.tests else "No test results were reported."
    if len(tests) > 2500:
        tests = tests[:2500] + "\n\nTest results truncated."
    sections = ["Codex completed this card.", summary,
                f"Commit \x60{run.commit}\x60", "**Test results**", tests,
                "**Review files**"]
    inline_left = INLINE_CHARS
    inline_sections = []
    for item in bundle["files"]:
        uploaded = by_path[item["path"]]
        url = uploaded["short_url"]
        if not re.fullmatch(r"upload://[A-Za-z0-9._-]+", url):
            raise ValueError("Invalid persistent upload URL")
        title = "Full diff" if item.get("kind") == "diff" else label(item["path"])
        sections.append(f"[{title}]({url})")
        if item["path"].lower().endswith(".md") and inline_left:
            content = base64.b64decode(item["content_base64"]).decode("utf-8", errors="replace")
            excerpt = content[:inline_left]
            inline_left -= len(excerpt)
            inline_sections.append(f"**{label(item['path'])}**\n\n" + markdown_preview(item["path"], excerpt, by_path))
            if len(excerpt) < len(content):
                inline_sections.append("Markdown preview truncated. Download the attached original for the complete document.")
    sections.extend(inline_sections)
    if bundle.get("no_changes"):
        sections.append("No code changes were made.")
    if bundle["omitted"]:
        sections.append("**Omitted from review attachments or diff**\n\n" +
                        "\n".join("- " + label(item) for item in bundle["omitted"])[:2500])
    sections.extend([f"[Admin preview]({run.preview_url}/session/admin-account/become)",
                     f"[User preview]({run.preview_url}/session/user-account/become)"])
    message = "\n\n".join(sections)
    if len(message) > 20_000:
        raise ValueError("Review handoff exceeds post limit")
    return message


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    bundle = validate_bundle(collect_bundle(args.repo, args.base, args.head))
    with open(args.output, "w") as output:
        json.dump(bundle, output)


if __name__ == "__main__":
    main()
