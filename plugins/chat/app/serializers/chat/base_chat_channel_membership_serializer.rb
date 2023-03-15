# frozen_string_literal: true

module Chat
  class BaseChatChannelMembershipSerializer < ApplicationSerializer
    attributes :following,
               :muted,
               :desktop_notification_level,
               :mobile_notification_level,
               :chat_channel_id,
               :last_read_message_id,
               :unread_count,
               :unread_mentions
  end
end
