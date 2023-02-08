# frozen_string_literal: true

class BaseChatChannelMembershipSerializer < ApplicationSerializer
  attributes :following,
             :muted,
             :desktop_notification_level,
             :mobile_notification_level,
             :chat_channel_id,
             :last_read_message_id,
             :unread_count,
             :unread_mentions,
             :can_join_chat_channel

  def can_join_chat_channel
    chat_channel = ChatChannel.find_by(id: object[:chat_channel_id])
    scope.can_join_chat_channel?(chat_channel) if chat_channel
  end
end
