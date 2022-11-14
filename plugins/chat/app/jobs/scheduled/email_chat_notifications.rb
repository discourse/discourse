# frozen_string_literal: true

module Jobs
  class EmailChatNotifications < ::Jobs::Scheduled
    every 5.minutes

    def execute(args = {})
      return unless SiteSetting.chat_enabled

      Chat::ChatMailer.send_unread_mentions_summary
    end
  end
end
