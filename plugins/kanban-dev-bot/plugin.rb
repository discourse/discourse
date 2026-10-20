# frozen_string_literal: true

# name: kanban-dev-bot
# about: Local development board automation
# version: 0.2.0
# authors: Joffrey Jaffeux
# url: https://github.com/discourse/discourse-plugin-skeleton
# required_version: 2.7.0

enabled_site_setting :kanban_dev_bot_enabled

module ::KanbanDevBot
  PLUGIN_NAME = "kanban-dev-bot"
  BOARD_ID = ENV.fetch("CODEX_BOARD_ID", "1").to_i
  STORE = "codex-board-bot"
  NOTE_SEPARATOR = "\n\n---\nCodex bot\n"
  NOTE_PATTERN = /\n{2,}(?:---|\*\s*\*\s*\*|___)\s*\n+Codex bot(?:\s*\n|$)/
end

require_relative "lib/kanban_dev_bot/engine"

after_initialize do
  require_relative "lib/kanban_dev_bot/topic_cards"
  Boards::CreateCard.prepend(KanbanDevBot::TopicCards)
  require_relative "lib/kanban_dev_bot/requeue_review_card"
  on(:post_created) { |post, options| KanbanDevBot::RequeueReviewCard.call(post, options) }
  require_relative "lib/kanban_dev_bot/deleted_topic_cards"
  Boards::DestroyCard.prepend(KanbanDevBot::DeletedTopicCards)
end
