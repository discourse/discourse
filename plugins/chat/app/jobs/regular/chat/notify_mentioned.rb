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
        @already_notified_user_ids = load_already_notified_user_ids

        notify_mentioned_users
        ::Chat::MentionsWarnings.send_for(@message)
      end

      private

      def already_notified?(mentioned_user)
        @already_notified_user_ids.include?(mentioned_user.id)
      end

      def get_mention(type, target_id = nil)
        @message.chat_mentions.where(type: type, target_id: target_id).first
      end

      def load_already_notified_user_ids
        user_ids =
          @message
            .chat_mentions
            .joins(
              "LEFT OUTER JOIN chat_mention_notifications cmn ON cmn.chat_mention_id = chat_mentions.id",
            )
            .joins("LEFT OUTER JOIN notifications n ON cmn.notification_id = n.id")
            .where.not("n.user_id IS NULL")
            .pluck("n.user_id")
        Set.new(user_ids)
      end

      def notify_mentioned_users
        # fixme andrei add a comment about precedence
        @message.user_mentions.each { |mention| notify(mention, mention.user) }

        if @message.here_mention
          @channel.members_here.each { |user| notify(@message.here_mention, user) }
        end

        @channel.members.each { |user| notify(@message.all_mention, user) } if @message.all_mention

        @parsed_mentions.all_users_reached_by_mentions_info.each do |info|
          mentioned_user = info[:user]
          mention = get_mention(info[:type], info[:target_id])
          notify(mention, mentioned_user)
        end
      end

      def notify(mention, mentioned_user)
        return if already_notified?(mentioned_user) || should_not_notify?(mention, mentioned_user)
        mention.create_notification_for(mentioned_user)
        @already_notified_user_ids << mentioned_user.id

        send_notifications(mention, mentioned_user)
      end

      def send_notifications(mention, mentioned_user)
        membership = @channel.membership_for(mentioned_user) # fixme andrei take care of N + 1
        return if membership.muted?

        payload = mention.notification_payload(mentioned_user)
        unless membership.desktop_notifications_never?
          ::PostAlerter.desktop_notification(mentioned_user, payload)
        end
        unless membership.mobile_notifications_never?
          ::PostAlerter.push_notification(mentioned_user, payload)
        end
      end

      def should_not_notify?(mention, mentioned_user)
        return true unless mentioned_user.user_option.chat_enabled

        if mention.is_mass_mention? &&
             (
               !@channel.allow_channel_wide_mentions ||
                 mentioned_user.user_option.ignore_channel_wide_mention
             )
          return true
        end

        mentioned_user.suspended? || mentioned_user == @sender ||
          mentioned_user.doesnt_want_to_hear_from(@sender) || !mentioned_user.following?(@channel)
      end
    end
  end
end
