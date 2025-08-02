# frozen_string_literal: true

module Jobs
  module Chat
    class EmailNotifications < ::Jobs::Scheduled
      every 5.minutes

      def execute(args = {})
        return if !SiteSetting.chat_enabled

        ::Chat::Mailer.send_unread_mentions_summary
      end
    end
  end
end
