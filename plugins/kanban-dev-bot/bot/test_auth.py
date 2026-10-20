import argparse
import base64
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import requests

from auth import BoardCredentials, configure_board_auth, load_board_credentials
from deployment import DockerBoard


class AuthTests(unittest.TestCase):
    def test_optional_configuration_and_fail_closed_missing_file(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(load_board_credentials())
        with patch.dict(os.environ, {"BOARD_HTTP_AUTH_FILE": "/missing-auth-fixture"}):
            with self.assertRaisesRegex(RuntimeError, "valid username/password"):
                load_board_credentials()

    def test_credentials_parse_without_exposing_secret_in_errors_or_repr(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "auth.json"
            with patch.dict(os.environ, {"BOARD_HTTP_AUTH_FILE": str(path)}):
                for value in ({"username": "", "password": "fixture-secret"},
                              {"username": "wrong:name", "password": "fixture-secret"},
                              {"username": "tester", "password": "bad\nfixture-secret"}, []):
                    path.write_text(json.dumps(value))
                    with self.assertRaises(RuntimeError) as error:
                        load_board_credentials()
                    self.assertNotIn("fixture-secret", str(error.exception))
                path.write_text(json.dumps({"username": "tester", "password": "fixture-secret"}))
                credentials = load_board_credentials()
                self.assertEqual(credentials.username, "tester")
                self.assertNotIn("fixture-secret", repr(credentials))

    def test_credentials_only_sent_to_exact_board_origin(self):
        session = requests.Session()
        configure_board_auth(session, "https://main.example", BoardCredentials("tester", "fixture"))
        for url in ("https://preview.example", "https://api.github.com", "http://main.example", "https://main.example:444"):
            request = session.prepare_request(requests.Request("GET", url))
            self.assertNotIn("Authorization", request.headers)
        request = session.prepare_request(requests.Request("GET", "https://main.example/uploads/image.png"))
        expected = "Basic " + base64.b64encode(b"tester:fixture").decode()
        self.assertEqual(request.headers["Authorization"], expected)

    def board(self):
        with patch.dict(os.environ, {}, clear=True):
            board = DockerBoard(argparse.Namespace(ngrok_api="http://agent:4040"), Mock())
        board.host = "main.example"
        board.credentials = BoardCredentials("tester", "fixture")
        board.ngrok = Mock()
        board.ngrok.get.return_value.json.return_value = {"tunnels": [
            {"name": "command_line", "public_url": "https://main.example", "config": {"addr": "http://127.0.0.1:3410"}},
            {"name": "card-preview", "public_url": "https://preview.example", "config": {"addr": "http://127.0.0.1:3500"}}]}
        return board

    def test_matching_address_without_auth_is_replaced_and_preview_is_untouched(self):
        board = self.board()
        board.tunnel_auth_matches = Mock(return_value=False)
        board.point_tunnel()
        self.assertEqual(board.ngrok.delete.call_count, 1)
        self.assertTrue(board.ngrok.delete.call_args.args[0].endswith("/command_line"))
        payload = board.ngrok.post.call_args.kwargs["json"]
        self.assertEqual(payload["basic_auth"], ["tester:fixture"])
        self.assertEqual(payload["hostname"], "main.example")
        board.tunnel_auth_matches.return_value = True
        board.point_tunnel()
        self.assertEqual(board.ngrok.delete.call_count, 1)
        self.assertEqual(board.ngrok.post.call_count, 1)

    def test_edge_probe_checks_anonymous_challenge_then_authenticated_success(self):
        board = self.board()
        session = Mock()
        session.headers = {}
        challenge = Mock(status_code=401, headers={"WWW-Authenticate": 'Basic realm="ngrok"'})
        session.get.side_effect = [challenge, Mock(status_code=200)]
        with patch("deployment.requests.Session") as factory:
            factory.return_value.__enter__.return_value = session
            self.assertTrue(board.tunnel_auth_matches())
        self.assertEqual(session.get.call_count, 2)
        self.assertIsNotNone(session.auth)
        session.get.side_effect = [Mock(status_code=200)]
        with patch("deployment.requests.Session") as factory:
            factory.return_value.__enter__.return_value = session
            self.assertFalse(board.tunnel_auth_matches())

    def test_protected_tunnel_survives_unavailable_upstream_and_rejects_wrong_password(self):
        board = self.board()
        for status, expected in ((200, True), (502, True), (503, True), (401, False)):
            with self.subTest(status=status):
                session = Mock(headers={})
                session.get.side_effect = [
                    Mock(status_code=401, headers={"WWW-Authenticate": 'Basic realm="ngrok"'}),
                    Mock(status_code=status)]
                with patch("deployment.requests.Session") as factory:
                    factory.return_value.__enter__.return_value = session
                    self.assertEqual(board.tunnel_auth_matches(), expected)

    def test_reconcile_restores_auth_after_agent_restart(self):
        board = self.board()
        with tempfile.TemporaryDirectory() as directory:
            board.target = Path(directory) / "board-target.json"
            container = Mock(status="running", labels={"commit": "fixture-commit"})
            container.exec_run.return_value = Mock(exit_code=0, output=b"fixture-commit\n")
            board.container = Mock(return_value=container)
            board.tunnel_auth_matches = Mock(return_value=False)
            board.reconcile()
            board.ngrok.post.assert_called_once()
            board.tunnel_auth_matches.return_value = True
            board.reconcile()
            board.ngrok.post.assert_called_once()


if __name__ == "__main__":
    unittest.main()
