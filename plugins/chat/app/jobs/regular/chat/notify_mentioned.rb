# frozen_string_literal: true

module Jobs
  module Chat
    class NotifyMentioned < ::Jobs::Base
      # fixme andrei preload user on mentions
      # fixme preload chat_channel and other stuff?
      def execute(args)
        @message = ::Chat::Message.find(args[:message_id])
        @sender = @message.user
        @channel = @message.chat_channel
        @parsed_mentions = @message.parsed_mentions

        notify_mentioned
        notify_about_groups_with_to_many_members
      end

      private

      def notify_about_groups_with_to_many_members
        groups_with_too_many_members = @parsed_mentions.groups_with_too_many_members
        return if groups_with_too_many_members.empty?

        ::Chat::Publisher.publish_notice(
          user_id: @sender.id,
          channel_id: @channel.id,
          text_content:
            ::Chat::Notices.groups_have_too_many_members_for_being_mentioned(
              groups_with_too_many_members.to_a,
            ),
        )
      end

      def notify_mentioned
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

      def notify(mention, mentioned_user)
        return unless user_participate_in_channel?(mentioned_user)
        return if mentioned_user.ignores?(@sender) # fixme andrei take care of n + 1's

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

      # fixme andrei make it user.participate_in?(@channel)
      def user_participate_in_channel?(user)
        @channel.membership_for(user).present?
      end
    end
  end
end
