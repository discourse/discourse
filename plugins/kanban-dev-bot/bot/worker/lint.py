import pathlib
import subprocess
import sys

paths = subprocess.check_output(["git", "diff", "--name-only", "-z", sys.argv[1]]).decode().split("\0")
files = [path for path in paths if path and pathlib.Path(path).is_file()]
if files:
    result = subprocess.run(["bin/lint", "--fix", *files], capture_output=True, text=True)
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)
    if result.returncode and "[bin/lint] Nothing to lint" not in result.stdout + result.stderr:
        result.check_returncode()
