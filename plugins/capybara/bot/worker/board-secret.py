import os
from pathlib import Path
import re
import secrets
import subprocess
import tempfile


def secret_key(path, redis_token=""):
    if path.exists():
        token = path.read_text().strip()
        if not re.fullmatch(r"[0-9a-f]{128}", token):
            raise RuntimeError("Persisted board secret is invalid; refusing to rotate login credentials")
        path.chmod(0o600)
        return token
    token = redis_token if re.fullmatch(r"[0-9a-f]{128}", redis_token) else secrets.token_hex(64)
    descriptor, temporary = tempfile.mkstemp(prefix=".board-secret-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as output:
            output.write(token + "\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return token


if __name__ == "__main__":
    path = Path("/workspace/board-secret-key-base")
    token = ""
    if not path.exists():
        token = subprocess.check_output(["redis-cli", "--raw", "GET", "SECRET_TOKEN"], text=True).strip()
    print(secret_key(path, token))
