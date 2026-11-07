import http.server
import json
import os
import threading
import unittest
from unittest.mock import patch

from rspec_llm import select


class LlmSelectionTest(unittest.TestCase):
    def setUp(self):
        self.context = {"head_sha": "a" * 40, "base_sha": "b" * 40, "inventory": ["spec/lib/url_helper_spec.rb"], "files": [{"path": "lib/url_helper.rb", "patch": "@@ normalized_encode @@"}]}

    def request(self, decision):
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(server):
                payload = json.loads(server.rfile.read(int(server.headers["Content-Length"])))
                if "normalized_encode" not in payload["messages"][0]["content"]:
                    server.send_error(400)
                    return
                response = {"choices": [{"message": {"content": json.dumps(decision)}}], "usage": {"prompt_tokens": 200, "completion_tokens": 20}}
                server.send_response(200)
                server.end_headers()
                server.wfile.write(json.dumps(response).encode())

            def log_message(*args):
                pass

        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            worker = threading.Thread(target=server.serve_forever)
            worker.start()
            try:
                with patch.dict(os.environ, {"RSPEC_LLM_URL": f"http://127.0.0.1:{server.server_port}/chat/completions", "RSPEC_LLM_MODEL": "test"}):
                    return select(self.context)
            finally:
                server.shutdown()
                worker.join()

    def test_accepts_existing_paths_and_preserves_usage(self):
        result = self.request({"uncertain": False, "specs": self.context["inventory"]})
        self.assertEqual(result["specs"], self.context["inventory"])
        self.assertEqual(result["usage"]["prompt_tokens"], 200)
        self.assertEqual(result["head_sha"], self.context["head_sha"])

    def test_uncertainty_and_invented_paths_require_full_selection(self):
        for decision in [{"uncertain": True, "specs": []}, {"uncertain": False, "specs": ["../../run"]}]:
            self.assertEqual(self.request(decision)["mode"], "full")

    def test_missing_configuration_requires_full_selection(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(select(self.context)["mode"], "full")

    def test_incomplete_diff_requires_full_selection(self):
        self.context["incomplete"] = True
        self.assertEqual(self.request({"uncertain": False, "specs": []})["mode"], "full")


if __name__ == "__main__":
    unittest.main()
