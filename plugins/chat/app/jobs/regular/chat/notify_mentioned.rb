# frozen_string_literal: true

module Jobs
  module Chat
    class NotifyMentioned < ::Jobs::Base
      # fixme andrei preload user on mentions
      # fixme preload chat_channel and other stuff?
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

      def create_notification!(mention, mentioned_user)
        # fixme andrei shouldn't this be already excluded from parsed_mentions?
        return if mentioned_user.id == @message.user_id

        notification =
          ::Notification.create!(
            notification_type: ::Notification.types[:chat_mention],
            user_id: mentioned_user.id,
            high_priority: true,
            data: mention.notification_data,
          )
        mention.notifications << notification
      end
    end
  end
end
