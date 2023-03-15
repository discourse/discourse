# frozen_string_literal: true

module Jobs
  class ChatEmailNotifications < ::Jobs::Scheduled
    every 5.minutes

    def execute(args = {})
      return unless SiteSetting.chat_enabled

      Chat::Mailer.send_unread_mentions_summary
    end
  end
end
