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
             :meta

  def meta
    { can_join_chat_channel: scope.can_join_chat_channel?(object.chat_channel) }
  end
end
