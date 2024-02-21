# frozen_string_literal: true

module Jobs
  module Chat
    class NotifyMentioned < ::Jobs::Base
      def execute(args)
        # fixme andrei preload user on mentions
        # fixme preload chat_channel and other stuff?
        @message = ::Chat::Message.find(args[:message_id])
        @parsed_mentions = @message.parsed_mentions
        return if @parsed_mentions.count > SiteSetting.max_mentions_per_chat_message

        @sender = @message.user
        @channel = @message.chat_channel
        @all_mentioned_users = User.where(id: @parsed_mentions.all_mentioned_users_ids).to_a # fixme andrei make sure to be efficient with this

        notify_mentioned_users
        notify_about_users_not_participating_in_channel
        notify_about_users_who_cannot_join_chanel
        notify_about_groups_with_to_many_members
        notify_about_groups_with_disabled_mentions
        notify_if_global_mentions_are_disabled
      end

      private

      def notify_about_groups_with_disabled_mentions
        groups = @parsed_mentions.groups_with_disabled_mentions
        return if groups.empty?

        notice = ::Chat::MentionNotices.groups_have_mentions_disabled(groups)
        publish_notice(notice)
      end

      def notify_about_groups_with_to_many_members
        groups = @parsed_mentions.groups_with_too_many_members
        return if groups.empty?

        notice = ::Chat::MentionNotices.groups_have_too_many_members(groups.to_a)
        publish_notice(notice)
      end

      def notify_about_users_not_participating_in_channel
        users =
          @all_mentioned_users.filter do |user|
            user.guardian.can_join_chat_channel?(@channel) && !user_participate_in_channel?(user) &&
              !user.mutes?(@sender) && !user.ignores?(@sender)
          end
        return if users.empty?

        notice = ::Chat::MentionNotices.users_do_not_participate_in_channel(users, @message.id)
        publish_notice(notice)
      end

      def notify_about_users_who_cannot_join_chanel
        users =
          @all_mentioned_users.filter { |user| !user.guardian.can_join_chat_channel?(@channel) }
        return if users.empty?

        notice = ::Chat::MentionNotices.users_cannot_join_channel(users)
        publish_notice(notice)
      end

      def notify_if_global_mentions_are_disabled
        return if !@parsed_mentions.has_global_mention && !@parsed_mentions.has_here_mention

        unless @channel.allow_channel_wide_mentions
          publish_notice(::Chat::MentionNotices.global_mentions_disabled)
        end
      end

      def notify_mentioned_users
        # fixme andrei dry up
        @parsed_mentions.direct_mentions.each do |mentioned_user|
          mention = @message.user_mentions.where(target_id: mentioned_user.id).first
          notify(mention, mentioned_user)
        end

        @parsed_mentions.group_mentions.each do |mentioned_user|
          mention = choose_group_mention(mentioned_user)
          notify(mention, mentioned_user)
        end

        return unless @channel.allow_channel_wide_mentions

        @parsed_mentions.global_mentions.each do |mentioned_user|
          notify(@message.all_mention, mentioned_user)
        end

        @parsed_mentions.here_mentions.each do |mentioned_user|
          notify(@message.here_mention, mentioned_user)
        end
      end

      def notify(mention, mentioned_user)
        return if @sender == mentioned_user
        return if mentioned_user.suspended?
        return unless user_participate_in_channel?(mentioned_user)
        return if mentioned_user.ignores?(@sender) || mentioned_user.mutes?(@sender) # fixme andrei take care of n + 1's
        return if mentioned_user.user_option.ignore_channel_wide_mention # fixme andrei take care of N + 1

        create_notification!(mention, mentioned_user)
        ::Chat::DesktopNotifier.notify_mentioned(mention, mentioned_user)

        # fixme andrei take care of N + 1
        # fixme andrei introduce MobileNotifier?
        payload = ::Chat::Mention.notification_payload(mention, mentioned_user)
        membership = mention.chat_message.chat_channel.membership_for(mentioned_user)
        if !membership.mobile_notifications_never? && !membership.muted?
          ::PostAlerter.push_notification(mentioned_user, payload)
        end
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

      def publish_notice(params)
        ::Chat::Publisher.publish_notice(user_id: @sender.id, channel_id: @channel.id, **params)
      end

      # fixme andrei make it user.participate_in?(@channel)
      def user_participate_in_channel?(user)
        membership = @channel.membership_for(user)
        membership.present? && membership.following
      end
    end
  end
end
