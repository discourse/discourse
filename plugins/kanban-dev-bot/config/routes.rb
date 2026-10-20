# frozen_string_literal: true

Discourse::Application.routes.append do
  get "/codex-board-bot/snapshot" => "kanban_dev_bot/bot#snapshot"
  post "/codex-board-bot/setup" => "kanban_dev_bot/bot#setup"
  post "/codex-board-bot/transition" => "kanban_dev_bot/bot#transition"
  post "/codex-board-bot/review-artifacts" => "kanban_dev_bot/bot#review_artifacts"
  post "/codex-board-bot/review-handoff" => "kanban_dev_bot/bot#review_handoff"
  get "/codex-board-bot/uploads/:id" => "kanban_dev_bot/bot#upload"
end
