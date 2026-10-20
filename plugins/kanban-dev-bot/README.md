# Kanban development bot

This plugin turns development board cards into Discourse topics and runs the local coding workflow. It requires the Boards plugin and runs only outside production.

Enable `kanban_dev_bot_enabled` to activate the bot API and card hooks. The Capybara product's `capybara_enabled` setting is independent. `CODEX_BOARD_ID` selects the board, defaulting to `1`.

New cards become topics in a category permitted by the board filter and author permissions. Human replies on REVIEW topics queue another TODO attempt. Bot replies and replies in other columns leave cards unchanged. Deleting a topic card closes its topic.

The API stays under `/codex-board-bot`, with existing run records in the `codex-board-bot` PluginStore namespace. Existing `capybara_bot_run` and `capybara_review_digest` post fields remain compatible. Only administrators and the `codex-bot` account with board access can use the API. Image downloads require access to the board and referenced topic.

The [bot operating guide](bot/README.txt) covers Docker workers, credentials, publication, recovery, and review attachments. The [workflow verification guide](doc/workflow-verification.md) describes the card lifecycle.

Capybara product changes belong in `plugins/capybara`. Automation and its operational documentation belong in `plugins/kanban-dev-bot`.
