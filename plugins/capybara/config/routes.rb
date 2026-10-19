# frozen_string_literal: true

Discourse::Application.routes.append do
  get "/codex-board-bot/snapshot" => "codex_board_bot/bot#snapshot"
  post "/codex-board-bot/setup" => "codex_board_bot/bot#setup"
  post "/codex-board-bot/transition" => "codex_board_bot/bot#transition"
  get "/codex-board-bot/uploads/:id" => "codex_board_bot/bot#upload"
end
