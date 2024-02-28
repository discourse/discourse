# frozen_string_literal: true

module Chat
  class Mention < ActiveRecord::Base
    self.table_name = "chat_mentions"
    self.ignored_columns = %w[notification_id user_id]

    belongs_to :chat_message, class_name: "Chat::Message"
    has_many :mention_notifications,
             class_name: "Chat::MentionNotification",
             foreign_key: :chat_mention_id
    has_many :notifications, through: :mention_notifications, dependent: :destroy

    def create_notification_for(mentioned_user)
      notification =
        ::Notification.create!(
          notification_type: notification_type,
          user_id: mentioned_user.id,
          high_priority: true,
          data: notification_data(mentioned_user).to_json,
        )
      notifications << notification
    end

    def identifier
      raise "Not Implemented"
    end

    def is_group_mention
      false
    end

    def notification_data(mentioned_user)
      channel = chat_message.chat_channel

      data = {
        chat_message_id: chat_message.id,
        chat_channel_id: channel.id,
        is_direct_message_channel: channel.direct_message_channel?,
        mentioned_by_username: chat_message.user.username,
        is_group_mention: is_group_mention,
        identifier: identifier,
      }

      data[:chat_thread_id] = chat_message.thread_id if chat_message.in_thread?
      data[:chat_channel_title] = channel.title(mentioned_user)
      data[:chat_channel_slug] = channel.slug

      data
    end

    def notification_payload(mentioned_user)
      channel = chat_message.chat_channel

      post_url =
        if chat_message.in_thread?
          chat_message.thread.relative_url
        else
          "#{channel.relative_url}/#{chat_message.id}"
        end

      translation_prefix =
        (
          if channel.direct_message_channel?
            "discourse_push_notifications.popup.direct_message_chat_mention"
          else
            "discourse_push_notifications.popup.chat_mention"
          end
        )

      {
        notification_type: notification_type,
        username: chat_message.user.username,
        tag: Chat::PushNotificationTag.for_mention(channel.id),
        excerpt: chat_message.push_notification_excerpt,
        post_url: post_url,
        translated_title:
          ::I18n.t(
            "#{translation_prefix}.#{translation_suffix}",
            username: chat_message.user.username,
            identifier: "@#{identifier}",
            channel: channel.title(mentioned_user),
          ),
      }
    end

    def should_notify?(user)
      true
    end

    private

    def notification_type
      ::Notification.types[:chat_mention]
    end

    def translation_suffix
      "other_type"
    end
  end
end

# == Schema Information
#
# Table name: chat_mentions
#
#  id              :bigint           not null, primary key
#  chat_message_id :integer          not null
#  user_id         :integer
#  notification_id :integer          not null
#  target_id       :integer
#  type            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
# index_chat_mentions_on_chat_message_id    (chat_message_id)
# index_chat_mentions_on_target_id          (target_id)
#
