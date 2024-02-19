# frozen_string_literal: true

module Jobs
  module Chat
    class NotifyMentioned < ::Jobs::Base
      # fixme andrei preload user on mentions
      # fixme preload chat_channel and other stuff?
      def execute(args)
        @message = ::Chat::Message.find(args[:message_id])
        @parsed_mentions = @message.parsed_mentions

        # fixme andrei dry up
        @parsed_mentions.direct_mentions.each do |mentioned_user|
          mention = @message.user_mentions.where(target_id: mentioned_user.id).first
          notify(mention, mentioned_user)
        end

        @parsed_mentions.group_mentions.each do |mentioned_user|
          mention = choose_group_mention(mentioned_user)
          notify(mention, mentioned_user)
        end

        @parsed_mentions.global_mentions.each do |mentioned_user|
          notify(@message.all_mention, mentioned_user)
        end

        @parsed_mentions.here_mentions.each do |mentioned_user|
          notify(@message.here_mention, mentioned_user)
        end
      end

      private

      def notify(mention, mentioned_user)
        create_notification!(mention, mentioned_user)
        ::Chat::DesktopNotifier.notify_mentioned(mention, mentioned_user)
      end

      # fixme andrei move into Notification
      def create_notification!(mention, mentioned_user)
        # fixme andrei shouldn't this be already excluded from parsed_mentions?
        return if mentioned_user.id == @message.user_id

        notification =
          ::Notification.create!(
            notification_type: ::Notification.types[:chat_mention],
            user_id: mentioned_user.id,
            high_priority: true,
            data: mention.notification_data(mentioned_user).to_json,
          )
        mention.notifications << notification
      end

      # fixme andrei refactor in a way so we can get rid of this method
      def choose_group_mention(user)
        # fixme andrei get rid of nil
        mention = nil
        @parsed_mentions.groups_to_mention.each do |group|
          if user.groups.include?(group)
            mention = @message.group_mentions.where(target_id: group.id).first
            break
          end
        end

        mention
      end
    end
  end
end
