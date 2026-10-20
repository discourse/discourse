# frozen_string_literal: true

Discourse::Application.routes.append do
  get "/codex-board-bot/snapshot" => "codex_board_bot/bot#snapshot"
  post "/codex-board-bot/setup" => "codex_board_bot/bot#setup"
  post "/codex-board-bot/transition" => "codex_board_bot/bot#transition"
  post "/codex-board-bot/review-artifacts" => "codex_board_bot/bot#review_artifacts"
  post "/codex-board-bot/review-handoff" => "codex_board_bot/bot#review_handoff"
  get "/codex-board-bot/uploads/:id" => "codex_board_bot/bot#upload"
end
