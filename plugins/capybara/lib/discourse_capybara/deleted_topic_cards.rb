# frozen_string_literal: true

module ::DiscourseCapybara
  module DeletedTopicCards
    private

    def destroy(card:, guardian:)
      if Rails.env.production? || !SiteSetting.capybara_enabled ||
           card.board_id != CodexBoardBot::BOARD_ID || !card.topic?
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
