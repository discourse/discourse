# frozen_string_literal: true

# name: kanban-dev-bot
# about: Local development board automation
# version: 0.2.0
# authors: Joffrey Jaffeux
# url: https://github.com/discourse/discourse-plugin-skeleton
# required_version: 2.7.0

enabled_site_setting :kanban_dev_bot_enabled

register_asset "stylesheets/kanban-dev-bot.scss"

module ::KanbanDevBot
  PLUGIN_NAME = "kanban-dev-bot"
  BOARD_ID = ENV.fetch("CODEX_BOARD_ID", "1").to_i
  STORE = "codex-board-bot"
  NOTE_SEPARATOR = "\n\n---\nCodex bot\n"
  NOTE_PATTERN = /\n{2,}(?:---|\*\s*\*\s*\*|___)\s*\n+Codex bot(?:\s*\n|$)/
end

require_relative "lib/kanban_dev_bot/engine"

after_initialize do
  require_relative "lib/kanban_dev_bot/lifecycle"
  require_relative "lib/kanban_dev_bot/lifecycle_guards"
  %w[
    CreateCard
    UpdateCard
    DestroyCard
    ClearColumn
    DestroyColumn
    DestroyBoard
    UpdateBoard
    UpdateColumn
    MoveColumn
    CreateColumn
    MoveTopicToColumn
    Archive
    Unarchive
  ].each { |name| "Boards::#{name}".constantize.prepend(KanbanDevBot::LifecycleService) }
  Boards::ClearColumn.prepend(KanbanDevBot::LifecycleClearColumn)
  Boards::UpdateBoard.prepend(KanbanDevBot::LifecycleUpdateBoard)
  Boards::ColumnMutator.singleton_class.prepend(KanbanDevBot::LifecycleColumnMutator)
  Boards::ColumnsReplacer.singleton_class.prepend(KanbanDevBot::LifecycleColumnsReplacer)
  PostDestroyer.prepend(KanbanDevBot::LifecyclePostDestroyer)
  Topic.prepend(KanbanDevBot::LifecycleTopic)
  Boards::TopicSync.singleton_class.prepend(KanbanDevBot::LifecycleTopicSync)
  add_to_serializer(:"boards/card", :kanban_dev_bot) do
    if KanbanDevBot::Lifecycle.enabled?(object.board_id)
      KanbanDevBot::Lifecycle.presentation(object)
    end
  end
  %i[can_move can_delete].each do |capability|
    add_to_serializer(:"boards/card", capability) do
      !KanbanDevBot::Lifecycle.enabled?(object.board_id) ||
        KanbanDevBot::Lifecycle.presentation(object)[capability]
    end
  end
  add_to_serializer(:"boards/column", :bot_controlled) do
    KanbanDevBot::Lifecycle.enabled?(object.board_id) &&
      KanbanDevBot::Lifecycle::BOT_COLUMNS.include?(object.title)
  end
  add_to_serializer(:"boards/basic_column", :can_add_cards) do
    !KanbanDevBot::Lifecycle.enabled?(object.board_id) || %w[BACKLOG TODO].include?(object.title)
  end
  add_to_serializer(:"boards/column", :can_receive_cards) do
    !KanbanDevBot::Lifecycle.enabled?(object.board_id) ||
      %w[BACKLOG TODO DONE].include?(object.title)
  end
  add_to_serializer(:"boards/column", :can_add_cards) do
    !KanbanDevBot::Lifecycle.enabled?(object.board_id) || %w[BACKLOG TODO].include?(object.title)
  end
  add_to_serializer(:"boards/column", :can_clear) do
    !KanbanDevBot::Lifecycle.enabled?(object.board_id) ||
      object.cards.none? do |card|
        KanbanDevBot::Lifecycle.accepted?(KanbanDevBot::Lifecycle.run(card))
      end
  end
  add_to_serializer(:"boards/column", :can_delete) do
    !KanbanDevBot::Lifecycle.enabled?(object.board_id)
  end
  require_relative "lib/kanban_dev_bot/topic_cards"
  Boards::CreateCard.prepend(KanbanDevBot::TopicCards)
  require_relative "lib/kanban_dev_bot/requeue_review_card"
  on(:post_created) { |post, options| KanbanDevBot::RequeueReviewCard.call(post, options) }
  require_relative "lib/kanban_dev_bot/deleted_topic_cards"
  Boards::DestroyCard.prepend(KanbanDevBot::DeletedTopicCards)
end
