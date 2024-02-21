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

    # fixme andrei actually move it to notification (but leave polymorphic parts in mentions)
    def notification_data(mentioned_user)
      message = self.chat_message
      channel = message.chat_channel

      data = {
        chat_message_id: message.id,
        chat_channel_id: channel.id,
        is_direct_message_channel: channel.direct_message_channel?,
        mentioned_by_username: message.user.username,
      }

      data[:chat_thread_id] = message.thread_id if message.in_thread?

      unless channel.direct_message_channel?
        data[:chat_channel_title] = channel.title(mentioned_user)
        data[:chat_channel_slug] = channel.slug
      end

      # fixme andrei handle this in subclasses
      return data if self.is_a?(::Chat::UserMention)

      case self
      when ::Chat::HereMention
        data[:identifier] = "here"
      when ::Chat::AllMention
        data[:identifier] = "all"
      when ::Chat::GroupMention
        data[:identifier] = self.group.name
        data[:is_group_mention] = true
      else
        raise "Unknown chat mention type"
      end

      data
    end

    # fixme andrei a better place for this?
    def self.notification_payload(chat_mention, mentioned_user)
      message = chat_mention.chat_message
      channel = message.chat_channel

      post_url =
        if message.in_thread?
          message.thread.relative_url
        else
          "#{channel.relative_url}/#{message.id}"
        end

      payload = {
        notification_type: ::Notification.types[:chat_mention],
        username: message.user.username,
        tag: ::Chat::Notifier.push_notification_tag(:mention, channel.id),
        excerpt: message.push_notification_excerpt,
        post_url: post_url,
      }

      translation_prefix =
        (
          if channel.direct_message_channel?
            "discourse_push_notifications.popup.direct_message_chat_mention"
          else
            "discourse_push_notifications.popup.chat_mention"
          end
        )

      translation_suffix = chat_mention.is_a?(::Chat::UserMention) ? "direct" : "other_type"

      identifier_text =
        case chat_mention
        when ::Chat::HereMention
          "@here"
        when ::Chat::AllMention
          "@all"
        when ::Chat::UserMention
          ""
        when ::Chat::GroupMention
          "@#{chat_mention.group.name}"
        else
          raise "Unknown mention type"
        end

      payload[:translated_title] = ::I18n.t(
        "#{translation_prefix}.#{translation_suffix}",
        username: message.user.username,
        identifier: identifier_text,
        channel: channel.title(mentioned_user),
      )

      payload
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
