# frozen_string_literal: true

module ::KanbanDevBot
  module DeletedTopicCards
    private

    def destroy(card:, guardian:)
      if Rails.env.production? || !SiteSetting.kanban_dev_bot_enabled ||
           card.board_id != KanbanDevBot::BOARD_ID || !card.topic?
        return super
      end

      topic = card.topic
      return super if topic.blank?
      raise Discourse::InvalidAccess if !topic.closed? && !guardian.can_close_topic?(topic)

      card.class.transaction do
        super
        topic.update_status("closed", true, guardian.user) unless topic.closed?
      end
    end
  end
end
