Use the Capybara board

Open https://joffrey.ngrok.dev/boards/capybara/1.
New cards are Discourse topics in the Capybara category. Open their topics to add replies or images.
Put draft requests in BACKLOG. The bot ignores that column.
Move a card to TODO to queue it. The bot reads the initial topic post, the latest 99 human replies, and their images.
It claims the card, moves it to IN PROGRESS, and starts a Codex session in Docker through OrbStack.
Each TODO attempt starts with a fresh checkout of the committed capybara branch in /Users/joffreyjaffeux/Code/discourse.
Uncommitted host edits are never copied. A previous unaccepted preview is retained for recovery but is not the next attempt's starting point.

Successful runs move to REVIEW and post a summary, commit, checks, and both preview links in the topic:
https://<card-preview>/session/admin-account/become
https://<card-preview>/session/user-account/become

Edit the topic or add replies, then move REVIEW back to TODO to request another attempt from current capybara.
Move REVIEW to DONE to accept the change. The bot removes that preview container and its ngrok tunnel.
It applies only the accepted task's changes to capybara as one commit, fetches official discourse/discourse main,
and rebases local commits onto that upstream SHA. Codex resolves conflicts inside an isolated Docker checkout.
Local integration requires a clean capybara checkout and preserves backup refs.
The Docker board then installs Bundler and pnpm dependencies, migrates its persistent database, starts the frontend and Rails,
and verifies public access and administrator login. A separate trusted publisher then updates only
discourse/capybara-bot:capybara for https://github.com/discourse/discourse/pull/44782 before reporting success.
Accepted DONE integration finishes before another TODO is claimed, including when the accepted card is reopened meanwhile.
Deployment and publication failures retry their saved phase with a delay. A pre-publication integration failure is reported on DONE and blocks new work until retried.
After fixing the reported issue, move that card to TODO. Your local edits are preserved rather than stashed or discarded.
Historical DONE cards from before integration was enabled are not merged retrospectively.

Operate the bot

Run ./manage.sh status to inspect the controller, or read http://localhost:8099/health.
Run ./manage.sh logs to follow logs. Run ./manage.sh stop to pause polling while review previews stay running.
Run ./manage.sh up to restart and reconcile. Run ./manage.sh build after changing worker helpers or dependencies.
Recreate the controller with Docker Compose up -d --build after changing its code.
The Mac, OrbStack, and native ngrok agent must remain running.
The control board is the capybara-board Docker container on localhost:3410. Its main tunnel is named command_line.
PostgreSQL, Redis, uploads, and the Linux board workspace use named capybara-board-* volumes.
The native development database and work/board-bootstrap/board.dump were retained during cutover.
The controller stores run records, desired deployment and refreshed authentication in kanban-bot_controller-state.

Coding credentials are copied only for coding, then removed before previews start.
Run ./manage.sh refresh-auth after replacing or revoking your Codex login.
Coding workers have a read-only seed, their own source and session volumes, and no Docker socket.
The trusted controller and publisher own Docker and Git integration. Conflict agents cannot write the host source mount.
Preview impersonation links allow anyone with the URL to use those development accounts.
Image downloads require bot access to the board and topic. PNG, JPEG, GIF and WebP are supported.
The input limits are 50 images, 20 MB per image and 50 MB combined. GIF inputs use their first frame.

Recover and verify

Run ./manage.sh export CARD_ID /absolute/path/card-source.tar.gz to recover the latest attempt's source and Git history.
Workspace volumes include the card and run IDs. Session volumes are retained per card.
Run logs include run.log, codex.jsonl, result.json, base.txt and commit.txt in the workspace volume.
Use Docker to run test_controller.py, test_integration.py and test_images.py.
The capybara plugin's Rails specs cover topic cards, discussion, uploads, permissions and integration status messages.
The plugin is tracked at plugins/capybara. Its bot/ directory contains the versioned bot package.
The installed runtime copy is /Users/joffreyjaffeux/Documents/Codex/2026-10-19/ok/outputs/kanban-bot.

Restricted GitHub publishing

publisher-target.json pins the fork repository ID, capybara branch, upstream main and PR 44782.
The publisher checks that the PR is open and still uses that exact head and base before pushing.
Its explicit refspec updates only refs/heads/capybara. A force-with-lease checks the last recorded remote SHA,
so rebased commits can replace the branch while unexpected manual changes stop publication.
The durable /data/fork-publication.json journal records the expected head and pending commit for crash recovery.
Do not reset that journal to bypass a remote mismatch. Inspect the unexpected change first.

The fine-grained token grants Contents read/write and Metadata read only on discourse/capybara-bot.
It expires on 17 January 2027. GitHub scopes it to the repository; the trusted publisher enforces the branch and PR restriction.
The host secret is /Users/joffreyjaffeux/Documents/Codex/capybara-secrets/github-fork-token, outside the coding mounts.
The controller mounts it read-only and copies it with root-only permissions into a separate disposable publisher container.
That container has a read-only source seed and no Docker socket or Codex credential. Coding workers never receive this token.
The token and publisher container are removed after each attempt. Host Docker administrators remain trusted.
To rotate it, replace the host secret with a token having the same repository permissions and recreate the controller.
Publication stops if the token expires, the PR closes, its target changes, or the remote branch changes unexpectedly.
Historical runs created before publishing was enabled keep their completed state and are not pushed retrospectively.
