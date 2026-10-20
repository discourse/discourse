# Capybara

Capybara makes new cards on the development board into Discourse topics. Open a card topic to add replies or upload images. The coding bot reads the latest human discussion and the images attached to those posts when it claims a TODO card. A human reply to a REVIEW card topic automatically returns it to TODO for another attempt. Bot replies do not queue work, and replies leave other columns unchanged. BACKLOG cards stay idle.

This plugin is based on [the official Discourse plugin skeleton](https://github.com/discourse/discourse-plugin-skeleton) at commit `9c79225314c80e3a5328730c51ff00fa5c7984c8`. The engine, plugin metadata, lint configuration, dependency manifests, and CI template come from that template. `DiscourseCapybara` avoids a namespace collision with the Capybara test library.

The development-only bot routes remain under `/codex-board-bot`, and existing run markers remain in the `codex-board-bot` PluginStore namespace. Only admins and the `codex-bot` account with board access can use them. Upload downloads are limited to image files referenced by visible topic posts on the configured board.

`CODEX_BOARD_ID` selects the board, defaulting to `1`. `capybara_enabled` defaults to enabled. Topic creation uses a category from the board's category filter that the author can create topics in. Configure a dedicated category with the intended reader permissions before adding cards. Category permissions govern topic visibility independently of board permissions. Unconstrained boards use the uncategorized category.

The plugin does not enable its bot routes or card conversion in production. Install the bot controller and Docker worker from the accompanying bot package.

ARCHIVED follows DONE. Accept a REVIEW card by moving it to DONE. After merging into capybara, deployment, and confirmed publication to the configured PR branch, the bot moves the card to ARCHIVED. Pending confirmation and failed publication stay in DONE. Reopened or superseded cards are not moved. Historical cleanup-only runs are not treated as published. Admin setup creates or repairs the ARCHIVED column order without duplicating it.

## Review deliverables

Every completed run posts its test results and a downloadable diff in the card topic.
Changed Markdown documents appear in the reply, with their originals attached alongside generated documents and assets.
Attachments use persistent Discourse uploads, so preview cleanup does not remove them.
The reply lists files excluded by safety or size limits.
