# frozen_string_literal: true

module Jobs
  module Chat
    class NotifyMentioned < ::Jobs::Base
      def execute(args)
        @message = ::Chat::Message.find(args[:message_id])
        parsed_mentions = @message.parsed_mentions

        parsed_mentions.global_mentions.each do |user|
          create_notification!(@message.all_mention, user)
        end

        parsed_mentions.here_mentions.each do |user|
          create_notification!(@message.here_mention, user)
        end
      end

      private

      def create_notification!(mention, user)
        # fixme andrei shouldn't this be already excluded from parsed_mentions?
        return if user.id == @message.user_id

        notification =
          ::Notification.create!(
            notification_type: ::Notification.types[:chat_mention],
            user_id: user.id,
            high_priority: true,
            data: [], # fixme andrei
          )
        mention.notifications << notification
      end
    end
  end
end
