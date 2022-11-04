# frozen_string_literal: true

class UserChatChannelMembershipSerializer < ApplicationSerializer
  attributes :following,
             :muted,
             :desktop_notification_level,
             :mobile_notification_level,
             :chat_channel_id,
             :last_read_message_id,
             :unread_count,
             :unread_mentions

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def user
    object.user
  end
end
