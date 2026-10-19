import argparse
import json
import time
import urllib.request
import uuid
from pathlib import Path

from test_bridge import Client

parser = argparse.ArgumentParser()
parser.add_argument("action", choices=["create", "queue", "done", "wait"])
parser.add_argument("--card", type=int)
parser.add_argument("--image", type=Path)
options = parser.parse_args()
client = Client("joffreyjaffeux")
columns = client.request("/codex-board-bot/snapshot")[1]["columns"]
if options.action == "create":
    brief = "Create plugins/capybara/doc/workflow-verification.md. Document BACKLOG as idle, TODO as a fresh capybara checkout, topic replies and images as task context, REVIEW with exactly the two preview impersonation links NGROKURL/session/admin-account/become and NGROKURL/session/user-account/become, and DONE as squash integration plus official upstream rebase and Docker board restart. If an image is attached in a reply, include its exact text in a short verification paragraph. Make no application behavior changes. Verify the document contents with a focused shell check."
    status, result = client.request("/boards/api/boards/1/cards", {"card": {"title": "Verify Capybara topic and Docker workflow", "column_id": columns["BACKLOG"], "notes": brief}})
    assert status == 201, (status, result)
    card_id = result["card"]["id"]
    card = next(x for x in client.request("/codex-board-bot/snapshot")[1]["cards"] if x["id"] == card_id)
    assert card["topic_id"], card
    if options.image:
        boundary = uuid.uuid4().hex
        parts = [f"--{boundary}\r\nContent-Disposition: form-data; name=\"type\"\r\n\r\ncomposer\r\n".encode(), f"--{boundary}\r\nContent-Disposition: form-data; name=\"files[]\"; filename=\"verification.png\"\r\nContent-Type: image/png\r\n\r\n".encode(), options.image.read_bytes(), f"\r\n--{boundary}--\r\n".encode()]
        headers = client.headers | {"Content-Type": f"multipart/form-data; boundary={boundary}"}
        request = urllib.request.Request("https://joffrey.ngrok.dev/uploads.json", data=b"".join(parts), headers=headers)
        with client.opener.open(request) as response:
            upload = json.load(response)
        status, reply = client.request("/posts.json", {"topic_id": card["topic_id"], "raw": f"Use this attached image as context and transcribe its exact label in the verification paragraph. ![verification image]({upload['short_url']})"})
        assert status == 200, (status, reply)
    Path("/task/work/capybara-smoke-card.json").write_text(json.dumps({"card_id": card_id, "topic_id": card["topic_id"]}))
    print(json.dumps({"card_id": card_id, "topic_id": card["topic_id"], "column": "BACKLOG"}), flush=True)
    raise SystemExit(0)
if options.action in ("queue", "done"):
    target = "TODO" if options.action == "queue" else "DONE"
    status, result = client.request(f"/boards/api/boards/1/cards/{options.card}", {"card": {"column_id": columns[target]}}, "PUT")
    assert status == 200, (status, result)
    print("Moved", options.card, "to", target, flush=True)
last = None
for attempt in range(360):
    try:
        status, snapshot = client.request("/codex-board-bot/snapshot")
        if status != 200:
            time.sleep(5)
            continue
        card = next(x for x in snapshot["cards"] if x["id"] == options.card)
        state = (card["column"], card["run"].get("run_id"), card["run"].get("status"))
        if state != last:
            print("Observed", state, flush=True)
            last = state
        if card["run"].get("status") in ("failed", "integration_failed"):
            raise RuntimeError("Verification card failed; inspect controller health and topic")
        if (options.action == "done" and card["run"].get("status") == "done") or (options.action != "done" and card["column"] == "REVIEW"):
            Path("/task/work/capybara-smoke-" + ("done" if options.action == "done" else "review") + ".json").write_text(json.dumps(card, indent=2))
            print("Verified", state, flush=True)
            break
    except (urllib.error.URLError, json.JSONDecodeError):
        pass
    time.sleep(5)
else:
    raise TimeoutError("Verification did not finish within 30 minutes")
