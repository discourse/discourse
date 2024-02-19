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
    def notification_data
      message = self.chat_message
      channel = message.chat_channel

      data = {
        chat_message_id: message.id,
        chat_channel_id: channel.id,
        is_direct_message_channel: channel.direct_message_channel?,
        mentioned_by_username: message.user.username,
      }

      data[:chat_thread_id] = message.thread_id if message.in_thread?

      if channel.direct_message_channel?
        data[:chat_channel_title] = channel.title(self.user)
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
