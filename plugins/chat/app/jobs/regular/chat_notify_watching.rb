# frozen_string_literal: true

module Jobs
  class ChatNotifyWatching < ::Jobs::Base
    def execute(args = {})
      @chat_message =
        Chat::Message.includes(:user, chat_channel: :chatable).find_by(id: args[:chat_message_id])
      return if @chat_message.nil?

      @creator = @chat_message.user
      @chat_channel = @chat_message.chat_channel
      @is_direct_message_channel = @chat_channel.direct_message_channel?

      always_notification_level = Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always]

      members =
        Chat::UserChatChannelMembership
          .includes(user: :groups)
          .joins(user: :user_option)
          .where(user_option: { chat_enabled: true })
          .where.not(user_id: args[:except_user_ids])
          .where(chat_channel_id: @chat_channel.id)
          .where(following: true)
          .where(
            "desktop_notification_level = ? OR mobile_notification_level = ?",
            always_notification_level,
            always_notification_level,
          )
          .merge(User.not_suspended)

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
      return if Chat::Notifier.user_has_seen_message?(membership, @chat_message.id)
      return if online_user_ids.include?(user.id)

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

      payload = {
        username: @creator.username,
        notification_type: Notification.types[:chat_message],
        post_url: @chat_channel.relative_url,
        translated_title: I18n.t(translation_key, translation_args),
        tag: Chat::Notifier.push_notification_tag(:message, @chat_channel.id),
        excerpt: @chat_message.push_notification_excerpt,
      }

      if membership.desktop_notifications_always? && !membership.muted?
        MessageBus.publish("/chat/notification-alert/#{user.id}", payload, user_ids: [user.id])
      end

      if membership.mobile_notifications_always? && !membership.muted?
        PostAlerter.push_notification(user, payload)
      end
    end

    def online_user_ids
      @online_user_ids ||= PresenceChannel.new("/chat/online").user_ids
    end
  end
end
