# frozen_string_literal: true

module Jobs
  module Chat
    class EmailNotifications < ::Jobs::Scheduled
      every 5.seconds

      def execute(args = {})
        Rails.logger.info("xxxxx execute")
        return if !SiteSetting.chat_enabled
        Rails.logger.info("xxxxx execut2e")

        ::Chat::Mailer.send_unread_mentions_summary
      end
    end
  end
end
