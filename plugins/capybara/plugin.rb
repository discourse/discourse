# frozen_string_literal: true

# name: capybara
# about: Topic-backed development cards and the local Docker coding bot
# version: 0.2.0
# authors: Joffrey Jaffeux
# url: https://github.com/discourse/discourse-plugin-skeleton
# required_version: 2.7.0

enabled_site_setting :capybara_enabled

module ::DiscourseCapybara
  PLUGIN_NAME = "capybara"
end

require_relative "lib/discourse_capybara/engine"

module ::CodexBoardBot
  BOARD_ID = ENV.fetch("CODEX_BOARD_ID", "1").to_i
  STORE = "codex-board-bot"
  NOTE_SEPARATOR = "\n\n---\nCodex bot\n"
  NOTE_PATTERN = /\n{2,}(?:---|\*\s*\*\s*\*|___)\s*\n+Codex bot(?:\s*\n|$)/
end

after_initialize do
  require_relative "lib/discourse_capybara/topic_cards"
  Boards::CreateCard.prepend(DiscourseCapybara::TopicCards)
end
