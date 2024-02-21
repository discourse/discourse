# frozen_string_literal: true

module Chat
  # fixme andrei drop
  module NotificationExtension
    extend ActiveSupport::Concern

    # fixme andrei build notification data can be in chat_mention
    def self.build_chat_mention_notification_data(chat_mention)
      message = chat_mention.chat_message
      channel = message.chat_channel

      data = {
        chat_message_id: message.id,
        chat_channel_id: channel.id,
        is_direct_message_channel: channel.direct_message_channel?,
        mentioned_by_username: message.user.username,
      }

      data[:chat_thread_id] = message.thread_id if message.in_thread?

      if channel.direct_message_channel?
        data[:chat_channel_title] = channel.title(chat_mention.user)
        data[:chat_channel_slug] = channel.slug
      end

      return data if chat_mention.is_a?(::Chat::UserMention)

      case chat_mention
      when ::Chat::HereMention
        data[:identifier] = "here"
      when ::Chat::AllMention
        data[:identifier] = "all"
      when ::Chat::GroupMention
        data[:identifier] = chat_mention.group.name
        data[:is_group_mention] = true
      else
        raise "Unknown chat mention type"
      end

      data
    end
  end
end
