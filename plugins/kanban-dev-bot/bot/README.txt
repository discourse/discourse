Use the Capybara board

Open https://joffrey.ngrok.dev/boards/capybara/1.
New cards are Discourse topics in the Capybara category. Open their topics to add replies or images.
Put draft requests in BACKLOG. The bot ignores that column.
Deleting a Capybara card closes its topic and cancels active coding or review previews.
The bot removes the preview container and tunnel on its next poll, retrying failed cleanup.
Accepted DONE integration already underway finishes its merge, deployment and publication even if the card is deleted.
Move a card to TODO to queue it. The bot reads the initial topic post, the latest 99 human replies, and their images.
It claims the card, moves it to IN PROGRESS, and starts a Codex session in Docker through OrbStack.
Card coding and conflict resolution both explicitly use gpt-6.1-sol with medium reasoning effort.
Each TODO attempt starts with a fresh checkout of the committed capybara branch in /Users/joffreyjaffeux/Code/discourse.
Uncommitted host edits are never copied. Failed work remains available for recovery until it is superseded, deleted, or moved to DONE. A new attempt does not use the previous preview as its starting point.

Review previews build frontend and plugin JavaScript assets once before starting Rails.
Frontend, plugin JavaScript and CSS watchers stay disabled for those fixed previews.
Build failures stop preview startup. The main board keeps its existing development startup.

Successful runs move to REVIEW and post a summary, commit, checks, and both preview links in the topic:
https://<card-preview>/session/admin-account/become
https://<card-preview>/session/user-account/become

Reply to a REVIEW card topic to automatically queue another attempt from current capybara. Bot replies and replies to cards in other columns leave the card unchanged. Editing an existing post does not queue work; move the card to TODO after an edit if needed.
Move REVIEW to DONE to accept the change. The bot removes that preview container and its ngrok tunnel.
It applies only the accepted task's changes to capybara as one commit, fetches official discourse/discourse main,
and rebases local commits onto that upstream SHA. Codex resolves conflicts inside an isolated Docker checkout.
Local integration requires a clean capybara checkout and preserves backup refs.
The Docker board then installs Bundler and pnpm dependencies, migrates its persistent database, starts the frontend and Rails,
and verifies public access and administrator login. A separate trusted publisher then updates only
discourse/capybara-bot:capybara for https://github.com/discourse/discourse/pull/44782 before reporting success.
Accepted DONE integration finishes before another TODO is claimed, including when the accepted card is reopened meanwhile.
Deployment and publication failures retry their saved phase with a delay.
After Git accepts a push, the bot reports that it is waiting for GitHub confirmation.
Confirmation retries only read the exact fork ref and PR metadata. They never fetch or push again, including after restart.
A stale PR SHA does not report a failed push. A changed branch, closed PR or API error remains visible in confirmation diagnostics. A pre-publication integration failure is reported on DONE and blocks new work until retried.
After fixing the reported issue, move that card to TODO. Your local edits are preserved rather than stashed or discarded.
Historical DONE cards from before integration was enabled are not merged retrospectively.

Operate the bot

Run ./manage.sh status to inspect the controller, or read http://localhost:8099/health.
Run ./manage.sh logs to follow logs. Run ./manage.sh stop to pause polling while review previews stay running.
Run ./manage.sh up to restart and reconcile. Run ./manage.sh build after changing worker helpers or dependencies.
Worker image builds use bot/.build/worker-image inside this plugin. Docker Compose keeps the kanban-bot project name and its existing controller-state volume.
After changing controller code, run ./manage.sh build followed by ./manage.sh up to recreate it.
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

Run ./manage.sh export CARD_ID /absolute/path/card-source.tar.gz to recover the latest retained attempt's source and Git history.
Workspace volumes include the card and run IDs. Session volumes are shared per card while recoverable attempts need them.
Completed, deleted, and superseded workspaces are reclaimed and cannot be exported.
Run logs include run.log, codex.jsonl, result.json, base.txt and commit.txt in the workspace volume.
Use Docker to run test_controller.py, test_integration.py and test_images.py.
The kanban-dev-bot plugin's Rails specs cover topic cards, discussion, uploads, permissions and integration status messages.
The bot plugin is tracked at plugins/kanban-dev-bot. Its bot/ directory contains the versioned bot package.
Every board card targets the Capybara product in plugins/capybara, including documentation requests.
Product guides live under plugins/capybara/doc/ and link from the product README. Unknown product requirements stay open questions.
Trusted prompts exclude the bot's operating workflow from product guides. Before REVIEW, the collector rejects changes to plugins/kanban-dev-bot and newly added explicit tooling identifiers in product Markdown.
Existing unchanged references and legitimate core Discourse changes are allowed. This guard catches known scope violations; the reviewer still checks the guide's subject.
Maintain automation and its documentation separately in plugins/kanban-dev-bot, outside this board's coding jobs.
The installed runtime copy is /Users/joffreyjaffeux/Documents/Codex/2026-10-19/ok/outputs/kanban-bot.

Restricted GitHub publishing

publisher-target.json pins the fork repository ID, capybara branch, upstream main and PR 44782.
The publisher checks that the PR is open and still uses that exact head and base before pushing.
Its explicit refspec updates only refs/heads/capybara. A force-with-lease checks the last recorded remote SHA,
so rebased commits can replace the branch while unexpected manual changes stop publication.
The durable /data/fork-publication.json journal records the expected head, pending commit and accepted push for crash recovery.
Each attempt appends sanitized diagnostics to /data/publication/<run_id>.jsonl in the controller-state volume.
The logs survive disposable publisher removal and controller replacement. They include timestamps, attempt number,
operation, expected and observed SHA, HTTP status, GitHub request ID, Retry-After and rate-limit information when available.
Fatal helper output and Git stderr are bounded and credentials are redacted before storage.
The /health response exposes confirmation_diagnostic and publication_log per run.
Read an attempt log with Docker Compose exec controller cat /data/publication/<run_id>.jsonl.
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

Main board HTTP authentication

The main joffrey.ngrok.dev endpoint requires HTTP Basic authentication at the ngrok edge.
Credentials are kept outside Git and coding mounts in /Users/joffreyjaffeux/Documents/Codex/capybara-secrets/board-http-auth.json.
The controller mounts that file read-only at BOARD_HTTP_AUTH_FILE. Missing or invalid configured credentials stop startup.
Polling, image uploads and deployment checks authenticate only to the configured main origin.
Reconciliation restores authentication after tunnel replacement or an ngrok agent restart.
To rotate credentials, replace that JSON file and recreate the controller. Preview domains keep their existing login flow.

Run volume retention
--------------------
Each successful board poll reconciles recorded workspace, integration, and session volumes. Running and REVIEW attempts, every integration/deployment/publication/confirmation phase, and unfinished background jobs retain their volumes. The current failed attempt retains its workspace for diagnosis and export until it is superseded, deleted, or moved to DONE. An integration failure retains its accepted work even in DONE until it is superseded or deleted. Shared sessions and legacy workspaces remain while any recoverable attempt references them.

Completed, deleted, cancelled, and superseded attempts release their volumes once container cleanup and background jobs finish. Completed/deleted/superseded workspaces can no longer be exported after reclamation. Publication diagnostics and run metadata remain in controller state. Ownership labels must match this board and card; unknown volumes and volumes attached to any running or stopped container are untouched. Docker conflicts and temporary API errors are logged and retried on later polls. No global volume prune is used. The main board database, Redis, uploads, workspace, and controller state are retained. A failed board snapshot cannot authorize volume deletion.

Main board login persistence

The main Redis volume mounts at /shared/redis_data, matching the worker image's Redis data directory. Before Rails starts, board-secret.py atomically persists its 128-hex application secret in /workspace/board-secret-key-base with mode 0600, and board.sh exports it as DISCOURSE_SECRET_KEY_BASE. The existing valid Redis SECRET_TOKEN is adopted on first initialization. Later restarts reuse the saved key even if Redis loses cached data, so application cookie encryption and auth-token digests stay stable. An invalid saved file stops startup rather than rotating the key.

When upgrading an existing board without this file, preserve its current Redis SECRET_TOKEN in that path before replacing the container. The previous Redis mount did not cover its actual data directory, so replacing first would discard the key and invalidate existing logins once more. Keep this file private and preserve the main workspace volume.

ARCHIVED follows DONE. Accept a REVIEW card by moving it to DONE. After merging into capybara, deployment, and confirmed publication to the configured PR branch, the bot moves the card to ARCHIVED. Pending confirmation and failed publication stay in DONE. Reopened or superseded cards are not moved. Historical cleanup-only runs are not treated as published. Admin setup creates or repairs the ARCHIVED column order without duplicating it.

Review deliverables
-------------------
A successful worker result includes an immutable base/head review bundle. The controller persists the bundle before uploading files or moving the card to REVIEW. Upload or reply failures retry from that saved result after a restart without another coding run.

Review replies contain explicit test results, a persistent review.diff attachment, generated files, and up to 6,500 characters of rendered Markdown. Long documents retain their complete attached originals. Relative links to other attached files point to those uploads. A zero-change run still attaches a diff with an explicit no-change message.

The collector reads Git blobs, never arbitrary worker filesystem paths. Attachments allow md, txt, rst, csv, pdf, docx, pptx, xlsx, zip, png, jpg, jpeg, gif, webp, diff, and patch. Limits are 24 files, 2 MiB per file, and 8 MiB per bundle. Secret-like paths/content, symlinks, submodules, and oversized blobs are omitted from attachments and diff with a visible notice. Unsupported attachment types remain in the diff. A diff exceeding 2 MiB fails collection explicitly.

To retrofit a current REVIEW handoff, load its saved Run and current card version. Use Runtime.collect_review_artifacts(run, base=base_sha, head=head_sha), then Controller.backfill_review(run, bundle). The controller revises the same bot post marked with capybara_bot_run, or creates one supplemental bot post if none exists. Repeating the operation with the same content creates no extra post or revision. A moved card or superseded run is rejected.

Preview memory validation (2026-10-20)

Five alternating watched/static restarts of the same preview used the normal public PREVIEW_HOST,
two Rails workers and a 6 GiB container limit. Each trial warmed both accounts and served
76 application JavaScript files and 27 stylesheets successfully, then sampled idle memory five times.
Watched median: 5.34 GiB, trial range 5.31 to 5.45 GiB.
Static median: 1.27 GiB, trial range 1.11 to 1.30 GiB.
The measured median reduction was 4.07 GiB (76.2%).
The metric is Docker cgroup usage minus inactive file cache after five seconds idle.
These are fresh-start preview measurements, not total OrbStack memory or long-term settled usage.
Compilation still needs temporary build memory. The main board was unchanged.

Automatic build image cleanup

manage.sh build serializes managed builds, snapshots existing worker/controller image IDs,
and cleans those IDs only after both builds succeed. Cleanup keeps both current :local images
for future cards, all running and stopped container images, and any image with a reference
outside discourse-codex-worker or discourse-board-controller. Docker removal is non-forced;
conflicts and inventory failures warn without failing a successful build. A failed snapshot
skips cleanup, including on a first build without an existing controller image.
Unknown dangling images, dependencies, base images, build cache, and volumes are untouched.
Manual image retagging outside this build lock must not run concurrently with cleanup.

Card lifecycle safeguards

Create cards in BACKLOG or TODO. The bot owns IN PROGRESS, REVIEW, and ARCHIVED.
While work is active, use Cancel to return to BACKLOG or Restart to queue the latest
discussion in TODO. The card stays in Stopping until the worker exits and final resource
cleanup succeeds. Deleting an unaccepted card closes its topic and records durable cleanup.
Bulk deletion checks the entire selection before changing any card.

Moving a completed REVIEW card to DONE atomically accepts its exact commit. Moves and
deletion then remain locked through integration, deployment, push, and confirmation.
A failed integration offers Retry for the same accepted run. Missing or inconsistent
controller recovery records show Needs attention and require restoring the controller
state; they never start replacement coding or release recovery volumes. Replies remain
available during acceptance. The bot archives the card only after publication is confirmed.

The managed board and its workflow columns cannot be deleted, archived, or structurally
reconfigured while the bot is enabled. The server enforces these rules for API requests,
bulk operations, topic deletion, and automatic topic synchronization as well as the UI.

PostgreSQL stores action and acceptance intent. Controller SQLite, integration refs, and
publisher receipts preserve execution progress. After restart, the controller reconciles
pending intent, retries cleanup and confirmation, and reclaims late resources from retired
runs. Keep the controller-state volume and recovery workspaces when repairing a failed run.
