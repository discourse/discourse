import dataclasses
import json
import os
from pathlib import Path
from urllib.parse import urlsplit

from requests.auth import AuthBase, HTTPBasicAuth


@dataclasses.dataclass(frozen=True, repr=False)
class BoardCredentials:
    username: str
    password: str

    def ngrok_value(self):
        return f"{self.username}:{self.password}"


def load_board_credentials():
    path = os.environ.get("BOARD_HTTP_AUTH_FILE")
    if not path:
        return None
    try:
        value = json.loads(Path(path).read_text())
        username, password = value["username"], value["password"]
        if not isinstance(username, str) or not isinstance(password, str):
            raise ValueError()
        if not username or not password or ":" in username or any(c in username + password for c in "\r\n"):
            raise ValueError()
        return BoardCredentials(username, password)
    except (OSError, ValueError, KeyError, TypeError):
        raise RuntimeError("BOARD_HTTP_AUTH_FILE must contain valid username/password credentials") from None


class BoardHTTPAuth(AuthBase):
    def __init__(self, root, credentials):
        self.origin = urlsplit(root)[:2]
        self.basic = HTTPBasicAuth(credentials.username, credentials.password)

    def __call__(self, request):
        if urlsplit(request.url)[:2] == self.origin:
            self.basic(request)
        return request


def configure_board_auth(session, root, credentials):
    if credentials:
        session.auth = BoardHTTPAuth(root, credentials)
