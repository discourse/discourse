# frozen_string_literal: true

module Jobs
  class ChatNotifyWatching < ::Jobs::Base
    def execute(args = {})
      @chat_message =
        ChatMessage.includes(:user, chat_channel: :chatable).find_by(id: args[:chat_message_id])
      return if @chat_message.nil?

      @creator = @chat_message.user
      @chat_channel = @chat_message.chat_channel
      @is_direct_message_channel = @chat_channel.direct_message_channel?

      always_notification_level = UserChatChannelMembership::NOTIFICATION_LEVELS[:always]

      direct_mentioned_user_ids = args[:direct_mentioned_user_ids].to_a
      global_mentions = args[:global_mentions].to_a
      mentioned_group_ids = args[:mentioned_group_ids].to_a

      members =
        UserChatChannelMembership
          .includes(:user)
          .joins(user: :user_option)
          .where(user_option: { chat_enabled: true })
          .where(chat_channel_id: @chat_channel.id)
          .where(following: true, muted: false)
          .where(
            "COALESCE(user_chat_channel_memberships.last_read_message_id, 0) < ?",
            @chat_message.id
          )
          .where.not(user_id: direct_mentioned_user_ids)
          .where(
            "desktop_notification_level = ? OR mobile_notification_level = ?",
            always_notification_level,
            always_notification_level,
          )
          .merge(User.not_suspended)

      if mentioned_group_ids.present?
        members = members
          .joins("LEFT OUTER JOIN group_users gu ON gu.user_id = users.id")
          .group("user_chat_channel_memberships.id")
          .having("COUNT(gu.group_id) = 0 OR bool_and(gu.group_id NOT IN (?))", mentioned_group_ids)
      end

      if global_mentions.include?(Chat::ChatNotifier::ALL_KEYWORD)
        members = members.where(user_option: { ignore_channel_wide_mention: true })
      elsif global_mentions.include?(Chat::ChatNotifier::HERE_KEYWORD)
        members = members.where("last_seen_at < ?", 5.minutes.ago)
      end

      if @is_direct_message_channel
        UserCommScreener
          .new(acting_user: @creator, target_user_ids: members.map(&:user_id))
          .allowing_actor_communication
          .each do |user_id|
            send_notifications(members.find { |member| member.user_id == user_id })
          end
      else
        members.each { |member| send_notifications(member) }
      end
    end

    def send_notifications(membership)
      user = membership.user
      guardian = Guardian.new(user)
      return unless guardian.can_chat? && guardian.can_join_chat_channel?(@chat_channel)
      return if online_user_ids.include?(user.id)

      payload = build_watching_payload(user)

      if membership.desktop_notifications_always?
        MessageBus.publish("/chat/notification-alert/#{user.id}", payload, user_ids: [user.id])
      end

      PostAlerter.push_notification(user, payload) if membership.mobile_notifications_always?
    end

    def online_user_ids
      @online_user_ids ||= PresenceChannel.new("/chat/online").user_ids
    end

    def build_watching_payload(user)
      translation_key =
        (
          if @is_direct_message_channel
            "discourse_push_notifications.popup.new_direct_chat_message"
          else
            "discourse_push_notifications.popup.new_chat_message"
          end
        )

      translation_args = { username: @creator.username }
      translation_args[:channel] = @chat_channel.title(user) unless @is_direct_message_channel

      {
        username: @creator.username,
        notification_type: Notification.types[:chat_message],
        post_url: @chat_channel.relative_url,
        translated_title: I18n.t(translation_key, translation_args),
        tag: Chat::ChatNotifier.push_notification_tag(:message, @chat_channel.id),
        excerpt: @chat_message.push_notification_excerpt,
      }
    end
  end
end
