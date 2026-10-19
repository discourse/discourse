import http.cookiejar
import json
import os
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from auth import load_board_credentials

BASE = os.environ.get('BOARD_URL', 'https://joffrey.ngrok.dev')

class Client:
    def __init__(self, username):
        handlers = [urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())]
        credentials = load_board_credentials()
        if credentials:
            passwords = urllib.request.HTTPPasswordMgrWithDefaultRealm()
            passwords.add_password(None, BASE, credentials.username, credentials.password)
            handlers.append(urllib.request.HTTPBasicAuthHandler(passwords))
        self.opener = urllib.request.build_opener(*handlers)
        self.opener.open(BASE + '/session/' + username + '/become').close()
        self.headers = {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest', 'ngrok-skip-browser-warning': '1'}
        self.headers['X-CSRF-Token'] = self.request('/session/csrf.json')[1]['csrf']

    def request(self, path, data=None, method=None):
        request = urllib.request.Request(BASE + path, data=json.dumps(data).encode() if data is not None else None, method=method, headers=self.headers | {'Content-Type': 'application/json'})
        try:
            with self.opener.open(request) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.loads(error.read())


def main():
    admin = Client('joffreyjaffeux')
    status, snapshot = admin.request('/codex-board-bot/snapshot')
    assert status == 200
    columns = snapshot['columns']
    status, result = admin.request('/boards/api/boards/1/cards', {'card': {'title': 'Capybara topic bridge verification', 'notes': 'Initial topic request', 'column_id': columns['BACKLOG']}})
    assert status == 201, (status, result)
    card_id = result['card']['id']
    card = next(card for card in admin.request('/codex-board-bot/snapshot')[1]['cards'] if card['id'] == card_id)
    assert card['topic_id'] and card['discussion'][0]['raw'] == 'Initial topic request', card
    status, result = admin.request('/posts.json', {'topic_id': card['topic_id'], 'raw': 'Latest human reply before the claim.'})
    assert status == 200, (status, result)
    status, result = admin.request(f'/boards/api/boards/1/cards/{card_id}', {'card': {'column_id': columns['TODO']}}, 'PUT')
    assert status == 200
    card = next(card for card in admin.request('/codex-board-bot/snapshot')[1]['cards'] if card['id'] == card_id)
    bot = Client('codex-bot')
    run_id = str(uuid.uuid4())
    claim = {'command': 'claim', 'card_id': card_id, 'expected_version': card['version'], 'run_id': run_id}
    status, owned = bot.request('/codex-board-bot/transition', claim)
    assert status == 200 and owned['column'] == 'IN PROGRESS', (status, owned)
    assert owned['discussion'][-1]['raw'] == 'Latest human reply before the claim.', owned
    status, duplicate = bot.request('/codex-board-bot/transition', claim)
    assert status == 200 and duplicate['version'] == owned['version']
    wrong_owner = {'command': 'review', 'card_id': card_id, 'expected_version': owned['version'], 'expected_run_id': 'another-run', 'run_id': run_id}
    assert bot.request('/codex-board-bot/transition', wrong_owner)[0] == 409
    assert admin.request(f'/boards/api/boards/1/cards/{card_id}', {'card': {'column_id': columns['DONE']}}, 'PUT')[0] == 200
    assert bot.request('/codex-board-bot/transition', wrong_owner | {'expected_run_id': run_id})[0] == 409
    done = next(card for card in bot.request('/codex-board-bot/snapshot')[1]['cards'] if card['id'] == card_id)
    ack = {'command': 'done', 'card_id': card_id, 'expected_version': done['version'], 'expected_run_id': run_id, 'run_id': run_id, 'message': 'Topic bridge verification passed. No coding run or preview was created.'}
    assert bot.request('/codex-board-bot/transition', ack)[0] == 200
    assert bot.request('/codex-board-bot/transition', ack)[0] == 200
    final = next(card for card in bot.request('/codex-board-bot/snapshot')[1]['cards'] if card['id'] == card_id)
    assert len(final['discussion']) == 2, final
    evidence = {'passed': True, 'card_id': card_id, 'topic_id': final['topic_id'], 'checks': ['BACKLOG topic card', 'latest human reply at claim', 'idempotent claim', 'wrong generation rejected', 'stale worker rejected', 'idempotent DONE status excluded from human discussion']}
    Path('/task/outputs/capybara-bridge-test.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps(evidence))

if __name__ == '__main__':
    main()
