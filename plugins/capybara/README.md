# Capybara

Capybara makes new cards on the development board into Discourse topics. Open a card topic to add replies or upload images. The coding bot reads the latest human discussion and the images attached to those posts when it claims a TODO card. BACKLOG cards stay idle.

This plugin is based on [the official Discourse plugin skeleton](https://github.com/discourse/discourse-plugin-skeleton) at commit `9c79225314c80e3a5328730c51ff00fa5c7984c8`. The engine, plugin metadata, lint configuration, dependency manifests, and CI template come from that template. `DiscourseCapybara` avoids a namespace collision with the Capybara test library.

The development-only bot routes remain under `/codex-board-bot`, and existing run markers remain in the `codex-board-bot` PluginStore namespace. Only admins and the `codex-bot` account with board access can use them. Upload downloads are limited to image files referenced by visible topic posts on the configured board.

`CODEX_BOARD_ID` selects the board, defaulting to `1`. `capybara_enabled` defaults to enabled. Topic creation uses a category from the board's category filter that the author can create topics in. Configure a dedicated category with the intended reader permissions before adding cards. Category permissions govern topic visibility independently of board permissions. Unconstrained boards use the uncategorized category.

The plugin does not enable its bot routes or card conversion in production. Install the bot controller and Docker worker from the accompanying bot package.
